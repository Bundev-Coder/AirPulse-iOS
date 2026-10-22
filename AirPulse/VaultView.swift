import SwiftUI

struct VaultView: View {
    @ObservedObject var client = AirPulseClient.shared
    @State private var shareItemUrl: URL? = nil
    @State private var isDownloadingForShare: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Kho Tệp Trên Máy Tính")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { client.fetchFiles() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                        Text("Làm mới")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Content List
            if client.files.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color.white.opacity(0.2))
                    Text("Chưa có tệp nào được truyền")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                    Spacer()
                }
            } else {
                List {
                    ForEach(client.files) { item in
                        vaultRow(item: item)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.bottom, 74)
        .sheet(item: $shareItemUrl) { url in
            NativeShareSheet(activityItems: [url])
        }
    }

    private func vaultRow(item: VaultItem) -> some View {
        HStack(spacing: 14) {
            // Thumb
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 52, height: 52)

                if item.is_image {
                    AsyncImage(url: URL(string: "\(client.baseUrl)\(item.view_url)")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        default:
                            Image(systemName: "photo")
                                .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                        }
                    }
                } else if item.is_video {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(Color(red: 139/255, green: 92/255, blue: 246/255))
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "doc.fill")
                        .foregroundColor(Color.white.opacity(0.6))
                        .font(.system(size: 22))
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.size_formatted)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
            }

            Spacer()

            // Actions: Save / Share
            Button(action: { downloadAndShare(item: item) }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(10)
                    .background(Color(red: 0, green: 245/255, blue: 212/255))
                    .clipShape(Circle())
            }

            // Delete
            Button(action: { client.deleteFile(name: item.name) }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 15/255, green: 20/255, blue: 32/255).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func downloadAndShare(item: VaultItem) {
        guard let url = URL(string: "\(client.baseUrl)\(item.download_url)") else { return }
        URLSession.shared.downloadTask(with: url) { localUrl, _, _ in
            if let local = localUrl {
                let tempDest = FileManager.default.temporaryDirectory.appendingPathComponent(item.name)
                try? FileManager.default.removeItem(at: tempDest)
                try? FileManager.default.copyItem(at: local, to: tempDest)
                DispatchQueue.main.async {
                    self.shareItemUrl = tempDest
                }
            }
        }.resume()
    }
}

// MARK: - Native Share Sheet Wrapper
struct NativeShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}
