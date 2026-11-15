import AppKit

/// Characters for the menu bar trigger: a cat, bunny, or fish drawn as a
/// monochrome template glyph, so AppKit tints it like the SF Symbols around it
/// (white on a dark menu bar, black on a light one). At 13pt only an outline
/// survives, so each character is recognized by its silhouette — the cat by
/// a sitting side profile with pointed ears and a raised tail — and the eyes
/// are holes cut out of the glyph. Motion is a large swing of one body part
/// during a burst, returning to the exact rest pose at phase 0 and 1; the
/// cat instead loops, so its tail is mid-sway at every phase except the ends.
@MainActor
enum MenuBarTriggerIconCharacterRenderer {
    enum Character {
        case cat
        case bunny
        case fish
    }

    static func image(character: Character, phase: CGFloat, size: CGFloat) -> NSImage? {
        guard size.isFinite, size > 0 else {
            return nil
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }
        NSGraphicsContext.current?.shouldAntialias = true

        let canvas = CharacterCanvas(size: size)
        switch character {
        case .cat:
            drawCat(on: canvas, phase: phase)
        case .bunny:
            drawBunny(on: canvas, phase: phase)
        case .fish:
            drawFish(on: canvas, phase: phase)
        }

        image.isTemplate = true
        return image
    }
}

// MARK: - Motion curves

extension MenuBarTriggerIconCharacterRenderer {
    /// 0 at both ends of a burst, 1 in the middle, so every motion eases in
    /// and settles back to the rest pose instead of snapping.
    static func envelope(_ phase: CGFloat) -> CGFloat {
        let clamped = min(max(phase, 0), 1)
        return sin(.pi * clamped)
    }

    /// Two full back-and-forth swings per burst, scaled by the envelope.
    static func swing(_ phase: CGFloat, cycles: CGFloat = 2) -> CGFloat {
        sin(2 * .pi * cycles * phase) * envelope(phase)
    }

    /// A short blink in the middle of the burst.
    static func isBlinking(_ phase: CGFloat) -> Bool {
        phase > 0.52 && phase < 0.60
    }

    /// The cat's tail sways without an envelope because the cat loops
    /// continuously: four whole sways per loop, so the pose at the end of a
    /// loop matches the start and the wrap from 1 back to 0 is seamless.
    static func tailSway(_ phase: CGFloat) -> CGFloat {
        sin(2 * .pi * 4 * phase)
    }

    /// One quick blink per loop, rather than one per tail sway. The window
    /// spans four 1/100 render steps, so even a full-speed loop (about four
    /// steps per frame) lands at least one frame inside it.
    static func isCatBlinking(_ phase: CGFloat) -> Bool {
        phase > 0.60 && phase < 0.645
    }
}

// MARK: - Characters

private extension MenuBarTriggerIconCharacterRenderer {
    /// A cat sitting in profile, facing left: head with two pointed ears,
    /// chest, haunch and front leg, and a long tail that rises behind it and
    /// sways side to side the whole time.
    static func drawCat(on canvas: CharacterCanvas, phase: CGFloat) {
        let base = CGPoint(x: 0.70, y: 0.88)
        // The tail already reaches the right edge at rest, so it sways mostly
        // toward the body: from 0.40 rad inward to 0.04 rad outward.
        let wag = -0.18 + tailSway(phase) * 0.22
        let tail = NSBezierPath()
        tail.move(to: canvas.point(base))
        tail.curve(
            to: canvas.point(rotate(CGPoint(x: 0.86, y: 0.30), around: base, by: wag)),
            controlPoint1: canvas.point(rotate(CGPoint(x: 0.97, y: 0.90), around: base, by: wag)),
            controlPoint2: canvas.point(rotate(CGPoint(x: 0.97, y: 0.50), around: base, by: wag))
        )
        canvas.strokeLimb(tail, width: 0.10)

        canvas.fillSilhouette([
            canvas.oval(center: CGPoint(x: 0.29, y: 0.34), rx: 0.17, ry: 0.15),
            canvas.polygon([CGPoint(x: 0.14, y: 0.31), CGPoint(x: 0.15, y: 0.06), CGPoint(x: 0.28, y: 0.21)]),
            canvas.polygon([CGPoint(x: 0.30, y: 0.20), CGPoint(x: 0.42, y: 0.05), CGPoint(x: 0.44, y: 0.28)]),
            canvas.oval(center: CGPoint(x: 0.39, y: 0.60), rx: 0.16, ry: 0.24),
            canvas.oval(center: CGPoint(x: 0.55, y: 0.73), rx: 0.22, ry: 0.23),
            canvas.polygon([CGPoint(x: 0.27, y: 0.62), CGPoint(x: 0.38, y: 0.62), CGPoint(x: 0.38, y: 0.96), CGPoint(x: 0.27, y: 0.96)]),
        ])
        canvas.cutEyes([CGPoint(x: 0.22, y: 0.33)], radius: 0.035, blinking: isCatBlinking(phase))
    }

