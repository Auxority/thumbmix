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
  - Sections 4 and 5: the DCA bit order and the DCA meter slots. Until section 4 has run, check a DCA's Members ticks against the desk once before assigning strips live: with the bit order wrong, a tap would assign the strip to another DCA.
  - Section 6: does `/meters/15` follow `/-prefs/rta/source`, and does "after EQ" include the low cut and the compressor?
  - Section 7: stereo links. 7e: does the Gain/Delay link carry polarity (the Ø alert names the partner as if it does)? Which side moves when a linked fader moves in Mixing Station, what linking copies besides the pans, whether an unticked Link Preference keeps the sides apart, which preference governs sends (assumed Mute/Fader) and the low cut (assumed EQ), and the preferences' factory defaults (the demo assumes all ticked). Also: does switching 48V on one side of a pair with Gain/Delay linked switch the partner's too? The 48V alert assumes it does.
  - Section 7f: Invert on a matrix. The doc lists `/mtx/NN/config/preamp/invert` (p.32), odd for a matrix, and Mixing Station shows no such control. The probe reads `/mtx/01/config/preamp/invert` once; show Invert on a matrix only if the desk answers.
  - Section 7g: an FX return's send to bus 1. The doc lists a return's send pan, tap point and pan follow from bus 3 on (p.30); the app assumes bus 1 has them too. The probe reads `/fxrtn/01/mix/01/type` once; if the desk doesn't answer, drop them for buses 1-2 of returns.
  - Mono mode (not in the probe yet). The doc only names `/config/mono/mode` (LR+M or LCR) and `/config/mono/link` ("M/C depends on Main L/R", p.21). Set LCR on the desk: what does a channel's M/C level do then? Tick the link: does a strip with its LR switch off still reach Main M? Main M's Fed by shows the same rows either way; if the link gates it, say so on that tab.
  - Comp mix (not in the probe yet). What does the desk's dyn screen call `dyn/mix`? The app says "Comp mix"; the M32 manual predates the control. And does Makeup gain lift only the compressed signal, or the blend? Set Threshold 0 dB, Makeup +6 dB and Comp mix 50 %, and play a steady tone below 0 dBFS: the strip's meter rises ~3.5 dB if makeup is on the compressed side only (what `TransferCurve.dynamicsOutput` assumes), 6 dB if it comes after the blend. Fix the curve if it's the latter.
  - Section 8: fader text. Does the desk's own dB text match the app's for every input fader? The app follows the doc's table (p.145), incl. a 0 dB detent and two odd steps (−8.7, −23.2). Set faders near 0, −8.6 and −23.2 with the desk's encoder first; each DIFFERS line goes in `FaderLaw.deskExceptions`. Untested: the fake desk doesn't answer `/node`. Then check whether a formula reproduces the desk's steps, and drop the list if it does; the same goes for any other list of steps that look inconsistent.
  - Inserts (not in the probe yet): does Pre/Post mean before/after EQ on an input channel too (the X32 quick start says so for buses, mains and matrices)? With an aux slot and nothing patched, does the strip go silent, and does that aux in become the return? Does a linked pair's insert follow the link, and under which Link Preference (assumed Dynamics)? What does picking a slot another strip holds do?
- [ ] **EQ cut filters.** Set a band to LCut, HCut and (on a main) BU12: do Gain and Q really do nothing? The app disables both rows there (`Catalog.eqTypeShapesLevel`); the doc lists gain and Q for every type without saying.
  - Crossovers (`Crossover`, guessed): on a matrix or main, set band 1 and band 6 to LR24 at 1 kHz. Does band 1 cut the lows and band 6 the highs? Is it −6 dB at 1 kHz, and BS24 −3 dB? Is band 2 (or 5) really off meanwhile? Can bands 2-5 be set to BU6 … LR24 at all? The app draws those flat.
- [ ] **How VEQ differs from PEQ.** The M32 manual only says VEQ is "a bell filter that provides a more 'Vintage EQ' sound"; the app draws it exactly like PEQ. Set two bands to PEQ and VEQ with the same frequency, gain and Q, and compare the desk's EQ screen (or the RTA on pink noise): skirts that dip past flat (a forum claim), a wider or narrower Q? Then give `EQResponse` its own VEQ curve.
- [ ] **Compressor knee width per step.** The app draws 6 dB per knee step (knee 5 = 30 dB), a guess: no source gives the unit, and `m32-probe` can't read it. Set knee 0 and 5 on the desk and compare its dynamics screen with the app's curve, or measure: a test tone at the threshold, 4:1, and the gain reduction meter at each knee step. Then set `TransferCurve.kneeDecibelsPerStep`.
- [ ] Does the desk show a channel's delay as a distance too (m or ft)? If it does, match its speed of sound; the app assumes 343 m/s.
- [ ] Walk the acceptance checklist in `README.md`.

