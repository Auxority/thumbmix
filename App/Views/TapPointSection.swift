import SwiftUI
import ThumbmixCore

/// A send's tap point (mock D3/S1, label E3): the strip's blocks as a chain, lit up to where the send is taken,
/// and one sentence on what that means while mixing. Tapping a block takes the send right after it; Subgroup asks
/// first, since it puts the send at a fixed 0 dB whatever its level is now.
struct TapPointSection: View {
    let source: StripID
    let target: StripID
    let mirror: ConsoleMirror
    @State private var confirmsSubgroup = false

    var body: some View {
        let chain = mirror.tapChain(from: source, to: target)
        let tap = mirror.sendTap(from: source, to: target)
        VStack(alignment: .leading, spacing: 8) {
            header(tap)
            TapChainBar(chain: chain, tap: tap) { block in select(block, in: chain, current: tap) }
            explanation(chain, tap)
            if let partner = sharedWith { Text("\(partner) shares this tap point.").font(.footnote).foregroundStyle(Theme.secondaryText) }
        }
        .padding(.top, 6)
        // The desk's value, never a guess: the chain waits until the tap point has been read.
        .disabled(tap == nil)
        .alert("Make this send a subgroup?", isPresented: $confirmsSubgroup) {
            Button("Make subgroup") { set(.subgroup) }
            Button("Cancel", role: .cancel) {}
        } message: {
            // A mono mix has no pan to follow.
            if mirror.isLinked(target) {
                Text("It follows \(mirror.name(source))’s fader and pan at a fixed 0 dB, whatever its level is now.")
            } else {
                Text("It follows \(mirror.name(source))’s fader at a fixed 0 dB, whatever its level is now.")
            }
        }
    }

    /// "Tap point · Pre-fader", with the plain name on the right; the desk's term only where it differs.
    private func header(_ tap: SendTap?) -> some View {
        let deskTerm = tap.flatMap { $0.deskTerm == $0.name ? nil : $0.deskTerm }
        return HStack(alignment: .firstTextBaseline) {
            Text(deskTerm.map { "Tap point · \($0)" } ?? "Tap point")
                .font(.footnote).textCase(.uppercase).foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 8)
            Text(tap?.name ?? "—").font(.headline)
        }
        .accessibilityElement(children: .combine)
    }

    /// Every sentence takes the same room, the longest one's, so nothing below moves when the tap changes.
    private func explanation(_ chain: TapChain, _ tap: SendTap?) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(SendTap.allCases, id: \.self) { candidate in
                Text(chain.explanation(candidate))
                    .opacity(candidate == tap ? 1 : 0)
                    .accessibilityHidden(candidate != tap)
            }
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// An unlinked odd send's tap point is the pair's (the desk sets it per two buses; m32-probe 10b).
    private var sharedWith: String? {
        guard !mirror.isLinked(target), let partner = target.partner else { return nil }
        return mirror.name(partner)
    }

    private func select(_ block: TapBlock, in chain: TapChain, current: SendTap?) {
        guard let current else { return }
        let next = chain.tap(afterTapping: block, current: current)
        guard next != current else { return }
        if next == .subgroup { confirmsSubgroup = true } else { set(next) }
    }

    private func set(_ tap: SendTap) {
        guard let spec = Catalog.sendTap(from: source, to: target) else { return }
        mirror.set(spec.address, .int(Int32(tap.rawValue)))
    }
}

/// Input › Gate › EQ › Comp › Fader (› Pan), lit up to the tap point.
private struct TapChainBar: View {
    let chain: TapChain
    let tap: SendTap?
    let select: (TapBlock) -> Void
    @ScaledMetric private var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(chain.blocks.enumerated()), id: \.element) { index, block in
                if index > 0 {
                    Text("›").font(.footnote).foregroundStyle(Theme.secondaryText).frame(height: height)
                        .background { (isLit(block) ? Self.lit : .clear).padding(.leading, -1) }
                        .accessibilityHidden(true)
                }
                blockButton(block, isFirst: index == 0)
            }
        }
        .padding(4)
        .background(Theme.track, in: Capsule())
    }

    private func blockButton(_ block: TapBlock, isFirst: Bool) -> some View {
        let isLit = isLit(block)
        let isLast = tap.map { chain.lastBlock($0) == block } ?? false
        return Button {
            select(block)
        } label: {
            Text(block.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(isLit ? Color.green : Theme.secondaryText)
                .background {
                    (isLit ? Self.lit : .clear)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: isFirst ? height / 2 : 0, bottomLeadingRadius: isFirst ? height / 2 : 0,
                                bottomTrailingRadius: isLast ? height / 2 : 0, topTrailingRadius: isLast ? height / 2 : 0)
                        )
                        .padding(.leading, isFirst ? 0 : -1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isLit ? "In this mix" : "Not in this mix")
        .accessibilityAddTraits(isLast ? .isSelected : [])
        .accessibilityIdentifier("tap-" + block.name)
    }

    private func isLit(_ block: TapBlock) -> Bool { tap.map { chain.reaches(block, at: $0) } ?? false }

    /// Opaque, and each lit piece reaches a point under its left neighbour: fills that only touched left a hairline
    /// seam where the widths round to pixels.
    private static let lit = Theme.track.mix(with: .green, by: 0.22)
}
