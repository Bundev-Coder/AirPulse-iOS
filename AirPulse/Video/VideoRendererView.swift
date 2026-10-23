import SwiftUI
import AVFoundation

public final class VideoSampleLayerUIView: UIView {
    public override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }

    public var sampleLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }

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
        sampleLayer.videoGravity = .resizeAspect
        sampleLayer.preventsDisplaySleepDuringVideoPlayback = true
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if sampleLayer.status == .failed {
            sampleLayer.flush()
        }

        if sampleLayer.isReadyForMoreMediaData {
            sampleLayer.enqueue(sampleBuffer)
        }
    }

    public func flush() {
        sampleLayer.flush()
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
        // Dynamic adjustments if needed
    }
}
