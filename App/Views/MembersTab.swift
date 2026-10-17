import SwiftUI
import ThumbmixCore

/// Every strip a DCA can hold, under its group's heading in desk order (mock 2026-10-17-dca-members, D with I3
/// marks). The chip assigns at once, the name opens the strip, as on Fed by. No row moves on a tap; unused strips
/// that aren't assigned fold into the last row.
struct MembersTab: View {
    let dca: Int
    let mirror: ConsoleMirror
    let open: (StripID) -> Void
    @AppStorage(UnusedFoldRow.membersKey) private var showsUnused = false

    var body: some View {
        ScrollView {
            let unused = mirror.unusedStrips(notAssignedTo: dca)
            VStack(spacing: 6) {
                AssignNote()
                ForEach(ConsoleMirror.dcaAssignableGroups) { group in
                    let rows = mirror.assignmentRows(group.strips.filter { showsUnused || !unused.contains($0) })
                    if !rows.isEmpty {
                        Text(group.title).sectionLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    ForEach(rows) { row in
                        memberRow(row).opacity(unused.contains(row.held) ? 0.45 : 1)
                    }
                }
                if !unused.isEmpty { UnusedFoldRow(strips: unused, isOpen: $showsUnused) }
            }
        }
        .keepsFoldInPlace()
    }

    private func memberRow(_ row: OverviewItem) -> some View {
        HStack(spacing: 8) {
            AssignChip(strip: row.held, dca: dca, mirror: mirror)
            Button {
                open(row.opens)
            } label: {
                StripNameBlock(
                    title: mirror.title(of: row), caption: mirror.numberCaption(of: row),
                    accent: Theme.color(mirror.color(row.held)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("member-" + row.held.id)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Lit with a tick while the row's strip is on the DCA, an empty ring while not: the colour and the mark carry the
/// state, as a column of words nobody reads would (the user, 2026-10-17). A half-assigned pair names its side.
private struct AssignChip: View {
    let strip: StripID
    let dca: Int
    let mirror: ConsoleMirror
    @ScaledMetric private var sizeScale: CGFloat = 1

    var body: some View {
        let assignment = mirror.dcaAssignment(of: strip, to: dca)
        Button {
            mirror.toggleDCAAssignment(of: strip, to: dca)
        } label: {
            mark(assignment)
                .frame(width: 72 * sizeScale)
                .frame(minHeight: 48 * sizeScale, maxHeight: .infinity)
                .background(assignment == .assigned ? Theme.usualOnTint : Theme.track, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if isHalf(assignment) {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.usualOnGreen.opacity(0.6), lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .dimmedUntilRead(assignment != .unread)
        .accessibilityIdentifier("assign-" + strip.id)
        .accessibilityLabel(Text("\(mirror.displayName(strip)) on \(mirror.name(StripID(.dca, dca)))"))
        .accessibilityValue(value(assignment))
    }

    @ViewBuilder private func mark(_ assignment: DCAAssignment) -> some View {
        switch assignment {
        case .assigned:
            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.black, Theme.usualOnGreen)
        case .leftOnly, .rightOnly:
            Text(assignment == .leftOnly ? "L only" : "R only")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.usualOnGreen)
        case .unassigned, .unread:
            Image(systemName: "circle").font(.title3).foregroundStyle(Theme.secondaryText)
        }
    }

    private func isHalf(_ assignment: DCAAssignment) -> Bool {
        assignment == .leftOnly || assignment == .rightOnly
    }

    private func value(_ assignment: DCAAssignment) -> Text {
        switch assignment {
        case .assigned: Text("Assigned")
        case .unassigned: Text("Not assigned")
        case .leftOnly: Text("Left side only")
        case .rightOnly: Text("Right side only")
        case .unread: Text(verbatim: "")
        }
    }
}

/// The strip's name in its colour, with the desk number under it and a › to its screen.
private struct StripNameBlock: View {
    let title: String
    let caption: String?
    let accent: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if let caption { Text(caption).font(.caption).foregroundStyle(.white.opacity(0.6)) }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        // Tinted over the track, as a Fed by row's fill is: on black the same tint reads darker.
        .background(accent.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}

/// Joining takes the DCA's fader and mute at once: say so once, above the chips.
private struct AssignNote: View {
    var body: some View {
        Label("An assigned strip follows this DCA's fader and mute at once.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
            .accessibilityIdentifier("assign-note")
    }
}

#if DEBUG
    #Preview {
        MembersTab(dca: 1, mirror: .preview()) { _ in }.padding().background(Theme.background)
    }
#endif
