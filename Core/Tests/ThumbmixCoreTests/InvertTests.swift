import Testing

@testable import ThumbmixCore

/// Polarity (doc p.25, p.28): a Ø button beside Trim that asks first, and the alert explains it (mock A, 2026-10-12).
struct InvertTests {
    @Test func inputsAndAuxInsHaveInvert() {
        #expect(Catalog.invert(StripID(.input, 3))?.address == "/ch/03/preamp/invert")
        #expect(Catalog.invert(StripID(.auxIn, 2))?.address == "/auxin/02/preamp/invert")
        #expect(Catalog.invert(StripID(.fxReturn, 1)) == nil)
        #expect(Catalog.invert(StripID(.matrix, 1)) == nil, "the doc's matrix invert is unconfirmed (m32-probe 7)")
    }

    /// The doc's "Delay + HA link" (p.20) is assumed to carry the preamp's polarity too; m32-probe section 7 checks.
    @Test func invertFollowsTheGainAndDelayLink() {
        #expect(LinkSection.of(suffix: "/preamp/invert") == .gainDelay)
    }

    @Test func invertIsSyncedAndStartsNormalInTheDemo() {
        let addresses = Set(Catalog.allAddresses())
        #expect(addresses.contains("/ch/32/preamp/invert"))
        #expect(addresses.contains("/auxin/08/preamp/invert"))
        #expect(DemoState.values()["/ch/01/preamp/invert"] == .int(0), "a toggle, not mid-travel")
    }

    @Test func flippingExplainsPolarity() {
        let prompt = PolarityPrompt(name: "Snare btm", isFlipped: false, partner: nil)
        #expect(prompt.title == "Flip the polarity of Snare btm?")
        #expect(prompt.message == "Turns the signal upside down. Try it when two mics on one source sound thin together.")
        #expect(prompt.confirm == "Flip")
    }

    @Test func flippingBackOnlyAsks() {
        let prompt = PolarityPrompt(name: "Snare btm", isFlipped: true, partner: nil)
        #expect(prompt.title == "Set Snare btm's polarity back to normal?")
        #expect(prompt.message == nil)
        #expect(prompt.confirm == "Normal")
    }

    /// Like the 48V alert: the desk's Gain/Delay link flips the partner too, so the alert says so first.
    @Test func aLinkedPartnerIsNamed() {
        let flip = PolarityPrompt(name: "Gtr L", isFlipped: false, partner: "Gtr R")
        #expect(flip.message?.hasSuffix("\nAlso flips Gtr R (linked).") == true)
        let back = PolarityPrompt(name: "Gtr L", isFlipped: true, partner: "Gtr R")
        #expect(back.message == "Also sets Gtr R back (linked).")
    }
}
