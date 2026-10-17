import SwiftUI
import ThumbmixCore

/// The strip's full level controls: fader with meter, solo, mute and pan.
struct MixTab: View {
    let strip: StripID
    let mirror: ConsoleMirror
    /// The other side of a linked pair: the fader is shared, but each side keeps its own pan.
    var panPartner: StripID?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ParameterRow(
                    spec: Catalog.fader(strip), mirror: mirror, accent: Theme.color(mirror.color(strip)), height: 72,
                    meter: mirror.meter(strip))
                // Solo and mute are hit mid-show, often in a hurry: they get the bigger targets.
                HStack(spacing: 10) {
                    SoloButton(strip: strip, mirror: mirror)
                    MuteButton(strip: strip, mirror: mirror, title: "MUTE", width: nil, height: 52)
                }
                if let panPartner {
                    ForEach([strip, panPartner]) { side in panRow(side, title: "Pan · \(mirror.name(side))") }
                } else {
                    panRow(strip, title: nil)
                }
                if strip.linkAddress != nil { LinkButton(strip: strip, mirror: mirror) }
                // Under Pan and Link: nothing above moves (mock A′). A pair the desk doesn't link inserts for shows both.
                let blocks = mirror.insertBlocks(strip, partner: panPartner)
                ForEach(blocks, id: \.self) { sides in
                    InsertBlock(
                        sides: sides, mirror: mirror,
                        title: blocks.count == 2 ? String(localized: "Insert · \(mirror.name(sides[0]))") : nil)
                }
            }
        }
        // A single strip fits the SE at default text size and can't scroll, so a fader drag never turns into a page scroll.
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder private func panRow(_ side: StripID, title: String?) -> some View {
        if let pan = Catalog.pan(side) {
            ParameterRow(spec: pan, mirror: mirror, title: title, height: 44)
        }
    }
}

/// Above every tab but Mix, so the engineer can pull, mute or solo a channel while editing its EQ. Letters keep the
/// fader wide; the overview's mute already reads "M".
struct SlimMixRow: View {
    let strip: StripID
    let mirror: ConsoleMirror

    var body: some View {
        HStack(spacing: 10) {
            ParameterRow(
                spec: Catalog.fader(strip), mirror: mirror, accent: Theme.color(mirror.color(strip)), height: 44,
                meter: mirror.meter(strip))
            SoloButton(strip: strip, mirror: mirror, title: "S", width: 48, height: 44)
            MuteButton(strip: strip, mirror: mirror, title: "M", width: 48, height: 44)
        }
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 20) {
            MixTab(strip: StripID(.input, 1), mirror: .preview())
            SlimMixRow(strip: StripID(.input, 1), mirror: .preview())
        }
        .padding()
        .background(Theme.background)
    }
#endif
