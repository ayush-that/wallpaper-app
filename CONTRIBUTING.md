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

## Pull requests

- Keep `./scripts/lint.sh` green.
- Keep the test suite passing.
- Keep commits focused; one logical change per pull request.
