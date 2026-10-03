# STAGE-02-ARCHITECT-FIX-06 — modal dependency wiring

Role: Implementation Engineer. This authorizes only the corrections below within Stage02. Read project handoff, AGENTS.md, and .ai/reviews/STAGE-02-ARCHITECT-ROUND-12.md first. Stage01 APPROVED; Stage02 CHANGES_REQUESTED; Stage03 prohibited.

## Evidence and root cause

Source0121261 passed80 unit+4 UI on actual macOS run37138644682, but real Appetize iPhone14Pro/iOS17.2 import->tap thumbnail exits the app. Downloaded actual log at02:56:46: SwiftUI/Environment+Objects.swift:32 Fatal error: No Observable object of type PhotoImportModel found. RootView.swift supplies models before .sheet; PhotoPreviewSheet reads required models. Existing UI tests only open/cancel picker and never open an imported preview. Do not attribute the crash to asset decoding or change storage.

## Authorized implementation

1. In RootView's existing .sheet closure, attach .environment(navigation),.environment(projectStore),.environment(photoImport) directly to sheet(for:route), passing the SAME root-owned instances. Preserve existing navigation/restore lifecycle and screen hierarchy. No new state/store/coordinator, optional fallback, environmentObject migration, service/protocol/package, or public interface change. Do not alter serialization fields, model invariants, asset processing, workflow, SDK/deployment/actor settings or design tokens.
2. Add ONE meaningful Stage02 UI regression for create->real PhotosPicker->select seeded simulator image(s)->Add->gallery->tap imported thumbnail->Preview. Existing cloud workflow already seeds3 synthetic photos; use actual native photo-grid cells and bounded waits; ensure picker really opened and selection/import succeeded. Do not rely on arbitrary sleeps, test-only production buttons/launch data injection, mock photo IDs handed to providers, screenshot-only assertions, skips or removed tests. Assert preview visible, image/info ready (not unavailable), Done returns to editor, reopen preview and Remove shows truthful native confirmation, Cancel keeps the photo/count and returns usable controls. If safely feasible within this single scenario also confirm removal updates count and source can be selected again; avoid broad testing beyond this defect. Do not guess unsupported system identifiers; report locator assumptions and leave runtime verification to Architect. Run UI query diagnostics on macOS only if needed; no cloud access yourself.
3. Update .ai/reports/STAGE-02-FIX-06-REPORT.md with exact changed files, rationale, actual Windows checks, test method counts and remaining unverified gates. Update TASKS.md, acceptance current snapshot and root handoff truthfully without erasing historical run records or setting owner approval. Architect already documented upload/crash.

## Verification and constraints

Run approved Windows project/Swift syntax/contract checks and git diff --check. Preserve all80 unit+4 UI existing tests and field names; additional regression increases UI count. Windows has no Xcode: build/tests/new UI regression remain UNVERIFIED until Architect runs macOS. Do not present static conformance scripts as behavioral tests. Keep change narrow; report a blocker if native picker selection cannot be designed without changing production boundaries.

Do not push/upload code, change accounts, run cloud builds, consume Appetize quota or start Stage03. Stop at READY_FOR_ARCHITECT_REVIEW and report actual checks. Architect will handle remaining build/runtime/owner gates.

## Same-scope review clarification (03:03)

The picker Add button must wait until enabled AND hittable after selecting a cell, not merely exist; the selection state updates asynchronously. Scope photo-cell queries to the native grid; do not fall back to unscoped app.images (it may pick unrelated icons). A preview.image wrapper existing is not proof its derivative has finished loading: use a bounded disappearance wait for its progress indicator then assert no photo.unavailable and a visible image area/info. Keep production UI unchanged; no additional loading-state API. If a cell locator fails on macOS, preserve app.debugDescription as diagnostic evidence and fail; do not broaden blind fallbacks or skip.
