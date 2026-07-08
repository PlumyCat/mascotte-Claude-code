import AppKit
import QuartzCore

final class SpriteEngine {
    private let layer: CALayer
    private let columns: Int
    private let rows: Int
    private var currentRow: Int
    private var currentFrameCount: Int
    private var currentFrame: Int = 0
    private var timer: Timer?
    private let fps: Double

    var frameInterval: TimeInterval { 1.0 / fps }

    init(
        layer: CALayer,
        sheetImage: CGImage,
        columns: Int,
        rows: Int,
        initialRow: Int,
        initialFrameCount: Int,
        fps: Double = 10.0
    ) {
        self.layer = layer
        self.columns = columns
        self.rows = rows
        self.currentRow = initialRow
        self.currentFrameCount = max(initialFrameCount, 1)
        self.fps = fps

        layer.contentsScale = 1.0
        layer.contentsGravity = .resize
        // Pixel-art sheet: nearest-neighbor keeps it crisp when the window
        // is scaled up via petScale instead of blurring with linear filtering.
        layer.magnificationFilter = .nearest
        layer.masksToBounds = true
        // The sprite sheet is loaded once as `contents`; only `contentsRect` moves per frame,
        // so implicit CALayer animations must be disabled or frames visibly slide into each other.
        layer.actions = [
            "contents": NSNull(),
            "contentsRect": NSNull(),
            "bounds": NSNull(),
            "position": NSNull()
        ]
        layer.contents = sheetImage

        applyFrame()
        startTimer()
    }

    func setRow(_ row: Int, frameCount: Int) {
        currentRow = row
        currentFrameCount = max(frameCount, 1)
        currentFrame = 0
        applyFrame()
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func advanceFrame() {
        currentFrame = (currentFrame + 1) % currentFrameCount
        applyFrame()
    }

    private func applyFrame() {
        let width = 1.0 / Double(columns)
        let height = 1.0 / Double(rows)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contentsRect = CGRect(
            x: Double(currentFrame) * width,
            y: Double(currentRow) * height,
            width: width,
            height: height
        )
        CATransaction.commit()
    }
}