    /// A bunny facing front: round body and two long ears; the right ear
    /// flops over once and springs back.
    static func drawBunny(on canvas: CharacterCanvas, phase: CGFloat) {
        let rightBase = CGPoint(x: 0.60, y: 0.50)
        let rightTip = rotate(CGPoint(x: 0.66, y: 0.07), around: rightBase, by: bunnyFlopAngle(phase))
        canvas.fillSilhouette([
            canvas.oval(center: CGPoint(x: 0.50, y: 0.70), rx: 0.34, ry: 0.27),
            earPath(on: canvas, base: CGPoint(x: 0.40, y: 0.50), tip: CGPoint(x: 0.34, y: 0.07), halfWidth: 0.075),
            earPath(on: canvas, base: rightBase, tip: rightTip, halfWidth: 0.075),
        ])
        canvas.cutEyes([CGPoint(x: 0.40, y: 0.68), CGPoint(x: 0.60, y: 0.68)], radius: 0.04, blinking: isBlinking(phase))
    }

    /// A fish in the classic icon shape: oval body, back fin and a big V
    /// tail that swishes while the body bobs.
    static func drawFish(on canvas: CharacterCanvas, phase: CGFloat) {
        let bob = sin(2 * .pi * phase) * envelope(phase) * 0.04
        let center = CGPoint(x: 0.40, y: 0.54 + bob)
        let tailBase = CGPoint(x: 0.68, y: center.y)
        let swish = swing(phase, cycles: 3) * 0.40
        let tail = [
            tailBase,
            CGPoint(x: 0.98, y: center.y - 0.26),
            CGPoint(x: 0.88, y: center.y),
            CGPoint(x: 0.98, y: center.y + 0.26),
        ].map { rotate($0, around: tailBase, by: swish) }

        canvas.fillSilhouette([
            canvas.polygon(tail),
            canvas.polygon([
                CGPoint(x: 0.28, y: center.y - 0.20), CGPoint(x: 0.46, y: center.y - 0.36), CGPoint(x: 0.54, y: center.y - 0.18),
            ]),
            canvas.oval(center: center, rx: 0.35, ry: 0.24),
        ])
        canvas.cutEyes([CGPoint(x: 0.22, y: center.y - 0.04)], radius: 0.045, blinking: isBlinking(phase))
    }
}

// MARK: - Shape helpers

private extension MenuBarTriggerIconCharacterRenderer {
    static func bunnyFlopAngle(_ phase: CGFloat) -> CGFloat {
        guard phase > 0, phase < 1 else { return 0 }
        if phase < 0.72 {
            return envelope(phase / 0.72) * 0.9
        }
        return -envelope((phase - 0.72) / 0.28) * 0.12
    }

    /// A long ear: straight sides from the root and a round cap at the tip.
    static func earPath(on canvas: CharacterCanvas, base: CGPoint, tip: CGPoint, halfWidth r: CGFloat) -> NSBezierPath {
        let length = max(hypot(tip.x - base.x, tip.y - base.y), 0.0001)
        let ux = (tip.x - base.x) / length
        let uy = (tip.y - base.y) / length
        let k: CGFloat = 0.55228475
        let at = { (origin: CGPoint, du: CGFloat, dn: CGFloat) -> NSPoint in
            canvas.point(CGPoint(x: origin.x + ux * du - uy * dn, y: origin.y + uy * du + ux * dn))
        }
        let path = NSBezierPath()
        path.move(to: at(base, 0, r))
        path.line(to: at(tip, 0, r))
        path.curve(to: at(tip, r, 0), controlPoint1: at(tip, k * r, r), controlPoint2: at(tip, r, k * r))
        path.curve(to: at(tip, 0, -r), controlPoint1: at(tip, r, -k * r), controlPoint2: at(tip, k * r, -r))
        path.line(to: at(base, 0, -r))
        path.close()
        // Built counter-clockwise on screen; reverse it to wind like the body
        // so the overlap merges instead of cutting a hole.
        return path.reversed
    }
}
