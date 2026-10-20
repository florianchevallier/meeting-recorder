#!/usr/bin/env bash
# Every deterministic quality gate of the repo, in one place.
#   scripts/check.sh            lint + build (everything)
#   scripts/check.sh lint       static checks, no compilation (CI "lint" job)
#   scripts/check.sh build      build, tests, coverage floor, dead code, sanitizers (CI "test" job)
#   scripts/check.sh fast       pre-commit subset (format, SwiftLint, staged secrets)
# Tools: `brew bundle --file=Brewfile`.
set -euo pipefail
cd "$(dirname "$0")/.."
# The Command Line Tools can't build the app (SwiftUIMacros lives in Xcode only).
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

# Sources line coverage in %. Raise it when tests are added, never lower it.
COVERAGE_FLOOR=17

step() { printf '\n\033[1m▶ %s\033[0m\n' "$1"; }

format_and_swiftlint() {
    step "swift-format"
    swift format lint --strict --recursive --parallel Sources Tests Package.swift
    step "SwiftLint"
    swiftlint lint --strict --quiet --baseline .swiftlint-baseline.json
}

lint() {
    format_and_swiftlint
    step "ShellCheck"
    shellcheck -S warning ./*.sh scripts/*.sh .githooks/pre-commit
    step "actionlint"
    actionlint
    step "zizmor (workflow security)"
    zizmor --offline --min-severity low .github/workflows
    step "Ruff"
    ruff check .github/scripts
    step "plutil"
    plutil -lint Info.plist MeetingRecorder.entitlements Sources/Resources/*.lproj/Localizable.strings
    step "brew style (cask)"
    brew style Casks/meety.rb
    step "gitleaks (history)"
    gitleaks git --no-banner --redact --log-level warn .
}

coverage() {
    local json percent
    json=$(swift test --show-codecov-path)
    percent=$(jq '[.data[0].files[] | select(.filename | contains("/Sources/")) | .summary.lines]
        | (map(.covered) | add) * 100 / (map(.count) | add) | floor' "$json")
    echo "Sources line coverage: ${percent}% (floor ${COVERAGE_FLOOR}%)"
    if ((percent < COVERAGE_FLOOR)); then
        echo "Coverage dropped below the floor." >&2
        return 1
    fi
}

build() {
    step "Build (warnings as errors)"
    swift build --build-tests -Xswiftc -warnings-as-errors
    step "Tests + coverage"
    swift test --parallel --enable-code-coverage -Xswiftc -warnings-as-errors
    coverage
    step "Periphery (unused code)"
    periphery scan --quiet --strict --baseline .periphery-baseline.json
    step "Tests under Thread Sanitizer"
    swift test --sanitize=thread --scratch-path .build/tsan
    step "Tests under Address + Undefined Behavior Sanitizers"
    swift test --sanitize=address --sanitize=undefined --scratch-path .build/asan
}

fast() {
    format_and_swiftlint
    step "gitleaks (staged)"
    gitleaks git --pre-commit --staged --no-banner --redact --log-level warn .
}

if (($# == 0)); then set -- lint build; fi
for stage in "$@"; do
    case "$stage" in
        lint | build | fast) "$stage" ;;
        *) echo "Unknown stage: $stage (lint, build, fast)" >&2; exit 2 ;;
    esac
done
printf '\n\033[1;32m✔ All checks passed\033[0m\n'
