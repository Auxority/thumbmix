# Contributing

Thanks for helping. Thumbmix is a one-person project, so a short note first saves us both time.

- **Questions and ideas:** start a [discussion](https://github.com/Auxority/thumbmix/discussions).
- **Bugs:** open an [issue](https://github.com/Auxority/thumbmix/issues/new/choose) with the bug form.
- **A change bigger than a small fix:** start a discussion before you write it, so we agree on the approach first.

## Pull requests

1. Build, lint and test as described in [Develop](README.md#develop):
   - `scripts/lint.sh` is clean.
   - `scripts/unused.sh` finds no unused code.
   - `swift test --package-path Core` passes.
   - `scripts/ui-test.sh` passes when the change shows in the app.
2. Add a test that fails without your change.
3. Title the pull request as a [conventional commit](https://www.conventionalcommits.org): `feat: …`, `fix: …`, `perf: …`, `docs: …`, `test: …`, `ci: …` or `chore: …`. Pull requests are squash-merged, so the title becomes the commit on `main`. A `feat`, `fix` or `perf` title publishes a release and becomes its release note.
