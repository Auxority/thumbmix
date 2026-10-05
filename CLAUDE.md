# Thumbmix

iPhone remote for the Midas M32 over OSC/UDP. `Core/` (Swift package: protocol, state, UI maths, all unit-tested) and `App/` (thin SwiftUI layer). The README covers install, develop and release commands.

## The safety rule

A remote that shows a stale or guessed value as live makes the engineer's next drag jump the desk mid-show. Every change keeps these true:

- The UI shows a value only after the console sent it; `ConsoleMirror.set` ignores controls whose cell was never read.
- When contact is lost the banner says so and controls are disabled; on return the mirror resyncs before going live.
- The user's finger owns a control from touch-down to just after release (`EditHolds`), then the console's value is re-read.

## Protocol facts

OSC addresses, ranges and value laws come from Patrick-Gilles Maillot's *Unofficial X32/M32 OSC Remote Protocol* (v4.09), cited by page in the code. Look facts up there; the fake console (`FakeM32`) encodes assumptions, not the real desk. Behaviour the doc leaves open (the `/xremote` client limit, whether the desk echoes a sender's own sets, DCA bit order, DCA meter slots) is answered by `m32-probe` on real hardware; record the answer in a comment where the code depends on it.

## Done means

`scripts/lint.sh` clean, `swift test --package-path Core` green, and the UI suite green on the **iPhone SE (3rd generation)** simulator (375 pt wide, like the target iPhone 11 Pro) with `fake-m32` running. Every change ships a test that failed first.

## Gotchas

- **Complexity gate** (`.swiftlint.yml`): functions at complexity ≤ 6 and ≤ 40 lines. Split by responsibility to get under it; the limits stay put.
- **Timing**: decisions about time live in pure types (`LinkSupervisor`, `EditHolds`) and are tested with explicit instants. Network tests assert end results with `eventually`, never a sleep-then-check race.
- **Locale**: this Mac's region uses a decimal comma. Unit tests pass `locale: .testEnglish`; UI tests launch with `fixedLocale`. Pin the locale in any new assertion on formatted text.
- **Localization**: user-facing text in Core goes through `CoreStrings.text(...)` and needs an explicit `en` entry in `Core/Sources/ThumbmixCore/Resources/Localizable.xcstrings` (SwiftPM drops empty entries; `LocalizationTests` fails without it). Refresh the app catalog with `xcodebuild -exportLocalizations -project Thumbmix.xcodeproj -localizationPath build/loc -exportLanguage en`.
- **Previews** use `ConsoleMirror.preview()`, which exists only in DEBUG: wrap every `#Preview` in `#if DEBUG` or the release IPA fails to build.
- **Project file**: `Thumbmix.xcodeproj` is generated; edit `project.yml` and run `xcodegen generate`.
- **Releases**: every push to `main` publishes `v<MARKETING_VERSION>-<run number>` with the IPA. Bump `MARKETING_VERSION` in `project.yml` for a new version.
- **Tools**: `brew install xcodegen swiftlint`; `swift format` ships with Xcode.

## Local-only context

`SPEC.md` and `notes/` (design spec, plan, protocol research with sources) live in the original checkout and are git-excluded on purpose. Read them when present; they never get committed.
