import AppKit

@MainActor
final class MenuBarMetricSparklineView: NSView {
    struct RenderedSeries {
        let values: [Double]
        let color: NSColor
    }

    struct RenderCacheKey: Hashable {
        let size: NSSize
        let scale: CGFloat
        let appearanceName: NSAppearance.Name
    }

    let series: [RenderedSeries]
    let kind: MenuBarStatusSegment.Kind
    private(set) var renderCacheKey: RenderCacheKey?
    private(set) var renderedImages = [RenderCacheKey: NSImage]()
    private static let maximumCachedImages = 4

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
    /// of it changes, so the bars and gradients are rasterized once per size/scale/appearance and
    /// later passes only blit the bitmap. Each display's menu bar can use a different appearance,
    /// so images are kept per appearance instead of being replaced: replicant passes that
    /// alternate light/dark must not re-render or invalidate the view. AppKit already marks the
    /// view for display on a real appearance change, so this view deliberately does not override
    /// `viewDidChangeEffectiveAppearance`; setting `needsDisplay` there fed back into another
    /// replicant pass on multi-display setups and kept the main thread redrawing continuously.
    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let appearance = NSAppearance.currentDrawing()
        let key = RenderCacheKey(
            size: bounds.size,
            scale: max(scaleFactor, 2.0),
            appearanceName: appearance.name
        )
        renderCacheKey = key
        if renderedImages[key] == nil {
            if renderedImages.count >= Self.maximumCachedImages {
                renderedImages.removeAll()
            }
            renderedImages[key] = renderImage(for: key, appearance: appearance)
        }

        if let renderedImage = renderedImages[key] {
            renderedImage.draw(in: bounds)
        } else {
            drawContent()
        }
    }

    private func renderImage(for key: RenderCacheKey, appearance: NSAppearance) -> NSImage? {
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
              let context = Self.drawingContext(for: bitmap, pointSize: key.size)
        else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        appearance.performAsCurrentDrawingAppearance {
            drawContent()
        }
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: key.size)
        image.addRepresentation(bitmap)
        return image
    }

    /// The context takes its point-to-pixel scale from the bitmap's size when it is created, so
    /// the size must be set first; otherwise drawing in points fills only the bottom-left quarter.
    private static func drawingContext(for bitmap: NSBitmapImageRep, pointSize: NSSize) -> NSGraphicsContext? {
        bitmap.size = pointSize
        return NSGraphicsContext(bitmapImageRep: bitmap)
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
