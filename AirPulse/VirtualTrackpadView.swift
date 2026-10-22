import SwiftUI

struct VirtualTrackpadView: View {
    @ObservedObject var client = AirPulseClient.shared
    @State private var lastDragLocation: CGPoint? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Trackpad Glass Surface
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 12/255, green: 16/255, blue: 28/255).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0, green: 245/255, blue: 212/255).opacity(0.4),
                                        Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )

                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.7))

                    Text("Rê ngón tay để di chuyển chuột PC")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))

                    Text("1 ngón = Rê chuột / Click • 2 ngón = Cuộn trang")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let last = lastDragLocation {
                            let dx = Int((value.location.x - last.x) * 2.2)
                            let dy = Int((value.location.y - last.y) * 2.2)
                            if dx != 0 || dy != 0 {
                                client.sendMouseMove(dx: dx, dy: dy)
                            }
                        }
                        lastDragLocation = value.location
                    }
                    .onEnded { value in
                        if let last = lastDragLocation, abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                            // Tap gesture
                            client.sendMouseClick(button: "left")
                        }
                        lastDragLocation = nil
                    }
            )

            // Tactile Mouse Buttons Row
            HStack(spacing: 14) {
                Button(action: { client.sendMouseClick(button: "left") }) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 16))
                        Text("Chuột Trái")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }

                Button(action: { client.sendMouseClick(button: "right") }) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 16))
                        Text("Chuột Phải")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.12))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.35), lineWidth: 1)
                    )
                }
            }
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
