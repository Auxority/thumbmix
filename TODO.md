# TODO

What's next for Thumbmix, newest decisions first within each section. Tick an item off (or delete it) in the PR that finishes it.

## On the real M32

- [ ] **Before using stereo pairs live:** link two channels on the desk, then move the pair's fader in Thumbmix. Does the desk move the other side by itself? The app writes one side and trusts the desk to copy it, then re-reads the other side. If a fader, mute or send didn't follow, the app writes both sides from then on; if anything else didn't follow (gain, EQ incl. low cut, dynamics: unverified), it shows that section per side and writes nothing. Either way it logs "didn't follow a linked edit". No test can tell: the fake console was written to copy.
- [ ] Run `m32-probe` with Mixing Station connected, and record each answer in a comment where the code depends on it:
  - Section 2: does `/xremote` push to a 7th+ client? The doc mentions a 4-client limit.
  - Section 3: the headamp feeding each input.
  - Section 4: the DCA bit order.
  - Section 5: the DCA meter slots.
  - Section 6: does `/meters/15` follow `/-prefs/rta/source`, and does "after EQ" include the low cut and the compressor?
- [ ] Walk the acceptance checklist in `README.md`.
- [ ] Check on a device that VoiceOver's swipe up/down adjusts parameter rows. XCUITest can't drive it.

## Fixes

- [ ] **Title and DEMO pill get truncated** on strip screens: the back button ("Thumbmix"), the title and the pill don't fit next to each other. Mock a layout that keeps all three readable on the iPhone SE.

## Performance

- [ ] **Fast, also on older devices.** Scrolling, fader drags, meters and the spectrum must stay smooth on the oldest iPhone the app supports (iOS 17.0: iPhone XS/XR, SE 2nd gen). Profile there with Instruments before and after a change, and keep that in mind for every new feature.

## Features

- [ ] **Redesign the Connect screen** (start with mocks). It now offers Connect, Scan and Try offline as a plain list; Offline mode's entry was placed there for now.
- [ ] **Matrix group.** Show Matrix 1–6 (overview chip and a basic strip screen), so they can be renamed and mixed too.
- [ ] **Inputs view on buses, like fader flip** on the desk. For each input feeding the bus: its send level, its tap (pre/post EQ, pre/post fader), its send pan and "follow LR pan", the input's own fader level, and its mute. Builds on today's "Fed by" tab.
- [ ] **Channel membership:** pick a channel's mute groups and DCAs from its strip screen, in a quick multi-select.
- [ ] revisit **Unused** approach
- [ ] **Solo** per channel.
- [ ] **Delay** per channel.
- [ ] **Inserts** per channel.
- [ ] **Dynamics before or after the EQ:** the toggle that moves the compressor ahead of the EQ.
- [ ] **More compressor settings:** auto time, the key filter frequency, and the detector and envelope (peak/rms, lin/log). Comp/exp already shows as Mode.
- [ ] **Gate key filter.** Lower priority than the compressor's.
- [ ] **Reset bands for buses and mains** (6 bands). Needs the engineer's default for each band. Inputs use PEQ at 91.4 Hz, 418 Hz, 1.91 kHz and 8.73 kHz, Q 1.7, 0 dB.
- [ ] **SVG icons instead of emoji** in Edit strip. Lucide (ISC licence) fits best but has no trumpet, sax, violin or cello. Emoji were chosen for now.

## Maybe later

- [ ] A 7th strip tab: switch the bottom tabs (`StripTabBar`) to scrolling chips (mock "T5"). Six chips are ≈ 55 pt wide on the iPhone SE; seven would be too narrow for "Sends".
- [ ] Spectrum: also show what comes in (pre-EQ) as a faint second glow (mock "V2"). Only if the single post-EQ glow proves too little.
- [ ] Other parameters the app doesn't read yet: the gate key source, and the compressor mix.
- [ ] **Roles, far future:** a first-run choice between musician/vocalist and mixing engineer. An engineer gets the whole desk; a musician gets only their own mix bus (an in-ear or wedge mix).

## Known limits

- The compressor knee is drawn at 2 dB per step: the doc gives the 0–5 knee setting no unit.
- Gate curves (EXPn 1:n, GATE, DUCK) follow the engineer's confirmation; the doc only lists the modes.
- The EQ and low-cut curves are RBJ and Butterworth approximations, not measurements of the desk.
- Xcode's built-in iOS 17.4 simulator doesn't take clicks. Use an iOS 27 simulator for trying the app by hand.
