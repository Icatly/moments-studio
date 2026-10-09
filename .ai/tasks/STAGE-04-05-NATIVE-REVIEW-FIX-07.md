# FIX07 — import remains visible; actual navigation identity

Owner authorized both stages. DSH implements; Architect specifies/reviews. No Stage06, persisted contract, dependency, workflow or old Stage02 test changes.

Actual repaired-source run [37966461191](https://github.com/Icatly/moments-studio/actions/runs/37966461191), source `5369354cb7a3efee264f8ab6c61e9bf50e42c2b4`: **186 executed/184 passed/2 UI failed/0 skipped**. All176 unit passed, all31 new Stage05 tests (including new UI) passed. Original private evidence `.ai/build/stage05-run-37966461191-20261010-014726/evidence/` and job-logs.zip. App and test targets compile; FIX06 solved the compiler collision.

## A. Product regression — import pushed out of viewport

`Stage02ImportUITests.swift:58` native Photos never appeared. Actual diagnostic shows no picker, editor scroll y436...874, `editor.importPhotos` frame y872.3...916.3 (center894.3 OUTSIDE window). The test taps the original entry, but only1.7px is visible. Added standalone Photo summary row before Layers pushed the essential import action down68px. This is a real layout regression, not a reason to lengthen the Photos wait or weaken/change old tests.

Architect approves minimal local product arrangement ONLY in `EditorPlaceholderView.swift`: put the existing Layouts and Photo summary buttons together in **one HStack** (existing spacing token, leading alignment via existing VStack). Preserve both button bodies, IDs, min44 targets, disabled conditions, hints, routing and the order/content of all other sections. This removes the added vertical row while keeping summary optional and discoverable. No conditional test UI, hiding functionality, new service, new navigation/contract or branding. Do not change Stage02 tests or any shared helper.

## B. Test's invented AX label precondition

`Stage04LayoutUITests.swift:69` fails because the precise navigation query `app.navigationBars.matching(identifier: "Layouts")` finds exactly1 but bar.label is **empty**, not `Layouts`. The original source's navigationTitle maps to native **identifier**, not bar.label. FIX05-added label equality was not one of frozen original155 behavior assertions, and is semantically wrong.

ONLY `Stage04LayoutUITests.swift`: remove that added bar.label==Layouts precondition; retain exact Layouts identifier query, uniqueness==1, finite/navigation viewport geometry, owning both Cancel/Apply, keyboard clipping, relative bounded slow drag, search query retention, preview/cancel/apply/repeat/restart and ALL original behavior assertions. Do not replace it with another unverified AX requirement or query whole-app nav count; do not blindly retry/skips.

## Deliver

Two Swift files ONLY; all other source/tests/workflows unchanged and all186 methods retained. Update DSH implementation report/root current snapshot with actual184/186 and exact changes, run available project/parse/manifest checks, record hashes and native pending. Stop READY_FOR_ARCHITECT_REVIEW; Architect independently checks then freezes source and executes one justified full186 run. Device packaging still waits for full native pass; no new IPA/owner approval exists.
