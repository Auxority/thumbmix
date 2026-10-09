# Thumbmix

iPhone remote for the Midas M32 over OSC/UDP. `Core/` (Swift package: protocol, state, UI maths, all unit-tested) and `App/` (thin SwiftUI layer).

Read `TODO.md` when choosing what to work on next or picking the project back up; tick an item off in the PR that finishes it.

Read `README.md` before building or running the app, starting `fake-m32`, running `m32-probe`, building the IPA, or checking work against the real-console acceptance checklist: it holds those commands and that list.

## The safety rule

A remote that shows a stale or guessed value as live makes the engineer's next drag jump the desk mid-show. Every change keeps these true:

- The UI shows a value only after the console sent it; `ConsoleMirror.set` ignores controls whose cell was never read.
- When contact is lost the banner says so and controls are disabled; on return the mirror resyncs before going live.
- The user's finger owns a control from touch-down to just after release (`EditHolds`), then the console's value is re-read.
- A desk-wide setting the app borrows (the RTA while an EQ tab is open, `ConsoleMirror+RTA`) is handed back on leaving, and only where the desk still shows the app's value: a change made on the desk meanwhile wins.

## Protocol facts

OSC addresses, ranges and value laws come from Patrick-Gilles Maillot's *Unofficial X32/M32 OSC Remote Protocol* (v4.09), cited by page in the code. Look facts up there: grep `notes/maillot-v4.09.txt`, its `pdftotext -layout` text, and cite the page; the fake console (`FakeM32`) encodes assumptions, not the real desk. Behaviour the doc leaves open (the `/xremote` client limit, whether the desk echoes a sender's own sets, DCA bit order, DCA meter slots) is answered by `m32-probe` on real hardware; record the answer in a comment where the code depends on it.

## Done means

`scripts/lint.sh` clean, `swift test --package-path Core` green, and `scripts/ui-test.sh` green: it runs the UI suite on the **iPhone SE (3rd generation)** simulator (375 pt wide, like the target iPhone 11 Pro), three test classes at a time on clones of it; each test talks to its own fake desk (`UITests/TestDesk.swift`). Every change ships a test that failed first.

The full UI suite takes minutes, so run it once, on the final code, before pushing. While iterating, run only the classes the change touches: `scripts/ui-test.sh -only-testing:ThumbmixUITests/PairUITests`. A change that UI can't see (Core logic with its own tests, docs, CI) doesn't need it.

When `scripts/ui-test.sh` stops before any test with "Failed to clone device … stuck in creation state", run the suite on the SE itself, one test at a time (≈ 4 min): `xcodebuild test -project Thumbmix.xcodeproj -scheme Thumbmix -destination id=<SE id> -parallel-testing-enabled NO`. The SE id is the first `iPhone SE (3rd generation)` in `xcrun simctl list devices available`, as the script picks it. For screenshots, `mkdir -p build/screens` first: `saveScreenshot` doesn't create it.

## How we work

- **New UI starts with a mock.** Show the options side by side in the browser (the superpowers visual companion) and build the one the user picks; they choose layouts by seeing them.
- **`m32-probe` stays read-only.** It never sends a set to the real desk: when a check needs a setting changed, the probe asks the engineer to change it on the desk, then reports what it sees.
- **One PR per concern**, branched from `main`. A change that builds on an unmerged PR waits on its own branch, and its PR opens after the base merges.

## Gotchas

