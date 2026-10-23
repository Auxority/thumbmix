public enum MirrorStatus: Equatable, Sendable {
    case connecting
    case syncing(Double)
    case live
    case lost
    case failed(LinkFailure)

    var failure: LinkFailure? {
        if case .failed(let failure) = self { failure } else { nil }
    }
}
