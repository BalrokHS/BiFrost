import SwiftUI
import UniformTypeIdentifiers

struct ProfilesView: View {
    @Environment(VPNController.self) private var controller
    @State private var editorProfile: VPNProfile?
    @State private var showingNewProfile = false
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var pendingDeletion: VPNProfile?

    var body: some View {
        List(controller.profiles) { profile in
            profileRow(profile)
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { editorProfile = profile }
                    Button("Delete", systemImage: "trash", role: .destructive) { pendingDeletion = profile }
                        .disabled(!canDelete(profile))
                }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItemGroup {
                Button("Import", systemImage: "square.and.arrow.down") { showingImporter = true }
                Button("New profile", systemImage: "plus") { showingNewProfile = true }
                    .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView()
                .environment(controller)
        }
        .sheet(item: $editorProfile) { profile in
            ProfileEditorView(profile: profile)
                .environment(controller)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data, .plainText],
            allowsMultipleSelection: true,
            onCompletion: importFiles
        )
        .alert("Import failed", isPresented: messageBinding($importError)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert("Delete \(pendingDeletion?.name ?? "profile")?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let profile = pendingDeletion { controller.delete(profile.id) }
                pendingDeletion = nil
            }
        } message: {
            Text("The saved profile and its Keychain password will be removed. Any file previously used for importing is never modified.")
        }
    }

    private func profileRow(_ profile: VPNProfile) -> some View {
        let state = controller.state(for: profile)
        return HStack(spacing: 14) {
            Image(systemName: profile.provider.symbol)
                .foregroundStyle(profile.accent.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name).font(.headline)
                Text(profile.server)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text(profile.authentication.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Circle().fill(state.color).frame(width: 8, height: 8)

            Button("Edit", systemImage: "pencil") { editorProfile = profile }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    private func canDelete(_ profile: VPNProfile) -> Bool {
        let state = controller.state(for: profile)
        return state == .disconnected || state == .failed
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get() {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                try controller.importConfiguration(at: url)
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    private func messageBinding(_ value: Binding<String?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
