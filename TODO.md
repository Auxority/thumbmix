# TODO

What's next for Thumbmix, newest decisions first within each section. The PR that finishes an item deletes it, and records anything lasting it decided in `DECISIONS.md`. For now, pick older items (lower in a section) before the newest ones (2026-10-14).

## On the real M32

- [ ] **Before using stereo pairs live:** link two channels on the desk, then move the pair's fader in Thumbmix. Does the desk move the other side by itself? The app writes one side and trusts the desk to copy it, then re-reads the other side. If a fader, mute or send didn't follow, the app writes both sides from then on; if anything else didn't follow (gain, EQ incl. low cut, dynamics: unverified), it shows that section per side and writes nothing. Either way it logs "didn't follow a linked edit". **So the other channel moves either way: watching the desk can't tell. Keep Console.app open on the Mac with the iPhone connected, filtered on "thumbmix", and look for that line.** No test can tell either: the fake console was written to copy.
  - If gain, EQ or dynamics didn't follow, the pair's tab switches to "… aren't linked on the desk." and the L/R buttons in the middle of that drag: content moving under the finger. Then pick a layout that can't jump (mock first), e.g. decide per side before the first edit.
- [ ] Run `m32-probe` with Mixing Station connected, and record each answer in a comment where the code depends on it:
  - Section 2: does `/xremote` push to a 7th+ client? The doc mentions a 4-client limit.
  - Section 3b: aux ins. With the aux jacks every aux headamp should read -1. Route aux 1-2 from AN1-2 (or A1-2) on the desk and run again: does aux 1's `/-ha/32/index` name the same preamp as the channel on that input? The app then shows Gain and 48V on the aux and names it in that channel's 48V alert.
  - Section 12: connect speed, and whether to raise requests in flight from 8 to 32. Connect reads the overview (690 values) 8 at a time; simulated, 32 at a time is ~4× faster, but the doc warns that a router can drop reply bursts (p.6). The probe times the overview read at 8 and at 32 and counts the unanswered requests: raise it only if 32 is much faster with 0 unanswered.
  - Section 11: EQ defaults. Reset channel 1's, aux 1's and FX 1's EQ on the desk; the probe reads them, and the app's Reset bands gives all three 91.4 Hz, 418 Hz, 1.91 kHz and 8.73 kHz. The probe doesn't cover buses and mains yet: Reset bands on one, then compare the six frequencies with what the desk shows. The app writes the desk steps nearest the engineer's 55.1, 152, 418, 1150, 3170 and 8730 Hz (54.5, 153.5, 418, 1.14k, 3.21k, 8.73k). Fix `Catalog.eqDefaults` where the desk shows other values.
  - Section 3: what feeds each input (local preamp, AES50, card such as Dante, USB; Rec or Playback routing), and the gain/trim question. Since #26 the app shows Trim on every input, but the doc lists trim as "digital sources only". On the desk: does a preamp channel offer Trim, and does it change the level? Does a card channel offer only Trim? Does Playback mode change that? Then decide: keep #26, revert it, or show Trim only for card inputs and in Playback mode.
  - Sections 4 and 5: the DCA bit order and the DCA meter slots.
  - Section 6: does `/meters/15` follow `/-prefs/rta/source`, and does "after EQ" include the low cut and the compressor?
  - Section 7: stereo links. 7e: does the Gain/Delay link carry polarity (the Ø alert names the partner as if it does)? Which side moves when a linked fader moves in Mixing Station, what linking copies besides the pans, whether an unticked Link Preference keeps the sides apart, which preference governs sends (assumed Mute/Fader) and the low cut (assumed EQ), and the preferences' factory defaults (the demo assumes all ticked). Also: does switching 48V on one side of a pair with Gain/Delay linked switch the partner's too? The 48V alert assumes it does.
  - Section 7f: Invert on a matrix. The doc lists `/mtx/NN/config/preamp/invert` (p.32), odd for a matrix, and Mixing Station shows no such control. The probe reads `/mtx/01/config/preamp/invert` once; show Invert on a matrix only if the desk answers.
  - Section 7g: an FX return's send to bus 1. The doc lists a return's send pan, tap point and pan follow from bus 3 on (p.30); the app assumes bus 1 has them too. The probe reads `/fxrtn/01/mix/01/type` once; if the desk doesn't answer, drop them for buses 1-2 of returns.
  - Mono mode (not in the probe yet). The doc only names `/config/mono/mode` (LR+M or LCR) and `/config/mono/link` ("M/C depends on Main L/R", p.21). Set LCR on the desk: what does a channel's M/C level do then? Tick the link: does a strip with its LR switch off still reach Main M? Main M's Fed by shows the same rows either way; if the link gates it, say so on that tab.
  - Section 8: fader text. Does the desk's own dB text match the app's for every input fader? The app follows the doc's table (p.145), incl. a 0 dB detent and two odd steps (−8.7, −23.2). Set faders near 0, −8.6 and −23.2 with the desk's encoder first; each DIFFERS line goes in `FaderLaw.deskExceptions`. Untested: the fake desk doesn't answer `/node`. Then check whether a formula reproduces the desk's steps, and drop the list if it does; the same goes for any other list of steps that look inconsistent.
  - Inserts (not in the probe yet): does Pre/Post mean before/after EQ on an input channel too (the X32 quick start says so for buses, mains and matrices)? With an aux slot and nothing patched, does the strip go silent, and does that aux in become the return? Does a linked pair's insert follow the link, and under which Link Preference (assumed Dynamics)? What does picking a slot another strip holds do?
