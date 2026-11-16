---
title: "Growing a function or type already over SwiftLint limits fails the lint, even with the baseline"
author: Florian
date: 2026-11-16
branch: feature/whisper-wake
cost: { minutes: 8, tokens: 212652 }
id: l-5ea46f52
scope: repo
status: active
src: agent
touches:
  - Tests/TranscriptionCoordinatorTests.swift
  - Sources/Transcription/TranscriptionCoordinator.swift
  - CLAUDE.md
---

## Decided
The SwiftLint baseline matches each grandfathered violation by its reason text, which contains the
current count ("currently spans 287 lines", "complexity is 15"). Adding even one line to a function
or class already listed there produces a new violation, and the repo forbids regenerating the
baseline to hide it. Keep such files at the same size: put new logic in the other type, or in an
extension outside the class body (type_body_length ignores it, file_length still counts it).

## Tried and ruled out
- New `TranscriptionEvent` case: pushes the reducer's complexity from 15 to 16. The wake-up message
  goes through `.progressMessage` instead.
- `any Clock<Duration>` passed to a generic `C: Clock<Duration>` parameter: Swift refuses to open it.
  The probe loop takes `any Clock<Duration>` and counts probes instead of reading `clock.now`.

## Watch out
In the code: RecordingCoordinator.swift (class 287 lines, file ≤ 400, performStart 72 lines),
TranscriptionState.swift `reduce` (complexity 15), `.swiftlint-baseline.json`.
