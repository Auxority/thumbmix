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
                    HStack(spacing: 8) {
                        ParameterRow(spec: Catalog.headampGain(headamp), mirror: mirror)
                        PhantomButton(spec: Catalog.headampPhantom(headamp), strip: strip, mirror: mirror)
                    }
                    sharedWarning
                } else {
                    Text("No preamp: this channel reads from an internal source.")
                        .font(.callout)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Engineers trim preamp channels too, so Trim shows on every input, not only digital sources.
                ParameterRow(spec: Catalog.trim(strip), mirror: mirror)
            }
        }
    }

    @ViewBuilder private var sharedWarning: some View {
        let sharing = mirror.inputsSharingHeadamp(withInput: strip.number)
        if !sharing.isEmpty {
            let names = sharing.map { mirror.name(StripID(.input, $0)) }.formatted(.list(type: .and))
            Label("Shares an input with \(names)", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleOnly)
                .font(.callout)
                .foregroundStyle(.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 48V beside the Gain row, red when on like MUTE beside a fader. Every switch asks first: phantom power can harm
/// a mic that doesn't want it, and channels that share an input all get it.
private struct PhantomButton: View {
    let spec: ParamSpec
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var isConfirming = false
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let state = mirror.cell(spec.address).argument
        let isOn = state == .int(1)
        Button {
            isConfirming = true
        } label: {
            Text(verbatim: "48V")
                .font(.headline)
                .frame(width: 64 * sizeScale, height: 48 * sizeScale)
                .foregroundStyle(isOn ? .white : Theme.secondaryText)
                .background(isOn ? Theme.muteRed : Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(state == nil)
        .accessibilityIdentifier("toggle-" + spec.address)
        .accessibilityValue(isOn ? "On" : "Off")
        .alert(title(isOn), isPresented: $isConfirming) {
            Button("Cancel", role: .cancel) {}
            Button(isOn ? "Turn Off" : "Turn On") { mirror.set(spec.address, .int(isOn ? 0 : 1)) }
        } message: {
            if !alsoPowers.isEmpty { Text(verbatim: alsoPowers.joined(separator: "\n")) }
        }
    }

    private func title(_ isOn: Bool) -> Text {
        let name = mirror.name(strip)
        return isOn ? Text("Turn off 48V for \(name)?") : Text("Turn on 48V for \(name)?")
    }

    /// Everyone else this switch powers: channels on the same input, and the linked partner.
    private var alsoPowers: [String] {
        [sharedInputLine, linkedPartnerLine].compactMap { $0 }
    }

    private var sharedInputLine: String? {
        let sharing = mirror.inputsSharingHeadamp(withInput: strip.number)
        guard !sharing.isEmpty else { return nil }
        let names = sharing.map { mirror.name(StripID(.input, $0)) }.formatted(.list(type: .and))
        return String(localized: "Also powers \(names) (same input).")
    }

    /// The desk copies Gain/Delay to a linked partner; the doc doesn't say 48V goes with it (m32-probe section 7).
    /// Warning about a switch that may not happen is safer than staying silent about one that does.
    private var linkedPartnerLine: String? {
        guard mirror.isLinked(strip), mirror.isShared(.gainDelay), let partner = strip.partner else { return nil }
        return String(localized: "Also powers \(mirror.name(partner)) (linked).")
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
