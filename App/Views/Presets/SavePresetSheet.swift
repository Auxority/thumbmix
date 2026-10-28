import SwiftUI
import ThumbmixCore

/// Name, match words and the parts to keep. Mix and Sends start unticked: the fader and sends belong to this show.
struct SavePresetSheet: View {
    let strip: StripID
    let mirror: ConsoleMirror
    let library: PresetLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var words: String
    @State private var ticked: Set<PresetPart> = [.input, .eq, .gate, .comp]
    @State private var notice: String?

    init(strip: StripID, mirror: ConsoleMirror, library: PresetLibrary) {
        self.strip = strip
        self.mirror = mirror
        self.library = library
        let start = mirror.rawName(strip)
        _name = State(initialValue: start)
        _words = State(initialValue: start)
    }

    private var parts: [PresetPart] { PresetPart.allCases.filter { $0.exists(on: strip) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $name).accessibilityIdentifier("preset-name")
                    TextField("Match words, separated by commas", text: $words).accessibilityIdentifier("preset-words")
                } footer: {
                    Text("Strips whose names contain a match word list this preset first.")
                }
                .listRowBackground(Theme.track)
                Section("Keep") {
                    ForEach(parts) { part in
                        Toggle(isOn: binding(part)) {
                            VStack(alignment: .leading) {
                                Text(verbatim: part.title)
                                if !mirror.isReadForPreset(part, of: strip) {
                                    Text("reading…").font(.footnote).foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                        .disabled(!mirror.isReadForPreset(part, of: strip))
                        .accessibilityIdentifier("keep-" + part.rawValue)
                    }
                }
                .listRowBackground(Theme.track)
            }
            .presetPage(mirror)
            .navigationTitle("Save as preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold).buttonStyle(.darkCapsule)
                        .disabled(!mirror.isLive).accessibilityIdentifier("preset-save-confirm")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .noticeAlert($notice)
        }
        .environment(\.isEnabled, true)
    }

    private func binding(_ part: PresetPart) -> Binding<Bool> {
        Binding(
            get: { ticked.contains(part) && mirror.isReadForPreset(part, of: strip) },
            set: { if $0 { ticked.insert(part) } else { ticked.remove(part) } })
    }

    /// Typed names are checked by the library, which refuses what the desk's file format would: the alert says why.
    private func save() {
        let keep = ticked.filter { mirror.isReadForPreset($0, of: strip) && $0.exists(on: strip) }
        guard !keep.isEmpty else {
            notice = String(localized: "Tick at least one part to keep.")
            return
        }
        let matchWords = words.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let title = name.trimmingCharacters(in: .whitespaces)
        guard let preset = mirror.capture(strip, parts: keep, name: title, matchWords: matchWords) else {
            notice = String(localized: "The desk hasn't sent every value yet. Try again in a moment.")
            return
        }
        do {
            try library.save(preset)
            dismiss()
        } catch {
            notice = error.localizedDescription
        }
    }
}
