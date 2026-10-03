# Stage02 Architect Review Round09 — actual runtime failures

2026-10-04. Status: CHANGES_REQUIRED. Owner Stage02 PENDING; Stage03 not authorized.

## Verified evidence
Source: 0c905a3f038b770169a930e8c16d27572fb639ca.
Run: https://github.com/Icatly/moments-studio/actions/runs/37135113445
Raw evidence: .ai/build/downloads/run-37135113445/evidence/xcodebuild.log and Stage02.xcresult; source-commit matches source above.
78 unit methods executed, 3 failed (5 assertions); 4 UI methods executed, 1 failed (1 assertion). All targets compiled. No Stage02 runnable package was produced because the test gate failed.

## Findings and decisions
1. HIGH — PhotoLibraryTests testSymlinkAliasInsideTheLibraryCannotRedirectAnotherProjectsAssets (882,889): A/assets symlink -> B/assets accepted a new import and changed B's directory listing. Production ownership boundary fails. Existing whole non-existing-destination canonical comparison is insufficient in this observed environment; exact Foundation implementation mechanics are not established. Inspect every existing generated component itself before access, reject all generated symlinks including dangling/inside aliases; preserve canonical trusted root and missing new tail. Audit staging, read/write/create/rollback/cleanup under the same invariant. Keep rejection and B preservation tests.
2. MEDIUM — ProjectPackageTests testPathRulesAcceptOnlyGeneratedReferences (260): original.gif parsed successfully despite unsupported format scope. Whitelist approved jpg/jpeg/png/heic/heif original extensions, keep derivative rules and serialization contract.
3. TEST DEFECT — PhotoLibraryTests testImportKeepsTransparencyAsPNGAndUsesJPEGOtherwise (230,243): source and thumbnail contain zero semi-transparent pixels. Source-over alpha0.5 band was painted on opaque backing. Clear band before filling; keep source/preview/thumbnail pixel-alpha assertions. This does not establish a renderer alpha defect.
4. TEST WAIT DEFECT — Stage02ImportUITests testImportPickerCanBeDismissedBackToTheEditor (62): waitForExistence is used to assert disappearance and can return immediately during dismissal. Require actual bounded absence wait and editor hittable/enabled. Actual dismissal behavior must still be verified next run; no production workaround warranted yet.

## Other actual results / limitations
Synthetic HEIC import PASS (not skipped). Large-batch cancellation PASS. Three serial 4000x3000 JPEG imports: 0.430 seconds measured after fixtures were prepared. Before/after footprint: 38,443,776 -> 38,656,768 bytes; resident: 214,761,472 -> 214,958,080 bytes. These are two simulator memory snapshots, NOT peak memory, and flat synthetic JPEG performance does not establish real-device throughput. Three AppIntents metadata extraction warnings due to absent AppIntents dependency; no observed Swift actor diagnostic. Real device/iPad/VoiceOver/exact iOS17/Xcode15.4 remain unverified.

Execute only .ai/tasks/STAGE-02-ARCHITECT-FIX-05.md. Architect must review actual changes and rerun macOS tests before app packaging and user acceptance. Windows static checks alone cannot clear these findings.

Evidence ZIP 63,985,064 bytes; SHA256 f433a6a9c3fc96669f4b739312c2925334c39bba5faaf478e2774bfe2f76da91 verified locally and matches GitHub. Architect added a diagnostic-only workflow step: native xcresulttool summary/failure-attachment export after the gate, retaining raw results and visible export warnings. It does not change xcodebuild test status or skip assertions. Apple command availability: https://developer.apple.com/documentation/xcode-release-notes/xcode-16_3-release-notes ; exact installed help is captured on the next run.
