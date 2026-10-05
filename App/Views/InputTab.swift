import SwiftUI
import ThumbmixCore

struct InputTab: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                InputMeter(cell: mirror.meter(strip))
                if let headamp = mirror.headamp(forInput: strip.number) {
                    ParameterRow(spec: Catalog.headampGain(headamp), mirror: mirror)
                    sharedWarning
                    HStack {
                        ToggleChip(
                            spec: Catalog.headampPhantom(headamp), mirror: mirror, onColor: Theme.muteRed)
                        Spacer()
                    }
                } else {
                    Text("No preamp: this channel reads from an internal source.")
                        .font(.callout)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ParameterRow(spec: Catalog.trim(strip), mirror: mirror)
            }
        }
    }

    @ViewBuilder private var sharedWarning: some View {
        let sharing = mirror.inputsSharingHeadamp(withInput: strip.number)
        if !sharing.isEmpty {
            let names = sharing.map { mirror.name(StripID(.input, $0)) }.formatted(.list(type: .and))
            Label("Shared with \(names)", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleOnly)
                .font(.callout)
                .foregroundStyle(.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InputMeter: View {
    let cell: MeterCell

    var body: some View {
        MeterBar(level: cell.level, height: 12)
            .padding(12)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
    }
}

#if DEBUG
    #Preview {
        InputTab(strip: StripID(.input, 14), mirror: .preview()).padding().background(Theme.background)
    }
#endif
