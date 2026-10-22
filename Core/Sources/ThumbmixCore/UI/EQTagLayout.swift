import Foundation

/// Where the EQ graph puts each point's number tag (2026-10-22, mock T4): the dot sits exactly on the band's value
/// and the tag floats just above it, or below it near the top edge. Tags that would overlap join one row, side by
/// side in frequency order so their stems never cross, centred on their dots and kept inside the graph. Dots never
/// move, so a crowd stays readable without any point lying about its value.
public struct EQTagLayout: Sendable {
    /// A position in the graph's points, x from the left, y from the top.
    public struct Spot: Equatable, Sendable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            (self.x, self.y) = (x, y)
        }
    }

    public let tagSize: Double
    public let gap = 3.0
    public var lift: Double { tagSize - 2 }
    private let margin = 2.0

    public init(tagSize: Double) {
        self.tagSize = tagSize
    }

    /// The band being dragged: its tag keeps the sideways `offset` from its dot it had at touch-down, so it never
    /// slides out from under the finger, and the others make room (Q6 B). Only at an edge does the row, and with it
    /// that tag, stay inside the graph instead.
    public struct Pin: Equatable, Sendable {
        public let band: Int
        public let offset: Double

        public init(band: Int, offset: Double) {
            (self.band, self.offset) = (band, offset)
        }
    }

    public func tags(for dots: [Int: Spot], width: Double, height: Double, pinned: Pin? = nil) -> [Int: Spot] {
        var rows = dots.keys.sorted().map { band in place([band], dots, width: width, height: height, pinned: pinned) }
        while let (first, second) = overlappingPair(in: rows) {
            let joined = place(rows[first].bands + rows[second].bands, dots, width: width, height: height, pinned: pinned)
            rows.remove(at: second)
            rows[first] = joined
        }
        return rows.reduce(into: [:]) { tags, row in tags.merge(row.tags) { $1 } }
    }

    private struct Row {
        let bands: [Int]
        let tags: [Int: Spot]
        let left: Double
        let right: Double
        let y: Double
    }

    private func overlappingPair(in rows: [Row]) -> (Int, Int)? {
        for first in rows.indices {
            for second in rows.indices where second > first {
                let a = rows[first]
                let b = rows[second]
                if a.left < b.right + gap && b.left < a.right + gap && abs(a.y - b.y) < tagSize { return (first, second) }
            }
        }
        return nil
    }

    private func place(_ bands: [Int], _ dots: [Int: Spot], width: Double, height: Double, pinned: Pin?) -> Row {
        let ordered = bands.sorted { (dots[$0]!.x, $0) < (dots[$1]!.x, $1) }
        let step = tagSize + gap
        let rowWidth = Double(ordered.count) * tagSize + Double(ordered.count - 1) * gap
        let wanted: Double
        if let pinned, let index = ordered.firstIndex(of: pinned.band) {
            wanted = dots[pinned.band]!.x + pinned.offset - tagSize / 2 - Double(index) * step
        } else {
            wanted = ordered.map { dots[$0]!.x }.reduce(0, +) / Double(ordered.count) - rowWidth / 2
        }
        let start = min(max(wanted, margin), width - margin - rowWidth)
        let y = rowY(ordered.map { dots[$0]!.y }, height: height)
        let tags = Dictionary(
            uniqueKeysWithValues: ordered.enumerated().map { index, band in
                (band, Spot(x: start + tagSize / 2 + Double(index) * step, y: y))
            })
        return Row(bands: ordered, tags: tags, left: start, right: start + rowWidth, y: y)
    }

    /// Above the highest dot; below the lowest one when that would leave the graph.
    private func rowY(_ dotYs: [Double], height: Double) -> Double {
        let above = dotYs.min()! - lift
        let y = above - tagSize / 2 < margin ? dotYs.max()! + lift : above
        return min(max(y, tagSize / 2 + margin), height - tagSize / 2 - margin)
    }
}
