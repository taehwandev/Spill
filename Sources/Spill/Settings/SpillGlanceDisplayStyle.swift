enum SpillGlanceDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case all
    case ticker

    var id: String { rawValue }

    static func normalized(rawValue: String?) -> SpillGlanceDisplayStyle {
        rawValue.flatMap(Self.init(rawValue:)) ?? .all
    }
}
