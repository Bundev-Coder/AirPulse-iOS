import SwiftUI

public struct RemoteDesktopView: View {
    @ObservedObject public var session: AirPulseSession
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingFileTransfer = false
    @State private var isShowingDisplayPicker = false
    @State private var isToolbarCollapsed = false
    @State private var clipboardToastText: String?

    public init(session: AirPulseSession) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 1. Video Layer (AVSampleBufferDisplayLayer)
            VideoRendererView(session: session)
                .ignoresSafeArea()

            // 2. Gesture / Touch Interaction Layer
            TouchInteractionOverlayView(session: session)
                .ignoresSafeArea()

            // 3. Simulated Cursor in Trackpad Mode
            GeometryReader { geo in
                if !session.isDirectTouchMode {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .shadow(color: .cyan.opacity(0.8), radius: 6)
                        .position(
                            x: CGFloat(session.cursorX) * geo.size.width,
                            y: CGFloat(session.cursorY) * geo.size.height
                        )
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()

            // 4. Floating Top Control Capsule
            VStack {
                topControlBar
                    .padding(.top, 8)
                Spacer()
            }

            // 5. Floating Virtual Keyboard
            VStack {
                Spacer()
                if session.isKeyboardVisible {
                    VirtualKeyboardView(session: session)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
            }

            // 6. Clipboard Notification Toast
            if let toast = clipboardToastText {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundColor(.cyan)
                        Text("Đã đồng bộ Clipboard: \(toast)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding(.top, 60)

                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        .navigationBarHidden(true)
        .sheet(isPresented: $isShowingFileTransfer) {
            FileTransferView(session: session)
        }
        .confirmationDialog("Chọn màn hình", isPresented: $isShowingDisplayPicker, titleVisibility: .visible) {
            ForEach(session.displays) { disp in
                Button("\(disp.name.isEmpty ? "Monitor \(disp.index + 1)" : disp.name) (\(disp.width)x\(disp.height))") {
                    session.sendDisplaySelect(displayIndex: disp.index)
                }
            }
            Button("Hủy", role: .cancel) {}
        }
        .onChange(of: session.incomingClipboardText) { text in
            guard let text = text else { return }
            clipboardToastText = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { clipboardToastText = nil }
            }
        }
    }

    // MARK: - Top Floating Control Bar

    private var topControlBar: some View {
        HStack(spacing: 10) {
            if isToolbarCollapsed {
                Button(action: { withAnimation(.spring()) { isToolbarCollapsed = false } }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(6)
                }
            } else {
                // Latency Badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(session.latencyMs < 30 ? Color.green : (session.latencyMs < 80 ? Color.yellow : Color.red))
                        .frame(width: 7, height: 7)
                    Text("\(session.latencyMs)ms")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)

                // FPS & Bitrate
                Text("\(session.currentFps) fps")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)

                Divider().frame(height: 18).background(Color.white.opacity(0.3))

                // Trackpad / Direct Touch Toggle
                Button(action: {
                    withAnimation { session.isDirectTouchMode.toggle() }
                }) {
                    Image(systemName: session.isDirectTouchMode ? "hand.point.up.left.fill" : "computermouse.fill")
                        .font(.system(size: 15))
                        .foregroundColor(session.isDirectTouchMode ? .cyan : .white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                }

                // Keyboard Toggle
                Button(action: {
                    withAnimation(.spring(response: 0.35)) {
                        session.isKeyboardVisible.toggle()
                    }
                }) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 15))
                        .foregroundColor(session.isKeyboardVisible ? .cyan : .white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                }

                // Displays Switcher
                if session.displays.count > 1 {
                    Button(action: { isShowingDisplayPicker = true }) {
                        Image(systemName: "display.2")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                }

                // File Transfer Button
                Button(action: { isShowingFileTransfer = true }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                }

                // Disconnect Button
                Button(action: {
                    session.disconnect()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                }

                // Collapse Button
                Button(action: { withAnimation(.spring()) { isToolbarCollapsed = true } }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.6))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.5), radius: 10)
    }
}
