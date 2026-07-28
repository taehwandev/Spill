import CoreGraphics

enum SpillGlanceDragPhase {
    case changed(CGSize)
    case ended(CGSize)
}
