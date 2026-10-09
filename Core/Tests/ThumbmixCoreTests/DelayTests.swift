import Foundation
import Testing

@testable import ThumbmixCore

/// An input channel's delay (doc p.25), shown in ms and as the distance sound travels in that time (mock C).
struct DelayTests {
    private let delay = Catalog.delay(StripID(.input, 3))!

    @Test func onlyInputChannelsHaveADelay() {
        #expect(delay.on.address == "/ch/03/delay/on")
        #expect(delay.time.address == "/ch/03/delay/time")
        #expect(delay.time.scale == .linear(min: 0.3, max: 500, step: 0.1))
        #expect(Catalog.delay(StripID(.auxIn, 1)) == nil)
        #expect(Catalog.delay(StripID(.bus, 1)) == nil)
    }

    /// The desk's Gain/Delay link preference ("hadly") moves a linked pair's delays together.
    @Test func delayFollowsTheGainAndDelayLink() {
        #expect(LinkSection.of(suffix: "/delay/time") == .gainDelay)
        #expect(LinkSection.of(suffix: "/delay/on") == .gainDelay)
    }

    @Test func timeReadsInMillisecondsAndMetres() {
        let metric = Locale(identifier: "nl_NL")
        #expect(ValueText.format(position(12.5), delay.time, locale: metric) == "12,5 ms · 4,3 m")
        #expect(ValueText.format(0, delay.time, locale: metric) == "0,30 ms · 0,1 m")
        #expect(ValueText.format(1, delay.time, locale: metric) == "500 ms · 171,5 m")
    }

    @Test func timeReadsInFeetOnAUSPhone() {
        #expect(ValueText.format(position(12.5), delay.time, locale: .testEnglish) == "12.5 ms · 14.1 ft")
    }

    @Test func delayAndPreampGainResetValues() {
        #expect(delay.time.resetValue == 0.3)
        #expect(Catalog.headampGain(0).resetValue == 0)
    }

    @Test func delayIsSyncedAndStartsOffInTheDemo() {
        let addresses = Set(Catalog.syncAddresses())
        #expect(addresses.contains("/ch/32/delay/time"))
        #expect(DemoState.values()["/ch/01/delay/on"] == .int(0))
    }

    private func position(_ milliseconds: Double) -> Float {
        delay.time.scale.normalized(forValue: milliseconds)
    }
}
