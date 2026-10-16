import Foundation
import Testing

@testable import ThumbmixCore

/// Guards the app's own strip-icon drawings (`App/Assets.xcassets/StripIcons`, made by `Design/strip-icons`):
/// every desk icon has one, and no two share a drawing, since a shared glyph tells neither icon apart.
struct StripIconArtTests {
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent("../../../App/Assets.xcassets/StripIcons")

    private func svg(_ icon: ConsoleIcon) throws -> String {
        let set = Self.folder.appendingPathComponent("\(icon.imageName).imageset")
        return try String(contentsOf: set.appendingPathComponent("\(icon.imageName).svg"), encoding: .utf8)
    }

    @Test func everyDeskIconHasItsOwnDrawing() throws {
        let drawings = try ConsoleIcon.all.map(svg)
        #expect(Set(drawings).count == ConsoleIcon.all.count, "two icons share a drawing")
    }

    /// Template rendering lets the drawing take the app's colour; kept vectors keep it sharp at any size.
    @Test func everyDrawingIsAVectorTemplate() throws {
        for icon in ConsoleIcon.all {
            let contents = try String(
                contentsOf: Self.folder.appendingPathComponent("\(icon.imageName).imageset/Contents.json"), encoding: .utf8)
            #expect(contents.contains("\"template-rendering-intent\" : \"template\""), "\(icon.imageName)")
            #expect(contents.contains("\"preserves-vector-representation\" : true"), "\(icon.imageName)")
        }
    }
}
