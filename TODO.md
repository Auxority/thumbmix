# TODO

What's next for Thumbmix, newest decisions first within each section. Tick an item off (or delete it) in the PR that finishes it.

## On the real M32

- [ ] Run `m32-probe` with Mixing Station connected, and record each answer in a comment where the code depends on it:
  - Section 2: does `/xremote` push to a 7th+ client? The doc mentions a 4-client limit.
  - Section 3: the headamp feeding each input, and whether any preamp channel has a non-zero trim (the app hides trim there).
  - Section 4: the DCA bit order.
  - Section 5: the DCA meter slots.
  - Section 6: does `/meters/15` follow `/-prefs/rta/source`, and does "after EQ" include the low cut and the compressor?
- [ ] Walk the acceptance checklist in `README.md`.
- [ ] Check on a device that VoiceOver's swipe up/down adjusts parameter rows. XCUITest can't drive it.

## Features

- [ ] **Redesign the Connect screen** (start with mocks). It now offers Connect, Scan and Try offline as a plain list; Offline mode's entry was placed there for now.
- [ ] **Matrix group.** Show Matrix 1–6 (overview chip and a basic strip screen) so they can be renamed too.
- [ ] **Reset bands for buses and mains** (6 bands). Needs the engineer's default for each band. Inputs use PEQ at 91.4 Hz, 418 Hz, 1.91 kHz and 8.73 kHz, Q 1.7, 0 dB.
- [ ] **SVG icons instead of emoji** in Edit strip. Lucide (ISC licence) fits best but has no trumpet, sax, violin or cello. Emoji were chosen for now.

## Maybe later

- [ ] A 7th strip tab: switch the bottom tabs (`StripTabBar`) to scrolling chips (mock "T5"). Six chips are ≈ 55 pt wide on the iPhone SE; seven would be too narrow for "Sends".
- [ ] Spectrum: also show what comes in (pre-EQ) as a faint second glow (mock "V2"). Only if the single post-EQ glow proves too little.
- [ ] Parameters the app doesn't read yet: gate key source and filter; compressor detector, envelope, position, mix and auto.

## Known limits

- The compressor knee is drawn at 2 dB per step: the doc gives the 0–5 knee setting no unit.
- Gate curves (EXPn 1:n, GATE, DUCK) follow the engineer's confirmation; the doc only lists the modes.
- The EQ and low-cut curves are RBJ and Butterworth approximations, not measurements of the desk.
- Xcode's built-in iOS 17.4 simulator doesn't take clicks. Use an iOS 27 simulator for trying the app by hand.
