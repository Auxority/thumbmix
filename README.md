# Thumbmix

An open-source (MIT) iPhone remote for the Midas M32, built for thumbs. Its controls are horizontal fader rows that you drag anywhere. Every common action is at most two taps deep. Channels use the desk's own names and colours everywhere, and the screen is OLED black.

v1 covers inputs, aux, FX returns, buses, mains and DCAs. Where the desk has them, it controls:

- faders, mutes and pan
- preamp gain, trim and 48V
- gate, compressor and 4- or 6-band EQ
- sends, and "fed by" (sends on fader)
- meters

It runs alongside Mixing Station and the desk, and changes made on either show up live.

It supports the Midas M32 family only (FW 4.x), on iPhone only, in portrait only.

## Install with SideStore (free Apple ID)

1. Download `Thumbmix.ipa` from the newest of the [releases](../../releases). Until 1.0.0 they are all pre-releases, which GitHub's "latest" link skips. Every merge to `main` with a `feat:` or `fix:` commit publishes one, tagged with its [semantic version](https://semver.org): a feature bumps the minor number, a fix the patch number. To build it yourself instead, run `scripts/build-ipa.sh` on a Mac with Xcode and XcodeGen (`brew install xcodegen`).
2. AirDrop the IPA to the iPhone, then open it with SideStore (My Apps → +).
3. On first launch, iOS asks for Local Network access. Allow it, or Thumbmix can't reach the desk.

SideStore re-signs apps every 7 days. A free Apple ID allows 3 active sideloaded apps, and SideStore itself counts as one.

## Connect

Join the console's Wi-Fi. Then tap **Scan this network** or type the M32's IP address. Thumbmix reconnects to the last console automatically.

No console nearby? **Try offline (demo console)** runs a demo M32 inside the app, so every screen works without a mixer. A DEMO pill in the title bar shows it isn't a real desk, and each visit starts from a fresh demo desk.

## Develop

```bash
scripts/lint.sh                             # style (swift-format) and complexity/size limits (SwiftLint)
swift test --package-path Core              # protocol, state and UI maths
scripts/ui-test.sh                          # the UI suite, each test against its own fake desk
scripts/strings.sh                          # refresh the app's String Catalog after changing text
scripts/render-icon.sh                      # render Design/AppIcon.svg into the app icon (brew install librsvg imagemagick)
swift run --package-path Core fake-m32      # a fake M32 on 127.0.0.1:10023 for the simulator
xcodegen generate && open Thumbmix.xcodeproj
```

`scripts/ui-test.sh` runs the UI tests on the iPhone SE (3rd generation) simulator, which is 375 pt wide like the iPhone 11 Pro. It runs three test classes at a time on clones of that simulator, and each test starts its own fake desk inside the test runner, so a `fake-m32` you have running doesn't matter. `UI_TEST_WORKERS` sets how many clones. Extra arguments go to `xcodebuild`, e.g. `-only-testing:ThumbmixUITests/ChannelUITests`; `UI_TEST_DESTINATION` (an `xcodebuild -destination` value) picks another simulator. The full log lands in `build/ui-test.log`. To save screenshots for a layout check, prefix the command with `TEST_RUNNER_SCREENSHOT_DIR="$PWD/build/screens"`.

## Check a real console

`swift run --package-path Core m32-probe <M32 IP>` is read-only. It prints:

- the console's model and firmware
- whether `/xremote` pushes arrive while other remotes are connected
- which preamp feeds each input
- the DCA bit order and the meter layout
- how stereo links behave: the Link Preferences, which side moves when a linked fader moves, what linking copies,
  and whether an unticked preference really keeps the sides apart (it asks you to act on the desk)

## Acceptance checklist (real M32)

1. Scan finds the M32, and entering the IP manually works.
2. Names and colours match the desk for all channel types.
3. A fader moved on the desk moves in the app, and vice versa, with Mixing Station also connected.
4. Meters move and roughly match the desk.
5. Gain on an input changes the matching DL32 preamp. Phantom power toggles, and trim works.
6. Gate, EQ and compressor edits are audible or visible on the desk.
7. Sends and Fed by match the desk's sends-on-fader.
8. A pair linked on the desk shows as one row; linking and unlinking from the app's Mix tab does the same on the desk.
8. Power off the access point: the app shows Disconnected and disables its controls. Restore power: the app resyncs and re-enables them.

## Credits

The protocol knowledge comes from Patrick-Gilles Maillot's *Unofficial X32/M32 OSC Remote Protocol*. Thumbmix is not affiliated with Midas, Behringer or Music Tribe.

## Licence

MIT. See `LICENSE`.
