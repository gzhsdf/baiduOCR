import SwiftUI
import AppKit

struct ImageRegionSelector: NSViewRepresentable {
    let image: NSImage?
    var cropRect: NSRect?
    var zoomScale: CGFloat = 1.0
    var rotationAngle: Double = 0
    var panOffset: CGPoint = .zero
    var invertScrollY: Bool = false

    let onRegionSelected: (NSRect) -> Void
    let onClear: () -> Void
    let onZoomChanged: (CGFloat) -> Void
    let onPanChanged: (CGPoint) -> Void

    func makeNSView(context: Context) -> RegionSelectView {
        let view = RegionSelectView()
        view.onRegionSelected = onRegionSelected
        view.onClear = onClear
        view.onZoomChanged = onZoomChanged
        view.onPanChanged = onPanChanged
        return view
    }

    func updateNSView(_ nsView: RegionSelectView, context: Context) {
        nsView.onRegionSelected = onRegionSelected
        nsView.onClear = onClear
        nsView.onZoomChanged = onZoomChanged
        nsView.onPanChanged = onPanChanged
        nsView.image = image
        nsView.imageCropRect = cropRect
        nsView.zoomScale = zoomScale
        nsView.rotationAngle = rotationAngle
        nsView.panOffset = panOffset
        nsView.invertScrollY = invertScrollY
        nsView.needsDisplay = true
    }
}

final class RegionSelectView: NSView {
    var onRegionSelected: ((NSRect) -> Void)?
    var onClear: (() -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?
    var onPanChanged: ((CGPoint) -> Void)?

    var image: NSImage? {
        didSet { needsDisplay = true }
    }
    var imageCropRect: NSRect? {
        didSet { needsDisplay = true }
    }
    var zoomScale: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }
    var rotationAngle: Double = 0 {
        didSet { needsDisplay = true }
    }
    var panOffset: CGPoint = .zero {
        didSet { needsDisplay = true }
    }
    var invertScrollY: Bool = false

    private var startPoint: NSPoint?
    private var dragRect: NSRect?
    private var isPanning: Bool = false
    private var resizeHandle: ResizeHandle = .none
    private var moveStartOrigin: NSPoint?
    // The "anchor" rect at the start of resize/move — in view coords
    private var anchorViewRect: NSRect?

    private let handleSize: CGFloat = 8

    enum ResizeHandle { case none, inside, n, s, e, w, ne, nw, se, sw }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Gesture events

    private var accumulatedMagnification: CGFloat = 0

    override func magnify(with event: NSEvent) {
        accumulatedMagnification += event.magnification
        let newScale = max(0.1, min(10.0, zoomScale * (1 + accumulatedMagnification)))
        if abs(newScale - zoomScale) / zoomScale > 0.02 {
            zoomScale = newScale
            onZoomChanged?(newScale)
            accumulatedMagnification = 0
        }
        needsDisplay = true
        if event.phase == .ended || event.phase == .cancelled {
            accumulatedMagnification = 0
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.hasPreciseScrollingDeltas else { return }
        let dy = invertScrollY ? -event.scrollingDeltaY : event.scrollingDeltaY
        panOffset = CGPoint(
            x: panOffset.x + event.scrollingDeltaX,
            y: panOffset.y + dy
        )
        onPanChanged?(panOffset)
        needsDisplay = true
    }

    // MARK: - Mouse events with resize support

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onClear?()
            resetDragState()
            needsDisplay = true
            return
        }
        let pt = convert(event.locationInWindow, from: nil)

        // Option key = pan
        if event.modifierFlags.contains(.option) {
            isPanning = true
            startPoint = pt
            return
        }

        // Check if clicking on an existing selection
        if let imgCrop = imageCropRect, let existingViewRect = imageToViewCoordsOpt(imgCrop) {
            let handle = hitTestHandle(at: pt, on: existingViewRect)
            if handle != .none {
                resizeHandle = handle
                startPoint = pt
                anchorViewRect = existingViewRect
                return
            }
        }

