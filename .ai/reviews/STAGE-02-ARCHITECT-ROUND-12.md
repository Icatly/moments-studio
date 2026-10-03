# Stage02 Architect Review Round12 — preview presentation crash

2026-10-04 02:48–02:57 Beijing. Verdict: CHANGES_REQUIRED; stage CHANGES_REQUESTED, owner PENDING. Stage03 prohibited.

## Verified build and actual observations

Source 012126165c0a00203a71b491fb7f632f4875d84c; run37138644682:80 unit+4 UI PASS,0 failed/skip. Uploaded the verified simulator ZIP to existing authorized Appetize application at02:48 (SHA25697396cf2d0a4680c259eb377590a9ae06f4ef191f9c7d92a768b2a81a3b0ce7c). Upload success and Stage02 Home confirmed. iPhone14Pro,iOS17.2.

Real PhotosPicker showed private/select-only access. Ordered selection flowers(1),synthetic portrait(2),waterfall(3) produced exactly3 thumbnails in that order; count3/20 and Saved on device Yes. Multi-file Appetize media upload delivered only the first fixture; do not claim the other two PNGs were manually checked. Subsequent clean session imported2 preset photos; tapping thumbnail exited to iOS SpringBoard. A third diagnostic session imported1 preset flower; tapping it captured an actual fatal error. Preview,remove,append,restart,dark/large-text gates remain incomplete. A device/session reset near first preview is not evidence of application persistence failure.

## P1 — missing modal dependencies

Raw downloaded log: .ai/build/downloads/stage02-appetize-preview-crash/debug-log.txt (original Downloads/2026-10-04 02-57-05 debug log.txt).

At02:56:46.643083+0800:
SwiftUI/Environment+Objects.swift:32: Fatal error: No Observable object of type PhotoImportModel found. A View.environmentObject(_:) for PhotoImportModel may be missing as an ancestor of this view.

RootView.swift attaches environment(navigation/projectStore/photoImport) before the sheet modifier. The preview reads PhotoImportModel and ProjectStore; presentation content does not receive the required instance in the observed iOS17.2 path. This is a modal dependency wiring defect, not an image/asset decoder defect. The exact OS-internal propagation mechanism is not claimed. About does not read these models; the existing4 UI tests never import/open a preview, so84 PASS did not cover this path.

Approved narrow repair: explicitly inject the SAME root-owned navigation,projectStore,photoImport instances into sheet(for:route) inside the sheet closure. Do not create replacements, migrate Observation, alter navigation contracts, or change image pipeline. Add one real-picker/import/preview UI regression using seeded simulator photos; prove preview/image/info/Done/removal confirmation and project count with real UI, no synthetic buttons or injected production shortcuts. See FIX06 task.

## Quota and session handling

Actual free quota before runtime19/30(11 minutes); after first two sessions UI refreshed25/30(5 minutes). Diagnostic session ended by closing play tab after log download at02:57; final quota must be rechecked before next session. Do not run paid sessions. Owner login unchanged. Browser translations can alter coordinates; full foreground confirmation prevented unsafe system-setting click. No system/security setting changed.

## Next

DSH fixes only FIX06 then stops READY_FOR_ARCHITECT_REVIEW. Architect re-reviews, reruns actual macOS tests, uploads corrected package and completes runtime gates. Existing binary is blocked from acceptance; retain Stage01 owner approval and all prior evidence. No WAITING_FOR_USER or APPROVED.

2026-10-04 03:02追加：FIX06已于03:01实际发送到正确DSH项目会话，DSH读取任务/日志并开始执行。Appetize应用页确认诊断会话结束后免费额度27/30，剩3分钟；当前没有活跃模拟器会话。原始日志599字节，SHA25633faea5d582817d1bfd31505dd45f99297d9adc85450ed480c56ee913e688caf。
