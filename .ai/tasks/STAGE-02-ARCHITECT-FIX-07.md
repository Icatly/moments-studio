# Stage 02 — Architect FIX 07: observed native picker test locator

Status: SPEC_READY. Authority: Architect Round14; Stage02 corrections only. Owner approval: PENDING; Stage03 forbidden.

## Goal / evidence

Read .ai/reviews/STAGE-02-ARCHITECT-ROUND-14.md and native failure-attachments/ABA75FF7-80B3-414D-B25C-8591AC245D1C.txt under .ai/build/downloads/run-37147120379/. Source96dece5 compiled; all80 unit and4 existingUI pass. The new fifthUI test fails before import at line111 because iOS18.5 picker uses a ScrollView, not collectionViews. Native dump shows ScrollView identifier 'content_scroll_view', containing Image identifier 'PXGGridLayout-Info' with Photo labels. Nine photos present; Add disabled because no photo was selected. Preview fix has NOT yet been exercised.

## Authorized implementation (minimal)

1. Modify only selectFirstPhotoCell in Stage02ImportUITests.swift and its directly relevant documentation: use the OBSERVED native picker scope app.scrollViews['content_scroll_view'] and its images matching identifier 'PXGGridLayout-Info'; select the first real photo. Swift actual quotes must be double quotes. Bounded wait for the picker scope/photo and enabled+hittable as appropriate, retain native debugDescription on failure. These are native accessibility queries, not runtime Apple private APIs.
2. Remove obsolete collectionViews assumptions in comments/report for this helper. No generic app.images fallback, screenshot coordinates, sleeps, skips, launch injection, fixture substitutions, test-only production buttons or app changes.
3. Preserve all85 method names and every end-to-end assertion: real picker+Add, committed thumbnail/count, preview info/image loading/error checks, Done, Cancel removal, Confirm removal, reimport same original source. Keep RootView's same root instances explicitly supplied to the sheet; change NO production Swift, serialized fields, storage, render logic, navigation contracts, dependencies, workflow or project settings.
4. Run actual Windows structure/syntax checks and diff whitespace; record executed vs not executed. Report in .ai/reports/STAGE-02-FIX-07-REPORT.md and update current handoff status/log. Do not write macOS build/tests passed; Architect will run them. Do not overwrite prior raw evidence or rewrite historical review decisions.

## Completion / stop

Stop at READY_FOR_ARCHITECT_REVIEW with exact changed files/checks and native-locator OS specificity disclosed. No cloud dispatch, push, Appetize upload/account change, quota consumption or Stage03. New scope requires Architect decision. DSH is Implementation Engineer only.