- **Complexity gate** (`.swiftlint.yml`): functions at complexity ≤ 6 and ≤ 40 lines. Split by responsibility to get under it; the limits stay put.
- **Timing**: decisions about time live in pure types (`LinkSupervisor`, `EditHolds`) and are tested with explicit instants. Network tests assert end results with `eventually`, never a sleep-then-check race.
- **Locale**: this Mac's region uses a decimal comma. Unit tests pass `locale: .testEnglish`; UI tests launch with `fixedLocale`. Pin the locale in any new assertion on formatted text.
- **Localization**: user-facing text in Core goes through `CoreStrings.text(...)` and needs an explicit `en` entry in `Core/Sources/ThumbmixCore/Resources/Localizable.xcstrings` (SwiftPM drops empty entries; `LocalizationTests` fails without it). Refresh the app catalog with `scripts/strings.sh`, which also checks both catalogs are strict JSON.
- **Previews** use `ConsoleMirror.preview()`, which exists only in DEBUG: wrap every `#Preview` in `#if DEBUG` or the release IPA fails to build.
- **Project file**: `Thumbmix.xcodeproj` is generated; edit `project.yml` and run `xcodegen generate`.
- **Hooks** (`.claude/settings.json`): an edited Swift file is formatted with `swift format` straight away, and edits inside `Thumbmix.xcodeproj` are blocked.
- **Fake state**: a UI test subclasses `DeskUITestCase`, which starts a fresh fake desk per test on a free port and passes it to the app (`-consolePort`, Debug builds only). To play a change made on the desk, call `desk.change(...)`, before `launch()` when the app should start with it. A long class slows the whole run, since a class runs on one simulator: split one that grows past ~10 tests. The standalone `fake-m32` keeps every set it receives, so a simulator app run by hand against it may need a restart of the fake.
- **375 pt screen edge**: on the iPhone SE the rows under the EQ graph start below the screen's bottom edge. A UI test scrolls by dragging from a visible row (the Type dropdown), never by swiping a hidden one.
- **Held gestures**: `onEnded` never runs when the system cancels a touch (a call, Notification Center). Anything that repeats or holds an edit follows `@GestureState` and stops when the scene leaves `.active`; test the slide-off with `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`.
- **UI waits**: use `appears(within:)` and `eventually(within:)` (`UITests/Waiting.swift`), never `waitForExistence` or a predicate expectation: those look again only once a second, which was a third of the suite's time.
- **Edit holds in tests**: for `ConsoleMirror.editHold` after the app's own edit, pushes for that address are ignored. A test that simulates a later desk change waits that out first.
- **Mirrored parameters**: `CatalogTests.everyTabsParametersAreSynced` checks that whatever a tab shows is in the sync list; a parameter on a new tab, or shown outside `ChannelTab`, gets a line in its `shownAddresses`. A new mirrored parameter also gets a typed default in `DemoState` (the fallback is `.float(0.5)`, wrong for int parameters).
- **Merging**: `main` is protected (required `check`) and PRs are rebase-merged. A branch need not be up to date with `main` to merge; the `check` run on `main` after each merge catches two PRs that break only together. Before rebasing a pushed branch, compare it with `origin/<branch>`: GitHub's "Update branch" adds commits there. A conflict in `App/Localizable.xcstrings` resolves by taking `main`'s version and running `scripts/strings.sh`.
- **Releases**: commit titles set the version, so keep them conventional. On `main`, a `feat:` publishes the next minor version, only `fix:`/`perf:` the next patch, anything else nothing (`scripts/next-version.sh`); before 1.0 a breaking change bumps only the minor. 1.0.0 and release candidates (`1.0.0-rc.1`) are manual runs of the release workflow with the version typed in. Every 0.x and `-rc` is a pre-release. The release job builds only; lint and tests are the PR `check`'s job.
- **Clicking through by hand**: use the `iPhone SE (3rd generation) iOS 27` simulator; the iOS 17.4 one ignores clicks. Xcode 27 ships no Simulator.app: its window opens with `open /Applications/Xcode.app/Contents/Applications/DeviceHub.app`. Build with `xcodebuild build … -destination id=<iOS 27 SE id> -derivedDataPath build/dd-run`, start `swift run --package-path Core fake-m32` in the background, then `xcrun simctl install <id> build/dd-run/Build/Products/Debug-iphonesimulator/Thumbmix.app` and `xcrun simctl launch --terminate-running-process <id> dev.thumbmix.app -lastConsoleHost 127.0.0.1 -consolePort 10023`.
- **Tools**: `brew install xcodegen swiftlint`; `swift format` ships with Xcode.

## Local-only context

`SPEC.md` and `notes/` (design spec, plan, protocol research with sources, and Maillot's protocol PDF) live in the original checkout and are git-excluded on purpose. Read them when present; they never get committed. When the PDF is missing, its link is on Maillot's X32 page (https://sites.google.com/site/patrickmaillot/x32).

Mocks live in `notes/mocks/<date>-<topic>/`, one HTML fragment per question with the options side by side; the spec in `notes/` names the option the user picked. The visual companion writes them inside the session's worktree (`.superpowers/brainstorm/*/content/`), which goes when the worktree does: copy them to `notes/mocks/` once the user has picked. To show one again, wrap the fragment in a page (`<!doctype html>`, dark background) and open it.
