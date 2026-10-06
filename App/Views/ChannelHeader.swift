import SwiftUI
import ThumbmixCore

/// The strip's colour and name; tapping it opens Edit strip.
struct ChannelHeader: View {
    let strip: StripID
    let mirror: ConsoleMirror
    @State private var isEditing = false

    var body: some View {
        Button {
            isEditing = true
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3).fill(Theme.color(mirror.color(strip))).frame(width: 8, height: 28)
                Text(mirror.name(strip)).font(.title2.bold()).lineLimit(1)
                Image(systemName: "pencil").font(.subheadline).foregroundStyle(Theme.secondaryText)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .disabled(!mirror.isLive)
        .accessibilityIdentifier("edit-strip")
        .accessibilityLabel("Edit name, colour and icon")
        .sheet(isPresented: $isEditing) { EditStripSheet(strip: strip, mirror: mirror) }
    }
}
