# Thumbmix

iPhone remote for the Midas M32 over OSC/UDP. `Core/` (Swift package: protocol, state, UI maths, all unit-tested) and `App/` (thin SwiftUI layer).

Read `TODO.md` when choosing what to work on next or picking the project back up; the PR that finishes an item deletes it from the file. Read `DECISIONS.md` before changing how something already behaves: it holds the settled choices and why. Anything lasting a finished item decided goes there.

Read `README.md` before building or running the app, starting `fake-m32`, running `m32-probe`, building the IPA, or checking work against the real-console acceptance checklist: it holds those commands and that list.

## The safety rule

A remote that shows a stale or guessed value as live makes the engineer's next drag jump the desk mid-show. Every change keeps these true:

- The UI shows a value only after the console sent it; `ConsoleMirror.set` ignores controls whose cell was never read.
- When contact is lost the banner says so and controls are disabled; on return the mirror resyncs before going live.
- The user's finger owns a control from touch-down to just after release (`EditHolds`), then the console's value is re-read.
- A desk-wide setting the app borrows (the RTA while an EQ tab is open, `ConsoleMirror+RTA`) is handed back on leaving, and only where the desk still shows the app's value: a change made on the desk meanwhile wins.

## Protocol facts

OSC addresses, ranges and value laws come from Patrick-Gilles Maillot's *Unofficial X32/M32 OSC Remote Protocol* (v4.09), cited by page in the code. Look facts up there: grep `notes/maillot-v4.09.txt`, its `pdftotext -layout` text, and cite the printed page, the first footer after the hit (`awk 'NR>=<line> && /Unofficial X32\/M32 OSC Remote Protocol/ {print; exit}' notes/maillot-v4.09.txt`); the fake console (`FakeM32`) encodes assumptions, not the real desk. Behaviour the doc leaves open (the `/xremote` client limit, whether the desk echoes a sender's own sets, DCA bit order, DCA meter slots) is answered by `m32-probe` on real hardware; record the answer in a comment where the code depends on it. What the desk itself shows and calls things (mode names, key sources) comes from the Midas M32 user manual: grep `notes/midas-m32-user-manual.txt`, decoded by `notes/decode-m32-manual.py` because the PDF's font shifts every character (raw `pdftotext` gives garbage), and cite its section; its page numbers don't survive the decoding.

## Done means

`scripts/lint.sh` and `scripts/unused.sh` clean, `swift test --package-path Core` green, and `scripts/ui-test.sh` green: it runs the UI suite on the **iPhone SE (3rd generation)** simulator on iOS 26+ (375 pt wide, like the target iPhone 11 Pro). Every change ships a test that failed first.

**Keep the loop tight.** Iterate on `swift test --package-path Core` (seconds): put the logic in Core, where a unit test reaches it, and keep the App layer thin enough that a UI test only checks the wiring. Any UI run costs minutes and loads the Mac, even one class. While working, run only the classes a change touches (`scripts/ui-test.sh SendsUITests`). The full suite runs at two moments: just before opening a PR, and just before pushing new code to an open PR. A branch pushed while its PR waits on its base, a rebase that changes no code, and a change UI can't see (Core logic with its own tests, docs, CI) need no full run.

**One launch per UI test class.** A launch is ~6.5 s of a test (XCTest attaching to the app), so `DeskUITestCase` launches once per class and sends each later test's fresh desk as `thumbmix-test://connect?port=N` (Debug builds only, `AppModel.openTestURL`); it relaunches when a test passes other launch arguments. A test therefore starts on the overview with nothing open, but must not rely on app state another test left (none survives today except the last host). Rerun only the failed tests, one at a time, rather than the whole suite: `scripts/ui-test.sh EQUITests/testX …` runs just those, on the SE itself.

**A hung UI run.** A healthy run starts its first test within ~2 min of the build; `scripts/ui-test.sh` stops one that hasn't (exit 2), since waiting ends only at xcodebuild's ~6 min timeout with "The test runner hung before establishing connection" and 0 tests run. The cause is unknown. Tell the user instead of retrying; they decide whether the PR goes up with the UI test unrun (then the PR says so).

