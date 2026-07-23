#!/usr/bin/env bash

set -euo pipefail

TAGLIB_VERSION="2.1.1"
TAGLIB_TAG="v${TAGLIB_VERSION}"
TAGLIB_COMMIT="7d86716194777e0294453bfdc9dd170bd033e1f4"
UTF8CPP_COMMIT="df857efc5bbc2aa84012d865f7d7e9cccdc08562"
TAGLIB_REPOSITORY="https://github.com/taglib/taglib.git"
MACOS_DEPLOYMENT_TARGET="13.0"
IOS_DEPLOYMENT_TARGET="16.0"

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
OUTPUT_PATH="${REPOSITORY_ROOT}/Vendor/TagLibBinaryPackage/Artifacts/TagLib.xcframework"
SOURCE_PATH=""
KEEP_WORK_DIRECTORY=0
REPLACE_OUTPUT=0

usage() {
    echo "Usage: $0 [--output PATH] [--source-dir PATH] [--keep-work-dir] [--replace]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        --source-dir)
            SOURCE_PATH="$2"
            shift 2
            ;;
        --keep-work-dir)
            KEEP_WORK_DIRECTORY=1
            shift
            ;;
        --replace)
            REPLACE_OUTPUT=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "${OUTPUT_PATH}" in
    *.xcframework) ;;
    *)
        echo "Output path must end in .xcframework: ${OUTPUT_PATH}" >&2
        exit 2
        ;;
esac

for required_tool in cmake git install_name_tool lipo ninja otool plutil shasum xcodebuild; do
    if ! command -v "${required_tool}" >/dev/null 2>&1; then
        echo "Required tool not found: ${required_tool}" >&2
        exit 1
    fi
done

WORK_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/taglib-xcframework.XXXXXX")"

cleanup() {
    if [[ "${KEEP_WORK_DIRECTORY}" -eq 1 ]]; then
        echo "Kept work directory: ${WORK_DIRECTORY}"
        return
    fi

    case "${WORK_DIRECTORY}" in
        "${TMPDIR:-/tmp}"/taglib-xcframework.*)
            rm -rf "${WORK_DIRECTORY}"
            ;;
        *)
            echo "Refusing to remove unexpected work directory: ${WORK_DIRECTORY}" >&2
            ;;
    esac
}
trap cleanup EXIT

if [[ -e "${OUTPUT_PATH}" ]]; then
    if [[ "${REPLACE_OUTPUT}" -ne 1 ]]; then
        echo "Output already exists; pass --replace to replace it: ${OUTPUT_PATH}" >&2
        exit 1
    fi
    rm -rf "${OUTPUT_PATH}"
fi

if [[ -z "${SOURCE_PATH}" ]]; then
    SOURCE_PATH="${WORK_DIRECTORY}/taglib"
    git clone --branch "${TAGLIB_TAG}" --depth 1 "${TAGLIB_REPOSITORY}" "${SOURCE_PATH}"
    git -C "${SOURCE_PATH}" submodule update --init --depth 1 3rdparty/utfcpp
else
    SOURCE_PATH="$(cd "${SOURCE_PATH}" && pwd)"
fi

ACTUAL_TAGLIB_COMMIT="$(git -C "${SOURCE_PATH}" rev-parse HEAD)"
ACTUAL_UTF8CPP_COMMIT="$(git -C "${SOURCE_PATH}/3rdparty/utfcpp" rev-parse HEAD)"

if [[ "${ACTUAL_TAGLIB_COMMIT}" != "${TAGLIB_COMMIT}" ]]; then
    echo "TagLib commit mismatch: expected ${TAGLIB_COMMIT}, got ${ACTUAL_TAGLIB_COMMIT}" >&2
    exit 1
fi

if [[ "${ACTUAL_UTF8CPP_COMMIT}" != "${UTF8CPP_COMMIT}" ]]; then
    echo "utf8cpp commit mismatch: expected ${UTF8CPP_COMMIT}, got ${ACTUAL_UTF8CPP_COMMIT}" >&2
    exit 1
fi

if [[ -n "$(git -C "${SOURCE_PATH}" status --porcelain --untracked-files=all)" ]] ||
   [[ -n "$(git -C "${SOURCE_PATH}/3rdparty/utfcpp" status --porcelain --untracked-files=all)" ]]; then
    echo "TagLib source tree is modified; refusing to build" >&2
    exit 1
fi

