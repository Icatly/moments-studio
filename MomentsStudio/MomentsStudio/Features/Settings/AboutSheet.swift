import SwiftUI

/// Presented from Settings.
///
/// Exists to prove the modal seam (`SheetRoute`) works before later stages add
/// real sheets such as photo import, templates and export.
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    InfoRow(title: "App", value: AppInfo.displayName)
                    InfoRow(title: "Version", value: "\(AppInfo.version) (\(AppInfo.build))")
                    InfoRow(title: "Stage", value: AppInfo.stageLabel)
                }

                Section {
                    Text("Photo import is implemented: photos you pick are copied into this app, with a thumbnail and a preview generated on device. The canvas, layers, layouts, cutouts, AI styling, manual editing and export are not implemented yet.")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("about.done")
                }
            }
        }
    }
}
