# FIX06 — XCTest superclass helper collision

Owner authorized Stage04 + Stage05. DSH implements; Architect independently reviews. No Stage06, contract, workflow, dependency, model or App changes.

Actual first Stage05 native run [37964463618](https://github.com/Icatly/moments-studio/actions/runs/37964463618), source `bc166d4517b9bced0f10e01b0240fd6ad4695543`, completed failure. Device App Release build passed, but XCTest target compilation failed before execution. Summary has 0 tests; it is NOT 0 failures passed.

Original private evidence: `.ai/build/stage05-run-37964463618-20261010-012020/evidence/xcodebuild-test.log`; retained archive SHA256 `e24a0657721b060f4c8b6943b6f641efe8d9fa2e882fd70c16f2dac8b22d0c20` (79146 bytes).

`MomentsStudio/MomentsStudioUITests/Stage04LayoutUITests.swift:23:18`: `private func isFinitePositive(_ rect: CGRect)` collides with inherited method from this repository's `extension XCTestCase` in `UITestSupport.swift:333` (NOT a new SDK API); compiler requires override and matching accessibility. This is a local geometry predicate, not intended to override XCTest.

Allowed implementation change ONLY `Stage04LayoutUITests.swift`: rename that local helper to a distinctive `layoutFrameIsFiniteAndPositive` and update all its calls. Keep body, all assertions, viewport/navigation/search/drag behavior, all 186 methods and all other files byte-identical. Do NOT add override, weaken tests, skip tests or change workflows.

Update DSH implementation report with actual failure and exactly this fix; explicitly distinguish first native build failure / 0 tests from the pending new run. Execute available project wiring and parse checks, report actual source hashes. Stop READY_FOR_ARCHITECT_REVIEW. Architect will freeze a narrowly scoped new commit and run complete 176 unit + 10 UI on macOS once; no blind rerun of the known failing commit.
