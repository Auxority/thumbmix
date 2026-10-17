/// The effect names the desk shows for `/fx/N/type` (doc appendix p.166). FX1-4 hold any of 61 effects; FX5-8 only
/// the 34 insert effects, in another order, so the same index names a different effect.
enum FXEffects {
    static func name(fx: Int, type: Int) -> String? {
        let names = fx <= 4 ? anySlot : insertSlots
        return names.indices.contains(type) ? names[type] : nil
    }

    // Product names as printed on the desk's screen, like the EQ types: not translated.
    private static let anySlot = [
        "Hall Reverb", "Ambiance", "Rich Plate Reverb", "Room Reverb", "Chamber Reverb", "Plate Reverb",
        "Vintage Reverb", "Vintage Room", "Gated Reverb", "Reverse Reverb", "Stereo Delay", "3-Tap Delay",
        "Rhythm Delay", "Stereo Chorus", "Stereo Flanger", "Stereo Phaser", "Dimension-C", "Mood Filter",
        "Rotary Speaker", "Tremolo/Panner", "Suboctaver", "Delay+Chamber", "Chorus+Chamber", "Flanger+Chamber",
        "Delay+Chorus", "Delay+Flanger", "Modulation Delay", "Dual Graphic EQ", "Stereo Graphic EQ", "Dual TrueEQ",
        "Stereo TrueEQ", "Dual DeEsser", "Stereo DeEsser", "Stereo Xtec EQ1", "Dual Xtec EQ1", "Stereo Xtec EQ5",
        "Dual Xtec EQ5", "Wave Designer", "Precision Limiter", "Combinator", "Dual Combinator", "Fair Comp",
        "M/S Fair Comp", "Dual Fair Comp", "Leisure Comp", "Dual Leisure Comp", "Ultimo Comp", "Dual Ultimo Comp",
        "Dual Enhancer", "Stereo Enhancer", "Dual Exciter", "Stereo Exciter", "Stereo Imager", "Edison EX1",
        "Sound Maxer", "Dual Guitar Amp", "Stereo Guitar Amp", "Dual Tube Stage", "Stereo Tube Stage",
        "Dual Pitch Shifter", "Stereo Pitch",
    ]

    private static let insertSlots = [
        "Dual Graphic EQ", "Stereo Graphic EQ", "Dual TrueEQ", "Stereo TrueEQ", "Dual DeEsser", "Stereo DeEsser",
        "Stereo Xtec EQ1", "Dual Xtec EQ1", "Stereo Xtec EQ5", "Dual Xtec EQ5", "Wave Designer", "Precision Limiter",
        "Fair Comp", "M/S Fair Comp", "Dual Fair Comp", "Leisure Comp", "Dual Leisure Comp", "Ultimo Comp",
        "Dual Ultimo Comp", "Dual Enhancer", "Stereo Enhancer", "Dual Exciter", "Stereo Exciter", "Stereo Imager",
        "Edison EX1", "Sound Maxer", "Dual Guitar Amp", "Stereo Guitar Amp", "Dual Tube Stage", "Stereo Tube Stage",
        "Stereo Phaser", "Mood Filter", "Tremolo/Panner", "Suboctaver",
    ]
}
