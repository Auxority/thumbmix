import SwiftUI
import ThumbmixCore

/// Where this channel goes: one row per bus, named and coloured like the bus on the desk.
struct SendsTab: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(StripID.all(.bus)) { bus in
                    SendRow(source: strip, bus: bus.number, title: mirror.name(bus), accent: Theme.color(mirror.color(bus)), mirror: mirror)
                }
            }
        }
    }
}

/// What feeds this bus: sends-on-fader across inputs, aux ins and FX returns.
struct FedByTab: View {
    let bus: StripID
    let mirror: ConsoleMirror
    @State private var showUnused = false

    var body: some View {
        let sources = [StripKind.input, .auxIn, .fxReturn]
            .flatMap(StripID.all)
            .filter { showUnused || !mirror.isUnused($0) }
        ScrollView {
            VStack(spacing: 6) {
                Toggle("Show unused", isOn: $showUnused)
                    .font(.subheadline)
                    .padding(.horizontal, 4)
                ForEach(sources) { source in
                    SendRow(source: source, bus: bus.number, title: mirror.name(source), accent: Theme.color(mirror.color(source)), mirror: mirror)
                }
            }
        }
    }
}

struct SendRow: View {
    let source: StripID
    let bus: Int
    let title: String
    let accent: Color
    let mirror: ConsoleMirror

    var body: some View {
        HStack(spacing: 8) {
            // Green like every other "on" chip: a red source colour would read as mute.
            ToggleChip(spec: Catalog.sendOn(from: source, toBus: bus), mirror: mirror, title: "On", onColor: .green)
            ParameterRow(spec: Catalog.sendLevel(from: source, toBus: bus), mirror: mirror, title: title, accent: accent)
        }
    }
}

#if DEBUG
#Preview("Sends") {
    SendsTab(strip: StripID(.input, 13), mirror: .preview()).padding().background(Theme.background)
}

#Preview("Fed by") {
    FedByTab(bus: StripID(.bus, 1), mirror: .preview()).padding().background(Theme.background)
}
#endif