configure_and_build() {
    local build_name="$1"
    local system_name="$2"
    local sdk_name="$3"
    local deployment_target="$4"
    local architectures="$5"
    local build_directory="${WORK_DIRECTORY}/build-${build_name}"

    local cmake_arguments=(
        -S "${SOURCE_PATH}"
        -B "${build_directory}"
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_FRAMEWORK=ON
        -DBUILD_SHARED_LIBS=ON
        -DBUILD_TESTING=OFF
        -DBUILD_EXAMPLES=OFF
        -DBUILD_BINDINGS=OFF
        -DWITH_ZLIB=ON
        -DVISIBILITY_HIDDEN=ON
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${deployment_target}"
        -DCMAKE_OSX_ARCHITECTURES="${architectures}"
    )

    if [[ -n "${system_name}" ]]; then
        cmake_arguments+=(
            -DCMAKE_SYSTEM_NAME="${system_name}"
            -DCMAKE_OSX_SYSROOT="${sdk_name}"
        )
    fi

    cmake "${cmake_arguments[@]}"
    cmake --build "${build_directory}" --config Release
}

stage_framework() {
    local build_name="$1"
    local staged_framework="${WORK_DIRECTORY}/framework-${build_name}/TagLib.framework"
    local built_framework="${WORK_DIRECTORY}/build-${build_name}/taglib/tag.framework"

    mkdir -p "${staged_framework}/Headers" "${staged_framework}/Modules"
    ditto "${built_framework}/Headers" "${staged_framework}/Headers"
    cp "${built_framework}/tag" "${staged_framework}/TagLib"
    chmod 755 "${staged_framework}/TagLib"
    install_name_tool -id "@rpath/TagLib.framework/TagLib" "${staged_framework}/TagLib"

    printf '%s\n' \
        'framework module TagLib {' \
        '  umbrella header "taglib.h"' \
        '  export *' \
        '  module * { export * }' \
        '}' \
        > "${staged_framework}/Modules/module.modulemap"

    plutil -create xml1 "${staged_framework}/Info.plist"
    plutil -insert CFBundleDevelopmentRegion -string English "${staged_framework}/Info.plist"
    plutil -insert CFBundleExecutable -string TagLib "${staged_framework}/Info.plist"
    plutil -insert CFBundleIdentifier -string org.taglib.TagLib "${staged_framework}/Info.plist"
    plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "${staged_framework}/Info.plist"
    plutil -insert CFBundleName -string TagLib "${staged_framework}/Info.plist"
    plutil -insert CFBundlePackageType -string FMWK "${staged_framework}/Info.plist"
    plutil -insert CFBundleShortVersionString -string "${TAGLIB_VERSION}" "${staged_framework}/Info.plist"
    plutil -insert CFBundleVersion -string "${TAGLIB_VERSION}" "${staged_framework}/Info.plist"

    echo "${staged_framework}"
}

configure_and_build macos "" "" "${MACOS_DEPLOYMENT_TARGET}" "arm64;x86_64"
configure_and_build ios-device iOS iphoneos "${IOS_DEPLOYMENT_TARGET}" "arm64"
configure_and_build ios-simulator iOS iphonesimulator "${IOS_DEPLOYMENT_TARGET}" "arm64;x86_64"

MACOS_FRAMEWORK="$(stage_framework macos)"
IOS_DEVICE_FRAMEWORK="$(stage_framework ios-device)"
IOS_SIMULATOR_FRAMEWORK="$(stage_framework ios-simulator)"
STAGED_XCFRAMEWORK="${WORK_DIRECTORY}/TagLib.xcframework"

xcodebuild -create-xcframework \
    -framework "${MACOS_FRAMEWORK}" \
    -framework "${IOS_DEVICE_FRAMEWORK}" \
    -framework "${IOS_SIMULATOR_FRAMEWORK}" \
    -output "${STAGED_XCFRAMEWORK}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"
ditto "${STAGED_XCFRAMEWORK}" "${OUTPUT_PATH}"

echo "Created ${OUTPUT_PATH}"
plutil -lint "${OUTPUT_PATH}/Info.plist"
find "${OUTPUT_PATH}" -type f -name TagLib -exec file {} \;
find "${OUTPUT_PATH}" -type f -name TagLib -exec otool -L {} \;
(
    cd "${OUTPUT_PATH}"
    find . -type f ! -name CHECKSUMS.txt -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 shasum -a 256
) > "${OUTPUT_PATH}/CHECKSUMS.txt"
shasum -a 256 "${OUTPUT_PATH}/CHECKSUMS.txt"
