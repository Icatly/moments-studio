# DSH Task — Stage 02 Implementation 01

Owner authorization, 2026-10-03: “确认验收 继续下一阶段任务”. Stage01 is APPROVED. You may implement Stage02 only; Stage03 is not authorized.

Read `AGENTS.md`, `项目要求与上下文交接.md`, and `docs/architecture/STAGE-02-PHOTO-ASSET-PIPELINE.md` before coding. The Stage02 architecture document is the exact approved boundary and contract. Older Stage01 stop instructions are historical and do not prohibit this newly authorized task.

## Goal

Implement native multi-photo import, app-owned original copies, ImageIO thumbnails/previews, project-owned photo records, local restoration of imported projects, and a minimal native UI for import/inspect/remove. Preserve the Stage01 framework.

## Required work, in order

1. Add the approved Foundation models `ImportedPhoto` and `ProjectPackage` with explicit coding keys and schemaVersion1. Do not change existing Project/CanvasDocument/Asset/Layer fields or encodings; keep all existing fixtures and tests.
2. Implement one non-MainActor `PhotoLibrary` actor and its concrete result values. Use an injected rootURL for tests; Application Support in the App. Validate generated relative paths, ownership, schema, limits, and supported image types. Atomic per-photo manifest commit; rollback before commit; removal commit before cleanup; report cleanup warnings. Preserve corrupt/unknown packages.
3. Implement file-based Transferable ingestion. Own the temporary file before the importing closure returns. Keep the received source bytes unchanged. Never retain a system temporary URL as the original. No all-image Data/UIImage arrays and no full-resolution UI decoding.
4. Generate oriented, bounded thumbnail320/preview2048 derivatives, no upsampling. Handle EXIF1...8, mirrored orientations, transparent PNG, JPEG/HEIC, sRGB SDR. Do not copy full EXIF/GPS into derivatives. Cap20 photos/project,100MiB/source,80MP/source; sequential processing.
5. Extend ProjectStore with only the approved photo snapshot/restore seams; keep its constructor filesystem-free and old create/rename/open signatures. Add the MainActor PhotoImportModel coordinator with async restore, single batch/mutation, item progress/errors/cancellation and captured project/batch identity. Only apply disk-committed values.
6. Wire RootView async startup restoration and the existing Editor placeholder import/gallery. Add native PhotosPicker ordered multi-selection/current encoding. Add the approved photoPreview sheet route, read-only preview and explicit Remove confirmation. Retain existing navigation/UI identifiers, dark/light button fix and neutral styling. Explain temporary empty projects vs persisted imported projects truthfully.
7. Add meaningful automated tests specified in the architecture. Preserve all Stage01 tests. Add/generate synthetic image fixtures in test tooling/targets, never private photos or runtime demo data. Add a minimal UI smoke path; describe unexecuted real picker checks honestly.
8. Update the generated Xcode project using existing tools, run Windows structure/static syntax checks, and review actual diffs. No new dependency, package, deployment-target change or warning suppression. Document Apple frameworks used.
9. Produce `.ai/reports/STAGE-02-REPORT.md`, `.ai/reviews/STAGE-02-REVIEW-PACKET.md`, update `.ai/acceptance/STAGE-02.md` with evidence and limitations, and update the handoff/current progress docs. Record IMPLEMENTING on actual start, then stop at READY_FOR_ARCHITECT_REVIEW. Do not mark WAITING_FOR_USER or APPROVED yourself.

## Exclusions and permissions

No AI/collage/layout/canvas editing/crop/filter/sticker/animation/export/cloud backend/auth/subscription/final brand design. No Project/Layer asset links, broad rewrites, generic repository protocols, job queues or speculative caches. Use only the approved native frameworks. Do not alter owner approval records, loosen AGENTS.md, change Architect tasks/decisions, cloud workflow, accounts or billing. Do not push/upload/run cloud services; Architect handles runnable-build verification.

Within the approved module boundaries, choose the smallest implementation. If this design cannot be implemented as specified, explain the exact blocker and propose a narrow change for Architect review before changing contracts. Do not silently substitute data loading, in-memory-only storage or system-temp references.

## Report truthfully

List actual files/decisions, tests added and executed, failed/unexecuted checks, memory/ordering/cancellation and disk-commit behavior, known limits and exact manual acceptance steps. Windows success is not Xcode success. Stage01's old cloud result is not Stage02 build evidence.

When finished, STOP at READY_FOR_ARCHITECT_REVIEW and report; do not start Stage03.
