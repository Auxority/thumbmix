import Foundation

/// Where a send is taken from its strip: the odd send's `mix/NN/type`, numbered as on the desk (doc p.26).
public enum SendTap: Int, CaseIterable, Sendable {
    case input, preEQ, postEQ, preFader, postFader, subgroup

    /// The desk's abbreviation, which the protocol's choice names use.
    public var deskAbbreviation: String {
        switch self {
        case .input: "IN/LC"
        case .preEQ: "<-EQ"
        case .postEQ: "EQ->"
        case .preFader: "PRE"
        case .postFader: "POST"
        case .subgroup: "GRP"
        }
    }

    /// What the app calls it: plain words for what the send hears.
    public var name: String {
        switch self {
        case .input: CoreStrings.text("Input")
        case .preEQ: CoreStrings.text("Before EQ")
        case .postEQ: CoreStrings.text("After EQ")
        case .preFader: CoreStrings.text("Before fader")
        case .postFader: CoreStrings.text("After fader")
        case .subgroup: CoreStrings.text("Subgroup")
        }
    }

    /// The desk's own term, spelled out (its screen shows IN/LC, <-EQ, EQ->, PRE, POST, GRP).
    public var deskTerm: String {
        switch self {
        case .input: CoreStrings.text("Input")
        case .preEQ: CoreStrings.text("Pre-EQ")
        case .postEQ: CoreStrings.text("Post-EQ")
        case .preFader: CoreStrings.text("Pre-fader")
        case .postFader: CoreStrings.text("Post-fader")
        case .subgroup: CoreStrings.text("Subgroup")
        }
    }
}
