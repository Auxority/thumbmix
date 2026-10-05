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

1. Download `Thumbmix.ipa` from the latest [release](../../releases/latest). Every merge to `main` publishes one, tagged `v<version>-<build>`. To build it yourself instead, run `scripts/build-ipa.sh` on a Mac with Xcode and XcodeGen (`brew install xcodegen`).
2. AirDrop the IPA to the iPhone, then open it with SideStore (My Apps → +).
3. On first launch, iOS asks for Local Network access. Allow it, or Thumbmix can't reach the desk.

SideStore re-signs apps every 7 days. A free Apple ID allows 3 active sideloaded apps, and SideStore itself counts as one.

## Connect

Join the console's Wi-Fi. Then tap **Scan this network** or type the M32's IP address. Thumbmix reconnects to the last console automatically.

## Develop

```bash
swift test --package-path Core              # protocol, state and UI maths
swift run --package-path Core fake-m32      # a fake M32 on 127.0.0.1:10023 for the simulator
xcodegen generate && open Thumbmix.xcodeproj
```

The UI tests expect `fake-m32` to be running. Run them on the iPhone SE (3rd generation) simulator, which is 375 pt wide like the iPhone 11 Pro.

## Check a real console

`swift run --package-path Core m32-probe <M32 IP>` is read-only. It prints:

- the console's model and firmware
- whether `/xremote` pushes arrive while other remotes are connected
- which preamp feeds each input
- the DCA bit order and the meter layout

## Acceptance checklist (real M32)

1. Scan finds the M32, and entering the IP manually works.
2. Names and colours match the desk for all channel types.
3. A fader moved on the desk moves in the app, and vice versa, with Mixing Station also connected.
4. Meters move and roughly match the desk.
5. Gain on an input changes the matching DL32 preamp. Phantom power toggles, and trim works.
6. Gate, EQ and compressor edits are audible or visible on the desk.
7. Sends and Fed by match the desk's sends-on-fader.
8. Power off the access point: the app shows Disconnected and disables its controls. Restore power: the app resyncs and re-enables them.

## Credits

The protocol knowledge comes from Patrick-Gilles Maillot's *Unofficial X32/M32 OSC Remote Protocol*. Thumbmix is not affiliated with Midas, Behringer or Music Tribe.

## Licence

MIT. See `LICENSE`.
