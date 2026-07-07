enum SleepGuardMenuBarSegmentFactory {
    static func make(
        isEnabled: Bool,
        isActive: Bool,
        remainingLabel: String,
        showsRemainingInMenuBar: Bool
    ) -> MenuBarStatusSegment? {
        guard isEnabled else {
            return nil
        }

        let displayText = isActive && showsRemainingInMenuBar ? remainingLabel : ""
        let visualStyle: MenuBarStatusSegment.VisualStyle = displayText.isEmpty ? .symbol : .symbolBadge

        return MenuBarStatusSegment(
            kind: .caffeine,
            title: AppL10n.text(.caffeine),
            shortTitle: "CAF",
            value: displayText,
            displayText: displayText,
            usageRatio: 0,
            state: isActive ? .active : .unavailable,
            symbolName: isActive ? "cup.and.saucer.fill" : "cup.and.saucer",
            visualStyle: visualStyle
        )
    }
}
