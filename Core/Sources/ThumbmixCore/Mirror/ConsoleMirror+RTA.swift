import Foundation

/// What the desk's RTA was set to before the app borrowed it, and what the app set it to.
struct RTALoan {
    let originalSource: Int32
    let originalPosition: Int32
    var source: Int32
    var position: Int32
}

extension ConsoleMirror {
    /// Points the desk's RTA at `strip`, after its EQ or before it, and streams the spectrum into `spectrum`: the
    /// EQ tab shows a strip after its EQ, the key graph what its gate or comp hears. Switching strips while following
    /// keeps the original setting, so release restores the desk's own choice. Does nothing until the desk has
    /// reported its RTA setting (the app never restores a guess), nor once the desk has taken the RTA back.
    public func followRTA(_ strip: StripID, afterEQ: Bool = true) {
        guard isLive, !isRTATakenByDesk, let source = strip.rtaSource else { return }
        if let loan = rtaLoan, !deskShows(loan) { return takenBackOnTheDesk() }
        let position: Int32 = afterEQ ? RTA.afterEQ : 0
        if rtaLoan == nil {
            guard case .int(let originalSource)? = cell(RTA.source).argument,
                case .int(let originalPosition)? = cell(RTA.position).argument
            else { return }
            rtaLoan = RTALoan(
                originalSource: originalSource, originalPosition: originalPosition, source: source, position: position)
            link.send(RTA.subscription)
        }
        rtaLoan?.source = source
        rtaLoan?.position = position
        set(RTA.source, .int(source))
        set(RTA.position, .int(position))
    }

    /// A spectrum arriving after release must not bring the glow back.
    func applySpectrum(_ message: OSCMessage) {
        guard rtaLoan != nil, case .blob(let blob)? = message.arguments.first else { return }
        spectrum.decibels = MeterBlob.rtaDecibels(from: blob)
    }

    /// Puts back the desk's own RTA setting. A setting someone changed on the desk meanwhile is kept: only values that
    /// still show what the app set are restored. While contact is lost the sets would be dropped, so the hand-back
    /// waits for the desk (`returnPendingRTA`).
    public func releaseRTA() {
        isRTATakenByDesk = false
        guard let loan = rtaLoan else { return }
        rtaLoan = nil
        spectrum.decibels = []
        if isLive { handBack(loan) } else { pendingRTAReturn = loan }
    }

    /// Once live again, with the RTA setting just re-read: a hand-back made while contact was lost.
    func returnPendingRTA() {
        guard let loan = pendingRTAReturn else { return }
        pendingRTAReturn = nil
        log.info("RTA handed back after contact returned")
        handBack(loan)
    }

    /// A desk value for the RTA setting that isn't the app's: the engineer took the RTA back.
    func noteRTASetting(_ address: String) {
        guard address == RTA.source || address == RTA.position, let loan = rtaLoan, !deskShows(loan) else { return }
        takenBackOnTheDesk()
    }

    private func handBack(_ loan: RTALoan) {
        if cell(RTA.source).argument == .int(loan.source) { set(RTA.source, .int(loan.originalSource)) }
        if cell(RTA.position).argument == .int(loan.position) { set(RTA.position, .int(loan.originalPosition)) }
    }

    private func deskShows(_ loan: RTALoan) -> Bool {
        cell(RTA.source).argument == .int(loan.source) && cell(RTA.position).argument == .int(loan.position)
    }

    /// The engineer pointed the RTA elsewhere on the desk: the desk wins, and what still shows ours goes back.
    private func takenBackOnTheDesk() {
        log.info("RTA changed on the desk while borrowed: the app lets go")
        releaseRTA()
        isRTATakenByDesk = true
    }
}
