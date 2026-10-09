# TODO

What's next for Thumbmix, newest decisions first within each section. Tick an item off (or delete it) in the PR that finishes it.

## On the real M32

- [ ] **Before using stereo pairs live:** link two channels on the desk, then move the pair's fader in Thumbmix. Does the desk move the other side by itself? The app writes one side and trusts the desk to copy it, then re-reads the other side. If a fader, mute or send didn't follow, the app writes both sides from then on; if anything else didn't follow (gain, EQ incl. low cut, dynamics: unverified), it shows that section per side and writes nothing. Either way it logs "didn't follow a linked edit". **So the other channel moves either way: watching the desk can't tell. Keep Console.app open on the Mac with the iPhone connected, filtered on "thumbmix", and look for that line.** No test can tell either: the fake console was written to copy.
  - If gain, EQ or dynamics didn't follow, the pair's tab switches to "… aren't linked on the desk." and the L/R buttons in the middle of that drag: content moving under the finger. Then pick a layout that can't jump (mock first), e.g. decide per side before the first edit.
- [ ] Run `m32-probe` with Mixing Station connected, and record each answer in a comment where the code depends on it:
  - Section 2: does `/xremote` push to a 7th+ client? The doc mentions a 4-client limit.
  - Section 3: what feeds each input (local preamp, AES50, card such as Dante, USB; Rec or Playback routing), and the gain/trim question. Since #26 the app shows Trim on every input, but the doc lists trim as "digital sources only". On the desk: does a preamp channel offer Trim, and does it change the level? Does a card channel offer only Trim? Does Playback mode change that? Then decide: keep #26, revert it, or show Trim only for card inputs and in Playback mode.
  - Section 4: the DCA bit order.
  - Section 5: the DCA meter slots.
  - Section 6: does `/meters/15` follow `/-prefs/rta/source`, and does "after EQ" include the low cut and the compressor?
  - Section 7: stereo links. Which side moves when a linked fader moves in Mixing Station, what linking copies besides the pans, whether an unticked Link Preference keeps the sides apart, which preference governs sends (assumed Mute/Fader) and the low cut (assumed EQ), and the preferences' factory defaults (the demo assumes all ticked). Also: does switching 48V on one side of a pair with Gain/Delay linked switch the partner's too? The 48V alert assumes it does.
  - Section 8: fader text. Does the desk's own dB text match the app's for every input fader? The app follows the doc's table (p.145), incl. a 0 dB detent and two odd steps (−8.7, −23.2). Set faders near 0, −8.6 and −23.2 with the desk's encoder first; each DIFFERS line goes in `FaderLaw.deskExceptions`. Untested: the fake desk doesn't answer `/node`.
- [ ] **EQ defaults and cut filters.** (a) Reset bands on a bus or main, then compare the six frequencies with what the desk shows: the app writes the desk steps nearest the engineer's 55.1, 152, 418, 1150, 3170 and 8730 Hz (54.5, 153, 418, 1.14k, 3.21k, 8.73k). Fix `Catalog.eqDefaults` if the desk shows other values. (b) Set a band to LCut, HCut and (on a main) BU12: do Gain and Q really do nothing? The app disables both rows there (`Catalog.eqTypeShapesLevel`); the doc lists gain and Q for every type without saying.
- [ ] Does the desk show a channel's delay as a distance too (m or ft)? If it does, match its speed of sound; the app assumes 343 m/s.
- [ ] Walk the acceptance checklist in `README.md`.
- [ ] Check on a device that VoiceOver's swipe up/down adjusts parameter rows. XCUITest can't drive it.

## Fixes

