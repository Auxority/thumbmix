import SwiftUI
import ThumbmixCore

/// A pair of sends' settings (mock H, pairs mock B): the level of each, the one tap point the desk keeps for the pair,
/// and on a linked pair the pan each side of `source` takes in that stereo mix. `target` is the pair's odd side. Half
/// height, so the strip's fader and mute stay usable above it.
struct SendSheet: View {
    let source: StripID
    let target: StripID
    let mirror: ConsoleMirror
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(levelTargets) { send in
                        SendRow(
                            source: source, target: send, title: levelTargets.count > 1 ? mirror.name(send) : "Level",
                            accent: Theme.color(mirror.color(send)), mirror: mirror, isLevelFixed: isSubgroup)
                    }
                    TapPointSection(source: source, target: target, mirror: mirror)
                    if mirror.isLinked(target) { panRows }
                }
                .padding(16)
                .disabled(!mirror.isLive)
            }
            .navigationTitle("\(sourceName) → \(targetName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold).buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    /// While the send follows the strip's LR pan, or is a subgroup (which follows it too), its own pan is ignored
    /// (assumed; m32-probe 10e), so the pan rows can't be dragged.
    @ViewBuilder private var panRows: some View {
        ForEach(sides) { side in
            if let pan = Catalog.sendPan(from: side, to: target) {
                ParameterRow(spec: pan, mirror: mirror, title: panTitle(side)).disabled(followsLRPan || isSubgroup)
            }
        }
        FollowLRPanToggle(sides: sides, target: target, mirror: mirror).disabled(isSubgroup)
    }

    /// A linked source keeps a send pan per side, as it keeps its LR pan per side (the Mix tab's two pan rows).
    private var sides: [StripID] {
        guard mirror.isLinked(source), let partner = source.partner else { return [source] }
        return [source, partner]
    }

    private var sourceName: String { mirror.isLinked(source) ? mirror.pairName(source) : mirror.name(source) }
    /// A linked pair is one send; an unlinked pair two, which share the tap point.
    private var levelTargets: [StripID] {
        guard !mirror.isLinked(target), let even = target.partner else { return [target] }
        return [target, even]
    }

    private var targetName: String {
        if mirror.isLinked(target) { return mirror.pairName(target) }
        return levelTargets.map(mirror.name).joined(separator: " & ")
    }

    private func panTitle(_ side: StripID) -> String? { sides.count > 1 ? "Pan · \(mirror.name(side))" : nil }

    private var followsLRPan: Bool { FollowLRPanToggle.isOn(source, target, mirror) }

    /// A subgroup send is at a fixed 0 dB and takes the strip's own pan (one tutorial; m32-probe 10d).
    private var isSubgroup: Bool { mirror.sendTap(from: source, to: target) == .subgroup }
}

/// One switch for every side: a stereo source half following its LR pan would make no sense.
private struct FollowLRPanToggle: View {
    let sides: [StripID]
    let target: StripID
    let mirror: ConsoleMirror
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        // The desk's value, never a guess: the switch waits until it has been read.
        let isRead = !sides.contains { mirror.cell(address($0)).argument == nil }
        Toggle("Follow LR pan", isOn: Binding(get: { Self.isOn(sides[0], target, mirror) }, set: set))
            .tint(.green)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            .disabled(!isRead)
            // The whole row dims like a disabled ParameterRow: a dimmed switch beside a bright label reads as on.
            .opacity(isEnabled && isRead ? 1 : 0.38)
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
