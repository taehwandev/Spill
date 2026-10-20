import AppKit

@MainActor
final class MenuBarMetricSparklineView: NSView {
    struct RenderedSeries {
        let values: [Double]
        let color: NSColor
    }

    struct RenderCacheKey: Equatable {
        let size: NSSize
        let scale: CGFloat
        let appearanceName: NSAppearance.Name
    }

    let series: [RenderedSeries]
    let kind: MenuBarStatusSegment.Kind
    private(set) var renderCacheKey: RenderCacheKey?
    private var renderedImage: NSImage?

    var scaleFactor: CGFloat {
        return window?.backingScaleFactor ?? 2.0
    }

    init(series: [MenuBarStatusSegment.GraphSeries], kind: MenuBarStatusSegment.Kind, statusColor: NSColor) {
        self.kind = kind
        let finiteSeries = series.map { graphSeries in
            (
                role: graphSeries.role,
                values: graphSeries.values.filter(\.isFinite).map { max($0, 0) }
            )
        }
        let relativePeak = finiteSeries
            .filter { $0.role != .status }
            .flatMap { $0.values }
            .max() ?? 0

        self.series = finiteSeries.map {
            RenderedSeries(
                values: Self.normalizedValues(
                    $0.values,
                    role: $0.role,
                    relativePeak: relativePeak
                ),
                color: Self.color(for: $0.role, statusColor: statusColor)
            )
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The status bar re-renders the whole item into a replicant per display whenever any part
    /// of it changes (including every trigger animation frame), so the bars and gradients are
    /// rasterized once per size/scale/appearance and later passes only blit the bitmap.
    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let key = RenderCacheKey(
            size: bounds.size,
            scale: max(scaleFactor, 2.0),
            appearanceName: effectiveAppearance.name
        )
        if renderCacheKey != key || renderedImage == nil {
            renderedImage = renderImage(for: key)
            renderCacheKey = key
        }

        if let renderedImage {
            renderedImage.draw(in: bounds)
        } else {
            drawContent()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        renderedImage = nil
        renderCacheKey = nil
        needsDisplay = true
    }

    private func renderImage(for key: RenderCacheKey) -> NSImage? {
        let pixelsWide = Int((key.size.width * key.scale).rounded(.up))
        let pixelsHigh = Int((key.size.height * key.scale).rounded(.up))
        guard pixelsWide > 0, pixelsHigh > 0,
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: pixelsWide,
                  pixelsHigh: pixelsHigh,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              ),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            return nil
        }
        bitmap.size = key.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        effectiveAppearance.performAsCurrentDrawingAppearance {
            drawContent()
        }
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: key.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func drawContent() {
        drawFrame()

        switch kind {
        case .cpu:
            drawCPUCores()
        case .network:
            drawNetworkWaves()
        default:
            drawMemoryWave()
        }
    }
}