- [ ] **RTA stuck on "waiting for the desk"** after 30 s in another app and back; switching views brings it back. Cause unknown.
- [ ] **Remove the duplicate meter from the Input tab:** the fader row above already shows the level (decided 2026-10-09).
- [ ] **Title and DEMO pill get truncated** on strip screens: the back button ("Thumbmix"), the title and the pill don't fit next to each other. Mock a layout that keeps all three readable on the iPhone SE.
- [ ] **Gain doesn't change the input level in Offline mode.** The demo meters are a time-based animation (`FakeState.meterBlob`) that ignores the desk state, so turning Gain up or down moves nothing. The input meter should follow the headamp gain (and trim), so gain staging can be tried offline. Gates and compressors could act on the demo signal the same way (on a real desk the console does that). Decide first whether it's worth the complexity and the performance cost.

## Performance

- [ ] **Fast, also on older devices.** Scrolling, fader drags, meters and the spectrum must stay smooth on the oldest iPhone the app supports (iOS 17.0: iPhone XS/XR, SE 2nd gen). Profile there with Instruments before and after a change, and keep that in mind for every new feature.

## Features

- [ ] **Output meter on the Mix tab:** the level after gate, EQ and compressor, if the desk sends one (find which meter bank carries it). Decide whether the Sends tab gets it too, by usefulness and the performance cost.
- [ ] **Muted strips' meters:** check whether muting should grey out the meters, or anything else.
- [ ] **Send pan on an input's Sends tab** (the pan on odd-numbered sends, `/ch/NN/mix/01/pan`, `…/03/pan`, …): missing today.
- [ ] **Short taps on slider rows:** decide whether a short tap nudges a fader, gain, delay or other row by one small step, also in the overview.
- [ ] **FX returns get EQ (and the other tabs) like an input:** the desk gives them a 4-band EQ. Check first whether that's good practice for returns.
- [ ] **Group chips within thumb reach.** Move the overview's Inputs/Aux/FX/Buses/DCA/Main chips (`GroupChips`, now at the top) down, so they can be reached easily one-handed with the thumb. Mock it first; the Matrix chip joins that row.
- [ ] **Name of the app.** Settle the name shown on the home screen and in releases.
- [ ] **Input meter marks at −18 dBFS and 0 dBFS?** A nominal-level mark and a clip mark, so gain can be set by eye. Check what the desk's own input meter shows first.
- [x] **The 48V alert names a linked partner.** When the pair's Gain/Delay is linked on the desk, the alert adds "Also powers Gtr R (linked).", like the shared-input line.
- [ ] **Redesign the Connect screen** (start with mocks). It now offers Connect, Scan and Try offline as a plain list; Offline mode's entry was placed there for now.
- [x] **48V as a button beside the Gain row** (mock R2), the same height, red when on, like MUTE beside a fader. Switching phantom power on or off asks first with the system alert ("Turn on 48V for Vox 2?"), plus "Also powers Vox 1 (same input)." when two channels share an input.
- [x] **Reset bands asks with the system alert** ("Reset all 4 bands of Kick?"), like linking and 48V. It names no frequencies: they mean little to non-technical users, and engineers know their desk.
- [x] **Matrix group.** Matrix 1–6 have a chip (last in the row, so DCA and Main stay on an iPhone SE screen) and a strip screen with Mix, EQ (6 bands), Comp and Fed by (the buses and both mains). They link in pairs (`/config/mtxlink/1-2` … `5-6`).
- [ ] **Fed by on Main LR and Main M.** Like a bus's Fed by: every input, aux in, FX return and bus with its LR switch on (`/…/mix/st`), and for Main M those with mono on (`/…/mix/mono`) with their mono level (`/…/mix/mlevel`). Matrices can't feed the mains; they're fed by them.
- [x] **Sends to the matrices from a bus or main screen** (mock B): buses get Mix · EQ · Comp · Sends · Fed by, the mains Mix · EQ · Comp · Sends, with one row per matrix.
- [ ] **Matrix send pan and tap** (`/bus/NN/mix/01/pan`, `…/type`, on the odd sends): needed to feed a stereo matrix pair properly. Neither Fed by tab shows them yet.
- [ ] **Inputs view on buses, like fader flip** on the desk. For each input feeding the bus: its send level, its tap (pre/post EQ, pre/post fader), its send pan and "follow LR pan", the input's own fader level, and its mute. Builds on today's "Fed by" tab.
- [ ] **Channel membership:** pick a channel's mute groups and DCAs from its strip screen, in a quick multi-select.
- [ ] **Replace the Unused / Show unused toggles** on every screen: switched on they're plain white, which looks off. Find a cleaner way to hide strips that aren't patched (mock first).
- [ ] **Solo** per channel.
- [x] **Delay** per channel (mock C): below Trim on the Input tab, an on/off chip and the time in ms and distance (343 m/s; feet on US-region phones). It follows the Gain/Delay link. A double-tap resets it to 0.3 ms, and preamp gain to 0 dB, after a system confirmation.
- [ ] **Inserts** per channel.
- [ ] **Dynamics before or after the EQ:** the toggle that moves the compressor ahead of the EQ.
- [ ] **More compressor settings:** auto time and the key filter frequency.
- [x] **Comp and Gate Mode, Detector and Envelope as dropdowns**, like EQ Type. Mode wasn't broken: it was a drag row that flips only past half its width, easy to miss. The open list says each choice in words with the desk's name under it ("Average level" · RMS); the closed row shows the desk's name. Detector and Envelope sit as a pair under Makeup gain (was "Makeup").
- [x] **Double-tap resets on the Comp and EQ rows.** Makeup gain goes to 0 dB at once; Ratio (3:1), an EQ band's Freq (its default), Q (1.7) and Gain (0 dB) ask first: a reset that can make the channel louder asks.
- [x] **A cut filter's Gain and Q are disabled** (LCut, HCut, and BU6…LR24 on matrices and mains): dimmed and showing "—", still in place, and the graph's drag and pinch leave them alone.
- [ ] **Gate key filter.** Lower priority than the compressor's.
- [x] **Reset bands for buses, matrices and mains** (6 bands): PEQ at 54.5 Hz, 153 Hz, 418 Hz, 1.14 kHz, 3.21 kHz and 8.73 kHz, Q 1.7, 0 dB. Inputs keep 91.4 Hz, 418 Hz, 1.91 kHz and 8.73 kHz.
- [ ] **SVG icons instead of emoji** in Edit strip. Lucide (ISC licence) fits best but has no trumpet, sax, violin or cello. Emoji were chosen for now.

