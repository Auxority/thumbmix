import SwiftUI
import ThumbmixCore

/// A mute group's name with the pencil, as a strip's (`ChannelHeader`); a tap opens the sheet that renames it (mock
/// R2-B, 2026-10-31). Beside the group's wide button, not in it: that one switches the group.
struct MuteGroupNameRow: View {
    let group: Int
    let mirror: ConsoleMirror
    @State private var isEditing = false
    @ScaledMetric private var minHeight: CGFloat = 32

    var body: some View {
        let isNamed = mirror.muteGroupName(group) != nil
        Button {
            isEditing = true
        } label: {
            HStack(spacing: 10) {
                // Unnamed: the number, grey, as the field's placeholder would read.
                Text(mirror.muteGroupTitle(group)).font(.title2.bold()).lineLimit(1)
                    .foregroundStyle(isNamed ? .white : Theme.secondaryText)
                Image(systemName: "pencil").font(.subheadline).foregroundStyle(Theme.secondaryText)
                Spacer()
            }
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit-mute-group-name")
        .accessibilityLabel("Edit mute group name")
        .accessibilityValue(mirror.muteGroupTitle(group))
        .sheet(isPresented: $isEditing) { MuteGroupNameSheet(group: group, mirror: mirror) }
    }
}

/// The name as a draft with Cancel and Done, as the strip's edit sheet. The name lives on this iPhone, so Done works
/// while contact with the desk is lost.
private struct MuteGroupNameSheet: View {
    let group: Int
    let mirror: ConsoleMirror
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(group: Int, mirror: ConsoleMirror) {
        self.group = group
        self.mirror = mirror
        _name = State(initialValue: mirror.muteGroupName(group) ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                NameField(
                    title: "Name", placeholder: String(localized: "Group \(group)"), name: $name,
                    identifier: "mute-group-name")
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Theme.background)
            .navigationTitle("Mute group \(group)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        mirror.renameMuteGroup(group, to: name)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .buttonStyle(.darkCapsule)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        // Only Cancel and Done close it, as the strip's edit sheet (2026-10-30).
        .interactiveDismissDisabled()
    }
}

#if DEBUG
    #Preview {
        MuteGroupNameRow(group: 2, mirror: .preview()).padding(12).background(Theme.background)
    }
#endif
