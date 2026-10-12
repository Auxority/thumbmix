import SwiftUI
import ThumbmixCore

/// One send to a linked pair of buses or matrices (mock H): its level, the pan each side of `source` takes in that
/// stereo mix, and whether the pan follows the strip's own LR pan instead. Half height, so the strip's fader and
/// mute stay usable above it.
struct SendSheet: View {
    let source: StripID
    let target: StripID
    let mirror: ConsoleMirror
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    SendRow(
                        source: source, target: target, title: "Level",
                        accent: Theme.color(mirror.color(target)), mirror: mirror)
                    ForEach(sides) { side in
                        if let pan = Catalog.sendPan(from: side, to: target) {
                            ParameterRow(spec: pan, mirror: mirror, title: panTitle(side)).disabled(followsLRPan)
                        }
                    }
                    FollowLRPanToggle(sides: sides, target: target, mirror: mirror)
                }
                .padding(16)
                .disabled(!mirror.isLive)
            }
            .navigationTitle("\(sourceName) → \(mirror.pairName(target))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold).buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    /// A linked source keeps a send pan per side, as it keeps its LR pan per side (the Mix tab's two pan rows).
    private var sides: [StripID] {
        guard mirror.isLinked(source), let partner = source.partner else { return [source] }
        return [source, partner]
    }

    private var sourceName: String { mirror.isLinked(source) ? mirror.pairName(source) : mirror.name(source) }

    private func panTitle(_ side: StripID) -> String? { sides.count > 1 ? "Pan · \(mirror.name(side))" : nil }

    /// Assumed: while it follows, the desk ignores the send's own pan, so the pan rows can't be dragged.
    private var followsLRPan: Bool { FollowLRPanToggle.isOn(source, target, mirror) }
}

/// One switch for every side: a stereo source half following its LR pan would make no sense.
private struct FollowLRPanToggle: View {
    let sides: [StripID]
    let target: StripID
    let mirror: ConsoleMirror

    var body: some View {
        Toggle("Follow LR pan", isOn: Binding(get: { Self.isOn(sides[0], target, mirror) }, set: set))
            .tint(.green)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            // The desk's value, never a guess: the switch waits until it has been read.
            .disabled(sides.contains { mirror.cell(address($0)).argument == nil })
            .accessibilityIdentifier("follow-" + address(sides[0]))
    }

    static func isOn(_ side: StripID, _ target: StripID, _ mirror: ConsoleMirror) -> Bool {
        guard let spec = Catalog.sendPanFollow(from: side, to: target) else { return false }
        return mirror.cell(spec.address).argument == .int(1)
    }

    private func set(_ isOn: Bool) {
        for side in sides { mirror.set(address(side), .int(isOn ? 1 : 0)) }
    }

    private func address(_ side: StripID) -> String {
        Catalog.sendPanFollow(from: side, to: target)?.address ?? ""
    }
}

#if DEBUG
    #Preview {
        Color.black.sheet(isPresented: .constant(true)) {
            SendSheet(source: StripID(.input, 9), target: StripID(.bus, 5), mirror: .preview())
                .presentationDetents([.medium])
        }
    }
#endif
