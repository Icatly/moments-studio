import SwiftUI

/// Read-only preview of one imported photo.
///
/// Shows the 2048px derivative with `aspectFit` and no editing controls. The
/// only destructive action is removing this project's copy, and it is behind an
/// explicit native confirmation that says the photo library original is not
/// touched.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference: the
/// `photo` lookup and the removal helper read the main-actor-isolated
/// coordinator and store outside `body` as well.
@MainActor
struct PhotoPreviewSheet: View {
    let projectID: UUID
    let assetID: UUID

    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingRemoval = false

    private var photo: ImportedPhoto? {
        projectStore.photos(for: projectID).first { $0.asset.id == assetID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let photo {
                    content(for: photo)
                } else {
                    Text("This photo is no longer part of the project.")
                        .font(Typography.body)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("preview.missingPhoto")
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("preview.done")
                }

                if photo != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Remove", role: .destructive) {
                            isConfirmingRemoval = true
                        }
                        .disabled(photoImport.isBusy || photoImport.failedDraft(for: projectID) != nil)
                        .accessibilityIdentifier("preview.remove")
                    }
                }
            }
            .confirmationDialog(
                "Remove this photo from the project?",
                isPresented: $isConfirmingRemoval,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    Task {
                        await photoImport.removePhoto(projectID: projectID, assetID: assetID)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(removalMessage)
            }
        }
    }

    private var removalMessage: String {
        let count = projectStore.openProject(id: projectID)?.document.layers.filter { $0.assetID == assetID }.count ?? 0
        let cascade = count == 0 ? "" : "This also removes \(count) canvas layer(s), including any locked layers. "
        return cascade + "Only this project's copy is deleted. The photo in your photo library is not changed."
    }

    private func content(for photo: ImportedPhoto) -> some View {
        VStack(spacing: Spacing.medium) {
            DerivedImageView(
                reference: photo.previewReference,
                contentMode: .fit,
                load: { reference in
                    await photoImport.loadImage(reference: reference)
                },
                placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("preview.image")

            Text("\(photo.displayPixelSize.width) × \(photo.displayPixelSize.height) · \(displayName(forContentType: photo.contentType))")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("preview.info")
        }
        .padding(Spacing.medium)
    }

    /// Human-readable format name. The stored value is a UTI such as
    /// `public.jpeg`, which is not something to show a user.
    private func displayName(forContentType contentType: String) -> String {
        switch contentType {
        case "public.jpeg":
            return "JPEG"
        case "public.png":
            return "PNG"
        case "public.heic":
            return "HEIC"
        case "public.heif":
            return "HEIF"
        default:
            return contentType
        }
    }
}
