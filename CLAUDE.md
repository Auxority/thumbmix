# Thumbmix

iPhone remote for the Midas M32 over OSC/UDP. `Core/` (Swift package: protocol, state, UI maths, all unit-tested) and `App/` (thin SwiftUI layer).

Read `README.md` before building or running the app, starting `fake-m32`, running `m32-probe`, building the IPA, or checking work against the real-console acceptance checklist: it holds those commands and that list.

## The safety rule

A remote that shows a stale or guessed value as live makes the engineer's next drag jump the desk mid-show. Every change keeps these true:

- The UI shows a value only after the console sent it; `ConsoleMirror.set` ignores controls whose cell was never read.
- When contact is lost the banner says so and controls are disabled; on return the mirror resyncs before going live.
- The user's finger owns a control from touch-down to just after release (`EditHolds`), then the console's value is re-read.

## Protocol facts

OSC addresses, ranges and value laws come from Patrick-Gilles Maillot's *Unofficial X32/M32 OSC Remote Protocol* (v4.09), cited by page in the code. Look facts up there; the fake console (`FakeM32`) encodes assumptions, not the real desk. Behaviour the doc leaves open (the `/xremote` client limit, whether the desk echoes a sender's own sets, DCA bit order, DCA meter slots) is answered by `m32-probe` on real hardware; record the answer in a comment where the code depends on it.

## Done means

`scripts/lint.sh` clean, `swift test --package-path Core` green, and the UI suite green on the **iPhone SE (3rd generation)** simulator (375 pt wide, like the target iPhone 11 Pro) with a freshly started `fake-m32`. Every change ships a test that failed first.

## Gotchas

- **Complexity gate** (`.swiftlint.yml`): functions at complexity ≤ 6 and ≤ 40 lines. Split by responsibility to get under it; the limits stay put.
- **Timing**: decisions about time live in pure types (`LinkSupervisor`, `EditHolds`) and are tested with explicit instants. Network tests assert end results with `eventually`, never a sleep-then-check race.
- **Locale**: this Mac's region uses a decimal comma. Unit tests pass `locale: .testEnglish`; UI tests launch with `fixedLocale`. Pin the locale in any new assertion on formatted text.
- **Localization**: user-facing text in Core goes through `CoreStrings.text(...)` and needs an explicit `en` entry in `Core/Sources/ThumbmixCore/Resources/Localizable.xcstrings` (SwiftPM drops empty entries; `LocalizationTests` fails without it). Refresh the app catalog with `xcodebuild -exportLocalizations -project Thumbmix.xcodeproj -localizationPath build/loc -exportLanguage en`.
- **Previews** use `ConsoleMirror.preview()`, which exists only in DEBUG: wrap every `#Preview` in `#if DEBUG` or the release IPA fails to build.
- **Project file**: `Thumbmix.xcodeproj` is generated; edit `project.yml` and run `xcodegen generate`.
- **Fake state**: `fake-m32` keeps every set it receives, from tests and from a simulator app alike, so state-dependent tests fail against a used fake. Restart it before a full run; a UI test that edits picks a channel no other test reads.
- **375 pt screen edge**: on the iPhone SE the rows under the EQ graph start below the screen's bottom edge. A UI test scrolls by dragging from a visible row (the Type dropdown), never by swiping a hidden one.
- **Edit holds in tests**: for `ConsoleMirror.editHold` after the app's own edit, pushes for that address are ignored. A test that simulates a later desk change waits that out first.
- **Mirrored parameters**: `CatalogTests.syncListIsCompleteAndUnique` pins the sync address count. A new mirrored parameter updates that count and its per-strip comment, and gets a typed default in `DemoState` (the fallback is `.float(0.5)`, wrong for int parameters).
- **Merging**: `main` is protected (required `check`, branch up to date) and PRs are rebase-merged. Before rebasing a pushed branch, compare it with `origin/<branch>`: GitHub's "Update branch" adds commits there. A conflict in `App/Localizable.xcstrings` resolves by taking `main`'s version and re-exporting (command above).
- **Releases**: every push to `main` publishes `v<MARKETING_VERSION>-<run number>` with the IPA. The release job builds only; lint and tests are the PR `check`'s job. Bump `MARKETING_VERSION` in `project.yml` for a new version.
- **Tools**: `brew install xcodegen swiftlint`; `swift format` ships with Xcode.

## Local-only context

`SPEC.md` and `notes/` (design spec, plan, protocol research with sources, and Maillot's protocol PDF) live in the original checkout and are git-excluded on purpose. Read them when present; they never get committed. When the PDF is missing, its link is on Maillot's X32 page (https://sites.google.com/site/patrickmaillot/x32).
