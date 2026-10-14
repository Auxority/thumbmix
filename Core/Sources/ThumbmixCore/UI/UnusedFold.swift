import Foundation

/// Unused strips fold into one row at the end of a list; opened, they return to their desk spots, dimmed (mocks
/// 2026-10-14-unused-strips, A1 + 2). Hiding one must never leave a live send out of reach (#67).
extension ConsoleMirror {
    /// The strips of `strips` a list folds away. A linked pair is one row, so it folds only when both sides are unused.
    /// The mains never fold: every show uses them.
    public func unusedStrips(_ strips: [StripID], where isUnused: (StripID) -> Bool) -> [StripID] {
        strips.filter { strip in
            guard ![.mainStereo, .mainMono].contains(strip.kind), isUnused(strip) else { return false }
            guard isLinked(strip), let partner = strip.partner else { return true }
            return isUnused(partner)
        }
    }

    /// Fed by's sources that fold: unused, and their send here at −∞ (on Main LR the level is the strip's own fader).
    public func unusedSources(of target: StripID) -> [StripID] {
        unusedStrips(target.kind.feeders.flatMap(StripID.all)) { source in
            isUnused(source) && isSilent(Catalog.feedLevel(from: source, to: target))
        }
    }

    /// The Sends tab's mixes that fold: unused, and `strip`'s send to them at −∞. A pair shares one row and one ›, so
    /// it folds only as a whole, linked or not.
    public func unusedSendTargets(of strip: StripID) -> [StripID] {
        guard let kind = strip.kind.sendTarget else { return [] }
        let silent = Set(
            StripID.all(kind).filter { isUnused($0) && isSilent(Catalog.sendLevel(from: strip, to: $0)) })
        return StripID.all(kind).filter { target in
            [target.oddSide, target.oddSide.partner ?? target].allSatisfy(silent.contains)
        }
    }

    /// An unread level isn't silent: unknown must not hide a send.
    private func isSilent(_ level: ParamSpec) -> Bool {
        normalized(level) == 0
    }
}

/// The fold row's list of what it holds: "Ch 3, 6, 13–14, Aux 3–8". A range never wraps inside: word joiners hold the
/// dash, a no-break space the kind to its first number.
public enum UnusedLabel {
    public static func text(_ strips: [StripID]) -> String {
        kindsInOrder(strips).map { kind in
            let numbers = strips.filter { $0.kind == kind }.map(\.number)
            return prefix(kind) + "\u{a0}" + runs(numbers).map(range).joined(separator: ", ")
        }
        .joined(separator: ", ")
    }

    private static func kindsInOrder(_ strips: [StripID]) -> [StripKind] {
        var seen = Set<StripKind>()
        return strips.map(\.kind).filter { seen.insert($0).inserted }
    }

    private static func runs(_ numbers: [Int]) -> [ClosedRange<Int>] {
        numbers.sorted().reduce(into: []) { runs, number in
            if let last = runs.last, last.upperBound + 1 == number {
                runs[runs.count - 1] = last.lowerBound...number
            } else {
                runs.append(number...number)
            }
        }
    }

    private static func range(_ run: ClosedRange<Int>) -> String {
        run.count == 1 ? "\(run.lowerBound)" : "\(run.lowerBound)\u{2060}–\u{2060}\(run.upperBound)"
    }

    private static func prefix(_ kind: StripKind) -> String {
        switch kind {
        case .input: CoreStrings.text("Ch")
        case .auxIn: CoreStrings.text("Aux")
        case .fxReturn: CoreStrings.text("FX")
        case .bus: CoreStrings.text("Bus")
        case .matrix: CoreStrings.text("Matrix")
        case .dca: CoreStrings.text("DCA")
        case .mainStereo: CoreStrings.text("Main LR")
        case .mainMono: CoreStrings.text("Main M")
        }
    }
}
