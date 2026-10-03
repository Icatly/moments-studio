# DSH Task — Stage02 Architect Fix04

Read Round07 review and actual downloaded run37133937308/evidence/xcodebuild.log. Compiler frontend crashes while typechecking ProjectPackageTests.testDecodingRejectsInvalidDimensionsOrientationAndContentType at165. This is not an ordinary diagnostic, and trigger is an inference until next actual run.

Only authorized correction: replace the heterogeneous inline for-loop tuple literal with an explicitly declared local cases: [(key: String, value: Any)], retaining all four values (pixelWidth0, pixelHeight-5, orientation9, contentType emptyString) and same per-case JSON mutation/decoder rejection assertions. Iterate that local array with unambiguous tuple fields. Audit any other heterogeneous tuple arrays in tests; add an explicit contextual type only if similarly untyped. No production changes, new tests, deletion/skip of existing tests, actor suppression/unsafe escape, SDK/compiler/language/deployment/workflow changes, or next Stage.

Run Windows structure/static syntax and diff whitespace once. Brief report .ai/reports/STAGE-02-FIX-04-REPORT.md with exact changed lines and actual previous frontend crash (tests not run), update current handoff truthfully, then stop READY_FOR_ARCHITECT_REVIEW for my cloud rerun. No account/cloud/push/upload actions.
