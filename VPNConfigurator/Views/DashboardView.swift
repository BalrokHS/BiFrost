import SwiftUI

struct DashboardView: View {
    @Environment(VPNController.self) private var controller
    @State private var showingNewProfile = false

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 430), spacing: 18)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.09), Color.purple.opacity(0.05), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if controller.profiles.isEmpty {
                        ContentUnavailableView(
                            "No VPN profiles",
                            systemImage: "shield.slash",
                            description: Text("Create a profile with Add VPN, or import an existing configuration from Profiles.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        GlassEffectContainer(spacing: 18) {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                                ForEach(controller.profiles) { profile in
                                    VPNCard(profile: profile)
                                }
                            }
                        }
                    }
                }
                .padding(28)
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem {
                Button("Add VPN", systemImage: "plus") { showingNewProfile = true }
                    .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView()
                .environment(controller)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your private networks")
                    .font(.largeTitle.bold())
                Text(summary)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !controller.disconnectableProfiles.isEmpty {
                Button("Disconnect all", systemImage: "stop.circle") {
                    controller.disconnectAll()
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var summary: String {
        let count = controller.connectedProfiles.count
        if controller.profiles.contains(where: { controller.state(for: $0) == .degraded }) {
            return "Some VPN connection states could not be confirmed."
        }
        if count == 0, !controller.busyProfiles.isEmpty { return "Checking or changing VPN connections…" }
        if count == 0 { return "No VPN connections are active." }
        return "\(count) VPN connection\(count == 1 ? " is" : "s are") active."
    }
}