- [ ] **Key source and Auto time.** Does the desk's key source list call 0 "Self" (the X32 manual) or "Off" (the doc)? The app says Self. With Auto time on, does the desk ignore Attack and Release? If it does, dim them like a cut filter's Gain and Q.
- [ ] **EQ cut filters.** Set a band to LCut, HCut and (on a main) BU12: do Gain and Q really do nothing? The app disables both rows there (`Catalog.eqTypeShapesLevel`); the doc lists gain and Q for every type without saying.
  - Crossovers (`Crossover`, guessed): on a matrix or main, set band 1 and band 6 to LR24 at 1 kHz. Does band 1 cut the lows and band 6 the highs? Is it −6 dB at 1 kHz, and BS24 −3 dB? Is band 2 (or 5) really off meanwhile? Can bands 2-5 be set to BU6 … LR24 at all? The app draws those flat.
- [ ] **Compressor knee width per step.** The app draws 6 dB per knee step (knee 5 = 30 dB), a guess: no source gives the unit, and `m32-probe` can't read it. Set knee 0 and 5 on the desk and compare its dynamics screen with the app's curve, or measure: a test tone at the threshold, 4:1, and the gain reduction meter at each knee step. Then set `TransferCurve.kneeDecibelsPerStep`.
- [ ] Does the desk show a channel's delay as a distance too (m or ft)? If it does, match its speed of sound; the app assumes 343 m/s.
- [ ] Walk the acceptance checklist in `README.md`. On the same device, check that VoiceOver's swipe up/down adjusts parameter rows: XCUITest can't drive it.

## Performance

- [ ] **Fast, also on older devices.** Scrolling, fader drags, meters and the spectrum must stay smooth on the oldest iPhone the app supports (iOS 26.0: iPhone 11, SE 2nd gen; the iPhone 11 Pro qualifies). Profile there with Instruments before and after a change, and keep that in mind for every new feature.
  - **Meters only for the strips in view?** Draw (or update) meters only for the rows on screen, not every strip. Measure first; if it saves only 1–2 % CPU, it isn't worth it and this sub-item goes.

## Small fixes

- [ ] **No "Thumbmix" title on the overview** (`OverviewView`, `.navigationTitle`). Offline mode shows its DEMO pill in that title (`demoTitle`): keep the pill where it moves no control.
- [ ] **Plain words for the desk's filter terms?** The key filter's types (LC6 … HC12, BP Q 1.0 … 10) and EQ types (LCut, PEQ, BU6 …) show the desk's terms. Revisit both together, like Detector's "Average level" · RMS.

## Features

