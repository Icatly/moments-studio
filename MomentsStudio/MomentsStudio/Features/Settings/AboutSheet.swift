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
                    Text("This is a foundation build. Photo import, collage layouts, cutouts, styling, editing and export are not implemented yet.")
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
