import SwiftUI
import ThumbmixCore

struct InputTab: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let headamp = mirror.headamp(of: strip) {
                    HStack(spacing: 8) {
                        ParameterRow(spec: Catalog.headampGain(headamp), mirror: mirror)
                        PhantomButton(spec: Catalog.headampPhantom(headamp), strip: strip, mirror: mirror)
                    }
                    sharedWarning
                } else if strip.kind == .input {
                    // An aux in without a preamp is its line jack, as expected; an input without one is worth a word.
                    Text("No preamp: this channel reads from an internal source.")
                        .font(.callout)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Engineers trim preamp channels too, so Trim shows on every input, not only digital sources.
                HStack(spacing: 8) {
                    ParameterRow(spec: Catalog.trim(strip), mirror: mirror)
                    if let invert = Catalog.invert(strip) { PolarityButton(spec: invert, strip: strip, mirror: mirror) }
                }
                if let delay = Catalog.delay(strip) { delayRow(delay) }
            }
        }
    }

    /// Like the low cut on the EQ tab, an on/off chip beside the time, which also reads as a distance.
    private func delayRow(_ delay: DelaySpecs) -> some View {
        HStack(spacing: 8) {
            ToggleChip(spec: delay.on, mirror: mirror, onColor: .green)
            ParameterRow(spec: delay.time, mirror: mirror)
        }
    }

    @ViewBuilder private var sharedWarning: some View {
        if let names = mirror.namesSharingHeadamp(with: strip) {
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
        .dimmedUntilRead(state != nil)
        .accessibilityIdentifier("toggle-" + spec.address)
        .accessibilityValue(state == nil ? Text(verbatim: "") : Text(isOn ? "On" : "Off"))
        .alert(title(isOn), isPresented: $isConfirming) {
            Button("Cancel", role: .cancel) {}
            Button(isOn ? "Turn Off" : "Turn On") { mirror.set(spec.address, .int(isOn ? 0 : 1)) }
        } message: {
            if let alsoPowers = PreampReach(strip, mirror).alsoPowers { Text(verbatim: alsoPowers) }
        }
    }

    private func title(_ isOn: Bool) -> Text {
        let name = mirror.name(strip)
        return isOn ? Text("Turn off 48V for \(name)?") : Text("Turn on 48V for \(name)?")
    }
}

/// Who else switching 48V reaches, named in its alert: channels on the same input (one
/// preamp), and the partner when the desk links Gain/Delay. Warning about a change that may not happen there
/// (48V on the partner is unverified) is safer than staying silent about one that does.
@MainActor private struct PreampReach {
    let sameInput: String?
    let partner: String?

    init(_ strip: StripID, _ mirror: ConsoleMirror) {
        sameInput = mirror.namesSharingHeadamp(with: strip)
        partner = mirror.gainDelayPartner(of: strip).map { mirror.name($0) }
    }

    /// 48V belongs to the preamp every channel on that input shares.
    var alsoPowers: String? {
        lines(
            sameInput.map { String(localized: "Also powers \($0) (same input).") },
            partner.map { String(localized: "Also powers \($0) (linked).") })
    }

    private func lines(_ candidates: String?...) -> String? {
        let present = candidates.compactMap { $0 }
        return present.isEmpty ? nil : present.joined(separator: "\n")
    }
}

#if DEBUG
    #Preview {
        InputTab(strip: StripID(.input, 14), mirror: .preview()).padding().background(Theme.background)
    }
#endif
