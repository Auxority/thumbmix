import FakeM32
import Testing

@testable import ThumbmixCore

/// Loading raises nothing the engineer didn't see asked about, even through a linked pair or after the desk moved.
@MainActor
struct PresetLoadSafetyTests {
    private let kick = StripID(.input, 1)
    private let snare = StripID(.input, 2)

    /// The desk copies a linked pair's gain to the partner, so a raise on the partner's side asks too.
    @Test func aLinkedPartnersGainRaiseAsksToo() async throws {
        try await withDesk([
            (Catalog.headampGain(32), 20), (Catalog.headampGain(40), 30), (Catalog.headampGain(41), 10),
        ]) { fake, mirror in
            let guitarL = StripID(.input, 9)
            await readTabs(mirror, kick, guitarL)
            let preset = try savePreset(kick, mirror, parts: [.input])

            let plan = mirror.loadPlan(preset, parts: [.input], onto: guitarL, locale: .testEnglish)

            let question = try #require(plan.questions.first { $0.kind == .gain })
            #expect(question.title.contains("10"), "the side that rises most: \(question.title)")
            mirror.apply(plan, answers: [question.id: false])
            try await Task.sleep(for: .milliseconds(200))
            #expect(deskValue(fake, Catalog.headampGain(41)) == 10, "Keep leaves the partner alone too")
        }
    }

    /// A write judged "lower, no question" must not become a raise because the desk moved during the alerts.
    @Test func aGainTheDeskLoweredMeanwhileIsNotRaisedWithoutAsking() async throws {
        try await withDesk([(Catalog.headampGain(32), 20), (Catalog.headampGain(33), 30)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.input, .gate])
            let plan = mirror.loadPlan(preset, parts: [.input, .gate], onto: snare)
            #expect(plan.questions.isEmpty, "30 dB down to 20 dB asks nothing")

            setOnDesk(fake, Catalog.headampGain(33), 10)
            #expect(await eventually { abs((mirror.value(Catalog.headampGain(33)) ?? 0) - 10) < 0.01 })
            let outcome = mirror.apply(plan, answers: [:])

            #expect(outcome == .heldBack(1))
            try await Task.sleep(for: .milliseconds(200))
            #expect(deskValue(fake, Catalog.headampGain(33)) == 10, "left where the engineer put it")
        }
    }

    /// "Keep" holds for that control, even where the desk moved meanwhile so the preset's value is no longer a raise.
    @Test func aKeptGainStaysKeptAfterTheDeskMoved() async throws {
        try await withDesk([(Catalog.headampGain(32), 30), (Catalog.headampGain(33), 10)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.input])
            let plan = mirror.loadPlan(preset, parts: [.input], onto: snare)
            let question = try #require(plan.questions.first { $0.kind == .gain })

            setOnDesk(fake, Catalog.headampGain(33), 40)
            #expect(await eventually { abs((mirror.value(Catalog.headampGain(33)) ?? 0) - 40) < 0.01 })
            #expect(mirror.apply(plan, answers: [question.id: false]) == .sent)

            try await Task.sleep(for: .milliseconds(200))
            #expect(deskValue(fake, Catalog.headampGain(33)) == 40, "not lowered to 30 either")
        }
    }

    /// A question that only arises when the writes are sent was never answered: that write stays out.
    @Test func a48VChangeThatAroseMeanwhileIsHeldBack() async throws {
        try await withDesk([(Catalog.headampPhantom(32), 1), (Catalog.headampPhantom(33), 1)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.input])
            let plan = mirror.loadPlan(preset, parts: [.input], onto: snare)
            #expect(!plan.questions.contains { $0.kind == .phantom(on: true) }, "snare already has 48V on")

            setOnDesk(fake, Catalog.headampPhantom(33), 0)
            #expect(await eventually { mirror.value(Catalog.headampPhantom(33)) == 0 })
            #expect(mirror.apply(plan, answers: [:]) == .heldBack(1))

            try await Task.sleep(for: .milliseconds(200))
            #expect(fake.value(at: Catalog.headampPhantom(33).address) == .int(0), "48V stays off unasked")
        }
    }

    @Test func aCleanLoadReportsItWasSent() async throws {
        try await withDesk([(Catalog.headampGain(32), 20), (Catalog.headampGain(33), 30)]) { _, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.gate])
            #expect(mirror.apply(mirror.loadPlan(preset, parts: [.gate], onto: snare), answers: [:]) == .sent)
        }
    }
}
