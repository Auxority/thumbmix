import SwiftUI
import ThumbmixCore

/// Every value of one part (round 4, 2026-10-28): its picture, then one panel per group, two cells to a row, the unit
/// small and grey beside the number. The EQ's bands are a table, a column per band, in the desk's type names. The
/// load chips stay at the bottom, so the engineer can decide here too.
struct PresetPartPage<Bar: View>: View {
    let preset: Preset
    let part: PresetPart
    let mirror: ConsoleMirror
    @ViewBuilder let bar: Bar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PresetPicture(preset: preset, part: part, size: .page).frame(maxWidth: .infinity)
                ForEach(Array(PresetSummary.groups(preset, part).enumerated()), id: \.offset) { index, group in
                    heading(group.title)
                    PresetPanel(cells: group.cells, mirror: mirror).accessibilityIdentifier("preset-group-\(index)")
                }
                if part == .eq { bands }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .presetPage(mirror)
        .navigationTitle(part.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { bar }
    }

    @ViewBuilder private var bands: some View {
        let bands = PresetSummary.bands(preset)
        if !bands.isEmpty {
            heading(String(localized: "Bands"))
            PresetBandTable(bands: bands).accessibilityIdentifier("preset-bands")
        }
    }

    private func heading(_ title: String) -> some View {
        Text(verbatim: title.uppercased()).font(.caption).foregroundStyle(Theme.secondaryText)
            .padding(.top, 14).padding(.bottom, 5).padding(.leading, 4)
    }
}

/// Cells two to a row with hairlines between; an odd last cell spans the row.
private struct PresetPanel: View {
    let cells: [PresetCell]
    let mirror: ConsoleMirror

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(stride(from: 0, to: cells.count, by: 2)), id: \.self) { start in
                HStack(spacing: 1) {
                    ForEach(cells[start..<min(start + 2, cells.count)].indices, id: \.self) { cell(cells[$0]) }
                }
            }
        }
        .background(Theme.raised.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func cell(_ cell: PresetCell) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: cell.bus.map { PresetBusName.label(cell.label, $0, mirror) } ?? cell.label)
                .font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: cell.number).font(.title3.weight(.semibold)).monospacedDigit()
                Text(verbatim: cell.unit).font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.track)
        .accessibilityElement(children: .combine)
    }
}

/// A column per band: the desk's type name, then frequency, gain and Q, each number over its unit, so the desk's
/// widest text ("10.02 kHz") fits a quarter of a 375 pt screen. Gain and Q of a cut band do nothing: shown dim.
private struct PresetBandTable: View {
    let bands: [PresetBand]

    var body: some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 0) {
            GridRow { ForEach(bands, id: \.number) { band in header("Band \(band.number)", band.type) } }
            GridRow { ForEach(bands, id: \.number) { value($0.frequency) } }
            GridRow { ForEach(bands, id: \.number) { value($0.gain, dim: !$0.shapesLevel) } }
            GridRow { ForEach(bands, id: \.number) { value($0.q, dim: !$0.shapesLevel) } }
        }
        .background(Theme.raised.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func header(_ title: LocalizedStringKey, _ type: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            Text(verbatim: type).font(.subheadline.bold())
        }
        .padding(.vertical, 8).frame(maxWidth: .infinity).background(Theme.track)
    }

    private func value(_ parts: ValueParts, dim: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: parts.number).font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(verbatim: parts.unit).font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 6).padding(.horizontal, 2).frame(maxWidth: .infinity)
        .background(Theme.track)
        .opacity(dim ? Theme.dimmedOpacity : 1)
        .accessibilityElement(children: .combine)
    }
}
