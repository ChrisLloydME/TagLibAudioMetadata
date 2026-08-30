import XCTest
import TagLibAudioMetadata

final class ModelSemanticsTests: XCTestCase {
    func testRandomUIIdentityDoesNotAffectSemanticEqualityOrHashing() {
        let rawA = RawPropertyEntry(key: "ARTIST", value: "One; Two", values: ["One", "Two"], count: 2)
        let rawB = RawPropertyEntry(key: "ARTIST", value: "One; Two", values: ["One", "Two"], count: 2)
        XCTAssertNotEqual(rawA.id, rawB.id)
        XCTAssertEqual(rawA, rawB)
        XCTAssertEqual(Set([rawA, rawB]).count, 1)

        let artworkA = StructuredArtwork(container: "id3v2", mimeType: "image/jpeg", data: Data([1, 2, 3]))
        let artworkB = StructuredArtwork(container: "id3v2", mimeType: "image/jpeg", data: Data([1, 2, 3]))
        XCTAssertNotEqual(artworkA.id, artworkB.id)
        XCTAssertEqual(artworkA, artworkB)
        XCTAssertEqual(Set([artworkA, artworkB]).count, 1)

        let atomA = StructuredMP4Atom(key: "trkn", type: "intPair", first: 1, second: 10)
        let atomB = StructuredMP4Atom(key: "trkn", type: "intPair", first: 1, second: 10)
        XCTAssertNotEqual(atomA.id, atomB.id)
        XCTAssertEqual(atomA, atomB)
        XCTAssertEqual(Set([atomA, atomB]).count, 1)
    }

    func testSemanticChangesStillAffectEquality() {
        let original = StructuredPropertyEntry(key: "ARTIST", values: ["One", "Two"])
        let changed = StructuredPropertyEntry(key: "ARTIST", values: ["One", "Three"])
        XCTAssertNotEqual(original, changed)
    }
}
