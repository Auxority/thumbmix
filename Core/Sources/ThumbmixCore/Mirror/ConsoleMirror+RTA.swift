import Foundation

/// What the desk's RTA was set to before the app borrowed it, and what the app set it to.
struct RTALoan {
    let originalSource: Int32
    let originalPosition: Int32
    var source: Int32
}

extension ConsoleMirror {
    /// Points the desk's RTA at `strip`, after its EQ, and streams the spectrum into `spectrum`.
    /// Switching strips while following keeps the original setting, so release restores the desk's own choice.
    /// Does nothing until the desk has reported its RTA setting: the app never restores a guess.
    public func followRTA(_ strip: StripID) {
        guard isLive, let source = strip.rtaSource else { return }
        if rtaLoan == nil {
            guard case .int(let originalSource)? = cell(RTA.source).argument,
                case .int(let originalPosition)? = cell(RTA.position).argument
            else { return }
            rtaLoan = RTALoan(originalSource: originalSource, originalPosition: originalPosition, source: source)
            link.renewals.append(RTA.subscription)
            link.send(RTA.subscription)
        }
        rtaLoan?.source = source
        set(RTA.source, .int(source))
        set(RTA.position, .int(RTA.afterEQ))
    }

    /// A spectrum arriving after release must not bring the glow back.
    func applySpectrum(_ message: OSCMessage) {
        guard rtaLoan != nil, case .blob(let blob)? = message.arguments.first else { return }
        spectrum.decibels = MeterBlob.rtaDecibels(from: blob)
    }

    /// Puts back the desk's own RTA setting. A setting someone changed on the desk meanwhile is kept:
    /// only values that still show what the app set are restored.
    public func releaseRTA() {
        guard let loan = rtaLoan else { return }
        rtaLoan = nil
        link.renewals.removeAll { $0 == RTA.subscription }
        spectrum.decibels = []
        if cell(RTA.source).argument == .int(loan.source) { set(RTA.source, .int(loan.originalSource)) }
        if cell(RTA.position).argument == .int(RTA.afterEQ) { set(RTA.position, .int(loan.originalPosition)) }
    }
}
