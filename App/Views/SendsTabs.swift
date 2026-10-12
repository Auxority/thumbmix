import SwiftUI
import ThumbmixCore

/// Where this strip goes: one row per bus (from a channel) or matrix (from a bus or main), named and coloured as on the desk.
struct SendsTab: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(strip.kind.sendTarget.map(StripID.all) ?? []) { target in
                    SendRow(
                        source: strip, target: target, title: mirror.name(target),
                        accent: Theme.color(mirror.color(target)), mirror: mirror)
                }
            }
        }
    }
}

/// What feeds this bus or matrix: the sends of every kind that feeds it (`StripKind.feeders`).
/// Unused sources show too, like the overview, until hiding them is redesigned (TODO).
struct FedByTab: View {
    let target: StripID
    let mirror: ConsoleMirror

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(target.kind.feeders.flatMap(StripID.all)) { source in
                    SendRow(
                        source: source, target: target, title: mirror.name(source),
                        accent: Theme.color(mirror.color(source)), mirror: mirror)
                }
            }
        }
    }
}

struct SendRow: View {
    let source: StripID
    let target: StripID
    let title: String
    let accent: Color
    let mirror: ConsoleMirror

    var body: some View {
        HStack(spacing: 8) {
            // Green like every other "on" chip: a red source colour would read as mute.
            ToggleChip(
                spec: Catalog.sendOn(from: source, to: target), mirror: mirror, title: "On", onColor: .green
            )
            ParameterRow(
                spec: Catalog.sendLevel(from: source, to: target), mirror: mirror, title: title,
                accent: accent)
        }
    }
}

#if DEBUG
    #Preview("Sends") {
        SendsTab(strip: StripID(.input, 13), mirror: .preview()).padding().background(Theme.background)
    }

    #Preview("Fed by") {
        FedByTab(target: StripID(.bus, 1), mirror: .preview()).padding().background(Theme.background)
    }

    #Preview("Matrix fed by") {
        FedByTab(target: StripID(.matrix, 1), mirror: .preview()).padding().background(Theme.background)
    }
#endif