## Maybe later

- [ ] Fold rarely used settings into one line that opens on tap, like "Delay · Off · 12.5 ms ›" (delay mock B). Worth it once the Input tab holds more than gain, trim and delay.
- [ ] A linked pair's pan as one track with an L and an R handle (mock "B"): a picture of the stereo image. Today it's two rows, "Pan · Gtr L" and "Pan · Gtr R"; revisit if those feel clunky.
- [ ] A 7th strip tab: switch the bottom tabs (`StripTabBar`) to scrolling chips (mock "T5"). Six chips are ≈ 55 pt wide on the iPhone SE; seven would be too narrow for "Sends".
- [ ] Spectrum: also show what comes in (pre-EQ) as a faint second glow (mock "V2"). Only if the single post-EQ glow proves too little.
- [ ] Other parameters the app doesn't read yet: the gate key source, and the compressor mix.
- [ ] **Roles, far future:** a first-run choice between musician/vocalist and mixing engineer. An engineer gets the whole desk; a musician gets only their own mix bus (an in-ear or wedge mix).

## Known limits

- The compressor knee is drawn at 2 dB per step: the doc gives the 0–5 knee setting no unit.
- Gate curves (EXPn 1:n, GATE, DUCK) follow the engineer's confirmation; the doc only lists the modes.
- The EQ and low-cut curves are RBJ and Butterworth approximations, not measurements of the desk.
- Xcode's built-in iOS 17.4 simulator doesn't take clicks. Use an iOS 27 simulator for trying the app by hand.
