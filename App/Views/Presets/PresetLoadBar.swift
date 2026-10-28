import SwiftUI
import ThumbmixCore

/// Which parts the engineer left out, shared by the preset page's bar and each part page's, so a chip tapped on one
/// shows on the other. `isLoading` holds the pages still from Load to the last alert's answer: a card or Back in the
/// 0.4 s between alerts would open a second bar with a load of its own, or leave this one's alerts with no page.
@Observable final class LoadChoice {
    var unticked: Set<PresetPart> = []
    var isLoading = false
}

/// The parts to load as chips above Load (pick F, 2026-10-28), pinned under the preset page and each part's page: a
/// tap meant for reading a card never changes what loads. What can't load is greyed with its reason. Loading never
/// changes 48V or raises the gain without asking: each such write is a system alert, one after another.
struct PresetLoadBar<Secondary: View>: View {
    let preset: Preset
    let strip: StripID
    let mirror: ConsoleMirror
    let choice: LoadChoice
    @ViewBuilder let secondary: Secondary
    @State private var run: LoadRun?
    /// The pause between one alert and the next; a Cancel in it ends the load.
    @State private var pause: Task<Void, Never>?
    /// Load reads "Loaded" for a moment after a load went out: the page stays, so the engineer sees it happened.
    @State private var justLoaded = false
    @State private var loadedReset: Task<Void, Never>?
    @State private var notice: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) { ForEach(preset.parts) { chip($0) } }
            ForEach(reasons, id: \.self) { Text(verbatim: $0).font(.footnote).foregroundStyle(Theme.secondaryText) }
            Button(loadTitle) { start() }
                .buttonStyle(.wideProminentDarkCapsule)
                .disabled(!mirror.isLive || loadable.isEmpty || choice.isLoading || justLoaded)
                .accessibilityIdentifier("preset-load")
            secondary
        }
        .padding(16)
        .background(Theme.background)
        .alert(
            run?.current?.title ?? "", isPresented: Binding(get: { run?.current != nil }, set: { _ in }),
            presenting: run?.current
        ) { question in
            Button(question.confirm) { answer(question, accepted: true) }
            Button(question.keep, role: .cancel) { answer(question, accepted: false) }
        } message: { question in
            if let message = question.message { Text(verbatim: message) }
        }
        .noticeAlert($notice)
        // A page that goes anyway (the scene closed it) ends its load: nothing is sent unasked.
        .onDisappear(perform: abandon)
    }

    /// Green while it will load; a tap leaves it out. One that can't load is greyed and disabled.
    private func chip(_ part: PresetPart) -> some View {
        let fits = mirror.fit(of: part, in: preset, onto: strip) == .fits
        let isOn = fits && !choice.unticked.contains(part)
        return Button {
            if choice.unticked.contains(part) { choice.unticked.remove(part) } else { choice.unticked.insert(part) }
        } label: {
            Text(verbatim: part.title).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isOn ? Theme.usualOnGreen : Theme.secondaryText)
                .background(isOn ? Theme.usualOnTint : Theme.track, in: Capsule())
                .overlay(Capsule().stroke(isOn ? Theme.usualOnGreen.opacity(0.4) : Theme.raised))
        }
        .buttonStyle(.plain)
        .disabled(!fits)
        .accessibilityIdentifier("load-" + part.rawValue)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Why a part can't load, one line each: "Gate: Aux 1 has no gate".
    private var reasons: [String] {
        preset.parts.compactMap { part in
            switch mirror.fit(of: part, in: preset, onto: strip) {
            case .fits, .notInPreset: nil
            case .reading: "\(part.title): " + String(localized: "reading…")
            case .cannot(let why): "\(part.title): \(why)"
            }
        }
    }

    private var loadTitle: String {
        if justLoaded { return String(localized: "Loaded") }
        let name = mirror.name(strip)
        let count = loadable.count
        guard count > 0, count < preset.parts.count else { return String(localized: "Load onto \(name)") }
        return Self.inflected(AttributedString(localized: "Load ^[\(count) part](inflect: true) onto \(name)"))
    }

    /// Ticked and able to load right now.
    private var loadable: Set<PresetPart> {
        Set(preset.parts.filter { !choice.unticked.contains($0) && mirror.fit(of: $0, in: preset, onto: strip) == .fits })
    }

    private func start() {
        choice.isLoading = true
        run = LoadRun(plan: mirror.loadPlan(preset, parts: loadable, onto: strip))
        finishIfDone()
    }

    private func abandon() {
        pause?.cancel()
        guard run != nil else { return }
        run = nil
        choice.isLoading = false
    }

    private func answer(_ question: PresetQuestion, accepted: Bool) {
        run?.answer(question, accepted: accepted)
        run?.current = nil
        // An alert ignores a new one while it still animates out (CLAUDE.md): the next waits 0.4 s.
        pause = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            run?.advance()
            finishIfDone()
        }
    }

    private func finishIfDone() {
        guard let run, run.isDone else { return }
        self.run = nil
        choice.isLoading = false
        switch mirror.apply(run.plan, answers: run.answers) {
        case .sent: showLoaded()
        case .notLive: notice = String(localized: "Contact with the desk was lost. Nothing was loaded.")
        case .heldBack(let count):
            notice = Self.inflected(
                AttributedString(localized: "^[\(count) setting](inflect: true) were left as they are: the desk changed meanwhile."))
        }
    }

    /// `String(localized:)` leaves "^[2 part](inflect: true)" as it is: only an attributed string inflects.
    private static func inflected(_ text: AttributedString) -> String { String(text.characters) }

    private func showLoaded() {
        justLoaded = true
        loadedReset?.cancel()
        loadedReset = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            justLoaded = false
        }
    }
}

/// A load in progress: the questions still to ask, one at a time, and how each was answered.
private struct LoadRun {
    let plan: LoadPlan
    private(set) var answers: [String: Bool] = [:]
    private var waiting: [PresetQuestion]
    var current: PresetQuestion?

    init(plan: LoadPlan) {
        self.plan = plan
        waiting = plan.questions
        advance()
    }

    var isDone: Bool { current == nil && waiting.isEmpty }

    mutating func answer(_ question: PresetQuestion, accepted isAccepted: Bool) {
        answers[question.id] = isAccepted
    }

    mutating func advance() {
        guard current == nil, !waiting.isEmpty else { return }
        current = waiting.removeFirst()
    }
}
