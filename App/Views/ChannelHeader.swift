import SwiftUI
import ThumbmixCore

/// The strip's colour and name; tapping it opens Edit strip. The Mix tab adds the "to Main LR" pill on the right.
struct ChannelHeader: View {
    let strip: StripID
    let mirror: ConsoleMirror
    var showsMainLR = false
    @State private var isEditing = false
    /// The LR pill's height on every tab: content mustn't jump 4 pt when switching to or from Mix.
    @ScaledMetric private var minHeight: CGFloat = 32

    var body: some View {
        HStack(spacing: 10) {
            editButton
            // Beside the edit button, not in it: a tap on the pill must not open Edit strip.
            if showsMainLR, strip.mainLR != nil { MainLRPill(strip: strip, mirror: mirror) }
        }
        .frame(minHeight: minHeight)
    }

    private var editButton: some View {
        Button {
            isEditing = true
        } label: {
            HStack(spacing: 10) {
                stripe
                Text(name).font(.title2.bold()).lineLimit(1)
                Image(systemName: "pencil").font(.subheadline).foregroundStyle(Theme.secondaryText)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .disabled(!mirror.isLive)
        .accessibilityIdentifier("edit-strip")
        .accessibilityLabel("Edit name, colour and icon")
        .accessibilityValue(name)
        .sheet(isPresented: $isEditing) { EditStripSheet(strip: strip, mirror: mirror) }
    }

    private var isPair: Bool { mirror.isLinked(strip) }

    private var name: String { isPair ? mirror.pairName(strip) : mirror.name(strip) }

    /// A pair's stripe is cut like its overview row: top for the left side, bottom for the right.
    @ViewBuilder private var stripe: some View {
        let color = Theme.color(mirror.color(strip))
        if isPair, let partner = strip.partner {
            StackedStripe(top: color, bottom: Theme.color(mirror.color(partner)), width: 8, height: 28)
        } else {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 8, height: 28)
        }
    }
}
