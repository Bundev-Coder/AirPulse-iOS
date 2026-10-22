import SwiftUI

struct ContentView: View {
    @StateObject private var client = AirPulseClient.shared
    @State private var selectedTab: Int = 0
    @State private var showConnectionSheet: Bool = false

    var body: some View {
        ZStack {
            // Dark Futuristic Ambient Background
            Color(red: 5/255, green: 7/255, blue: 12/255)
                .ignoresSafeArea()

            // Glow spheres
            VStack {
                Circle()
                    .fill(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.08))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(y: -100)
                Spacer()
                Circle()
                    .fill(Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.08))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(y: 100)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Dynamic Island Capsule
                dynamicIslandTopBar

                // Active View Body
                ZStack {
                    switch selectedTab {
                    case 0:
                        KineticBeamView(client: client)
                    case 1:
                        RemoteDeckView(client: client)
                    case 2:
                        VirtualTrackpadView(client: client)
                    case 3:
                        VaultView(client: client)
                    default:
                        KineticBeamView(client: client)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom Cyber-Glass Bottom Dock
                cyberGlassBottomDock
            }

            // Emergency Shutdown Countdown Overlay (if triggered)
            if client.isShutdownActive {
                EmergencyShutdownOverlay(client: client)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionSheetView(client: client)
        }
        .onAppear {
            client.connect()
        }
    }

    // MARK: - Top Dynamic Island
    private var dynamicIslandTopBar: some View {
        HStack(spacing: 10) {
            // Pulsar Dot
            Circle()
                .fill(client.isConnected ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 245/255, green: 158/255, blue: 11/255))
                .frame(width: 8, height: 8)
                .shadow(color: client.isConnected ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color.clear, radius: 4)

            // Status Title
            Text(client.isConnected ? "AirPulse • Đã kết nối" : "AirPulse • Đang dò PC...")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Latency Badge if connected
            if client.isConnected && client.pingMs > 0 {
                Text("\(client.pingMs)ms")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.12))
                    .cornerRadius(6)
            }

            // Config IP Button
            Button(action: { showConnectionSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: client.isWanMode ? "antenna.radiowaves.left.and.right" : "wifi")
                        .font(.system(size: 11))
                    Text(client.isWanMode ? "WAN" : "LAN")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(red: 10/255, green: 14/255, blue: 24/255).opacity(0.95))
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: - Custom Cyber-Glass Bottom Dock
    private var cyberGlassBottomDock: some View {
        HStack {
            dockTabButton(title: "Bắn Tệp", icon: "bolt.fill", tag: 0)
            Spacer()
            dockTabButton(title: "Điều Khiển", icon: "slider.horizontal.3", tag: 1)
            Spacer()
            dockTabButton(title: "Bàn Chuột", icon: "cursorarrow.rays", tag: 2)
            Spacer()
            dockTabButton(title: "Kho Tệp", icon: "tray.fill", tag: 3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color(red: 10/255, green: 14/255, blue: 24/255).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.8), radius: 24)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func dockTabButton(title: String, icon: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tag
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color(red: 0, green: 245/255, blue: 212/255) : Color.white.opacity(0.4))

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .heavy : .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.4))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                isSelected ?
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.4), lineWidth: 1)
                    ) : nil
            )
        }
    }
}