        // New selection
        isPanning = false
        resizeHandle = .none
        startPoint = pt
        dragRect = nil
        anchorViewRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        if isPanning {
            let dx = current.x - start.x
            let dy = current.y - start.y
            panOffset = CGPoint(x: panOffset.x + dx, y: panOffset.y + dy)
            onPanChanged?(panOffset)
            startPoint = current
            needsDisplay = true
            return
        }

        if resizeHandle != .none, let anchor = anchorViewRect {
            dragRect = computeResizedRect(handle: resizeHandle, anchor: anchor, start: start, current: current)
            needsDisplay = true
            return
        }

        // New selection drag
        let clamped = clampToImage(current)
        dragRect = NSRect(
            x: min(start.x, clamped.x),
            y: min(start.y, clamped.y),
            width: abs(clamped.x - start.x),
            height: abs(clamped.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isPanning {
            isPanning = false
            resetDragState()
            needsDisplay = true
            return
        }

        let finalRect: NSRect?
        if resizeHandle != .none {
            finalRect = dragRect ?? anchorViewRect
        } else {
            finalRect = dragRect
        }

        if let rect = finalRect, rect.width > 8, rect.height > 8 {
            if let imgRect = viewToImageCoords(rect) {
                onRegionSelected?(imgRect)
            }
        }
        resetDragState()
        needsDisplay = true
    }

    private func resetDragState() {
        startPoint = nil
        dragRect = nil
        resizeHandle = .none
        anchorViewRect = nil
    }

    // MARK: - Hit testing for resize handles

    private func hitTestHandle(at point: NSPoint, on rect: NSRect) -> ResizeHandle {
        let h = handleSize

        // Corners first (they take priority)
        let nw = NSRect(x: rect.minX - h, y: rect.maxY - h, width: h * 2, height: h * 2)
        let ne = NSRect(x: rect.maxX - h, y: rect.maxY - h, width: h * 2, height: h * 2)
        let sw = NSRect(x: rect.minX - h, y: rect.minY - h, width: h * 2, height: h * 2)
        let se = NSRect(x: rect.maxX - h, y: rect.minY - h, width: h * 2, height: h * 2)

        if nw.contains(point) { return .nw }
        if ne.contains(point) { return .ne }
        if sw.contains(point) { return .sw }
        if se.contains(point) { return .se }

        // Edges
        let topEdge    = NSRect(x: rect.minX, y: rect.maxY - h, width: rect.width, height: h * 2)
        let bottomEdge = NSRect(x: rect.minX, y: rect.minY - h, width: rect.width, height: h * 2)
        let leftEdge   = NSRect(x: rect.minX - h, y: rect.minY, width: h * 2, height: rect.height)
        let rightEdge  = NSRect(x: rect.maxX - h, y: rect.minY, width: h * 2, height: rect.height)

        if topEdge.contains(point)    { return .n }
        if bottomEdge.contains(point) { return .s }
        if leftEdge.contains(point)   { return .w }
        if rightEdge.contains(point)  { return .e }

        // Inside
        if rect.contains(point) { return .inside }

        return .none
    }

    private func computeResizedRect(handle: ResizeHandle, anchor: NSRect, start: NSPoint, current: NSPoint) -> NSRect {
        let imgFrame = computeTransformedImageFrame()
        let dx = current.x - start.x
        let dy = current.y - start.y
        let minSize: CGFloat = 10

        var r = anchor

        switch handle {
        case .nw:
            r.origin.x = min(anchor.maxX - minSize, anchor.minX + dx)
            r.size.width = anchor.maxX - r.minX
            r.size.height = max(minSize, anchor.height + dy)
        case .ne:
            r.size.width = max(minSize, anchor.width + dx)
            r.size.height = max(minSize, anchor.height + dy)
        case .sw:
            r.origin.x = min(anchor.maxX - minSize, anchor.minX + dx)
            r.size.width = anchor.maxX - r.minX
            r.origin.y = min(anchor.maxY - minSize, anchor.minY + dy)
            r.size.height = anchor.maxY - r.minY
        case .se:
            r.size.width = max(minSize, anchor.width + dx)
            r.origin.y = min(anchor.maxY - minSize, anchor.minY + dy)
            r.size.height = anchor.maxY - r.minY
        case .n:
            r.size.height = max(minSize, anchor.height + dy)
        case .s:
            r.origin.y = min(anchor.maxY - minSize, anchor.minY + dy)
            r.size.height = anchor.maxY - r.minY
        case .w:
            r.origin.x = min(anchor.maxX - minSize, anchor.minX + dx)
            r.size.width = anchor.maxX - r.minX
        case .e:
            r.size.width = max(minSize, anchor.width + dx)
        case .inside:
            r.origin.x = anchor.minX + dx
            r.origin.y = anchor.minY + dy
            // Clamp to image bounds
            if r.minX < imgFrame.minX { r.origin.x = imgFrame.minX }
            if r.maxX > imgFrame.maxX { r.origin.x = imgFrame.maxX - r.width }
            if r.minY < imgFrame.minY { r.origin.y = imgFrame.minY }
            if r.maxY > imgFrame.maxY { r.origin.y = imgFrame.maxY - r.height }
        case .none:
            break
        }

        // Clamp to image bounds for all handles
        r.origin.x = max(imgFrame.minX, r.minX)
        r.origin.y = max(imgFrame.minY, r.minY)
        if r.maxX > imgFrame.maxX { r.size.width = imgFrame.maxX - r.minX }
        if r.maxY > imgFrame.maxY { r.size.height = imgFrame.maxY - r.minY }

        return r
    }

    private func clampToImage(_ point: NSPoint) -> NSPoint {
        let frame = computeTransformedImageFrame()
        return NSMakePoint(
            max(frame.minX, min(frame.maxX, point.x)),
            max(frame.minY, min(frame.maxY, point.y))
        )
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Black background
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        // Draw image with full transform
        if let img = image, let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()

            // Compute base image frame (centered, fit)
            let baseFrame = computeBaseImageFrame()

            // Build transform around image center
            let cx = baseFrame.midX + panOffset.x
            let cy = baseFrame.midY + panOffset.y

            context.translateBy(x: cx, y: cy)
            context.rotate(by: rotationAngle * .pi / 180.0)
            context.scaleBy(x: zoomScale, y: zoomScale)
            context.translateBy(x: -baseFrame.midX, y: -baseFrame.midY)

            // Clip to rounded rect
            let clipPath = NSBezierPath(roundedRect: baseFrame, xRadius: 4, yRadius: 4)
            clipPath.addClip()

            context.draw(cgImage, in: baseFrame)
            context.restoreGState()
        }

        // Draw selection overlay
        let selectionInView: NSRect?
        if let drag = dragRect {
            selectionInView = drag
        } else if let imgCrop = imageCropRect, image != nil {
            selectionInView = imageToViewCoords(imgCrop)
        } else {
            selectionInView = nil
        }

        if let rect = selectionInView, rect.width > 0, rect.height > 0 {
            // Dim outside
            context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            context.fill(NSRect(x: bounds.minX, y: rect.maxY, width: bounds.width, height: bounds.height - rect.maxY))
            context.fill(NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: rect.minY - bounds.minY))
            context.fill(NSRect(x: bounds.minX, y: rect.minY, width: rect.minX - bounds.minX, height: rect.height))
            context.fill(NSRect(x: rect.maxX, y: rect.minY, width: bounds.width - rect.maxX, height: rect.height))

            // Border
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()

            drawCorners(in: rect)

            // Size label removed — user prefers unobstructed view
        }