## Performance

- [ ] **Fast, also on older devices.** Scrolling, fader drags, meters and the spectrum must stay smooth on the oldest iPhone the app supports (iOS 26.0: iPhone 11, SE 2nd gen; the iPhone 11 Pro qualifies). Profile there with Instruments before and after a change, and keep that in mind for every new feature.
  - **Meters only for the strips in view?** Draw (or update) meters only for the rows on screen, not every strip. Measure first; if it saves only 1–2 % CPU, it isn't worth it and this sub-item goes.

## Small fixes

- [ ] **Dashed lines glitch while dragging the threshold** (2026-10-17, the user): on the Gate and Comp graphs the dashed lines jump or flicker as the Threshold moves. Reproduce on the simulator first and say which line does it (likely the curve as set, dashed while Gate/Comp is off since #140, or the threshold mark), then fix.

## Features

- [ ] **Shortcuts** (2026-10-17): App Intents for the Shortcuts app, the Action button and Control Center, e.g. "Mute Vox 1", "Solo Kick", "Fader of Vox 1 to −5 dB". Not Siri voice (the user: unreliable next to a PA). Ask before mocking:
  - Which actions? Each one changes the desk without the engineer looking at the app.
  - The safety rule: an intent connects, reads the current value, then sets; it fails out loud when the desk doesn't answer, never acting on a guess. A relative change ("+3 dB") needs that read; an absolute one ("mute") still needs the desk to answer.
  - Running in the background, often while the app isn't connected: the intent makes its own connection (~0.6 s).
  - Naming strips: the desk's names ("Vox 1") as `AppEntity` values the engineer picks in Shortcuts.
  - Adding the first intent: delete `LM_SKIP_METADATA_EXTRACTION` from `project.yml`, or the system never sees it.
- [ ] **Show the key in Gate and Comp** (2026-10-17): the key source and key filter, in the graph or near it. Mock first.
- [ ] **Too many options at once on Comp, Gate and the Mix tab's Insert block** (2026-10-17). Each needs a redesign that shows less at a time. Mock first.
- [ ] **More reset options** (2026-10-17). Which values get a reset, and where? Ask the user before mocking.
- [ ] **Should picking a view in the app pick it on the desk, or the other way round, or neither?** (2026-10-17) Decide first (e.g. selected channel, the desk's screen page).

- [ ] **Make the insert slot editable** once m32-probe answers what picking a held slot does. The Slot row becomes a menu in place (mock `insert-slot-future-v2.html`): each slot names its effect and the strip holding it; a held slot asks first, naming the strip that loses it.
- [ ] **A gain helper:** listen to an input for a few seconds (the engineer picks how long) and suggest the gain that puts its peaks at a target level. Ties in with the input meter marks under "More meters". Mock first.
- [ ] **Solo on the overview?** A row there is mostly fader, and a solo target competes with it for the thumb. Find a place that keeps the faders easy to drag (mock first). At least show which strips are soloed there (2026-10-17).
- [ ] **Presets from the channel name**, based on James Attaway's *Live Mixing Field Guide*: a channel called "Kick" offers kick presets first (EQ, gate, compressor, low cut). Find a good spot to pick them from (mock first).
- [ ] **More meters**, each weighed by its usefulness and its performance cost (see "Meters only for the strips in view?"):
  - Fed by: a meter per source row showing what it puts into the bus: its signal at the send's tap point (with the fader when post-fader) plus the send level, so a +10 dB fader and a +10 dB send show clipping (2026-10-14, mocks in `notes/mocks/2026-10-14-fed-by-inputs/`). Waits on `m32-probe` section 13: the doc names no per-send meter, only "16 bus send meters" (`/meters/7`, p.18) without saying whose. If they are the selected channel's sends, they cover one strip at a time; computing it from the strip's own meters misses the EQ on Pre/Post EQ taps (only post gain and post-fade are metered, `/meters/6`), a guess the safety rule forbids.
  - Output meter on the Mix tab: the level after gate, EQ and compressor, if the desk sends one (find which meter bank carries it). Decide whether the Sends tab gets it too.
  - Input meter marks at −18 dBFS and 0 dBFS? A nominal-level mark and a clip mark, so gain can be set by eye. Check what the desk's own input meter shows first.
  - Muted strips: check whether muting should grey out the meters, or anything else.
- [ ] **Membership from a strip: mute groups and DCAs.** Pick a strip's mute groups and DCAs on its strip screen, in a quick multi-select. A DCA's Members tab assigns strips since 2026-10-17; consider whether the strip side is worth having too.

## Code and docs

- [ ] **The user rewrites README by hand** (2026-10-17); developer details (build, tests, gates) move to a separate Markdown file.
- [ ] **Try PMD CPD for duplication** (2026-10-17). SonarQube's free local edition has no Swift, and Sigrid guardrails return nothing for Swift. SwiftLint guards complexity and size, and CodeQL (GitHub's default setup) scans Swift on every PR. Decide whether CI runs it. Unused code has no tool: Periphery went (DECISIONS).
- [ ] **A pull request template** (2026-10-17): What and why, How I tested it (lint + Core tests; full UI suite if the change shows in the app), Screenshots. A Maxxton hook on the Mac blocks agents from writing `.github/pull_request_template.md`, so the user adds it.
- [ ] **At 1.0.0: serve the SideStore source as a release asset** (2026-10-16, the user's pick as the cleanest). Each release attaches `source.json` and users add `https://github.com/Auxority/thumbmix/releases/latest/download/source.json`; the `sidestore` branch, its force-push and the "157 behind" in GitHub's branch list go. Waits on 1.0.0, because `latest` skips pre-releases and every 0.x is one. The URL changes, so users must re-add the source once: keep the branch published for a while with a note telling them to, then delete it. Update the DECISIONS line on the `sidestore` branch, README's install step and `scripts/publish-sidestore-source.sh`.

## Maybe later

- [ ] **Headphone correction on a monitor mix:** load a headphone's AutoEQ profile into the EQ of the bus that feeds it. Can 4 bands do it? Fits with "Roles" below (a musician's in-ear mix).
- [ ] **Long term: a landscape layout.**
- [ ] **Long term: Low Power Mode** spends less (e.g. slower meters and spectrum), if that's simple.
- [ ] **Long, long term: iPad.**
- [ ] **Long term: a lightweight API and an MCP server** for the desk.
- [ ] **Long term: effect controls** (reverb and the other FX).
- [ ] Fold rarely used settings into one line that opens on tap, like "Delay · Off · 12.5 ms ›" (delay mock B). Worth it once the Input tab holds more than gain, trim and delay.
- [ ] A linked pair's pan as one track with an L and an R handle (mock "B"): a picture of the stereo image. Today it's two rows, "Pan · Gtr L" and "Pan · Gtr R"; revisit if those feel clunky.
- [ ] A 7th strip tab: six of the bottom pills (`PillBar`) are ≈ 53 pt wide on the iPhone SE; seven would be too narrow for "Sends". Short tab names, as the overview's groups have, or a scrolling bar (mock "T5"), which DECISIONS turned down for the overview.
- [ ] Spectrum: also show what comes in (pre-EQ) as a faint second glow (mock "V2"). Only if the single post-EQ glow proves too little.
- [ ] **Roles, far future:** a first-run choice between musician/vocalist and mixing engineer. An engineer gets the whole desk; a musician gets only their own mix bus (an in-ear or wedge mix).

## Known limits

- Offline mode's meters are a time-based animation (`FakeState.meterBlob`): gain, trim, gate and compressor don't move them. Simulating the signal wasn't worth the complexity (decided 2026-10-09).
- The compressor knee is drawn at 6 dB per step: the doc gives the 0–5 knee setting no unit (see "Compressor knee width per step").
- Gate curves (EXPn 1:n, GATE, DUCK) follow the engineer's confirmation; the doc only lists the modes.
- VEQ is drawn as PEQ: no source gives its shape (see "How VEQ differs from PEQ").
- The comp curve blends Comp mix with Makeup gain on the compressed side only: no source says where makeup sits (see m32-probe "Comp mix").
- The EQ and low-cut curves are RBJ and Butterworth approximations, not measurements of the desk.
