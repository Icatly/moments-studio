# DSH Task — Stage 02 Architect Fix 01

Authorized by Architect within owner-approved Stage02. Read current .ai/reviews/STAGE-02-ARCHITECT-ROUND-01.md and preserve all 13 in-flight corrections. Fix only the six concrete findings, then stop at READY_FOR_ARCHITECT_REVIEW. No Stage03, dependency, account, workflow changes, push or upload.

1. Return PhotoFileTransfer from the FileRepresentation importing closure, wrapping the result of try await stageCopy. Keep borrowed file copy before closure return.
2. Validate canonical root plus generated Temporary target before stage create/copy/delete; reject aliases both outside and inside the library. Check cancellation after copying and remove only own copied target before throwing. In library staging cleanup, match the incoming URL to the exact owned staged file, not just its basename. Keep unknown staging directories/files safe.
3. Return runtime cleanup warnings from discardStagedFile to the coordinator and append them. This internal cleanup-result change is approved; no persisted contracts change and no additional actor/service. A cleanup failure remains visible and retried on startup.
4. Validate schema and full existing package at import/remove entry, and shared package validity before manifest write. Reject bad values, preserve existing files and manifest. No silent schema downgrade.
5. Guard source pixel multiplication against overflow before computing product. Keep ordinary size-limit errors distinguishable.

Add only necessary behavior tests: file-transfer type is checked by actual Xcode; staging aliases/source unchanged, cancellation/cleanup, same-basename outside source does not delete an owned staged file, bad/future package rejection without writes. Preserve original Stage01 tests and field names. Check callers of the async staging helper and update tests with await. No production test buttons or generic test protocol.

Keep explicit MainActor isolation on new UI types that access the main-actor coordinator/store from helpers, consistent with the approved Stage01 actor boundary; do not depend on newer SDK-only View isolation inference.

Produce .ai/reports/STAGE-02-FIX-01-REPORT.md and update current acceptance/handoff truthfully. Windows structure/static syntax only; Xcode tests/build and performance stay unverified until Architect runs them. Do not mark WAITING_FOR_USER or APPROVED.

6. The synthetic alpha fixture currently fills every pixel with alpha1; add an actually transparent/semitransparent region and assert preserved pixel alpha in the PNG derivative (not only its extension). Add real coordinator mutation coverage for two removals/import-vs-removal so the single-operation guard cannot regress. If deterministic coordinator batch testing needs a seam, a narrow internal injected file-loader closure with the existing concrete library is approved; no service protocol, mock repository, production test button, or second scheduler. Keep critical fixture/context/PNG/JPEG failures as failures, not XCTSkip; any HEIC environment skip must be disclosed and does not prove HEIC support.
