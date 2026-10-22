import SwiftUI
import UniformTypeIdentifiers

struct KineticBeamView: View {
    @ObservedObject var client = AirPulseClient.shared

    // Staged File State
    @State private var stagedData: Data? = nil
    @State private var stagedName: String = ""
    @State private var stagedSizeStr: String = ""
    @State private var stagedImage: UIImage? = nil
    
    // Drag / Flick Gesture Physics
    @State private var dragOffset: CGSize = .zero
    @State private var isLaunching: Bool = false
    @State private var uploadProgress: Double = 0.0
    @State private var isUploading: Bool = false
    
    // Pickers
    @State private var showPhotoPicker: Bool = false
    @State private var showDocPicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Portal Arena
            ZStack {
                // Cyber Rings
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0, green: 245/255, blue: 212/255).opacity(0.4),
                                Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.3),
                                Color(red: 0, green: 245/255, blue: 212/255).opacity(0.4)
                            ]),
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(isUploading ? 360 : 0))
                    .animation(isUploading ? Animation.linear(duration: 4).repeatForever(autoreverses: false) : .default, value: isUploading)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 220, height: 220)

                // Staged Card OR Empty Core
                if let _ = stagedData {
                    stagedCardView
                        .offset(y: dragOffset.height)
                        .scaleEffect(max(0.7, 1.0 - abs(dragOffset.height) * 0.001))
                        .opacity(isLaunching ? 0 : 1)
                        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if !isUploading {
                                        if value.translation.height < 0 {
                                            dragOffset = value.translation
                                        }
                                    }
                                }
                                .onEnded { value in
                                    if !isUploading {
                                        if value.translation.height < -100 || value.predictedEndTranslation.height < -200 {
                                            launchFlickBeam()
                                        } else {
                                            dragOffset = .zero
                                        }
                                    }
                                }
                        )
                } else {
                    emptyStateView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Quick Pickers Row
            HStack(spacing: 16) {
                Button(action: { showPhotoPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16, weight: .bold))
                        Text("Chọn Ảnh / Video")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.12))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.3), lineWidth: 1)
                    )
                }

                Button(action: { showDocPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Chọn Tệp")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(Color(red: 139/255, green: 92/255, blue: 246/255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.12))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showPhotoPicker) {
            NativePhotoPicker { image, data, name in
                stageFile(data: data, name: name, image: image)
            }
        }
        .sheet(isPresented: $showDocPicker) {
            NativeDocumentPicker { data, name in
                stageFile(data: data, name: name, image: nil)
            }
        }
    }

    // MARK: - Staged Card View
    private var stagedCardView: some View {
        VStack(spacing: 12) {
            if let img = stagedImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
            } else {
                Image(systemName: "doc.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                    .frame(width: 80, height: 80)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(spacing: 4) {
                Text(stagedName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(stagedSizeStr)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
            }

            // Flick hint
            VStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                Text("Vuốt Lướt Lên (Flick) Để Bắn Sang PC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 4)

            // Direct button
            Button(action: launchFlickBeam) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                    Text("Bắn Sang PC Ngay")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0, green: 245/255, blue: 212/255))
                .clipShape(Capsule())
            }
        }
        .frame(width: 220, height: 260)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 15/255, green: 20/255, blue: 32/255).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.4), lineWidth: 1.5)
                )
        )
        .shadow(color: Color(red: 0, green: 245/255, blue: 212/255).opacity(0.25), radius: 24)
    }

    // MARK: - Empty State Core
    private var emptyStateView: some View {
        Button(action: { showPhotoPicker = true }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.12))
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                }

                Text("Chạm để chọn Tệp")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text("Truyền siêu tốc không nén chất lượng")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Actions
    private func stageFile(data: Data, name: String, image: UIImage?) {
        stagedData = data
        stagedName = name
        stagedImage = image
        let mb = Double(data.count) / (1024 * 1024)
        stagedSizeStr = String(format: "%.1f MB", mb)
        dragOffset = .zero
        isLaunching = false
    }

    private func launchFlickBeam() {
        guard let data = stagedData, !isUploading else { return }
        isUploading = true

        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: 0, height: -450)
            isLaunching = true
        }

        let mime = stagedImage != nil ? "image/jpeg" : "application/octet-stream"

        client.uploadFile(data: data, filename: stagedName, mimeType: mime, progress: { p in
            uploadProgress = p
        }) { success in
            isUploading = false
            withAnimation {
                stagedData = nil
                stagedImage = nil
                dragOffset = .zero
                isLaunching = false
            }
        }
    }
}

// MARK: - Native Photo Picker UIKit Wrapper
struct NativePhotoPicker: UIViewControllerRepresentable {
    var onPick: (UIImage?, Data, String) -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image", "public.movie"]
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NativePhotoPicker

        init(_ parent: NativePhotoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.95) {
                let name = "IMG_\(Int(Date().timeIntervalSince1970)).jpg"
                parent.onPick(image, data, name)
            } else if let mediaUrl = info[.mediaURL] as? URL,
                      let data = try? Data(contentsOf: mediaUrl) {
                parent.onPick(nil, data, mediaUrl.lastPathComponent)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Native Document Picker UIKit Wrapper
struct NativeDocumentPicker: UIViewControllerRepresentable {
    var onPick: (Data, String) -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: NativeDocumentPicker

        init(_ parent: NativeDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first, let data = try? Data(contentsOf: url) {
                parent.onPick(data, url.lastPathComponent)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
