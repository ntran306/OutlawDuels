import SwiftUI

/// The menu sheet. Phase 0 holds only the "Dev server" field of PLAN.md §1B.6.
struct SettingsView: View {
    @ObservedObject var dev: DevServerClient
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.20:8765", text: $draft)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LabeledContent("Status", value: dev.status)
                    LabeledContent("Tuning revision", value: "\(dev.tuning.revision)")
                } header: {
                    Text("Dev server")
                } footer: {
                    Text("The address printed by tools/devserver.py on the laptop. Leave empty to turn it off.")
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dev.setAddress(draft)
                    }
                }
            }
            .onAppear { draft = dev.address }
        }
    }
}
