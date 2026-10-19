import SwiftUI
import ThumbmixCore

/// One DCA or mute group in a strip's edit sheet (S1, 2026-10-19): tinted green with a tick while the strip is in,
/// like the Members chip. A mute group that's on right now also gets the red border it has on the Main page.
struct DraftGroupChip: View {
    let title: String
    var caption: String?
    let shown: Assignment
    var isGroupOn = false
    let identifier: String
    let action: () -> Void
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title).font(.headline)
                if let caption { Text(caption).font(.caption2).lineLimit(1) }
                if let side = halfSide { Text(side).font(.caption2.weight(.semibold)) }
            }
            .frame(maxWidth: .infinity, minHeight: 52 * sizeScale)
            .foregroundStyle(shown == .assigned ? Theme.usualOnGreen : Theme.offText)
            .background(shown == .assigned ? Theme.usualOnTint : Theme.track, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                if shown == .assigned {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Theme.usualOnGreen)
                        .padding(5)
                }
            }
            .overlay {
                if isGroupOn { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.muteRed, lineWidth: 2) }
            }
        }
        .buttonStyle(.plain)
        .dimmedUntilRead(shown != .unread)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(value)
    }

    private var halfSide: LocalizedStringKey? {
        switch shown {
        case .leftOnly: "L only"
        case .rightOnly: "R only"
        default: nil
        }
    }

    private var value: Text {
        switch shown {
        case .assigned: Text("Assigned")
        case .unassigned: Text("Not assigned")
        case .leftOnly: Text("Left side only")
        case .rightOnly: Text("Right side only")
        case .unread: Text(verbatim: "")
        }
    }
}
