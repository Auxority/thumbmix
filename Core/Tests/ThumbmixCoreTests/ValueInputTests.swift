import Testing

@testable import ThumbmixCore

/// Typing a value into a row's alert: what an engineer types, and what is refused rather than clamped.
struct ValueInputTests {
    private let kick = StripID(.input, 1)
    private var fader: ParamSpec { Catalog.fader(kick) }
    private var frequency: ParamSpec { Catalog.eqBand(kick, 1).frequency }
    private var q: ParamSpec { Catalog.eqBand(kick, 1).q }
    private var pan: ParamSpec { Catalog.pan(kick)! }
    private var ratio: ParamSpec { Catalog.dynamics(kick).ratio }
    private var delay: ParamSpec { Catalog.delay(kick)!.time }

    private func expectValue(_ text: String, _ spec: ParamSpec, _ value: Double, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(
            ValueInput.normalized(from: text, for: spec) == spec.scale.normalized(forValue: value), "\(text)",
            sourceLocation: sourceLocation)
    }

    @Test func faderTakesDecibelsWithOrWithoutUnit() {
        expectValue("-6", fader, -6)
        expectValue("−6 dB", fader, -6)
        expectValue("+10", fader, 10)
        expectValue("-6,5", fader, -6.5)
        expectValue(" -6.5db ", fader, -6.5)
    }

    @Test func faderOffIsMinusInfinity() {
        for text in ["-inf", "−∞", "off", "-∞ dB"] { #expect(ValueInput.normalized(from: text, for: fader) == 0, "\(text)") }
    }

    /// Set is the confirmation, so a number past either end lands on that end.
    @Test func outOfRangeLandsOnTheNearestEnd() {
        #expect(ValueInput.normalized(from: "100", for: fader) == 1)
        #expect(ValueInput.normalized(from: "-200", for: fader) == 0)
        #expect(ValueInput.normalized(from: "19", for: frequency) == 0)
        #expect(ValueInput.normalized(from: "21k", for: frequency) == 1)
        #expect(ValueInput.normalized(from: "11", for: q) == 0, "Q runs from 10 down to 0.3")
        #expect(ValueInput.normalized(from: "0.2", for: q) == 1)
        #expect(ValueInput.normalized(from: "0.2", for: delay) == 0)
        #expect(ValueInput.normalized(from: "L101", for: pan) == 0)
    }

    @Test func nonsenseIsRefused() {
        for text in ["", "abc", "--6", "6 6", "k"] { #expect(ValueInput.normalized(from: text, for: fader) == nil, "\(text)") }
    }

    /// Swift reads "nan" and "inf" as numbers; a NaN must never reach the desk.
    @Test func onlyFiniteNumbersAreValues() {
        for text in ["nan", "inf", "+inf", "infinity", "nan dB"] {
            #expect(ValueInput.normalized(from: text, for: frequency) == nil, "\(text)")
            #expect(ValueInput.normalized(from: text, for: pan) == nil, "\(text)")
        }
        #expect(ValueInput.normalized(from: "nan", for: fader) == nil)
        #expect(ValueInput.normalized(from: "nan", for: ratio) == nil)
    }

    @Test func frequencyTakesHertzAndKilohertz() {
        expectValue("1k", frequency, 1000)
        expectValue("1.2 kHz", frequency, 1200)
        expectValue("1,2k", frequency, 1200)
        expectValue("200hz", frequency, 200)
        expectValue("20k", frequency, 20000)
    }

    @Test func qAndDelayTakePlainNumbers() {
        expectValue("1.7", q, 1.7)
        expectValue("12.5 ms", delay, 12.5)
        expectValue("12.5", delay, 12.5)
    }

    @Test func panTakesTheSidesAsShown() {
        expectValue("L20", pan, -20)
        expectValue("r30", pan, 30)
        expectValue("C", pan, 0)
        expectValue("-50", pan, -50)
    }

    /// The ratio is a list of the desk's options: a number picks the nearest one.
    @Test func ratioTakesItsNumber() {
        let four = Double(Catalog.ratios.firstIndex(of: "4.0")!)
        let three = Double(Catalog.ratios.firstIndex(of: "3.0")!)
        expectValue("4", ratio, four)
        expectValue("4:1", ratio, four)
        expectValue("3.4", ratio, three)
        #expect(ValueInput.normalized(from: "0.5", for: ratio) == 0)
        #expect(ValueInput.normalized(from: "200", for: ratio) == 1)
    }

    @Test func togglesTakeNoTypedValue() {
        #expect(ValueInput.normalized(from: "1", for: Catalog.on(kick)) == nil)
    }

    @Test func rangeTextReadsLowToHigh() {
        #expect(ValueInput.rangeText(fader, locale: .testEnglish) == "−∞ dB to +10.0 dB")
        #expect(ValueInput.rangeText(frequency, locale: .testEnglish) == "20.0 Hz to 20.00 kHz")
        #expect(ValueInput.rangeText(q, locale: .testEnglish) == "0.3 to 10.0")
        #expect(ValueInput.rangeText(pan, locale: .testEnglish) == "L100 to R100")
        #expect(ValueInput.rangeText(ratio, locale: .testEnglish) == "1.1:1 to 100:1")
    }
}
