import SwiftUI
import ThumbmixCore

/// Where this strip goes: one row per bus (from a channel) or matrix (from a bus or main), named and coloured as on the desk.
/// The desk keeps one tap point per pair of buses, so a pair shares one tall › that opens its settings (`SendSheet`,
/// mock B): a linked pair is one send, an unlinked pair two rows beside the same ›.
struct SendsTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// Opens a strip's own screen; the names in the sheet's title call it once the sheet is gone.
    let open: (StripID) -> Void
    @State private var openSend: StripID?
    @State private var stripToOpen: StripID?
    @AppStorage(UnusedFoldRow.sendsKey) private var showsUnused = false

    var body: some View {
        ScrollView {
            let unused = mirror.unusedSendTargets(of: strip)
            VStack(spacing: 6) {
                ForEach(pairs(hiding: unused), id: \.self) { pair in
                    sendPair(pair).opacity(pair.allSatisfy(unused.contains) ? 0.45 : 1)
                }
                if !unused.isEmpty { UnusedFoldRow(strips: unused, isOpen: $showsUnused) }
            }
        }
        .keepsFoldInPlace()
        // Pushing a strip while the sheet still covers the screen would be lost: it waits for the sheet to close.
        .sheet(item: $openSend, onDismiss: openChosenStrip) { target in
            SendSheet(source: strip, target: target, mirror: mirror) { stripToOpen = $0 }
                .sendSheetPresentation(stereo: mirror.isLinked(target))
        }
    }

    private func sendPair(_ pair: [StripID]) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 6) {
                ForEach(pair) { target in
                    SendRow(
                        source: strip, target: target, title: mirror.displayName(target), caption: caption(target),
                        accent: Theme.color(mirror.color(target)), mirror: mirror)
                }
            }
            SendSettingsButton(address: Catalog.sendLevel(from: strip, to: pair[0]).address) {
                openSend = pair[0]
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A pair folds as a whole (`unusedSendTargets`): it shares one ›.
    private func pairs(hiding unused: [StripID]) -> [[StripID]] {
        let pairs = mirror.sendPairs(of: strip)
        return showsUnused ? pairs : pairs.filter { !$0.allSatisfy(unused.contains) }
    }

    private func openChosenStrip() {
        guard let chosen = stripToOpen else { return }
        stripToOpen = nil
        open(chosen)
    }

    private func caption(_ target: StripID) -> String? {
        mirror.numberCaption(of: mirror.isLinked(target) ? .pair(target.oddSide) : .strip(target, .full))
    }
}

private struct SendSettingsButton: View {
    let address: String
    let open: () -> Void
    @ScaledMetric private var size: CGFloat = 44