**Exit 3: the Mac slept mid-run** (lid closed on battery): every running test stalls 15+ min and fails with "Timed out while synthesizing event". The failures say nothing about the app; ask the user to keep the Mac awake and run the full suite again.

When `scripts/ui-test.sh` stops before any test with "Failed to clone device … stuck in creation state", run the suite on the SE itself, one test at a time (≈ 4 min): `scripts/ui-test.sh --serial`. Every run saves `saveScreenshot` images to `build/screens`.

## How we work

- **New UI starts with a browser mock.** Show the options side by side in the browser (the superpowers visual companion), never as a text preview in a question, and build the one the user picks; they choose layouts by seeing them. Each option's note says what the engineer's touch changes mid-show (what else moves), not only how it looks. Mock for one thumb on a 5.8″ iPhone: frequent taps sit in the lower half, and each phone shows the thumb-reach overlay (copy it from `notes/mocks/2026-10-15-connect-screen/connect-layout-v2.html`).
- **`m32-probe` stays read-only.** It never sends a set to the real desk: when a check needs a setting changed, the probe asks the engineer to change it on the desk, then reports what it sees.
- **One PR per concern**, branched from `main`. A change that builds on an unmerged PR waits on its own branch, and its PR opens after the base merges.

## Gotchas

- **Complexity gate** (`.swiftlint.yml`): functions at complexity ≤ 6 and ≤ 40 lines. Split by responsibility to get under it; the limits stay put.
- **Timing**: decisions about time live in pure types (`LinkSupervisor`, `EditHolds`) and are tested with explicit instants. Network tests assert end results with `eventually`, never a sleep-then-check race.
- **Locale**: this Mac's region uses a decimal comma. Unit tests pass `locale: .testEnglish`; UI tests launch with `fixedLocale`. Pin the locale in any new assertion on formatted text.
- **Localization**: user-facing text in Core goes through `CoreStrings.text(...)`. Run `scripts/strings.sh` after changing user-facing text: it refreshes both catalogs, gives new Core text its English value (SwiftPM drops empty entries; `LocalizationTests` fails on one), and checks both catalogs are strict JSON.
- **Previews** use `ConsoleMirror.preview()`, which exists only in DEBUG: wrap every `#Preview` in `#if DEBUG` or the release IPA fails to build.
- **Project file**: `Thumbmix.xcodeproj` is generated; edit `project.yml` and run `xcodegen generate`.
- **Hooks** (`.claude/settings.json`): an edited Swift file is formatted with `swift format` straight away, and edits inside `Thumbmix.xcodeproj` are blocked.
- **Fake state**: a UI test subclasses `DeskUITestCase`, which starts a fresh fake desk per test on a free port and passes it to the app (`-consolePort`, Debug builds only). To play a change made on the desk, call `desk.change(...)`, before `launch()` when the app should start with it. A long class slows the whole run, since a class runs on one simulator: split one that grows past ~10 tests. The standalone `fake-m32` keeps every set it receives, so a simulator app run by hand against it may need a restart of the fake.
- **375 pt screen edge**: on the iPhone SE the rows under the EQ graph start below the screen's bottom edge. A UI test scrolls by dragging from a visible row (the Type dropdown), never by swiping a hidden one. `exists` is true for an off-screen row too, and a drag on one lands under the tab bar: assert `isHittable` before dragging.
- **System alerts** (iOS 27): an alert button whose `.disabled` changes while the alert is open (e.g. with a TextField) loses its action: the tap closes the alert and runs nothing. Keep buttons enabled and handle bad input in the action. An alert also ignores `isPresented = true` while it still animates out; reopen after ~0.4 s. An alert's TextField does show text the app rewrites while it's open (`onChange`), but XCUITest never sees its `accessibilityIdentifier`: query `app.alerts.textFields.firstMatch`.
- **Menus**: a second `Text` inside a `Label` title is dropped. Put the title, subtitle and image straight in the Button's label.
- **Held gestures**: `onEnded` never runs when the system cancels a touch (a call, Notification Center). Anything that repeats or holds an edit follows `@GestureState` and stops when the scene leaves `.active`; test the slide-off with `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`.
- **UI waits**: use `appears(within:)` and `eventually(within:)` (`UITests/Waiting.swift`), never `waitForExistence` or a predicate expectation: those look again only once a second, which was a third of the suite's time.
- **Edit holds in tests**: for `ConsoleMirror.editHold` after the app's own edit, pushes for that address are ignored. A test that simulates a later desk change waits that out first.
- **Mirrored parameters**: connect reads only `Catalog.overviewAddresses()`; a tab's values are read when it opens (`Catalog.tabAddresses`, `ConsoleMirror.read`). `CatalogTests.everyTabsParametersAreRead` checks that whatever a tab shows is in the overview or that tab's list: a value in neither is never read, and its row stays disabled. A parameter on a new tab, or shown outside `ChannelTab`, gets a line in its `shownAddresses` and in `Catalog.tabAddresses`. Core tests that use a tab's values call `openTab(_:of:in:)` first. A new mirrored parameter also gets a typed default in `DemoState` (the fallback is `.float(0.5)`, wrong for int parameters).
- **Merging**: `main` is protected (required `check`) and PRs are squash-merged: the PR title becomes `main`'s commit title. A branch need not be up to date with `main` to merge; the `check` run on `main` after each merge catches two PRs that break only together. Before rebasing a pushed branch, compare it with `origin/<branch>`: GitHub's "Update branch" adds commits there. After a base PR merges, rebase a branch stacked on it with `git rebase --onto origin/main <old base commit>`: the squash leaves the base's own commits off `main`. A conflict in `App/Localizable.xcstrings` resolves by taking `main`'s version and running `scripts/strings.sh`.
- **Releases**: PR titles set the version, so keep them conventional. On `main`, a `feat:` publishes the next minor version, only `fix:`/`perf:` the next patch, anything else nothing (`scripts/next-version.sh`); before 1.0 a breaking change bumps only the minor. 1.0.0 and release candidates (`1.0.0-rc.1`) are manual runs of the release workflow with the version typed in. Every 0.x and `-rc` is a pre-release. The release job builds only; lint and tests are the PR `check`'s job. Each release run builds main's newest commit that passed CI, not the one that triggered it, so a burst of merges can't strand one. A manual run refuses to start until CI has passed on main's latest commit. Each release also force-pushes the SideStore source (`scripts/publish-sidestore-source.sh`) to the `sidestore` branch, which users' SideStore reads: never delete that branch.
- **Clicking through by hand**: use the `iPhone SE (3rd generation) iOS 27` simulator. Xcode 27 ships no Simulator.app: its window opens with `open /Applications/Xcode.app/Contents/Applications/DeviceHub.app`. Build with `xcodebuild build … -destination id=<iOS 27 SE id> -derivedDataPath build/dd-run`, start `swift run --package-path Core fake-m32` in the background, then `xcrun simctl install <id> build/dd-run/Build/Products/Debug-iphonesimulator/Thumbmix.app` and `xcrun simctl launch --terminate-running-process <id> dev.thumbmix.app -connectOnLaunch YES -consolePort 10023` (leave out `-connectOnLaunch YES` to land on the Connect screen).

## Local-only context

`SPEC.md` and `notes/` (design spec, plan, protocol research with sources, Maillot's protocol PDF and the M32 user manual) live in the original checkout and are git-excluded on purpose. Read them when present; they never get committed. When the PDF is missing, its link is on Maillot's X32 page (https://sites.google.com/site/patrickmaillot/x32).

Mocks live in `notes/mocks/<date>-<topic>/`, one HTML fragment per question with the options side by side; the spec in `notes/` names the option the user picked. The visual companion writes them inside the session's worktree (`.superpowers/brainstorm/*/content/`), which goes when the worktree does: copy them to `notes/mocks/` once the user has picked. To show one again, wrap the fragment in a page (`<!doctype html>`, dark background) and open it.