        // Draw resize handles on the existing selection (not during drag)
        if let selRect = selectionInView, dragRect == nil, imageCropRect != nil {
            drawHandles(in: selRect, context: context)
        }

        // Hint text
        if imageCropRect == nil && dragRect == nil && image != nil {
            let hints = [
                "拖拽选区 | 拖拽边缘调整 | 双击清除",
                "双指缩放 | 双指滑动平移 | Option+拖拽平移",
                "缩放: \(String(format: "%.0f", zoomScale * 100))% | 旋转: \(Int(rotationAngle))°"
            ]
            var y = bounds.maxY - 18
            for hint in hints {
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.white.withAlphaComponent(0.45),
                    .font: NSFont.systemFont(ofSize: 10)
                ]
                let astr = NSAttributedString(string: hint, attributes: attrs)
                let size = astr.size()
                astr.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: y))
                y -= size.height + 4
            }
        }
    }

    private func drawCorners(in rect: NSRect) {
        let len: CGFloat = 16
        let corners: [(NSPoint, NSPoint, NSPoint, NSPoint)] = [
            (NSPoint(x: rect.minX, y: rect.maxY), NSPoint(x: rect.minX, y: rect.maxY - len),
             NSPoint(x: rect.minX, y: rect.maxY), NSPoint(x: rect.minX + len, y: rect.maxY)),
            (NSPoint(x: rect.maxX, y: rect.maxY), NSPoint(x: rect.maxX, y: rect.maxY - len),
             NSPoint(x: rect.maxX, y: rect.maxY), NSPoint(x: rect.maxX - len, y: rect.maxY)),
            (NSPoint(x: rect.minX, y: rect.minY), NSPoint(x: rect.minX, y: rect.minY + len),
             NSPoint(x: rect.minX, y: rect.minY), NSPoint(x: rect.minX + len, y: rect.minY)),
            (NSPoint(x: rect.maxX, y: rect.minY), NSPoint(x: rect.maxX, y: rect.minY + len),
             NSPoint(x: rect.maxX, y: rect.minY), NSPoint(x: rect.maxX - len, y: rect.minY)),
        ]
        NSColor.white.setStroke()
        for (vStart, vEnd, hStart, hEnd) in corners {
            let vp = NSBezierPath(); vp.move(to: vStart); vp.line(to: vEnd); vp.lineWidth = 2; vp.stroke()
            let hp = NSBezierPath(); hp.move(to: hStart); hp.line(to: hEnd); hp.lineWidth = 2; hp.stroke()
        }
    }

    private func drawHandles(in rect: NSRect, context: CGContext) {
        let s: CGFloat = 8
        let positions: [NSPoint] = [
            NSPoint(x: rect.minX, y: rect.minY),        // sw
            NSPoint(x: rect.midX, y: rect.minY),         // s
            NSPoint(x: rect.maxX, y: rect.minY),         // se
            NSPoint(x: rect.maxX, y: rect.midY),         // e
            NSPoint(x: rect.maxX, y: rect.maxY),         // ne
            NSPoint(x: rect.midX, y: rect.maxY),         // n
            NSPoint(x: rect.minX, y: rect.maxY),         // nw
            NSPoint(x: rect.minX, y: rect.midY),         // w
        ]
        for p in positions {
            let handleRect = NSRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(handleRect)
            context.setStrokeColor(NSColor.black.cgColor)
            context.stroke(handleRect)
        }
    }

    // MARK: - Coordinate conversions

    /// Base image frame (centered, aspect-fit, BEFORE transforms)
    private func computeBaseImageFrame() -> NSRect {
        guard let img = image else { return .zero }
        let viewW = bounds.width
        let viewH = bounds.height
        let imgRatio = img.size.width / img.size.height
        let viewRatio = viewW / viewH
        if imgRatio > viewRatio {
            let h = viewW / imgRatio
            return NSRect(x: 0, y: (viewH - h) / 2, width: viewW, height: h)
        } else {
            let w = viewH * imgRatio
            return NSRect(x: (viewW - w) / 2, y: 0, width: w, height: viewH)
        }
    }

    /// The image frame AFTER transforms applied (for hit testing)
    private func computeTransformedImageFrame() -> NSRect {
        let base = computeBaseImageFrame()
        let cx = base.midX + panOffset.x
        let cy = base.midY + panOffset.y
        // Apply inverse transform to get the bounding box of the transformed image
        let rad = rotationAngle * .pi / 180.0
        let cosR = abs(cos(rad))
        let sinR = abs(sin(rad))
        let tw = base.width * zoomScale
        let th = base.height * zoomScale
        let bw = tw * cosR + th * sinR
        let bh = tw * sinR + th * cosR
        return NSRect(x: cx - bw / 2, y: cy - bh / 2, width: bw, height: bh)
    }

    /// Convert view coordinates → image pixel coordinates
    private func viewToImageCoords(_ viewPt: NSRect) -> NSRect? {
        guard let img = image else { return nil }
        let base = computeBaseImageFrame()

        // For each corner of the view rect, invert the transform
        func invert(_ p: NSPoint) -> NSPoint {
            let rad = rotationAngle * .pi / 180.0
            let cosR = cos(-rad)
            let sinR = sin(-rad)
            let cx = base.midX + panOffset.x
            let cy = base.midY + panOffset.y
            var x = p.x - cx
            var y = p.y - cy
            let rx = x * cosR - y * sinR
            let ry = x * sinR + y * cosR
            x = rx / zoomScale + base.midX
            y = ry / zoomScale + base.midY
            return NSPoint(x: x, y: y)
        }

        let tl = invert(NSPoint(x: viewPt.minX, y: viewPt.maxY))
        let br = invert(NSPoint(x: viewPt.maxX, y: viewPt.minY))

        let frame = computeBaseImageFrame()
        let scaleX = img.size.width / frame.width
        let scaleY = img.size.height / frame.height
        let x = max(0, (min(tl.x, br.x) - frame.minX) * scaleX)
        let y = max(0, (min(tl.y, br.y) - frame.minY) * scaleY)
        let w = min(abs(br.x - tl.x) * scaleX, img.size.width - x)
        let h = min(abs(br.y - tl.y) * scaleY, img.size.height - y)
        return NSRect(x: x, y: y, width: w, height: h)
    }

    /// Safe version: Convert image pixel coords → view coordinates (nil if no image)
    private func imageToViewCoordsOpt(_ imgRect: NSRect) -> NSRect? {
        guard let img = image else { return nil }
        let base = computeBaseImageFrame()
        let scaleX = base.width / img.size.width
        let scaleY = base.height / img.size.height
        let bx = base.minX + imgRect.minX * scaleX
        let by = base.minY + imgRect.minY * scaleY
        let bw = imgRect.width * scaleX
        let bh = imgRect.height * scaleY
        let rad = rotationAngle * .pi / 180.0
        let cosR = cos(rad), sinR = sin(rad)
        let cx = base.midX + panOffset.x
        let cy = base.midY + panOffset.y
        func t(_ p: NSPoint) -> NSPoint {
            let dx = (p.x - base.midX) * zoomScale
            let dy = (p.y - base.midY) * zoomScale
            return NSPoint(x: cx + dx * cosR - dy * sinR, y: cy + dx * sinR + dy * cosR)
        }
        let tl = t(NSPoint(x: bx, y: by + bh))
        let tr = t(NSPoint(x: bx + bw, y: by + bh))
        let bl = t(NSPoint(x: bx, y: by))
        let br = t(NSPoint(x: bx + bw, y: by))
        return NSRect(
            x: min(tl.x, tr.x, bl.x, br.x),
            y: min(tl.y, tr.y, bl.y, br.y),
            width: max(tl.x, tr.x, bl.x, br.x) - min(tl.x, tr.x, bl.x, br.x),
            height: max(tl.y, tr.y, bl.y, br.y) - min(tl.y, tr.y, bl.y, br.y)
        )
    }

    /// Convert image pixel coords → view coordinates
    private func imageToViewCoords(_ imgRect: NSRect) -> NSRect {
        imageToViewCoordsOpt(imgRect) ?? .zero
    }
}
