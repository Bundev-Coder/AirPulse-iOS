import SwiftUI

struct EmergencyShutdownOverlay: View {
    @ObservedObject var client = AirPulseClient.shared

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            // Card
            VStack(spacing: 16) {
                // Hazard Icon Ring
                ZStack {
                    Circle()
                        .stroke(Color(red: 255/255, green: 51/255, blue: 102/255).opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(client.shutdownCountdown) / 15.0)
                        .stroke(Color(red: 255/255, green: 51/255, blue: 102/255), lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: client.shutdownCountdown)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 255/255, green: 51/255, blue: 102/255))
                }

                VStack(spacing: 6) {
                    Text("ĐÃ KÍCH HOẠT LỆNH TẮT PC!")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.white)

                    Text("Máy tính sẽ tự động tắt nguồn sau:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Huge Countdown Number
                Text("\(client.shutdownCountdown)s")
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 255/255, green: 51/255, blue: 102/255))
                    .shadow(color: Color(red: 255/255, green: 51/255, blue: 102/255).opacity(0.6), radius: 18)

                // ABORT BUTTON
                Button(action: {
                    client.sendRemoteAction("cancel_shutdown")
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 20))
                        Text("HỦY LỆNH TẮT MÁY NGAY (ABORT)")
                            .font(.system(size: 15, weight: .black))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 16/255, green: 185/255, blue: 129/255),
                                Color(red: 5/255, green: 150/255, blue: 105/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.4), radius: 12)
                }

                Text("Bấm nút trên để hủy bỏ ngay lập tức nếu vô tình bấm nhầm.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 20/255, green: 12/255, blue: 22/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color(red: 255/255, green: 51/255, blue: 102/255).opacity(0.5), lineWidth: 1.5)
                    )
            )
            .shadow(color: Color(red: 255/255, green: 51/255, blue: 102/255).opacity(0.3), radius: 30)
            .padding(.horizontal, 24)
        }
    }
}
