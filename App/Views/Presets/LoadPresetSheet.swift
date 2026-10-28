import SwiftUI
import ThumbmixCore

/// Which parts of a preset to load onto a strip. What can't load is greyed with its reason. Loading never changes 48V
/// or raises the gain without asking: each such write is a system alert, one after another.
struct LoadPresetSheet: View {
    let preset: Preset
    let strip: StripID
    let mirror: ConsoleMirror
    @Environment(\.dismiss) private var dismiss
    @State private var unticked: Set<PresetPart> = []
    @State private var run: LoadRun?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PresetPart.allCases.filter { preset.holds($0) }) { part in row(part) }
                } footer: {
                    Text("48V changes and a higher gain ask first.")
                }
                .listRowBackground(Theme.track)
            }
            .presetPage(mirror)
            .navigationTitle("Load onto \(mirror.name(strip))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    // Always enabled: a button that changes while an alert is open would lose its action (CLAUDE.md).
                    Button("Load") { start() }
                        .fontWeight(.bold).buttonStyle(.darkCapsule)
                        .disabled(!mirror.isLive || loadable.isEmpty).accessibilityIdentifier("preset-load-confirm")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .alert(
                run?.current?.title ?? "", isPresented: Binding(get: { run?.current != nil }, set: { _ in }),
                presenting: run?.current
            ) { question in
                Button(question.confirm) { answer(question, accepted: true) }
                Button(question.keep, role: .cancel) { answer(question, accepted: false) }
            } message: { question in
                if let message = question.message { Text(verbatim: message) }
            }
        }
        .environment(\.isEnabled, true)
    }

    private func row(_ part: PresetPart) -> some View {
        let fit = mirror.fit(of: part, in: preset, onto: strip)
        return Toggle(isOn: Binding(get: { fit == .fits && !unticked.contains(part) }, set: { set(part, $0) })) {
            VStack(alignment: .leading) {
                Text(verbatim: part.title)
                if let reason = reason(fit) { Text(verbatim: reason).font(.footnote).foregroundStyle(Theme.secondaryText) }
            }
        }
        .disabled(fit != .fits)
        .accessibilityIdentifier("load-" + part.rawValue)
    }

    private func reason(_ fit: PartFit) -> String? {
        switch fit {
        case .fits, .notInPreset: nil
        case .reading: String(localized: "reading…")
        case .cannot(let why): why
        }
    }

    private func set(_ part: PresetPart, _ isOn: Bool) {
        if isOn { unticked.remove(part) } else { unticked.insert(part) }
    }

    /// Ticked and able to load right now.
    private var loadable: Set<PresetPart> {
        Set(preset.parts.filter { !unticked.contains($0) && mirror.fit(of: $0, in: preset, onto: strip) == .fits })
    }

    private func start() {
        let plan = mirror.loadPlan(preset, parts: loadable, onto: strip)
        run = LoadRun(plan: plan)
        finishIfDone()
    }

    private func answer(_ question: PresetQuestion, accepted: Bool) {
        run?.answer(question, accepted: accepted)
        run?.current = nil
        // An alert ignores a new one while it still animates out (CLAUDE.md): the next waits 0.4 s.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            run?.advance()
            finishIfDone()
        }
    }

    private func finishIfDone() {
        guard let run, run.isDone else { return }
        mirror.apply(run.plan, accepting: run.accepted)
        dismiss()
    }
}

/// A load in progress: the questions still to ask, one at a time, and what was said yes to.
private struct LoadRun {
    let plan: LoadPlan
    private(set) var accepted: Set<Int> = []
    private var waiting: [PresetQuestion]
    var current: PresetQuestion?

    init(plan: LoadPlan) {
        self.plan = plan
        waiting = plan.questions
        advance()
    }

    var isDone: Bool { current == nil && waiting.isEmpty }

    mutating func answer(_ question: PresetQuestion, accepted isAccepted: Bool) {
        if isAccepted { accepted.insert(question.id) }
    }

    mutating func advance() {
        guard current == nil, !waiting.isEmpty else { return }
        current = waiting.removeFirst()
    }
}
