import AppKit

extension StatusItemController {
    func configureStatusButtons() {
        configureStatusButton(
            triggerItem,
            action: #selector(mainStatusButtonClicked(_:)),
            isVisible: true
        )
        configureStatusButton(
            systemItem,
            action: #selector(systemStatusButtonClicked(_:)),
            isVisible: false
        )
        configureStatusButton(
            aiItem,
            action: #selector(aiStatusButtonClicked(_:)),
            isVisible: false
        )
    }

    func configureStatusButton(
        _ item: NSStatusItem,
        action: Selector,
        isVisible: Bool
    ) {
        item.isVisible = isVisible
        item.length = defaultLength
        guard let button = item.button else {
            return
        }

        button.target = self
        button.action = action
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.isBordered = false
    }
}

extension StatusItemController {
    func applySegments(
        _ segments: [MenuBarStatusSegment],
        to item: NSStatusItem,
        contentView: inout MenuBarStatusContentView?,
        statusTooltip: String,
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool,
        groupsMainCaffeine: Bool,
        isVisible: Bool,
        rebuildsContentView: Bool
    ) {
        item.isVisible = isVisible
        guard isVisible, let button = item.button else {
            item.length = 0
            removeStatusContentView(&contentView)
            return
        }

        item.length = MenuBarStatusContentView.preferredWidth(
            for: segments,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            groupsMainCaffeine: groupsMainCaffeine
        )
        configureAppearance(
            for: button,
            contentView: &contentView,
            segments: segments,
            statusTooltip: statusTooltip,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            groupsMainCaffeine: groupsMainCaffeine,
            rebuildsContentView: rebuildsContentView
        )
    }

    func configureAppearance(
        for button: NSStatusBarButton,
        contentView: inout MenuBarStatusContentView?,
        segments: [MenuBarStatusSegment],
        statusTooltip: String,
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool,
        groupsMainCaffeine: Bool,
        rebuildsContentView: Bool
    ) {
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.isBordered = false

        if !segments.isEmpty {
            installStatusContentView(
                on: button,
                contentView: &contentView,
                segments: segments,
                layoutStyle: layoutStyle,
                textFontSize: textFontSize,
                textIsBold: textIsBold,
                groupsMainCaffeine: groupsMainCaffeine,
                rebuildsContentView: rebuildsContentView
            )
            button.setAccessibilityLabel(statusTooltip.isEmpty ? "Spill" : statusTooltip)
            return
        }

        configureIconAppearance(for: button, contentView: &contentView)
    }

    func configureIconAppearance(
        for button: NSStatusBarButton,
        contentView: inout MenuBarStatusContentView?
    ) {
        removeStatusContentView(&contentView)
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.isBordered = false

        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let triggerIconStyle = settings.menuBarTriggerIconStyle
        if let image = MenuBarTriggerIconRenderer.image(
            style: triggerIconStyle,
            size: 18
        ) {
            button.image = image
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("Spill")
            return
        }

        let symbolName = triggerIconStyle.symbolName(isActive: isSpillBarVisible)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Spill")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("Spill")
            return
        }

        button.image = nil
        button.imagePosition = .noImage
        button.title = "Spill"
        button.attributedTitle = attributedTitle("Spill", fontSize: 12)
        button.setAccessibilityLabel("Spill")
    }
}
