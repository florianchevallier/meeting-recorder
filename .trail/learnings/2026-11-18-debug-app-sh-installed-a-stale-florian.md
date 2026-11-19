---
title: debug_app.sh installed a stale binary
author: Florian
date: 2026-11-18
branch: main
id: l-24f322c8
scope: repo
status: active
src: agent
touches:
  - debug_app.sh
  - Sources/MCP/MCPTranscriber.swift
---

## Decided
With the Xcode 26 toolchain, swift build writes to .build/out/Products/<Config>, not .build/<arch>-apple-macosx/<config>. debug_app.sh still copied from the old folder, so it installed a September binary without error (a 1.8 MB binary instead of 4.4 MB, and a suspiciously fast install). It now asks swift build --show-bin-path.

## Watch out
- The release-mode pkill -x "Meety" never matched: the process is named MeetingRecorder. It now uses pkill -f on the full app path, anchored with $ so the MeetingRecorder mcp servers keep running.
- The script ends with log stream, which never exits. If it looks like a slow install, it has already finished.
- transcribe_file without speakers sends the settings' nbSpeaker (2 by default) as max_speakers, so WhisperX merges voices when more people talk. Pass speakers when the count is known.
