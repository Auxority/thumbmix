import Testing

@testable import ThumbmixCore

struct EQAxisTests {
    @Test func endsOfTheAxis() {
        #expect(EQAxis.position(hertz: 20) == 0)
        #expect(abs(EQAxis.position(hertz: 20_000) - 1) < 1e-12)
        #expect(abs(EQAxis.hertz(at: 0.5) - 632.455) < 0.01)
    }

    @Test(arguments: [20.0, 55, 440, 1_000, 8_000, 20_000])
    func roundTrips(hertz: Double) {
        #expect(abs(EQAxis.hertz(at: EQAxis.position(hertz: hertz)) - hertz) < 1e-6 * hertz)
    }
}
