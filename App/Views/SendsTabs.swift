import SwiftUI
import ThumbmixCore

/// Where this strip goes: one row per bus (from a channel) or matrix (from a bus or main), named and coloured as on the desk.
/// The desk keeps one tap point per pair of buses, so a pair shares one tall › that opens its settings (`SendSheet`,
/// mock B): a linked pair is one send, an unlinked pair two rows beside the same ›.
struct SendsTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// Opens a bus's own screen; the sheet's bus names call it once the sheet is gone.
    let open: (StripID) -> Void
    @State private var openSend: StripID?
    @State private var busToOpen: StripID?

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(mirror.sendPairs(of: strip), id: \.self) { pair in
                    HStack(spacing: 8) {
                        VStack(spacing: 6) {
                            ForEach(pair) { target in
                                SendRow(
                                    source: strip, target: target, title: title(target),
                                    accent: Theme.color(mirror.color(target)), mirror: mirror)
                            }
                        }
                        SendSettingsButton(address: Catalog.sendLevel(from: strip, to: pair[0]).address) {
                            openSend = pair[0]
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        // Pushing the bus while the sheet still covers the screen would be lost: it waits for the sheet to close.
        .sheet(item: $openSend, onDismiss: openChosenBus) { target in
            SendSheet(source: strip, target: target, mirror: mirror) { busToOpen = $0 }
                // A stereo mix's sheet adds pans below the tap point: it can be dragged up to see them all.
                .presentationDetents(mirror.isLinked(target) ? [.medium, .large] : [.medium])
                // The strip's fader and mute above the sheet stay usable: a channel that rings can still be pulled.
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                // Glass tinted black, like the toolbar buttons (`DarkCapsuleStyle`): the edge still shows, the
                // chips behind don't bleed through.
                .presentationBackground { Color.clear.glassEffect(.regular.tint(.black), in: .rect) }
        }
    }

    private func openChosenBus() {
        guard let bus = busToOpen else { return }
        busToOpen = nil
        open(bus)
    }

    private func title(_ target: StripID) -> String {
        mirror.isLinked(target) ? mirror.pairName(target) : mirror.name(target)
    }
}

private struct SendSettingsButton: View {
    let address: String
    let open: () -> Void
    @ScaledMetric private var size: CGFloat = 44

    var body: some View {
        Button(action: open) {
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .frame(width: size * 0.8)
                .frame(minHeight: size, maxHeight: .infinity)
                .foregroundStyle(Theme.secondaryText)
                .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send settings")
        .accessibilityIdentifier("settings-" + address)
    }
}

/// What feeds this bus or matrix: the sends of every kind that feeds it (`StripKind.feeders`).
/// Unused sources show too, like the overview, until hiding them is redesigned (TODO).
struct FedByTab: View {
    let target: StripID
    let mirror: ConsoleMirror
    /// Opened from a channel's send, that channel's row comes into view: it can be the 13th source or further down.
    var focus: StripID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(target.kind.feeders.flatMap(StripID.all)) { source in
                        SendRow(
                            source: source, target: target, title: mirror.name(source),
                            accent: Theme.color(mirror.color(source)), mirror: mirror
                        )
                        .id(source)
                    }
                }
            }
            .onAppear { if let focus { proxy.scrollTo(focus, anchor: .center) } }
        }
    }
}

struct SendRow: View {
    let source: StripID
    let target: StripID
    let title: String
    let accent: Color
    let mirror: ConsoleMirror
    /// A subgroup send's level is fixed at 0 dB; it can still be switched off.
    var isLevelFixed = false

    var body: some View {
        HStack(spacing: 8) {
            // Green like every other "on" chip: a red source colour would read as mute.
            ToggleChip(
                spec: Catalog.sendOn(from: source, to: target), mirror: mirror, title: "On", onColor: .green
            )
            ParameterRow(
                spec: Catalog.sendLevel(from: source, to: target), mirror: mirror, title: title,
                accent: accent
            )
            .disabled(isLevelFixed)
        }
    }
}

#if DEBUG
    #Preview("Sends") {
        SendsTab(strip: StripID(.input, 13), mirror: .preview()) { _ in }.padding().background(Theme.background)
    }

    #Preview("Fed by") {
        FedByTab(target: StripID(.bus, 1), mirror: .preview()).padding().background(Theme.background)
    }

    #Preview("Matrix fed by") {
        FedByTab(target: StripID(.matrix, 1), mirror: .preview()).padding().background(Theme.background)
    }
#endif
