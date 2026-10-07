import SwiftUI
import ThumbmixCore

/// Links this strip with its odd/even neighbour, or unlinks the pair, after a system alert: linking pans the sides
/// hard left and right on the desk, so it is never one stray tap.
struct LinkButton: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var isConfirming = false

    var body: some View {
        let isLinked = mirror.isLinked(strip)
        Button {
            isConfirming = true
        } label: {
            VStack(spacing: 2) {
                Text(isLinked ? "Unlink" : "Stereo link").font(.headline)
                Text(verbatim: detail(isLinked))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("link-button")
        .accessibilityLabel(
            isLinked ? String(localized: "Unlink \(detail(true))") : String(localized: "Stereo link \(detail(false))")
        )
        .alert(title(isLinked), isPresented: $isConfirming) {
            Button("Cancel", role: .cancel) {}
            Button(isLinked ? "Unlink" : "Link") { mirror.setLinked(strip, !isLinked) }
        } message: {
            Text(verbatim: message(isLinked))
        }
    }

    private var odd: StripID { strip.oddSide }
    private var even: StripID { odd.partner ?? odd }

    /// Who the pair is: "with OH R · Ch 8" before linking, both sides once linked.
    private func detail(_ isLinked: Bool) -> String {
        guard !isLinked else { return String(localized: "\(label(odd)) and \(label(even))") }
        return String(localized: "with \(label(strip.partner ?? strip))")
    }

    /// The desk name and number, or the number alone for an unnamed strip.
    private func label(_ side: StripID) -> String {
        let name = mirror.name(side)
        return name == side.defaultName ? name : "\(name) · \(side.defaultName)"
    }

    private func title(_ isLinked: Bool) -> Text {
        isLinked
            ? Text("Unlink \(mirror.name(odd)) and \(mirror.name(even))?")
            : Text("Link \(mirror.name(odd)) and \(mirror.name(even))?")
    }

    /// Linking adds a line only for what the desk's Link Preferences keep separate.
    private func message(_ isLinked: Bool) -> String {
        guard !isLinked else { return String(localized: "Each can be set on its own again.") }
        let lines =
            [String(localized: "They'll work as one stereo channel.")]
            + [LinkPrompt.separateLine(mirror.separateSections)].compactMap { $0 }
        return lines.joined(separator: "\n")
    }
}
