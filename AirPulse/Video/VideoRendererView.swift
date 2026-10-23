import SwiftUI
import AVFoundation

public final class VideoSampleLayerUIView: UIView {
    public let displayLayer = AVSampleBufferDisplayLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        backgroundColor = .black
        displayLayer.videoGravity = .resizeAspect
        displayLayer.preventsDisplaySleepDuringVideoPlayback = true
        layer.addSublayer(displayLayer)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if displayLayer.status == .failed {
            displayLayer.flush()
        }

        if displayLayer.isReadyForMoreMediaData {
            displayLayer.enqueue(sampleBuffer)
        }
    }

    public func flush() {
        displayLayer.flush()
    }
}

public struct VideoRendererView: UIViewRepresentable {
    @ObservedObject public var session: AirPulseSession

    public init(session: AirPulseSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> VideoSampleLayerUIView {
        let view = VideoSampleLayerUIView(frame: .zero)
        session.videoRendererView = view
        return view
    }

    public func updateUIView(_ uiView: VideoSampleLayerUIView, context: Context) {
        uiView.displayLayer.frame = uiView.bounds
    }
}
