struct SpillGlancePresentation: Equatable {
    let isVisible: Bool
    let items: [SpillGlanceItem]

    static let hidden = SpillGlancePresentation(isVisible: false, items: [])
}
