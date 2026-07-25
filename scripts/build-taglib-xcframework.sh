#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
VERSION_CONFIGURATION="${SCRIPT_DIRECTORY}/taglib-binary-version.env"

# shellcheck source=taglib-binary-version.env
source "${VERSION_CONFIGURATION}"

TAGLIB_REPOSITORY="https://github.com/taglib/taglib.git"
MACOS_DEPLOYMENT_TARGET="13.0"
IOS_DEPLOYMENT_TARGET="16.0"
OUTPUT_PATH="${REPOSITORY_ROOT}/.build/taglib-binary/TagLib.xcframework"
ARCHIVE_OUTPUT_PATH="${REPOSITORY_ROOT}/.build/taglib-release/${TAGLIB_BINARY_ASSET_NAME}"
SOURCE_PATH=""
KEEP_WORK_DIRECTORY=0
REPLACE_OUTPUT=0

usage() {
    echo "Usage: $0 [--output PATH] [--archive-output PATH] [--source-dir PATH] [--keep-work-dir] [--replace]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        --archive-output)
            ARCHIVE_OUTPUT_PATH="$2"
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

case "${ARCHIVE_OUTPUT_PATH}" in
    *.xcframework.zip) ;;
    *)
        echo "Archive output path must end in .xcframework.zip: ${ARCHIVE_OUTPUT_PATH}" >&2
        exit 2
        ;;
esac

for required_tool in cmake ditto git install_name_tool lipo ninja otool plutil swift unzip vtool xcodebuild zip; do
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

if [[ -e "${ARCHIVE_OUTPUT_PATH}" ]]; then
    if [[ "${REPLACE_OUTPUT}" -ne 1 ]]; then
        echo "Archive already exists; pass --replace to replace it: ${ARCHIVE_OUTPUT_PATH}" >&2
        exit 1
    fi
    rm -f "${ARCHIVE_OUTPUT_PATH}"
fi

if [[ -z "${SOURCE_PATH}" ]]; then
    SOURCE_PATH="${WORK_DIRECTORY}/taglib"
    GIT_TERMINAL_PROMPT=0 git -c credential.helper= clone \
        --branch "${TAGLIB_TAG}" \
        --depth 1 \
        "${TAGLIB_REPOSITORY}" \
        "${SOURCE_PATH}"
    GIT_TERMINAL_PROMPT=0 git -c credential.helper= \
        -C "${SOURCE_PATH}" submodule update --init --depth 1 3rdparty/utfcpp
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
    local platform="$2"
    local staged_framework="${WORK_DIRECTORY}/framework-${build_name}/TagLib.framework"
    local built_framework="${WORK_DIRECTORY}/build-${build_name}/taglib/tag.framework"
    local content_root="${staged_framework}"
    local info_plist="${staged_framework}/Info.plist"

    if [[ "${platform}" == "macos" ]]; then
        content_root="${staged_framework}/Versions/A"
        info_plist="${content_root}/Resources/Info.plist"
        mkdir -p "${content_root}/Headers" "${content_root}/Modules" "${content_root}/Resources"
    else
        mkdir -p "${content_root}/Headers" "${content_root}/Modules"
    fi

    ditto "${built_framework}/Headers" "${content_root}/Headers"
    cp "${built_framework}/tag" "${content_root}/TagLib"
    chmod 755 "${content_root}/TagLib"
    install_name_tool -id "@rpath/TagLib.framework/TagLib" "${content_root}/TagLib"

    printf '%s\n' \
        'framework module TagLib {' \
        '  umbrella header "taglib.h"' \
        '  export *' \
        '  module * { export * }' \
        '}' \
        > "${content_root}/Modules/module.modulemap"

    plutil -create xml1 "${info_plist}"
    plutil -insert CFBundleDevelopmentRegion -string English "${info_plist}"
    plutil -insert CFBundleExecutable -string TagLib "${info_plist}"
    plutil -insert CFBundleIdentifier -string org.taglib.TagLib "${info_plist}"
    plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "${info_plist}"
    plutil -insert CFBundleName -string TagLib "${info_plist}"
    plutil -insert CFBundlePackageType -string FMWK "${info_plist}"
    plutil -insert CFBundleShortVersionString -string "${TAGLIB_VERSION}" "${info_plist}"
    plutil -insert CFBundleVersion -string "${TAGLIB_VERSION}" "${info_plist}"

    if [[ "${platform}" == "macos" ]]; then
        ln -s A "${staged_framework}/Versions/Current"
        ln -s Versions/Current/Headers "${staged_framework}/Headers"
        ln -s Versions/Current/Modules "${staged_framework}/Modules"
        ln -s Versions/Current/Resources "${staged_framework}/Resources"
        ln -s Versions/Current/TagLib "${staged_framework}/TagLib"
    fi

    echo "${staged_framework}"
}

