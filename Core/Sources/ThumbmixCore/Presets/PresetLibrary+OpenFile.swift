import Foundation

/// A `.json` opened in Thumbmix from AirDrop, Mail, Messages or the Files share sheet.
extension PresetLibrary {
    /// Copies the file On this iPhone, checked as any other preset, and says where it went; or says why it was
    /// refused. Always a message to show: a file that did nothing, silently, would look like a broken app.
    public func openFile(at url: URL) -> String {
        defer { removeInboxCopy(url) }
        do {
            let entry = try importPreset(at: url)
            return CoreStrings.text("Added “\(entry.preset.name)” to your presets On this iPhone. Open a strip's Presets to use it.")
        } catch {
            return CoreStrings.text("\(url.lastPathComponent) was not added: \(error.localizedDescription)")
        }
    }

    /// Nothing is asked on import: asking happens on loading. Access is held only while the file is read: a file opened
    /// in place from Files carries it, a copy in the app's own folder doesn't need it.
    private func importPreset(at url: URL) throws -> LibraryEntry {
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        return try save(PresetFiles.preset(at: url))
    }

    /// Mail and Messages hand the app a copy in the inbox, which the Files app lists: it goes once imported or refused,
    /// or every file would show twice. A file anywhere else is the engineer's own.
    private func removeInboxCopy(_ url: URL) {
        guard let inbox, BookmarkAccess.path(of: url.deletingLastPathComponent()) == BookmarkAccess.path(of: inbox) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