    var body: some View {
        Button(action: open) {
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .frame(width: size * 0.8)
                .frame(minHeight: size, maxHeight: .infinity)
                .foregroundStyle(Theme.secondaryText)
                .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send settings")
        .accessibilityIdentifier("settings-" + address)
    }
}

/// What feeds this bus, matrix or main: a row per strip of every kind that feeds it (`StripKind.feeders`), its
/// switch and level from `Catalog.feedOn` and `feedLevel`.
/// Unused sources whose send here is at −∞ fold into the last row (`UnusedFoldRow`). A linked source pair is one row
/// whenever it is on the overview: the desk links sends with the faders (`LinkSection.of`).
/// A row's tall › opens the send's sheet, as on Sends; the mains have no tap or send pan, so no › (2026-10-14).
struct FedByTab: View {
    let target: StripID
    let mirror: ConsoleMirror
    /// Opened from a channel's send, that channel's row comes into view: it can be the 13th source or further down.
    var focus: StripID?
    /// Opens a strip's own screen; the names in the sheet's title call it once the sheet is gone.
    let open: (StripID) -> Void
    /// The source whose send sheet is open.
    @State private var openSend: StripID?
    @State private var stripToOpen: StripID?
    @AppStorage(UnusedFoldRow.fedByKey) private var showsUnused = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let unused = mirror.unusedSources(of: target)
                SteadyRows(wanted: rows(hiding: unused), mirror: mirror) { rows in
                    VStack(spacing: 6) {
                        if target.kind == .mainStereo { FaderNote() }
                        ForEach(rows) { row in
                            sourceRow(row).opacity(unused.contains(row.held) ? 0.45 : 1).id(row)
                        }
                        if !unused.isEmpty { UnusedFoldRow(strips: unused, isOpen: $showsUnused) }
                    }
                }
            }
            .keepsFoldInPlace()
            .onAppear { scrollToFocus(proxy) }
        }
        // Pushing a strip while the sheet still covers the screen would be lost: it waits for the sheet to close.
        .sheet(item: $openSend, onDismiss: openChosenStrip) { source in
            // The pair's odd side: it keeps the tap and pans, and an unlinked pair's sheet shows both levels.
            SendSheet(source: source, target: target.oddSide, mirror: mirror) { stripToOpen = $0 }
                .sendSheetPresentation(stereo: mirror.isLinked(target))
        }
    }

    private func sourceRow(_ row: OverviewItem) -> some View {
        HStack(spacing: 8) {
            SendRow(
                source: row.held, target: target, title: mirror.title(of: row),
                caption: mirror.fedByCaption(of: row, on: target), accent: Theme.color(mirror.color(row.held)),
                mirror: mirror
            )
            if Catalog.sendTap(from: row.held, to: target.oddSide) != nil {
                SendSettingsButton(address: Catalog.sendLevel(from: row.held, to: target).address) {
                    openSend = row.held
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func openChosenStrip() {
        guard let chosen = stripToOpen else { return }
        stripToOpen = nil
        open(chosen)
    }

    private func rows(hiding unused: [StripID]) -> [OverviewItem] {
        let sources = target.kind.feeders.flatMap(StripID.all)
        return mirror.overviewItems(showsUnused ? sources : sources.filter { !unused.contains($0) }, showUnused: true)
    }

    /// A folded source has no row to bring into view: the list then opens at its top.
    private func scrollToFocus(_ proxy: ScrollViewProxy) {
        guard let focus, let row = rows(hiding: mirror.unusedSources(of: target)).first(where: { $0.holds(focus) })
        else { return }
        proxy.scrollTo(row, anchor: .center)
    }
}

/// Main LR's rows look like send rows, but a drag moves the strip's fader and so its post-fader sends too. The
/// caption says "Fader" on every row; this line says it once more, for whoever skips captions (mock F4, 2026-10-13).
private struct FaderNote: View {
    var body: some View {
        Label("Levels here are each strip's own fader.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
            .accessibilityIdentifier("fader-note")
    }
}

/// One send, or one row of Fed by: On and level, or on Main LR the LR switch and the strip's own fader.
struct SendRow: View {
    let source: StripID
    let target: StripID
    let title: String
    /// nil in the send sheet, whose title names the buses.
    var caption: String?
    let accent: Color
    let mirror: ConsoleMirror
    /// A subgroup send's level is fixed at 0 dB; it can still be switched off.
    var isLevelFixed = false

    var body: some View {
        HStack(spacing: 8) {
            if target.kind == .mainStereo {
                MainLRChip(strip: source, mirror: mirror)
            } else {
                // Tinted, not filled like the other "on" chips: a send is on almost all show, and a column of green
                // fills would shout. Green, as a red source colour would read as mute.
                ToggleChip(
                    spec: Catalog.feedOn(from: source, to: target), mirror: mirror, title: "On",
                    onColor: Theme.usualOnTint, onText: Theme.usualOnGreen
                )
            }
            ParameterRow(
                spec: Catalog.feedLevel(from: source, to: target), mirror: mirror, title: title, caption: caption,
                accent: accent
            )
            .disabled(isLevelFixed)
        }
    }
}

#if DEBUG
    #Preview("Sends") {
        SendsTab(strip: StripID(.input, 13), mirror: .preview()) { _ in }.padding().background(Theme.background)
    }

    #Preview("Fed by") {
        FedByTab(target: StripID(.bus, 1), mirror: .preview()) { _ in }.padding().background(Theme.background)
    }

    #Preview("Matrix fed by") {
        FedByTab(target: StripID(.matrix, 1), mirror: .preview()) { _ in }.padding().background(Theme.background)
    }

    #Preview("Main LR fed by") {
        FedByTab(target: StripID(.mainStereo), mirror: .preview()) { _ in }.padding().background(Theme.background)
    }

    #Preview("Main M fed by") {
        FedByTab(target: StripID(.mainMono), mirror: .preview()) { _ in }.padding().background(Theme.background)
    }
#endif
