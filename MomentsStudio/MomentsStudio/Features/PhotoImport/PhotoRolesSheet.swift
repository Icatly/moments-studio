import SwiftUI

/// Optional per-photo roles: what the user wants each imported photo to be.
///
/// Opening it runs a bounded, one-at-a-time local pass over the project's photos
/// (at most the project's photo limit), always in import order: Stage 05 pixel
/// statistics plus the Stage 06 Vision role evidence on the generated 320px
/// thumbnail. It writes **nothing** until the user saves; closing cancels the run,
/// "Analyze again" recomputes the evidence, "Reload" re-reads the saved choices,
/// and a stored observation only ever belongs to the photo snapshot it was observed
/// from.
///
/// The suggestions are deterministic project policy over local evidence. They are
/// not identity recognition, not an aesthetic score and not a saved automatic
/// decision: nothing is saved unless this sheet's Save choices succeeds.
///
/// Draft semantics (the correction this type is built around):
/// * the draft keeps **only** what the user actually decided. A photo the user never
///   touched is `.absent`, so a saved choice is never frozen into the draft and a
///   saved `manual` can always go back to Automatic;
/// * a saved role is used as the starting point only once, when the sheet loads or
///   when the user taps Reload. After that the draft (`PhotoRoleDraft`) plus the
///   current run decide everything;
/// * `expectedSnapshot` is captured at load/Reload and is the **only** thing Save
///   submits, so a stale draft cannot be written after the project changed.
@MainActor
struct PhotoRolesSheet: View {
    let projectID: UUID

    @Environment(ProjectStore.self) private var store
    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(AppNavigationModel.self) private var navigation

    /// Observations, failures, project identity and request token — the exact guard
    /// the UI writes and reads through (`PhotoRolesRun`).
    @State private var run: PhotoRolesRun
    /// This sheet's draft: the real three-state decision per photo
    /// (`PhotoRoleDraft`). Absent means "not changed here"; `.automatic` is the
    /// explicit Automatic answer that really clears a saved choice; `.role` is a
    /// manual choice.
    @State private var draft: [UUID: PhotoRoleDraft] = [:]
    /// The photo snapshot the choices on screen were made against. Captured on load
    /// and on Reload, never at the moment of saving.
    @State private var expectedSnapshot: [UUID: String] = [:]
    /// The saved role choices as they were when the snapshot was captured, so the
    /// draft can tell an untouched photo from an explicit Automatic and so a newly
    /// promoted primary can demote the previously saved manual primary.
    @State private var capturedRoles: [UUID: PhotoRoleChoice?] = [:]
    @State private var isRunning = false
    @State private var isSaving = false
    @State private var reloadID = 0
    @State private var message: String?
    /// A rejected/impossible save is a rejection, not a retryable IO failure.
    @State private var canRetrySave = false

    private var photos: [ImportedPhoto] { store.photos(for: projectID) }

    /// The project the sheet is presenting right now (`nil` once it is dismissed).
    private var presentedProjectID: UUID? {
        guard case .photoRoles(let id)? = navigation.sheet else { return nil }
        return id
    }

    private var isSheetCurrent: Bool {
        presentedProjectID == projectID && store.openProject(id: projectID) != nil
    }

