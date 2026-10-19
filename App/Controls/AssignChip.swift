import SwiftUI
import ThumbmixCore

/// Lit with a tick while the row's strip is in the DCA or mute group, an empty ring while not: the colour and the mark
/// carry the state, as a column of words nobody reads would (the user, 2026-10-17). A half-assigned pair names its side.
struct AssignChip: View {
    let strip: StripID
    let membership: Membership
    let mirror: ConsoleMirror
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let assignment = mirror.assignment(of: strip, to: membership)
        Button {
            mirror.toggleAssignment(of: strip, to: membership)
        } label: {
            mark(assignment)
                .frame(width: 72 * sizeScale)
                .frame(minHeight: 48 * sizeScale, maxHeight: .infinity)
                .background(assignment == .assigned ? Theme.usualOnTint : Theme.track, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if [.leftOnly, .rightOnly].contains(assignment) {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.usualOnGreen.opacity(0.6), lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .dimmedUntilRead(assignment != .unread)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .accessibilityValue(value(assignment))
    }

    private var identifier: String {
        switch membership {
        case .dca: "assign-" + strip.id
        case .muteGroup: "mute-assign-" + strip.id
        }
    }

    private var label: Text {
        switch membership {
        case .dca(let dca): Text("\(mirror.displayName(strip)) on \(mirror.name(StripID(.dca, dca)))")
        case .muteGroup(let group): Text("\(mirror.displayName(strip)) in mute group \(group)")
        }
    }

    @ViewBuilder private func mark(_ assignment: Assignment) -> some View {
        switch assignment {
        case .assigned:
            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.black, Theme.usualOnGreen)
        case .leftOnly:
            halfMark("L only")
        case .rightOnly:
            halfMark("R only")
        case .unassigned, .unread:
            Image(systemName: "circle").font(.title3).foregroundStyle(Theme.secondaryText)
        }
    }

    private func halfMark(_ side: LocalizedStringKey) -> some View {
        Text(side).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.usualOnGreen)
    }

    private func value(_ assignment: Assignment) -> Text {
        switch assignment {
        case .assigned: Text("Assigned")
        case .unassigned: Text("Not assigned")
        case .leftOnly: Text("Left side only")
        case .rightOnly: Text("Right side only")
        case .unread: Text(verbatim: "")
        }
    }
}

/// The strip's stripe and name, with the desk number under it and a › to its screen.
struct StripNameBlock: View {
    let title: String
    let caption: String?
    let stripe: ItemStripe
    /// Yellow, and "Solo" in the caption, as everywhere a soloed strip's name shows (2026-10-19).
    var isSoloed = false

    var body: some View {
        HStack(spacing: 10) {
            stripe
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundStyle(isSoloed ? Theme.soloYellow : .white)
                if let shown = isSoloed ? ConsoleMirror.soloCaption(caption) : caption {
                    Text(shown).font(.caption).foregroundStyle(isSoloed ? Theme.soloYellow : .white.opacity(0.6))
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}
