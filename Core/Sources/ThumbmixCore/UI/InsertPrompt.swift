/// Asked before switching on an insert that sends to an aux: the strip then plays only what comes back, and with
/// nothing patched it goes silent. The app can't see what's patched (side-agent note, user 2026-10-14). An FX always
/// returns sound, and switching off only removes processing: neither asks.
public struct InsertPrompt: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirm: String

    public init?(name: String, turningOn: Bool, slots: [InsertSlot]) {
        let auxes = slots.filter { if case .aux = $0 { true } else { false } }.map(\.short)
        guard turningOn, !auxes.isEmpty else { return nil }
        let gear = auxes.joined(separator: CoreStrings.text(" and "))
        title = CoreStrings.text("Turn on the insert for \(name)?")
        message = CoreStrings.text(
            "\(name) will play only what comes back from the gear on \(gear). If nothing is connected there, \(name) goes silent.")
        confirm = CoreStrings.text("Turn On")
    }
}
