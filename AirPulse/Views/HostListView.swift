import SwiftUI

public struct HostListView: View {
    @StateObject private var mdns = MdnsDiscovery.shared
    @StateObject private var session = AirPulseSession()

    @State private var pairedHosts: [PairedHost] = []
    @State private var isShowingPairingView = false
    @State private var isShowingSettings = false
    @State private var isShowingManualConnect = false
    @State private var manualIp: String = ""
    @State private var pairingInitialIp: String = ""

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // Header Banner
                        headerBanner

                        // Section 1: Paired Hosts
                        if !pairedHosts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(title: "Máy tính đã ghép đôi", count: pairedHosts.count, icon: "desktopcomputer")
                                ForEach(pairedHosts) { host in
                                    pairedHostCard(host)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Section 2: Discovered LAN Hosts
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                sectionHeader(title: "Tìm thấy trong mạng LAN", count: mdns.discoveredHosts.count, icon: "bonjour")
                                Spacer()
                                if mdns.isScanning {
                                    RadarPulseIndicator()
                                }
                            }
                            
                            if mdns.discoveredHosts.isEmpty {
                                emptyDiscoveryCard
                            } else {
                                ForEach(mdns.discoveredHosts) { disc in
                                    discoveredHostCard(disc)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Section 3: Manual IP Connect
                        manualConnectSection
                            .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 10)
                }
            }
            .navigationTitle("AirPulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.cyan)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        pairingInitialIp = ""
                        isShowingPairingView = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Ghép đôi")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $isShowingPairingView) {
                PairingView(session: session, initialIp: pairingInitialIp)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: Binding(
                get: {
                    if case .streaming = session.state { return true }
                    return false
                },
                set: { if !$0 { session.disconnect() } }
            )) {
                RemoteDesktopView(session: session)
            }
            .onAppear {
                reloadPairedHosts()
                mdns.startScanning()
            }
        }
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))

                VStack(alignment: .leading, spacing: 2) {
                    Text("AirPulse LAN Control")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Điều khiển Windows PC từ iPhone cực mượt, không cần Internet")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.cyan)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text("(\(count))")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Paired Host Card

    private func pairedHostCard(_ host: PairedHost) -> some View {
        let isOnline = mdns.discoveredHosts.contains { $0.id == host.id || $0.ip == host.lastKnownIp }

        return HStack(spacing: 14) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: "pc")
                    .font(.system(size: 20))
                    .foregroundColor(.white)

                Circle()
                    .fill(isOnline ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                    .offset(x: 14, y: 14)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(host.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(host.lastKnownIp):\(host.controlPort) • \(isOnline ? "Trực tuyến" : "Ngoại tuyến")")
                    .font(.system(size: 13))
                    .foregroundColor(isOnline ? .green : .gray)
            }

            Spacer()

            // Connect Button
            Button(action: {
                Task {
                    await session.connect(
                        hostIp: host.lastKnownIp,
                        controlPort: host.controlPort,
                        expectedFingerprint: host.certFingerprint
                    )
                }
            }) {
                Text("Kết nối")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: {
                KeychainManager.shared.removePairedHost(id: host.id)
                reloadPairedHosts()
            }) {
                Label("Hủy ghép đôi", systemImage: "trash")
            }
        }
    }

    // MARK: - Discovered Host Card

    private func discoveredHostCard(_ disc: DiscoveredHost) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "display")
                    .font(.system(size: 20))
                    .foregroundColor(.cyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(disc.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(disc.ip):\(disc.port)")
                    .font(.system(size: 13))
                    .foregroundColor(.cyan.opacity(0.8))
            }

            Spacer()

            // Pair Button
            Button(action: {
                pairingInitialIp = disc.ip
                isShowingPairingView = true
            }) {
                Text("Ghép đôi")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    // MARK: - Empty Card

    private var emptyDiscoveryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 22))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 2) {
                Text("Đang quét máy tính trong cùng mạng Wi-Fi...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text("Hãy đảm bảo AirPulse Host đang chạy trên PC")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    // MARK: - Manual Connect

    private var manualConnectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Kết nối thủ công qua IP", count: 1, icon: "network")

            HStack {
                TextField("Nhập IP máy tính (VD: 192.168.1.10)", text: $manualIp)
                    .keyboardType(.numbersAndPunctuation)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(10)

                Button(action: {
                    guard !manualIp.isEmpty else { return }
                    pairingInitialIp = manualIp
                    isShowingPairingView = true
                }) {
                    Text("Tiếp")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(manualIp.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(manualIp.isEmpty)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
    }

    private func reloadPairedHosts() {
        pairedHosts = KeychainManager.shared.getPairedHosts()
    }
}

// MARK: - Radar Pulse Animation

private struct RadarPulseIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
                .frame(width: 18, height: 18)
                .scaleEffect(isPulsing ? 1.8 : 0.8)
                .opacity(isPulsing ? 0 : 1)

            Circle()
                .fill(Color.cyan)
                .frame(width: 7, height: 7)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
