# Decisions

Settled choices about how Thumbmix behaves, with the reason, so nobody proposes undoing one by accident. Read this before changing existing behaviour. A decision changes only when the user asks; then edit its line here in the same PR. Finished TODOs leave `TODO.md`; anything lasting they decided goes here.

## Platform

- **Latest M32 firmware only** (2026-10-12). No fallbacks for older firmware; X32 and X Air are out of scope.
- **iOS 26 and newer, iPhone only** (2026-10-12): the first iOS with glass, on the same devices as iOS 27 (iPhone 11 and SE 2nd gen onward).
- **Native iOS UI first**: system alerts, switches, sheets and back buttons stay iOS's own.

## Editing values

- **Hold a slider row to type its value** (system alert, Set only). Any unit or none ("−6", "1k", "L20", "-inf"), decimal comma or point. VoiceOver gets an "Enter value" action.
- **A typed value out of range is refused, never clamped** (2026-10-10): "1000000" on a fader must not set +10 dB. Set reopens the alert saying it's out of range, with the text kept. The fader's low end is −∞, so "-200" is −∞.
- **A drag has one speed** (2026-10-12). Finer drags (½, ¼) came only after the value had moved, so they didn't help a small nudge. Hold-then-drag (it would overload the hold that types a value), slow-finger acceleration and a Fine button were mocked and turned down. Exact values are typed or nudged ±1 dB.
- **No tap-to-step, no hold-to-reset.**
- **A double-tap resets at once, without asking**: preamp gain to 0 dB, delay to 0.3 ms, Makeup gain to 0 dB, Ratio to 3:1, an EQ band's Freq to its Reset bands frequency, Q to 1.7, Gain to 0 dB.
- **Changes that are hard to undo ask first, with the system alert**: linking, 48V ("Turn on 48V for Vox 2?", naming a channel that shares the input or a linked partner), and Reset bands ("Reset all 4 bands of Kick?"). The reset alert names no frequencies: they mean little to non-technical users, and engineers know their desk.

## Layout

- **Group chips sit at the bottom, in one dark glass bar that scrolls sideways** (2026-10-12, mock A2 from real iOS 27 screenshots): in thumb reach, and a new group is just one more chip.
- **A send's settings open in a sheet** (2026-10-12, mock H, picked over a pushed send screen and four inline layouts): a › on the send row opens a half-height sheet of black-tinted glass, picked from real iOS 27 screenshots. The sheet keeps you on the Sends tab, in thumb reach, closes with a swipe down, and the strip's fader and mute above it stay usable. Sheets are for details of where you are (like Edit strip), pushed screens for going somewhere. A stereo mix's sheet, with its pans, drags up to full height.
- **A linked bus or matrix pair is one send**, like on the desk. Every odd send has a › (its tap point); the pans show only for a linked pair, since a send pan does nothing on a mono bus. A linked source gets a send pan per side, like its LR pan, and one Follow LR pan switch for both.
- **A send's tap point is a chain of its strip's blocks** (2026-10-12, after eight mock rounds; real iOS 27 screenshots): Input › Gate › EQ › Comp › Fader, in the strip's real order (the comp moves with `dyn/pos`), lit up to where the send is taken, and one sentence on what that means while mixing. Engineers get the consequences wrong, not the labels, so the chain shows what reaches the mix; it replaced a dropdown, which said the same thing twice.
  - Tapping a block takes the send right after it. Tapping the current one does nothing: a nervous double tap mustn't move a monitor mix.
  - Plain names ("Before fader"); the desk's full term sits in the label ("Tap point · Pre-fader").
  - The sentence always takes the longest one's height: nothing below it moves when the tap changes.
  - Subgroup ends the chain: Pan on a stereo mix (it follows the channel's pan), Group on a mono one, so a Subgroup set on the desk never looks like After fader. It asks first with the system alert, since it puts the send at a fixed 0 dB; the other taps change at once.
- **Every strip shows, used or not**: the overview's and Fed by's "Show unused" toggles are gone until hiding is redesigned (TODO).
- **Toolbar buttons and Connect are glass tinted black** (`DarkCapsuleStyle`, 2026-10-12, picked from real iOS 27 screenshots over a flat black capsule), so they sit with iOS's own back button and swipe-back stays. The app's own greys (fader tracks, chips, M) stay: they show where a control is.
- **48V is a button beside the Gain row**, the same height, red when on, like MUTE beside a fader.
- **Delay sits below Trim on the Input tab**: an on/off chip and the time in ms and distance (343 m/s; feet on US-region phones). It follows the Gain/Delay link.
- **The Input tab has no meter of its own**: the fader row above already shows the level (2026-10-09).
- **Comp and Gate Mode, Detector and Envelope are dropdowns**, like EQ Type: the open list says each choice in words with the desk's name under it ("Average level" · RMS); the closed row shows the desk's name.
- **A cut filter's Gain and Q stay in place, dimmed and showing "—"** (LCut, HCut, BU6…LR24), and the graph's drag and pinch leave them alone.
- **Reset bands**: buses, matrices and mains (6 bands) to PEQ at 54.5 Hz, 153.5 Hz, 418 Hz, 1.14 kHz, 3.21 kHz and 8.73 kHz, Q 1.7, 0 dB; inputs keep 91.4 Hz, 418 Hz, 1.91 kHz and 8.73 kHz.
- **Tabs**: buses get Mix · EQ · Comp · Sends · Fed by (Fed by keeps the far right, where a monitor engineer's thumb goes), the mains Mix · EQ · Comp · Sends, matrices Mix · EQ · Comp · Fed by.

## How we decide

- **UI is picked from mocks shown side by side**; glass and material choices from real iOS 27 simulator screenshots, since HTML can't show glass.
- **One app launch per UI test class, not per simulator** (2026-10-12): one launch per simulator measured slower (556 s vs 523 s) and adds an easy-to-forget rule.
