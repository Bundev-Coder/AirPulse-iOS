import SwiftUI
import UIKit

// MARK: - Windows Virtual Key Codes (VK)

public enum WindowsVK: UInt32 {
    case backspace = 0x08
    case tab = 0x09
    case enter = 0x0D
    case shift = 0x10
    case ctrl = 0x11
    case alt = 0x12
    case pause = 0x13
    case capsLock = 0x14
    case escape = 0x1B
    case space = 0x20
    case pageUp = 0x21
    case pageDown = 0x22
    case end = 0x23
    case home = 0x24
    case left = 0x25
    case up = 0x26
    case right = 0x27
    case down = 0x28
    case printScreen = 0x2C
    case insert = 0x2D
    case delete = 0x2E
    case win = 0x5B

    case f1 = 0x70
    case f2 = 0x71
    case f3 = 0x72
    case f4 = 0x73
    case f5 = 0x74
    case f6 = 0x75
    case f7 = 0x76
    case f8 = 0x77
    case f9 = 0x78
    case f10 = 0x79
    case f11 = 0x7A
    case f12 = 0x7B
}

// MARK: - Touch Interaction Overlay View

public struct TouchInteractionOverlayView: UIViewRepresentable {
    @ObservedObject public var session: AirPulseSession

    public init(session: AirPulseSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> TouchOverlayUIView {
        let view = TouchOverlayUIView()
        view.session = session
        return view
    }

    public func updateUIView(_ uiView: TouchOverlayUIView, context: Context) {
        uiView.session = session
    }
}

public final class TouchOverlayUIView: UIView, UIGestureRecognizerDelegate {
    public weak var session: AirPulseSession?

    private var panGesture: UIPanGestureRecognizer!
    private var twoFingerPanGesture: UIPanGestureRecognizer!
    private var singleTapGesture: UITapGestureRecognizer!
    private var doubleTapGesture: UITapGestureRecognizer!
    private var twoFingerTapGesture: UITapGestureRecognizer!

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }

    private func setupGestures() {
        backgroundColor = .clear
        isMultipleTouchEnabled = true

        // 1-finger Pan (Trackpad cursor)
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        // 2-finger Pan (Scroll)
        twoFingerPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPanGesture.minimumNumberOfTouches = 2
        twoFingerPanGesture.maximumNumberOfTouches = 2
        twoFingerPanGesture.delegate = self
        addGestureRecognizer(twoFingerPanGesture)

        // Single tap (Left Click)
        singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        addGestureRecognizer(singleTapGesture)

        // Double tap (Double Click)
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        addGestureRecognizer(doubleTapGesture)

        // Two-finger tap (Right Click)
        twoFingerTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTapGesture.numberOfTouchesRequired = 2
        addGestureRecognizer(twoFingerTapGesture)
    }

    // MARK: - Direct Touch vs Trackpad handling

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let s = session, s.isDirectTouchMode, let touch = touches.first else { return }

        let loc = touch.location(in: self)
        let normX = Float(loc.x / bounds.width)
        let normY = Float(loc.y / bounds.height)

        s.sendMouseMove(normX: normX, normY: normY)
        s.sendMouseButton(button: .left, action: .down)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let s = session, s.isDirectTouchMode, let touch = touches.first else { return }

        let loc = touch.location(in: self)
        let normX = Float(loc.x / bounds.width)
        let normY = Float(loc.y / bounds.height)

        s.sendMouseMove(normX: normX, normY: normY)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let s = session, s.isDirectTouchMode else { return }
        s.sendMouseButton(button: .left, action: .up)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard let s = session, s.isDirectTouchMode else { return }
        s.sendMouseButton(button: .left, action: .up)
    }

    // MARK: - Gesture Callbacks (Trackpad Mode)

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let s = session, !s.isDirectTouchMode else { return }

        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)

        // High precision sensitivity scaling
        s.sendTrackpadDelta(dx: Float(translation.x), dy: Float(translation.y), sensitivity: 0.0012)
    }

    @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
        guard let s = session else { return }

        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)

        s.sendMouseScroll(deltaX: Float(translation.x * 2), deltaY: Float(-translation.y * 2))
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        guard let s = session, !s.isDirectTouchMode else { return }
        s.sendMouseClick(button: .left)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let s = session, !s.isDirectTouchMode else { return }
        s.sendMouseButton(button: .left, action: .doubleClick)
    }

    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard let s = session else { return }
        s.sendMouseClick(button: .right)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
