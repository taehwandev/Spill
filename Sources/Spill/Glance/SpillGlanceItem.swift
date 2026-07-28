import Foundation

struct SpillGlanceItem: Identifiable, Equatable {
    static let rotationInterval: TimeInterval = 3

    let module: SpillGlanceModule
    let title: String
    let displayValues: [String]
    let rotationEpoch: Date?
    let symbolName: String
    let tint: SpillGlanceTint

    init(
        module: SpillGlanceModule,
        title: String,
        value: String,
        symbolName: String,
        tint: SpillGlanceTint
    ) {
        self.init(
            module: module,
            title: title,
            displayValues: [value],
            rotationEpoch: nil,
            symbolName: symbolName,
            tint: tint
        )
    }

    init(
        module: SpillGlanceModule,
        title: String,
        displayValues: [String],
        rotationEpoch: Date? = nil,
        symbolName: String,
        tint: SpillGlanceTint
    ) {
        self.module = module
        self.title = title
        self.displayValues = displayValues.isEmpty ? ["—"] : displayValues
        self.rotationEpoch = rotationEpoch
        self.symbolName = symbolName
        self.tint = tint
    }

    var id: SpillGlanceModule {
        module
    }

    var value: String {
        displayValues[0]
    }

    func displayValue(
        at date: Date,
        interval: TimeInterval = rotationInterval
    ) -> String {
        guard displayValues.count > 1,
              interval > 0,
              let rotationEpoch
        else {
            return value
        }

        let elapsed = max(0, date.timeIntervalSince(rotationEpoch))
        let tick = Int(elapsed / interval)
        return displayValues[tick % displayValues.count]
    }
}
