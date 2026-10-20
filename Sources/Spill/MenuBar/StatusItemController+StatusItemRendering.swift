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
        // Every status item mutation makes AppKit re-render the item's replicant on each
        // display, so periodic refreshes only touch properties whose values actually changed.
        if item.isVisible != isVisible {
            item.isVisible = isVisible
        }
        guard isVisible, let button = item.button else {
            if item.length != 0 {
                item.length = 0
            }
            removeStatusContentView(&contentView)
            return
        }

        let length = MenuBarStatusContentView.preferredWidth(
            for: segments,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            groupsMainCaffeine: groupsMainCaffeine
        )
        if item.length != length {
            item.length = length
        }
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
        if !segments.isEmpty {
            if rebuildsContentView || contentView == nil {
                clearButtonContent(button)
            }
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
            let accessibilityLabel = statusTooltip.isEmpty ? "Spill" : statusTooltip
            if button.accessibilityLabel() != accessibilityLabel {
                button.setAccessibilityLabel(accessibilityLabel)
            }
            return
        }

        clearButtonContent(button)
        configureIconAppearance(for: button, contentView: &contentView)
    }

    private func clearButtonContent(_ button: NSStatusBarButton) {
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.isBordered = false
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
