# Contributing to Mural

Thanks for your interest in Mural. This guide covers the local development setup.

## Toolchain

```bash
brew install xcodegen swiftformat swiftlint xcbeautify pre-commit
```

The Xcode project is generated from `project.yml` with XcodeGen. `Mural.xcodeproj` is a build artifact and is gitignored; never edit it directly. Edit `project.yml` and regenerate:

```bash
xcodegen generate
```

## Formatting and linting

Mural uses two tools, each with its own config at the repo root:

- **SwiftFormat** (`.swiftformat`) owns whitespace, wrapping, and brace style.
- **SwiftLint** (`.swiftlint.yml`) enforces correctness and readability rules that the formatter does not cover.

Run both across the whole tree the same way CI does:

```bash
./scripts/lint.sh
```

Auto-fix formatting:

```bash
swiftformat App Sources Tests Tools
```

### Pre-commit hooks

A `.pre-commit-config.yaml` wires SwiftFormat and SwiftLint into a git pre-commit hook so problems are caught before they reach CI. Install it once:

```bash
pre-commit install
```

Now SwiftFormat and SwiftLint run on the Swift files you stage for each commit. To run the hooks against every file on demand:

```bash
pre-commit run --all-files
```

## Build and test

```bash
xcodebuild -scheme Mural -configuration Debug -destination 'platform=macOS' build | xcbeautify
xcodebuild test -scheme Mural -destination 'platform=macOS' | xcbeautify
```

The build enforces strict concurrency and treats warnings as errors, so new code must be concurrency-clean and warning-free.

## Code signing for local development

By default the Debug build is ad-hoc signed. macOS keys privacy (TCC) grants such as Screen Recording to the code-signing identity, and an ad-hoc signature has no stable identity, so the grant is tied to the binary hash and is invalidated on every rebuild. The result is that a permission you granted keeps reappearing as a prompt after each build.

To make grants persist across rebuilds, sign the Debug build with a stable identity. Create a gitignored `Config/Local.xcconfig` (the app target's Debug config includes it optionally, so it has no effect when absent):

```
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = Developer ID Application: Your Name (TEAMID)
DEVELOPMENT_TEAM = TEAMID
PROVISIONING_PROFILE_SPECIFIER =
```

Use any signing identity you have in your keychain (`security find-identity -v -p codesigning`). Then run `xcodegen generate`, build once, and grant the permission a final time. It will stick from then on.

## Pull requests

- Keep `./scripts/lint.sh` green.
- Keep the test suite passing.
- Keep commits focused; one logical change per pull request.
