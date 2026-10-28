import FakeM32
import Testing

@testable import ThumbmixCore

/// Loading a saved preset onto another strip, against the fake desk.
@MainActor
struct PresetLoadTests {
    private let kick = StripID(.input, 1)
    private let snare = StripID(.input, 2)

    // MARK: Loading

    @Test func aSavedStripLoadsOntoAnotherAndReachesTheDesk() async throws {
        try await withDesk([
            (Catalog.gate(kick).threshold, -33), (Catalog.eqBand(kick, 3).gain, 4.5), (Catalog.dynamics(kick).ratio, 8),
            (Catalog.headampGain(32), 20), (Catalog.headampGain(33), 40),
        ]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: Set(PresetPart.allCases).subtracting([.mix, .sends]))
            let plan = mirror.loadPlan(preset, parts: preset.parts.reduce(into: []) { $0.insert($1) }, onto: snare)
            #expect(plan.questions.isEmpty, "gain goes down, 48V, polarity and comp position stay")

            mirror.apply(plan, answers: [:])

            #expect(await eventually { deskValue(fake, Catalog.gate(snare).threshold) == -33 })
            #expect(await eventually { deskValue(fake, Catalog.eqBand(snare, 3).gain) == 4.5 })
            #expect(await eventually { deskValue(fake, Catalog.dynamics(snare).ratio) == 8 })
            #expect(await eventually { deskValue(fake, Catalog.headampGain(33)) == 20 }, "a lower gain asks nothing")
        }
    }

    @Test func raisingTheGainAsksAndKeepDropsOnlyThatWrite() async throws {
        try await withDesk([(Catalog.headampGain(32), 30), (Catalog.headampGain(33), 10), (Catalog.gate(kick).threshold, -50)]) {
            fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.input, .gate])
            let plan = mirror.loadPlan(preset, parts: [.input, .gate], onto: snare)
            let question = try #require(plan.questions.first)
            #expect(plan.questions.count == 1)
            #expect(question.kind == .gain)
            #expect(question.title.contains("10") && question.title.contains("30"))

            mirror.apply(plan, answers: [question.id: false])

            #expect(await eventually { deskValue(fake, Catalog.gate(snare).threshold) == -50 }, "the rest still loads")
            try await Task.sleep(for: .milliseconds(200))
            #expect(deskValue(fake, Catalog.headampGain(33)) == 10, "kept")
        }
    }

    @Test func acceptingTheGainQuestionRaisesIt() async throws {
        try await withDesk([(Catalog.headampGain(32), 30), (Catalog.headampGain(33), 10)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.input])
            let plan = mirror.loadPlan(preset, parts: [.input], onto: snare)
            let question = try #require(plan.questions.first { $0.kind == .gain })

            mirror.apply(plan, answers: [question.id: true])

            #expect(await eventually { deskValue(fake, Catalog.headampGain(33)) == 30 })
        }
    }

    @Test func theGainQuestionNamesWhoElseSharesThePreamp() async throws {
        try await withDesk([(Catalog.headampGain(44), 10), (Catalog.headampGain(32), 30)]) { _, mirror in
            let vox1 = StripID(.input, 13)
            await readTabs(mirror, kick, vox1)
            let preset = try savePreset(kick, mirror, parts: [.input])
            let plan = mirror.loadPlan(preset, parts: [.input], onto: vox1, locale: .testEnglish)
            let question = try #require(plan.questions.first { $0.kind == .gain })
            #expect(question.message?.contains("Vox 2") == true, "Vox 2 is on the same input")
        }
    }

    @Test func aTrimRaiseAsksLikeAGainRaise() async throws {
        try await withDesk([(Catalog.trim(kick), 6), (Catalog.trim(snare), -3)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.input])
            let plan = mirror.loadPlan(preset, parts: [.input], onto: snare)
            let question = try #require(plan.questions.first { $0.kind == .trim })
            mirror.apply(plan, answers: [question.id: true])
            #expect(await eventually { deskValue(fake, Catalog.trim(snare)) == 6 })
        }
    }

    @Test func switching48VEitherWayAsksAndSameStateDoesNot() async throws {
        try await withDesk([(Catalog.headampPhantom(32), 1), (Catalog.headampGain(32), 10), (Catalog.headampGain(33), 30)]) {
            fake, mirror in
            await readTabs(mirror, kick, snare)
            let on = try savePreset(kick, mirror, parts: [.input])
            let plan = mirror.loadPlan(on, parts: [.input], onto: snare)
            let question = try #require(plan.questions.first { $0.kind == .phantom(on: true) })
            mirror.apply(plan, answers: [question.id: false])
            try await Task.sleep(for: .milliseconds(200))
            #expect(fake.value(at: Catalog.headampPhantom(33).address) == .int(0), "Keep 48V off")
            #expect(question.keep.contains("48V"))

            let samePlan = mirror.loadPlan(on, parts: [.input], onto: kick)
            #expect(samePlan.questions.isEmpty, "kick already has 48V on")
        }
    }

    @Test func aPolarityChangeAsksWithThePolarityPrompt() async throws {
        try await withDesk([(Catalog.invert(kick)!, 1)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.input])
            let plan = mirror.loadPlan(preset, parts: [.input], onto: snare, locale: .testEnglish)
            let question = try #require(plan.questions.first { $0.kind == .polarity })
            #expect(question.title == PolarityPrompt(name: "Snare", isFlipped: false, partner: nil).title)
            mirror.apply(plan, answers: [question.id: true])
            #expect(await eventually { fake.value(at: Catalog.invert(snare)!.address) == .int(1) })
        }
    }

    @Test func movingTheCompAsksOnlyWhenAMixHearsTheDifference() async throws {
        try await withDesk([(Catalog.dynamicsPosition(snare)!, 0)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.comp])
            #expect(preset[.comp, "dyn/pos"] == .option("POST"))
            let quiet = mirror.loadPlan(preset, parts: [.comp], onto: snare)
            #expect(quiet.questions.isEmpty, "the demo's sends are tapped before the fader: no mix changes")

            let bus1 = StripID(.bus, 1)
            fake.deskChange(try #require(Catalog.sendTap(from: snare, to: bus1)).address, .int(Int32(SendTap.preEQ.rawValue)))
            #expect(await eventually { mirror.sendTap(from: snare, to: bus1) == .preEQ })

            let plan = mirror.loadPlan(preset, parts: [.comp], onto: snare)
            let question = try #require(plan.questions.first { $0.kind == .compMove })
            #expect(question.message?.contains("Mon 1") == true)
            mirror.apply(plan, answers: [question.id: false])
            try await Task.sleep(for: .milliseconds(200))
            #expect(fake.value(at: Catalog.dynamicsPosition(snare)!.address) == .int(0), "kept before the EQ")
            #expect(await eventually { deskValue(fake, Catalog.dynamics(snare).ratio) == deskValue(fake, Catalog.dynamics(kick).ratio) })
        }
    }

    @Test func aLinkedPairFollowsAndTheAlertNamesIt() async throws {
        try await withDesk([
            (Catalog.gate(kick).threshold, -45), (Catalog.headampGain(32), 10), (Catalog.headampGain(40), 30),
            (Catalog.headampGain(41), 30),
        ]) { fake, mirror in
            let guitarL = StripID(.input, 9)
            let guitarR = StripID(.input, 10)
            await readTabs(mirror, kick, guitarL)
            let preset = try savePreset(kick, mirror, parts: [.input, .gate])
            let plan = mirror.loadPlan(preset, parts: [.input, .gate], onto: guitarL, locale: .testEnglish)
            #expect(plan.questions.isEmpty, "10 dB is lower than 30")

            mirror.apply(plan, answers: [:])

            #expect(await eventually { deskValue(fake, Catalog.gate(guitarR).threshold) == -45 }, "the partner follows")

            setOnDesk(fake, Catalog.headampPhantom(40), 0)
            let phantom = Preset(
                name: "P", matchWords: [], stripKind: .input, values: [.input: ["headamp/phantom": .flag(true)]])
            let question = try #require(mirror.loadPlan(phantom, parts: [.input], onto: guitarL).questions.first)
            #expect(question.title.contains("Gtr"), "the pair's name: \(question.title)")
            #expect(!question.title.contains("Gtr L"))
        }
    }

    /// A strip no preamp feeds (its source is a card or USB input) has no gain or 48V: Input loads the rest.
    @Test func aStripWithoutAPreampLoadsTheRestOfInput() async throws {
        try await withDesk([(Catalog.trim(kick), -3)]) { fake, mirror in
            await readTabs(mirror, kick)
            let preset = try savePreset(kick, mirror, parts: [.input])
            fake.deskChange(try #require(Catalog.headampIndex(snare)), .int(-1))
            #expect(await eventually { mirror.headamp(of: snare) == nil })
            await readTabs(mirror, snare)

            #expect(mirror.fit(of: .input, in: preset, onto: snare) == .fits)
            mirror.apply(mirror.loadPlan(preset, parts: [.input], onto: snare), answers: [:])

            #expect(await eventually { deskValue(fake, Catalog.trim(snare)) == -3 })
        }
    }

    @Test func sendsLoadByTargetNumber() async throws {
        try await withDesk([(Catalog.sendLevel(from: kick, to: StripID(.bus, 3)), -6)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror, parts: [.sends])
            #expect(preset[.sends, "mix/03/level"] == .number(-6))
            #expect(preset[.sends, "mix/03/type"] != nil, "odd sends carry a tap")
            #expect(preset[.sends, "mix/04/type"] == nil)
            #expect(preset.values[.sends]?.count == 16 * 2 + 8)

            let plan = mirror.loadPlan(preset, parts: [.sends], onto: snare)
            mirror.apply(plan, answers: [:])

            #expect(await eventually { deskValue(fake, Catalog.sendLevel(from: snare, to: StripID(.bus, 3))) == -6 })
        }
    }

    @Test func aPartLoadsOnlyWhenTicked() async throws {
        try await withDesk([(Catalog.gate(kick).threshold, -45), (Catalog.dynamics(kick).threshold, -30)]) { fake, mirror in
            await readTabs(mirror, kick, snare)
            let preset = try savePreset(kick, mirror)
            let before = deskValue(fake, Catalog.dynamics(snare).threshold)
            mirror.apply(mirror.loadPlan(preset, parts: [.gate], onto: snare), answers: [:])
            #expect(await eventually { deskValue(fake, Catalog.gate(snare).threshold) == -45 })
            try await Task.sleep(for: .milliseconds(200))
            #expect(deskValue(fake, Catalog.dynamics(snare).threshold) == before)
        }
    }

    @Test func aPartNotYetReadIsNotWritten() async throws {
        try await withLiveDesk { fake, mirror in
            await readTabs(mirror, kick)
            let preset = try savePreset(kick, mirror, parts: [.gate])
            let unopened = StripID(.input, 22)
            mirror.apply(mirror.loadPlan(preset, parts: [.gate], onto: unopened), answers: [:])
            try await Task.sleep(for: .milliseconds(200))
            #expect(fake.receivedSets.allSatisfy { !$0.address.hasPrefix("/ch/22/") })
        }
    }
}