configure_and_build macos "" "" "${MACOS_DEPLOYMENT_TARGET}" "arm64;x86_64"
configure_and_build ios-device iOS iphoneos "${IOS_DEPLOYMENT_TARGET}" "arm64"
configure_and_build ios-simulator iOS iphonesimulator "${IOS_DEPLOYMENT_TARGET}" "arm64;x86_64"

MACOS_FRAMEWORK="$(stage_framework macos macos)"
IOS_DEVICE_FRAMEWORK="$(stage_framework ios-device ios)"
IOS_SIMULATOR_FRAMEWORK="$(stage_framework ios-simulator ios)"
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

verify_slice() {
    local binary_path="$1"
    local expected_platform="$2"
    local expected_minos="$3"
    shift 3
    local expected_architectures=("$@")
    local expected_architecture_count="${#expected_architectures[@]}"
    local build_versions

    test -f "${binary_path}"
    lipo "${binary_path}" -verify_arch "${expected_architectures[@]}"
    build_versions="$(vtool -show-build "${binary_path}")"
    test "$(grep -c "platform ${expected_platform}" <<<"${build_versions}" || true)" -eq "${expected_architecture_count}"
    test "$(grep -c "minos ${expected_minos}" <<<"${build_versions}" || true)" -eq "${expected_architecture_count}"
    otool -D "${binary_path}" | grep -F '@rpath/TagLib.framework/TagLib'
}

MACOS_FRAMEWORK_PATH="${OUTPUT_PATH}/macos-arm64_x86_64/TagLib.framework"
IOS_DEVICE_FRAMEWORK_PATH="${OUTPUT_PATH}/ios-arm64/TagLib.framework"
IOS_SIMULATOR_FRAMEWORK_PATH="${OUTPUT_PATH}/ios-arm64_x86_64-simulator/TagLib.framework"
test -f "${MACOS_FRAMEWORK_PATH}/Versions/A/Resources/Info.plist"
test -L "${MACOS_FRAMEWORK_PATH}/Versions/Current"
test -L "${MACOS_FRAMEWORK_PATH}/TagLib"
verify_slice "${MACOS_FRAMEWORK_PATH}/Versions/A/TagLib" MACOS "${MACOS_DEPLOYMENT_TARGET}" arm64 x86_64
verify_slice "${IOS_DEVICE_FRAMEWORK_PATH}/TagLib" IOS "${IOS_DEPLOYMENT_TARGET}" arm64
verify_slice "${IOS_SIMULATOR_FRAMEWORK_PATH}/TagLib" IOSSIMULATOR "${IOS_DEPLOYMENT_TARGET}" arm64 x86_64

mkdir -p "$(dirname "${ARCHIVE_OUTPUT_PATH}")"
(
    cd "$(dirname "${OUTPUT_PATH}")"
    zip -qry -y "${ARCHIVE_OUTPUT_PATH}" "$(basename "${OUTPUT_PATH}")"
)
unzip -tq "${ARCHIVE_OUTPUT_PATH}"

ARCHIVE_CHECKSUM="$(swift package compute-checksum "${ARCHIVE_OUTPUT_PATH}")"
echo "Created ${ARCHIVE_OUTPUT_PATH}"
echo "Release tag: ${TAGLIB_BINARY_RELEASE_TAG}"
echo "SwiftPM checksum: ${ARCHIVE_CHECKSUM}"
