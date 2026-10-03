import PhotosUI
import SwiftUI

/// Import and gallery block for the editor placeholder.
///
/// Stage 02 scope only: pick photos with the system picker, watch progress,
/// cancel, open a read-only preview, and remove a photo from this project. No
/// canvas, layers, editing, AI, styling or export exist yet, and nothing here
/// pretends otherwise.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference: the
/// private computed properties and helpers below read the main-actor-isolated
/// coordinator and store, not only `body`.
@MainActor
struct PhotoImportSection: View {
    let projectID: UUID

    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(ProjectStore.self) private var projectStore
    @Environment(AppNavigationModel.self) private var navigation

    /// Picker selection is import UI state. It is cleared as soon as a batch
    /// starts so the same photo can be picked again in the next round.
    @State private var selection: [PhotosPickerItem] = []

    private var photos: [ImportedPhoto] {
        projectStore.photos(for: projectID)
    }

    private var capacity: Int {
        photoImport.remainingCapacity(for: projectID)
    }

    private var batchIsRunning: Bool {
        photoImport.isImporting(projectID: projectID)
    }

    /// Creating or importing is only safe once the library finished loading, and
    /// only one mutation may run at a time.
    private var isBlocked: Bool {
        !photoImport.isReady || photoImport.isBusy || batchIsRunning || capacity == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            importControls

            if !photoImport.isReady {
                Text(photoImport.isRestoring ? "Loading saved projects…" : "Photo import is unavailable until saved projects finish loading.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("editor.importUnavailable")
            }

            if batchIsRunning {
                progressRow
            }

            if photos.isEmpty {
                Text("No photos imported yet.")
                    .font(Typography.body)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("editor.galleryEmpty")
            } else {
                photoGrid
            }

            if !photoImport.itemErrors.isEmpty {
                errorList
            }
        }
        .onChange(of: selection) { _, newSelection in
            guard !newSelection.isEmpty else { return }
            let items = newSelection
            selection = []
            Task {
                await photoImport.importSelection(items, projectID: projectID)
            }
        }
    }

    // MARK: - Controls

    private var importControls: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            PhotosPicker(
                selection: $selection,
                maxSelectionCount: max(1, capacity),
                selectionBehavior: .ordered,
                matching: .images,
                preferredItemEncoding: .current
            ) {
                Label("Import Photos", systemImage: "photo.badge.plus")
                    .font(Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Layout.minimumTapTarget)
            }
            .tint(Palette.accent)
            .disabled(isBlocked)
            .accessibilityIdentifier("editor.importPhotos")
            .accessibilityHint("Opens the system photo picker; photos are copied into this project")

            Text("\(photos.count) of \(ProjectPackage.photoLimit) photos")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("editor.photoCount")

            if capacity == 0 {
                Text("This project has reached the Stage 02 photo limit. Remove a photo to import another.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    private var progressRow: some View {
        HStack(spacing: Spacing.medium) {
            ProgressView(
                value: Double(photoImport.completedCount),
                total: Double(max(1, photoImport.totalCount))
            )
            .accessibilityIdentifier("editor.importProgress")

            Text("\(photoImport.completedCount) of \(photoImport.totalCount)")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)

            Spacer(minLength: 0)

            Button("Cancel") {
                photoImport.cancelImport(projectID: projectID)
            }
            .accessibilityIdentifier("editor.cancelImport")
        }
    }

    private var photoGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.small)],
            spacing: Spacing.small
        ) {
            ForEach(photos) { photo in
                Button {
                    navigation.present(.photoPreview(projectID: projectID, assetID: photo.asset.id))
                } label: {
                    DerivedImageView(
                        reference: photo.thumbnailReference,
                        contentMode: .fill,
                        load: { reference in
                            await photoImport.loadImage(reference: reference)
                        },
                        placeholder: {
                            RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous)
                                .fill(Palette.thumbnailFill)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(Color.secondary)
                                }
                        }
                    )
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.photo.\(photo.asset.id.uuidString)")
                .accessibilityHint("Opens a read-only preview of this photo")
            }
        }
    }

    private var errorList: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            ForEach(photoImport.itemErrors, id: \.self) { message in
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(Color.red)
                    .accessibilityIdentifier("editor.importError")
            }

            Button("Dismiss") {
                photoImport.dismissItemErrors()
            }
            .font(Typography.caption)
        }
    }
}
