import Carbon.HIToolbox
import Foundation

enum WindowActionShortcutKey: String, CaseIterable, Identifiable, Sendable {
    case off
    case leftArrow
    case rightArrow
    case upArrow
    case downArrow
    case c
    case d
    case m
    case r
    case returnKey
    case one
    case two
    case three
    case four
    case five
    case six

    var id: String {
        rawValue
    }

    var keyCode: UInt32? {
        switch self {
        case .off:
            return nil
        case .leftArrow:
            return UInt32(kVK_LeftArrow)
        case .rightArrow:
            return UInt32(kVK_RightArrow)
        case .upArrow:
            return UInt32(kVK_UpArrow)
        case .downArrow:
            return UInt32(kVK_DownArrow)
        case .c:
            return UInt32(kVK_ANSI_C)
        case .d:
            return UInt32(kVK_ANSI_D)
        case .m:
            return UInt32(kVK_ANSI_M)
        case .r:
            return UInt32(kVK_ANSI_R)
        case .returnKey:
            return UInt32(kVK_Return)
        case .one:
            return UInt32(kVK_ANSI_1)
        case .two:
            return UInt32(kVK_ANSI_2)
        case .three:
            return UInt32(kVK_ANSI_3)
        case .four:
            return UInt32(kVK_ANSI_4)
        case .five:
            return UInt32(kVK_ANSI_5)
        case .six:
            return UInt32(kVK_ANSI_6)
        }
    }

    var shortcutLabel: String {
        switch self {
        case .off:
            return "Off"
        case .leftArrow:
            return "⌃⌥←"
        case .rightArrow:
            return "⌃⌥→"
        case .upArrow:
            return "⌃⌥↑"
        case .downArrow:
            return "⌃⌥↓"
        case .c:
            return "⌃⌥C"
        case .d:
            return "⌃⌥D"
        case .m:
            return "⌃⌥M"
        case .r:
            return "⌃⌥R"
        case .returnKey:
            return "⌃⌥↩"
        case .one:
            return "⌃⌥1"
        case .two:
            return "⌃⌥2"
        case .three:
            return "⌃⌥3"
        case .four:
            return "⌃⌥4"
        case .five:
            return "⌃⌥5"
        case .six:
            return "⌃⌥6"
        }
    }

    var pickerTitle: String {
        shortcutLabel
    }
}

extension WindowActionKind {
    var defaultShortcutKey: WindowActionShortcutKey {
        switch self {
        case .leftHalf:
            return .leftArrow
        case .rightHalf:
            return .rightArrow
        case .center:
            return .c
        case .maximize:
            return .returnKey
        case .nextDisplay:
            return .d
        case .restore:
            return .r
        }
    }

    static var defaultShortcutKeys: [WindowActionKind: WindowActionShortcutKey] {
        Dictionary(uniqueKeysWithValues: panelOrder.map { ($0, $0.defaultShortcutKey) })
    }

    var hotKeyID: UInt32 {
        switch self {
        case .leftHalf:
            return 10
        case .rightHalf:
            return 11
        case .center:
            return 12
        case .maximize:
            return 13
        case .nextDisplay:
            return 14
        case .restore:
            return 15
        }
    }
}