    init(projectID: UUID, store: ProjectStore, photoImport: PhotoImportModel) {
        self.projectID = projectID
        _run = State(initialValue: PhotoRolesRun(projectID: projectID))
        // The captured state is frozen here, once, and only Reload replaces it — a
        // save may therefore never quietly adopt a store change that happened after
        // the sheet opened.
        let photos = store.photos(for: projectID)
        _capturedRoles = State(initialValue: Dictionary(
            uniqueKeysWithValues: photos.map { ($0.id, $0.roleChoice) }
        ))
        _expectedSnapshot = State(initialValue: photoImport.roleSnapshot(for: projectID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    if store.openProject(id: projectID) == nil {
                        Text("This project is no longer available.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)
                            .accessibilityIdentifier("roles.missingProject")
                    } else if photos.isEmpty {
                        Text("Import photos to suggest a role for each of them.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)
                            .accessibilityIdentifier("roles.empty")
                    } else {
                        Text("Local suggestions on your thumbnails. Nothing is saved until you tap Save choices.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)

                        Text(statusText)
                            .font(Typography.caption)
                            .foregroundStyle(Color.secondary)
                            .accessibilityIdentifier("roles.status")

                        if isRunning {
                            ProgressView("Checking your photos…")
                                .accessibilityIdentifier("roles.running")
                        }

                        Button("Use suggested roles") {
                            // The button's meaning is exactly what it says: every photo
                            // is put into this pass's automatic draft, so a stored
                            // manual choice — touched or not — is visibly replaced by
                            // the suggestion and can really be reset. It stays only a
                            // draft: Cancel writes nothing and Save persists it.
                            draft = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, .automatic) })
                            message = nil
                            canRetrySave = false
                        }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .disabled(isRunning || isSaving || !canResetToSuggested)
                        .accessibilityIdentifier("roles.useSuggested")

                        if let message {
                            Text(message)
                                .font(Typography.caption)
                                .foregroundStyle(Color.secondary)
                                .accessibilityIdentifier("roles.message")
                            if canRetrySave {
                                Button("Retry saving") { save() }
                                    .frame(minHeight: Layout.minimumTapTarget)
                                    .disabled(isSaving)
                                    .accessibilityIdentifier("roles.retry")
                            }
                        } else if isSaving {
                            ProgressView("Saving choices…")
                                .accessibilityIdentifier("roles.saving")
                        }

                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            row(photo, index: index, suggestion: suggestions[photo.id] ?? .none)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.medium)
            }
            .accessibilityIdentifier("roles.scroll")
            .navigationTitle("Photo roles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissIfCurrent() }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .disabled(isSaving)
                        .accessibilityIdentifier("roles.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Analyze again") {
                        // Recomputation keeps the user's own draft and the snapshot
                        // the draft was made against; it only invalidates the current
                        // evidence, so no stale observation can be written back.
                        run.invalidate()
                        reloadID += 1
                        message = nil
                        canRetrySave = false
                    }
                    .frame(minHeight: Layout.minimumTapTarget)
                    .disabled(isSaving)
                    .accessibilityIdentifier("roles.analyzeAgain")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reload") { reload() }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .disabled(isSaving)
                        .accessibilityIdentifier("roles.reload")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save choices") { save() }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .disabled(isSaving || isRunning || photos.isEmpty || expectedSnapshot.isEmpty
                                  || !hasDraftEdits)
                        .accessibilityIdentifier("roles.save")
                }
            }
        }
        // A write in flight must not be dismissed by a swipe: the user either sees it
        // finish or waits, exactly like the layout sheet's saving state.
        .interactiveDismissDisabled(isSaving)
        // The key carries the project, the ordered photo identities and their stored
        // metadata plus the manual reload counter: any change restarts the pass, and
        // closing the sheet cancels the task.
        .task(id: taskKey) {
            await startRun()
        }
        .onDisappear {
            run.invalidate()
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ photo: ImportedPhoto, index: Int, suggestion: PhotoRolePolicy.Suggestion) -> some View {
        let display = photo.displayPixelSize
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .top, spacing: Spacing.medium) {
                DerivedImageView(
                    reference: photo.thumbnailReference,
                    contentMode: .fill,
                    load: { reference in await photoImport.loadImage(reference: reference) },
                    placeholder: { Color.secondary.opacity(0.15) }
                )
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    Text("Photo \(index + 1)")
                        .font(Typography.body)
                    Text("Display \(display.width) × \(display.height) px")
                        .font(Typography.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("roles.size.\(photo.id.uuidString)")

                    Picker("Role", selection: pickerBinding(for: photo)) {
                        Text("Automatic").tag(PhotoRole?.none)
                        ForEach(PhotoRole.allCases, id: \.self) { role in
                            Text(role.title).tag(PhotoRole?.some(role))
                        }
                    }
                    .accessibilityIdentifier("roles.picker.\(photo.id.uuidString)")

                    evidence(photo, suggestion: suggestion)
                    sourceLine(photo)
                }

                Spacer(minLength: 0)
            }
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roles.row.\(photo.id.uuidString)")
    }

    @ViewBuilder
    private func evidence(_ photo: ImportedPhoto, suggestion: PhotoRolePolicy.Suggestion) -> some View {
        if let observation = run.observation(for: photo, currentProjectID: presentedProjectID) {
            if observation.skippedPixelMeasurement {
                Text("Nothing visible to measure here, so no role was suggested from it.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("roles.transparent.\(photo.id.uuidString)")
            } else {
                if observation.looksLikeNaturalScene {
                    Text("Looks like a natural scene.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("roles.scene.\(photo.id.uuidString)")
                }
                if observation.hasDetectedFace {
                    // Deliberately about the photo, not about a person: no identity,
                    // no gender and no beauty judgement.
                    Text("Face detected; original photo kept.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("roles.face.\(photo.id.uuidString)")
                }
                if observation.analysis?.confidence == .limited {
                    Text("Small sample here — treat this as a rough guess.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("roles.lowConfidence.\(photo.id.uuidString)")
                }
                if !observation.classificationRan {
                    Text("Image recognition did not finish for this photo.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("roles.noSemantics.\(photo.id.uuidString)")
                }
            }
            suggestedLine(photo, suggestion: suggestion)
        } else if let failure = run.failure(for: photo, currentProjectID: presentedProjectID) {
            Text(displayedRole(photo) == nil
                 ? Self.message(for: failure)
                 : "Kept your choice; \(Self.message(for: failure).lowercased())")                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("roles.failure.\(photo.id.uuidString)")
        } else if PhotoRolesRun.pixelArea(of: photo) == nil {
            Text("This photo's saved size is unusable, so no role can be suggested.")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("roles.unusableSize.\(photo.id.uuidString)")
        } else {
            Text(isRunning ? "Checking…" : "Not checked yet.")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("roles.pending.\(photo.id.uuidString)")
        }
    }

    /// What the row's advice line should say, derived as a pure value so the view and
    /// the tests share one rule.
    enum Advice: Equatable {
        /// This sheet's own manual pick: the source line already explains it.
        case none
        /// A genuinely automatic role from this pass.
        case suggestion(PhotoRole)
        /// A stored manual choice that is kept.
        case keptManualChoice(PhotoRole)
        /// The pass produced no evidence; a stored manual choice still survives.
        case noEvidence(keepingManualChoice: PhotoRole?)
    }

    /// The pure advice rule. A stored manual choice is never described as a device
    /// suggestion, and a failed pass says so.
    nonisolated static func advice(
        for photo: ImportedPhoto,
        draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        suggestion: PhotoRolePolicy.Suggestion
    ) -> Advice {
        let stored = capturedRoles[photo.id] ?? nil
        switch PhotoRoleDraft.value(in: draft, for: photo.id) {
        case .role:
            return .none
        case .automatic:
            return suggestion.role.map { Advice.suggestion($0) }
                ?? .noEvidence(keepingManualChoice: nil)
        case .absent:
            if case .failed = suggestion {
                return .noEvidence(keepingManualChoice: stored?.source == .manual ? stored?.role : nil)
            }
            if let stored, stored.source == .manual {
                return .keptManualChoice(stored.role)
            }
            return suggestion.role.map { Advice.suggestion($0) } ?? .none
        }
    }

    /// The advice line under the picker: the text for the pure `advice` value.
    @ViewBuilder
    private func suggestedLine(_ photo: ImportedPhoto, suggestion: PhotoRolePolicy.Suggestion) -> some View {
        switch Self.advice(
            for: photo, draft: draft, capturedRoles: capturedRoles, suggestion: suggestion
        ) {
        case .none:
            EmptyView()
        case .suggestion(let role):
            Text("Suggested: \(role.title)")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("roles.suggestion.\(photo.id.uuidString)")
        case .keptManualChoice(let role):
            Text("Kept as your earlier choice: \(role.title).")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("roles.suggestion.\(photo.id.uuidString)")
        case .noEvidence(let keeping):
            Text(keeping.map { "Nothing could be read this time; your earlier choice \($0.title) is kept." }
                 ?? "Nothing could be read from this photo, so it keeps no role.")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier(keeping == nil
                                          ? "roles.noSuggestion.\(photo.id.uuidString)"
                                          : "roles.suggestion.\(photo.id.uuidString)")
        }
    }

    /// States the **source** of the role this row currently shows, driven by the real
    /// draft state first — not by the effective manual role, which already folds the
    /// stored manual choice in and would make the "saved earlier" case unreachable.
    ///
    /// * `.role` → this sheet's own manual pick (will be saved as manual);
    /// * `.automatic` → the user asked for Automatic: the fresh suggestion when there
    ///   is one, otherwise the stored choice is being cleared;
    /// * `.absent` → the stored source is described honestly, and a device suggestion
    ///   is stated as automatic rather than as a user choice.
    @ViewBuilder
    private func sourceLine(_ photo: ImportedPhoto) -> some View {
        let stored = capturedRoles[photo.id] ?? nil
        let suggestion = suggestions[photo.id].role
        switch PhotoRoleDraft.value(in: draft, for: photo.id) {
        case .role(let role):
            Text("Your choice: \(role.title). Saved as manual when you tap Save choices.")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("roles.source.\(photo.id.uuidString)")
        case .automatic:
            if let suggestion {
                Text("Automatic: this device suggests \(suggestion.title). Saved as automatic when you tap Save choices.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("roles.source.\(photo.id.uuidString)")
            } else {
                Text("Automatic: no suggestion for this photo, so saving clears its saved role.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("roles.source.\(photo.id.uuidString)")
            }
        case .absent:
            if let stored, stored.source == .manual {
                Text("Saved earlier as your choice: \(stored.role.title).")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("roles.source.\(photo.id.uuidString)")
            } else if let stored, stored.source == .automatic {
                Text("Saved earlier as automatic: \(stored.role.title).")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("roles.source.\(photo.id.uuidString)")
            } else if let suggestion {
                Text("Suggested by this device: \(suggestion.title). Saved as automatic when you tap Save choices.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("roles.source.\(photo.id.uuidString)")
            }
        }
    }

    /// The picker shows the real draft state, and only a **manual** choice is ever shown
    /// as a specific role:
    /// * `.role` → the user's new manual pick;
    /// * `.automatic` → Automatic;
    /// * `.absent` with a captured **manual** choice → that saved role (it is the
    ///   user's own decision);
    /// * `.absent` with a captured **automatic** choice, or no saved choice at all →
    ///   Automatic.
    ///
    /// This is the one pure rule the view and the tests share
    /// (`Self.pickerSelection`), so a saved automatic role can never be shown as if the
    /// user had picked it. The setter is the only writer, and choosing Automatic
    /// writes `.automatic`, so a saved choice can really be cleared.
    private func pickerBinding(for photo: ImportedPhoto) -> Binding<PhotoRole?> {
        Binding(
            get: {
                Self.pickerSelection(
                    draft: draft, capturedRoles: capturedRoles, photo: photo
                )
            },
            set: { newValue in
                var updated = draft
                switch newValue {
                case .none:
                    // Explicit Automatic: a real draft value, so it survives the
                    // getter, the candidates and Save.
                    updated[photo.id] = .automatic
                case .some(.primary):
                    // A saved manual primary that was never touched in this sheet is
                    // demoted here too, so Save can never produce two primaries.
                    updated = PhotoRoleDraft.demotingOtherPrimaries(
                        in: updated, capturedRoles: capturedRoles, photos: photos, promoting: photo.id
                    )
                    updated[photo.id] = .role(.primary)
                case .some(let role):
                    updated[photo.id] = .role(role)
                }
                draft = updated
                message = nil
                canRetrySave = false
            }
        )
    }

    // MARK: - Draft

    /// The one pure picker rule: a specific role only for a **manual** decision
    /// (this sheet's draft or a captured manual choice); every automatic case is
    /// `nil`, i.e. Automatic. `nonisolated` so the value-model tests call exactly the
    /// code the view calls.
    nonisolated static func pickerSelection(
        draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        photo: ImportedPhoto
    ) -> PhotoRole? {
        switch PhotoRoleDraft.value(in: draft, for: photo.id) {
        case .role(let role):
            return role
        case .automatic:
            return nil
        case .absent:
            guard let captured = capturedRoles[photo.id] ?? nil, captured.source == .manual else {
                return nil
            }
            return captured.role
        }
    }

    /// The role one row's picker shows.
    private func displayedRole(_ photo: ImportedPhoto) -> PhotoRole? {
        Self.pickerSelection(draft: draft, capturedRoles: capturedRoles, photo: photo)
    }

    /// True when this save would actually change something.
    ///
    /// It compares the **exact choice that would be stored (role *and* source)** with
    /// what is currently captured, using the same derivation Save uses. Comparing only
    /// the role would hide a real change — an `automatic` supporting photo the user
    /// explicitly re-picks as a manual supporting photo, or a fresh automatic role
    /// from Analyze again — and could also miss a clear. Nothing to store and nothing
    /// to clear means nothing to save.
    nonisolated static func hasChanges(
        photos: [ImportedPhoto],
        draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        suggestions: [UUID: PhotoRolePolicy.Suggestion]
    ) -> Bool {
        let stored = choices(
            photos: photos, draft: draft, capturedRoles: capturedRoles, suggestions: suggestions
        )
        for photo in photos {
            // `stored[key]` is `nil` both for "cleared" and for "absent", and both
            // mean no saved choice, so comparing the unwrapped values is exact.
            let before = capturedRoles[photo.id] ?? nil
            if before != stored[photo.id] {
                return true
            }
        }
        return false
    }

    private var hasDraftEdits: Bool {
        Self.hasChanges(photos: photos, draft: draft, capturedRoles: capturedRoles, suggestions: suggestions)
    }

    /// True when there is anything the "Use suggested roles" reset could change: a
    /// non-empty draft, or any saved choice that the automatic draft would replace or
    /// clear. It deliberately does **not** depend on the draft already differing, so a
    /// stored manual role that was never touched in this sheet can still be reset.
    private var canResetToSuggested: Bool {
        if !draft.isEmpty { return true }
        return photos.contains { photo in
            if capturedRoles[photo.id] ?? nil != nil { return true }
            return suggestions[photo.id].role != nil
        }
    }

    /// The effective manual role for one photo, resolved by the shared model so the
    /// UI and the tests use the same rule.
    static func effectiveManualRole(
        draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        photo: ImportedPhoto
    ) -> PhotoRole? {
        PhotoRoleDraft.effectiveManualRole(draft: draft, capturedRoles: capturedRoles, assetID: photo.id)
    }

    // MARK: - Run

    private var taskKey: String {
        let signature = photos.map(PhotoRolesRun.signature(of:)).joined(separator: "|")
        return "\(projectID.uuidString)|\(reloadID)|\(signature)"
    }

    /// The automatic suggestion for every photo, from the observations this run
    /// actually accepted. Photos whose stored size cannot produce a candidate are
    /// simply absent (and reported in their row).
    private var suggestions: [UUID: PhotoRolePolicy.Suggestion] {
        PhotoRolePolicy.suggest(candidates).suggestions
    }

    /// The policy inputs for one row, with the draft applied through the shared rule.
    private var candidates: [PhotoRolePolicy.Candidate] {
        photos.enumerated().compactMap { index, photo in
            run.candidate(
                for: photo,
                importIndex: index,
                manualRole: Self.effectiveManualRole(draft: draft, capturedRoles: capturedRoles, photo: photo),
                sceneScore: run.observation(for: photo, currentProjectID: presentedProjectID)?.sceneScore ?? 0
            )
        }
    }

    private var statusText: String {
        let checked = photos.filter { run.observation(for: $0, currentProjectID: presentedProjectID) != nil }.count
        let failed = photos.filter { run.failure(for: $0, currentProjectID: presentedProjectID) != nil }.count
        if failed > 0 {
            return "Checked \(checked) of \(photos.count) photos — \(failed) could not be read."
        }
        return "Checked \(checked) of \(photos.count) photos"
    }

    /// The live copy of one photo, so a write-back compares the snapshot the
    /// observation was requested with against the snapshot that is current now.
    private func currentPhoto(_ assetID: UUID) -> ImportedPhoto? {
        photos.first { $0.id == assetID }
    }

    private func startRun() async {
        let key = taskKey
        guard !Task.isCancelled, isSheetCurrent, run.projectID == projectID else { return }
        if expectedSnapshot.isEmpty {
            // First appearance: freeze exactly what is on disk now. A later store
            // change is a stale draft, not something a Save may quietly adopt.
            captureSnapshot()
        }
        guard let token = run.beginRequest(taskKey: key, currentTaskKey: key,
                                           isSheetCurrent: isSheetCurrent) else { return }
        await observe(photos: photos, token: token, taskKey: key)
    }

    private func observe(photos: [ImportedPhoto], token: UUID, taskKey key: String) async {
        guard !photos.isEmpty else {
            isRunning = false
            return
        }
        isRunning = true
        defer {
            if run.token == token { isRunning = false }
        }

        for photo in photos {
            guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
            do {
                let observation = try await photoImport.observeRole(projectID: projectID, assetID: photo.id)
                guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
                guard run.accept(observation, observedFor: photo, current: currentPhoto(photo.id),
                                 token: token, currentProjectID: presentedProjectID,
                                 isProjectAvailable: store.openProject(id: projectID) != nil) else { return }
            } catch is CancellationError {
                return
            } catch let failure as PhotoRoleObservationFailure {
                guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
                guard run.reject(failure, observedFor: photo, current: currentPhoto(photo.id),
                                 token: token, currentProjectID: presentedProjectID,
                                 isProjectAvailable: store.openProject(id: projectID) != nil) else { return }
            } catch {
                guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
                guard run.reject(.unreadable, observedFor: photo, current: currentPhoto(photo.id),
                                 token: token, currentProjectID: presentedProjectID,
                                 isProjectAvailable: store.openProject(id: projectID) != nil) else { return }
            }
        }
    }

    // MARK: - Snapshot and save

    /// Freezes the current committed photos (metadata + saved choice) and the roles
    /// that go with them. Only Reload and the first appearance call this.
    private func captureSnapshot() {
        expectedSnapshot = photoImport.roleSnapshot(for: projectID)
        capturedRoles = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.roleChoice) })
    }

    /// Reload re-reads the saved choices and starts from the current project: it is
    /// the answer to a stale-draft rejection, so it also drops the local draft.
    private func reload() {
        draft = [:]
        // Re-freeze the committed state, including the saved choices, so the new
        // expected snapshot and the captured roles describe the same moment.
        capturedRoles = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.roleChoice) })
        expectedSnapshot = photoImport.roleSnapshot(for: projectID)
        message = nil
        canRetrySave = false
        run.invalidate()
        reloadID += 1
    }

    private func save() {
        guard !isSaving else { return }
        guard !expectedSnapshot.isEmpty else {
            message = "Reload Photo roles and try again."
            canRetrySave = false
            return
        }
        let choices = Self.choices(
            photos: photos,
            draft: draft,
            capturedRoles: capturedRoles,
            suggestions: suggestions
        )
        isSaving = true
        message = nil
        canRetrySave = false
        Task { @MainActor in
            let outcome = await photoImport.saveRoleChoices(
                projectID: projectID,
                choices: choices,
                expecting: expectedSnapshot
            )
            isSaving = false
            switch outcome {
            case .saved:
                draft = [:]
                // Close only this sheet: a save that finished later must not dismiss
                // whatever the user has since opened.
                if navigation.sheet == .photoRoles(projectID: projectID) {
                    navigation.dismissSheet()
                }
            case .rejected(let text):
                message = text
                canRetrySave = false
            case .saveFailed(let text):
                message = text
                canRetrySave = true
            case .busy:
                message = "Another photo operation is still running. Try again in a moment."
                canRetrySave = true
            }
        }
    }

    /// The choices one Save materialises, as a **total** map over the photos the
    /// sheet is showing, resolved through the shared draft model
    /// (`PhotoRolePolicy.choices`). This is a pure, non-isolated function: the UI and
    /// the tests call exactly the same code.
    nonisolated static func choices(
        photos: [ImportedPhoto],
        draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        suggestions: [UUID: PhotoRolePolicy.Suggestion]
    ) -> [UUID: PhotoRoleChoice] {
        let candidates = photos.enumerated().map { index, photo in
            PhotoRolePolicy.Candidate(
                assetID: photo.id,
                importIndex: index,
                manualRole: PhotoRoleDraft.effectiveManualRole(
                    draft: draft, capturedRoles: capturedRoles, assetID: photo.id
                ),
                sceneScore: 0,
                analysisSucceeded: false,
                adequateSample: false,
                pixelArea: PhotoRolesRun.pixelArea(of: photo) ?? 0
            )
        }
        return PhotoRolePolicy.choices(
            candidates: candidates,
            draft: draft,
            capturedRoles: capturedRoles,
            outcome: PhotoRolePolicy.Outcome(suggestions: suggestions)
        )
    }

    private func dismissIfCurrent() {
        if navigation.sheet == .photoRoles(projectID: projectID) {
            // Cancel invalidates the run immediately, so a late observation, retry or
            // save callback can never write into whatever comes next.
            run.invalidate()
            navigation.dismissSheet()
        }
    }

    private static func message(for failure: PhotoRoleObservationFailure) -> String {
        switch failure {
        case .missing: return "This photo is no longer part of the project."
        case .unreadable: return "The saved thumbnail could not be read."
        case .invalidMetadata: return "This photo's saved size or orientation is unusable."
        case .visionUnavailable: return "Image recognition did not finish for this photo."
        }
    }
}
