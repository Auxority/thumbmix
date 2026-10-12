import Testing

@testable import ThumbmixCore

/// Typing a value into a row's alert: what an engineer types, and what is refused: never clamped.
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
            ValueInput.read(text, for: spec) == .value(spec.scale.normalized(forValue: value)), "\(text)",
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
        for text in ["-inf", "−∞", "off", "-∞ dB"] { #expect(ValueInput.read(text, for: fader) == .value(0), "\(text)") }
    }

    /// A number past either end is refused, not moved onto that end: "1000000" on a fader must never set +10 dB.
    @Test func outOfRangeIsRefused() {
        let cases: [(String, ParamSpec)] = [
            ("100", fader), ("10.1", fader), ("1000000", fader), ("19", frequency), ("21k", frequency), ("0", frequency),
            ("-5", frequency), ("11", q), ("0.2", q), ("0.2", delay), ("L101", pan), ("R101", pan), ("101", pan),
        ]
        for (text, spec) in cases { #expect(ValueInput.read(text, for: spec) == .outOfRange, "\(text)") }
    }

    /// Typing an end as the row shows it is in range, despite float rounding in the scale's maths.
    @Test func theEndsThemselvesAreValues() {
        expectValue("10", fader, 10)
        expectValue("20", frequency, 20)
        expectValue("20k", frequency, 20000)
        expectValue("10", q, 10)
        expectValue("0.3", q, 0.3)
        expectValue("L100", pan, -100)
        expectValue("R100", pan, 100)
    }

    /// The fader's low end is −∞, so a level below the desk's lowest step is −∞ itself, not past the end.
    @Test func veryLowLevelsAreMinusInfinity() {
        #expect(ValueInput.read("-200", for: fader) == .value(0))
    }

    @Test func nonsenseIsRefused() {
        for text in ["", "abc", "--6", "6 6", "k"] { #expect(ValueInput.read(text, for: fader) == .notAValue, "\(text)") }
    }

    /// Swift reads "nan" and "inf" as numbers; a NaN must never reach the desk.
    @Test func onlyFiniteNumbersAreValues() {
        for text in ["nan", "inf", "+inf", "infinity", "nan dB"] {
            #expect(ValueInput.read(text, for: frequency) == .notAValue, "\(text)")
            #expect(ValueInput.read(text, for: pan) == .notAValue, "\(text)")
        }
        #expect(ValueInput.read("nan", for: fader) == .notAValue)
        #expect(ValueInput.read("nan", for: ratio) == .notAValue)
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

    /// The ratio is a list of the desk's options: a number from 1.1 to 100 picks the nearest one.
    @Test func ratioTakesItsNumber() {
        let four = Double(Catalog.ratios.firstIndex(of: "4.0")!)
        let three = Double(Catalog.ratios.firstIndex(of: "3.0")!)
        expectValue("4", ratio, four)
        expectValue("4:1", ratio, four)
        expectValue("3.4", ratio, three)
        expectValue("100", ratio, Double(Catalog.ratios.count - 1))
        #expect(ValueInput.read("0.5", for: ratio) == .outOfRange)
        #expect(ValueInput.read("200", for: ratio) == .outOfRange)
    }

    @Test func togglesTakeNoTypedValue() {
        #expect(ValueInput.read("1", for: Catalog.on(kick)) == .notAValue)
    }

    @Test func rangeTextReadsLowToHigh() {
        #expect(ValueInput.rangeText(fader, locale: .testEnglish) == "−∞ dB to +10.0 dB")
        #expect(ValueInput.rangeText(frequency, locale: .testEnglish) == "20.0 Hz to 20.00 kHz")
        #expect(ValueInput.rangeText(q, locale: .testEnglish) == "0.3 to 10.0")
        #expect(ValueInput.rangeText(pan, locale: .testEnglish) == "L100 to R100")
        #expect(ValueInput.rangeText(ratio, locale: .testEnglish) == "1.1:1 to 100:1")
    }
}