- [ ] **Make the insert slot editable** once m32-probe answers what picking a held slot does. The Slot row becomes a menu in place (mock `insert-slot-future-v2.html`): each slot names its effect and the strip holding it; a held slot asks first, naming the strip that loses it.
- [ ] **Remove the ±1 dB buttons on the Mix tab?** Holding a parameter row now types a value (`ParameterRow`, `onHold`), and the buttons repeat while held (`NudgeButton`). Removing them moves Solo, Mute and the pan up: mid-show, the thumb finds them in a new place.
- [ ] **A gain helper:** listen to an input for a few seconds (the engineer picks how long) and suggest the gain that puts its peaks at a target level. Ties in with the input meter marks under "More meters". Mock first.
- [ ] **Solo on the overview?** A row there is mostly fader, and a solo target competes with it for the thumb. Find a place that keeps the faders easy to drag (mock first).
- [ ] **Presets from the channel name**, based on James Attaway's *Live Mixing Field Guide*: a channel called "Kick" offers kick presets first (EQ, gate, compressor, low cut). Find a good spot to pick them from (mock first).
- [ ] **More meters**, each weighed by its usefulness and its performance cost (see "Meters only for the strips in view?"):
  - Fed by: a meter per source row showing what it puts into the bus: its signal at the send's tap point (with the fader when post-fader) plus the send level, so a +10 dB fader and a +10 dB send show clipping (2026-10-14, mocks in `notes/mocks/2026-10-14-fed-by-inputs/`). Waits on `m32-probe` section 13: the doc names no per-send meter, only "16 bus send meters" (`/meters/7`, p.18) without saying whose. If they are the selected channel's sends, they cover one strip at a time; computing it from the strip's own meters misses the EQ on Pre/Post EQ taps (only post gain and post-fade are metered, `/meters/6`), a guess the safety rule forbids.
  - Output meter on the Mix tab: the level after gate, EQ and compressor, if the desk sends one (find which meter bank carries it). Decide whether the Sends tab gets it too.
  - Input meter marks at −18 dBFS and 0 dBFS? A nominal-level mark and a clip mark, so gain can be set by eye. Check what the desk's own input meter shows first.
  - Muted strips: check whether muting should grey out the meters, or anything else.
- [ ] **Membership: mute groups and DCAs.**
  - From a strip: pick its mute groups and DCAs on its strip screen, in a quick multi-select.
  - From a DCA: add and remove strips on its Members tab (`MembersTab`), which today only lists them. Wanted (2026-10-14); start here, then consider whether the strip side is worth having too.
- [ ] **The group pill design everywhere?** Consider using the pills (Inputs, Aux, FX…) more consistently: on the channel, aux, FX and bus screens too.
- [ ] **Name of the app.** Settle the name shown on the home screen and in releases.
- [ ] **Redesign the Connect screen** (start with mocks). It now offers Connect, Scan and Try offline as a plain list; Offline mode's entry was placed there for now.
- [ ] Maybe later: **the compressor mix** (`dyn/mix`, p.25; the app doesn't read it yet).
- [ ] **SVG icons instead of emoji** in Edit strip. Lucide (ISC licence) fits best but has no trumpet, sax, violin or cello. Emoji were chosen for now.

## Code and docs

- [ ] **Review the code** for simplification, duplication, single responsibility, maintainability and architecture. One PR per concern found.
- [ ] **Update the README:** it's out of date. Check each command and the acceptance checklist against today's app.

## Maybe later

- [ ] **Headphone correction on a monitor mix:** load a headphone's AutoEQ profile into the EQ of the bus that feeds it. Can 4 bands do it? Fits with "Roles" below (a musician's in-ear mix).
- [ ] **Long term: a landscape layout.**
- [ ] **Long term: Low Power Mode** spends less (e.g. slower meters and spectrum), if that's simple.
- [ ] **Long, long term: iPad.**
- [ ] **Long term: a lightweight API and an MCP server** for the desk.
- [ ] **Long term: effect controls** (reverb and the other FX).
- [ ] Fold rarely used settings into one line that opens on tap, like "Delay · Off · 12.5 ms ›" (delay mock B). Worth it once the Input tab holds more than gain, trim and delay.
- [ ] A linked pair's pan as one track with an L and an R handle (mock "B"): a picture of the stereo image. Today it's two rows, "Pan · Gtr L" and "Pan · Gtr R"; revisit if those feel clunky.
- [ ] A 7th strip tab: switch the bottom tabs (`StripTabBar`) to scrolling chips (mock "T5"). Six chips are ≈ 55 pt wide on the iPhone SE; seven would be too narrow for "Sends".
- [ ] Spectrum: also show what comes in (pre-EQ) as a faint second glow (mock "V2"). Only if the single post-EQ glow proves too little.
- [ ] **Roles, far future:** a first-run choice between musician/vocalist and mixing engineer. An engineer gets the whole desk; a musician gets only their own mix bus (an in-ear or wedge mix).

## Known limits

- Offline mode's meters are a time-based animation (`FakeState.meterBlob`): gain, trim, gate and compressor don't move them. Simulating the signal wasn't worth the complexity (decided 2026-10-09).
- The compressor knee is drawn at 6 dB per step: the doc gives the 0–5 knee setting no unit (see "Compressor knee width per step").
- Gate curves (EXPn 1:n, GATE, DUCK) follow the engineer's confirmation; the doc only lists the modes.
- The EQ and low-cut curves are RBJ and Butterworth approximations, not measurements of the desk.
