import Carbon.HIToolbox
import Foundation

enum WindowActionShortcutModifier: Hashable, Sendable {
    case standard
    case display

    var carbonFlags: UInt32 {
        switch self {
        case .standard:
            return UInt32(controlKey | optionKey)
        case .display:
            return UInt32(controlKey | optionKey | cmdKey)
        }
    }

    var title: String {
        switch self {
        case .standard:
            return "Control + Option"
        case .display:
            return "Control + Option + Command"
        }
    }

    var glyph: String {
        switch self {
        case .standard:
            return "⌃⌥"
        case .display:
            return "⌃⌥⌘"
        }
    }
}

enum WindowActionShortcutKey: String, CaseIterable, Identifiable, Sendable {
    case off
    case leftArrow
    case rightArrow
    case upArrow
    case downArrow
    case c
    case d
    case i
    case j
    case k
    case m
    case r
    case u
    case returnKey
    case deleteKey
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine
    case zero

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
        case .i:
            return UInt32(kVK_ANSI_I)
        case .j:
            return UInt32(kVK_ANSI_J)
        case .k:
            return UInt32(kVK_ANSI_K)
        case .m:
            return UInt32(kVK_ANSI_M)
        case .r:
            return UInt32(kVK_ANSI_R)
        case .u:
            return UInt32(kVK_ANSI_U)
        case .returnKey:
            return UInt32(kVK_Return)
        case .deleteKey:
            return UInt32(kVK_Delete)
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
        case .seven:
            return UInt32(kVK_ANSI_7)
        case .eight:
            return UInt32(kVK_ANSI_8)
        case .nine:
            return UInt32(kVK_ANSI_9)
        case .zero:
            return UInt32(kVK_ANSI_0)
        }
    }

    var shortcutLabel: String {
        shortcutLabel(with: .standard)
    }

    func shortcutLabel(with modifier: WindowActionShortcutModifier) -> String {
        guard self != .off else {
            return keyLabel
        }

        return "\(modifier.glyph)\(keyLabel)"
    }

    var keyLabel: String {
        switch self {
        case .off:
            return "Off"
        case .leftArrow:
            return "←"
        case .rightArrow:
            return "→"
        case .upArrow:
            return "↑"
        case .downArrow:
            return "↓"
        case .c:
            return "C"
        case .d:
            return "D"
        case .i:
            return "I"
        case .j:
            return "J"
        case .k:
            return "K"
        case .m:
            return "M"
        case .r:
            return "R"
        case .u:
            return "U"
        case .returnKey:
            return "↩"
        case .deleteKey:
            return "⌫"
        case .one:
            return "1"
        case .two:
            return "2"
        case .three:
            return "3"
        case .four:
            return "4"
        case .five:
            return "5"
        case .six:
            return "6"
        case .seven:
            return "7"
        case .eight:
            return "8"
        case .nine:
            return "9"
        case .zero:
            return "0"
        }
    }

    var pickerTitle: String {
        keyLabel
    }
}

extension WindowActionKind {
    var defaultShortcutKey: WindowActionShortcutKey {
        switch self {
        case .leftHalf:
            return .leftArrow
        case .rightHalf:
            return .rightArrow
        case .topHalf:
            return .upArrow
        case .bottomHalf:
            return .downArrow
        case .center:
            return .c
        case .maximize:
            return .returnKey
        case .topLeft:
            return .u
        case .topRight:
            return .i
        case .bottomLeft:
            return .j
        case .bottomRight:
            return .k
        case .previousDisplay:
            return .leftArrow
        case .nextDisplay:
            return .rightArrow
        case .restore:
            return .deleteKey
        }
    }

    var shortcutModifier: WindowActionShortcutModifier {
        switch self {
        case .previousDisplay, .nextDisplay:
            return .display
        case .leftHalf,
             .rightHalf,
             .topHalf,
             .bottomHalf,
             .center,
             .maximize,
             .topLeft,
             .topRight,
             .bottomLeft,
             .bottomRight,
             .restore:
            return .standard
        }
    }

    func shortcutLabel(for key: WindowActionShortcutKey) -> String {
        key.shortcutLabel(with: shortcutModifier)
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
        case .topHalf:
            return 14
        case .bottomHalf:
            return 15
        case .topLeft:
            return 16
        case .topRight:
            return 17
        case .bottomLeft:
            return 18
        case .bottomRight:
            return 19
        case .previousDisplay:
            return 20
        case .nextDisplay:
            return 21
        case .restore:
            return 22
        }
    }
}
