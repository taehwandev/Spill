import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarStatusContentViewTests: XCTestCase {
    func testStatusControllerPlacesCaffeineAtLeftEdge() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let cpu = MenuBarStatusSegment(
            kind: .cpu,
            title: "CPU",
            shortTitle: "CPU",
            value: "20.0%",
            displayText: "CPU 20.0%",
            usageRatio: 0.2,
            state: .normal,
            symbolName: "cpu"
        )
        let memory = MenuBarStatusSegment(
            kind: .memory,
            title: "Memory",
            shortTitle: "MEM",
            value: "60.0%",
            displayText: "MEM 60.0%",
            usageRatio: 0.6,
            state: .normal,
            symbolName: "memorychip"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .unavailable,
            symbolName: "cup.and.saucer"
        )

        let segments = StatusItemController.orderedSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu, .memory])
    }

    func testSegmentHitTestingFindsInactiveCaffeineInsideMainChip() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .unavailable,
            symbolName: "cup.and.saucer"
        )
        let cpu = MenuBarStatusSegment(
            kind: .cpu,
            title: "CPU",
            shortTitle: "CPU",
            value: "20.0%",
            displayText: "CPU 20.0%",
            usageRatio: 0.2,
            state: .normal,
            symbolName: "cpu"
        )

        let segments = [caffeine, trigger, cpu]
        let mainWidth = MenuBarStatusContentView.preferredWidth(
            for: [caffeine, trigger],
            groupsMainCaffeine: true
        )

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: 4, y: 10),
                in: segments,
                groupsMainCaffeine: true
            ),
            .trigger
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: mainWidth - 6, y: 10),
                in: segments,
                groupsMainCaffeine: true
            ),
            .caffeine
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: mainWidth + 4, y: 10),
                in: segments,
                groupsMainCaffeine: true
            ),
            .cpu
        )
        XCTAssertNil(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 9_999, y: 10), in: segments)
        )
    }

    func testSegmentHitTestingFindsActiveCaffeineBadgeInsideMainChip() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "15m",
            displayText: "15m",
            usageRatio: 0,
            state: .active,
            symbolName: "cup.and.saucer.fill"
        )
        let segments = [caffeine, trigger]
        let width = MenuBarStatusContentView.preferredWidth(for: segments, groupsMainCaffeine: true)

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: width - 3, y: 18),
                in: segments,
                groupsMainCaffeine: true
            ),
            .caffeine
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: 4, y: 10),
                in: segments,
                groupsMainCaffeine: true
            ),
            .trigger
        )
    }

    func testMainChipShowsCaffeineIconEvenWhenInactive() throws {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .unavailable,
            symbolName: "cup.and.saucer"
        )

        let view = MenuBarStatusContentView(segments: [caffeine, trigger], groupsMainCaffeine: true)
        let chip = try XCTUnwrap(view.subviews.first)

        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSImageView }.count, 2)
        XCTAssertTrue(chip.subviews.compactMap { $0 as? NSTextField }.isEmpty)
    }

    func testInactiveCaffeineInMainChipUsesNormalIconColor() throws {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment()
        let view = MenuBarStatusContentView(segments: [caffeine, trigger], groupsMainCaffeine: true)
        let chip = try XCTUnwrap(view.subviews.first)
        let icons = chip.subviews.compactMap { $0 as? NSImageView }

        XCTAssertEqual(icons.count, 2)
        XCTAssertEqual(icons.last?.contentTintColor, .labelColor)
    }

    func testMainChipAppearanceChangeDoesNotRecreateSymbolImages() throws {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment()
        let view = MenuBarStatusContentView(segments: [caffeine, trigger], groupsMainCaffeine: true)
        let chip = try XCTUnwrap(view.subviews.first)
        let icons = chip.subviews.compactMap { $0 as? NSImageView }
        XCTAssertEqual(icons.count, 2)
        let initialImages = try icons.map { try XCTUnwrap($0.image) }

        chip.viewDidChangeEffectiveAppearance()

        XCTAssertTrue(icons[0].image === initialImages[0])
        XCTAssertTrue(icons[1].image === initialImages[1])
    }

    func testMetricChipAppearanceChangeDoesNotRecreateSymbolImage() throws {
        let cpu = makeStatusSegment(kind: .cpu, value: "20.0%")
        let view = MenuBarStatusContentView(segments: [cpu])
        let chip = try XCTUnwrap(view.subviews.first)
        let icon = try XCTUnwrap(chip.subviews.compactMap { $0 as? NSImageView }.first)
        let initialImage = try XCTUnwrap(icon.image)

        chip.viewDidChangeEffectiveAppearance()

        XCTAssertTrue(icon.image === initialImage)
    }

    func testDefaultLayoutKeepsCaffeineAndTriggerSeparate() throws {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment()
        let view = MenuBarStatusContentView(segments: [caffeine, trigger])

        XCTAssertEqual(view.subviews.count, 2)
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: 4, y: 10), in: [caffeine, trigger]),
            .caffeine
        )
    }

    func testTriggerUsesLargerIconOnlyFootprintThanCaffeine() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let caffeine = MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .unavailable,
            symbolName: "cup.and.saucer"
        )

        XCTAssertGreaterThan(
            MenuBarStatusContentView.preferredWidth(for: [trigger]),
            MenuBarStatusContentView.preferredWidth(for: [caffeine])
        )
    }

    func testStatusChipsDoNotDrawRoundedBackgrounds() {
        let trigger = MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
        let cpu = MenuBarStatusSegment(
            kind: .cpu,
            title: "CPU",
            shortTitle: "CPU",
            value: "20.0%",
            displayText: "CPU 20.0%",
            usageRatio: 0.2,
            state: .normal,
            symbolName: "cpu"
        )

        let view = MenuBarStatusContentView(segments: [trigger, cpu])

        XCTAssertEqual(view.subviews.count, 2)
        view.subviews.forEach { chip in
            XCTAssertFalse(chip.wantsLayer)
            XCTAssertNil(chip.layer?.backgroundColor)
        }
    }

    func testMenuBarTextOptionsAffectWidthAndLabelFont() {
        let cpu = makeStatusSegment(kind: .cpu, value: "34.0%")
        let normalWidth = MenuBarStatusContentView.preferredWidth(
            for: [cpu],
            textFontSize: 11,
            textIsBold: false
        )
        let largerBoldWidth = MenuBarStatusContentView.preferredWidth(
            for: [cpu],
            textFontSize: 15,
            textIsBold: true
        )

        XCTAssertGreaterThan(largerBoldWidth, normalWidth)

        let view = MenuBarStatusContentView(
            segments: [cpu],
            textFontSize: 15,
            textIsBold: true
        )
        let valueLabel = view.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? NSTextField }
            .first

        XCTAssertEqual(valueLabel?.font?.pointSize, 15)
        XCTAssertEqual(valueLabel?.font?.fontDescriptor.symbolicTraits.contains(.bold), true)
    }

    func testVisibleSegmentsKeepAllRequestedSegmentsWhenTheyFit() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "15m", active: true)
        let cpu = makeStatusSegment(kind: .cpu, value: "20.0%")
        let memory = makeStatusSegment(kind: .memory, value: "60.0%")

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: 1_000
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu, .memory])
        XCTAssertEqual(segments.first?.value, "15m")
    }

    func testVisibleSegmentsUseValueOnlyStatusSegmentsWhenActiveStateWouldOverflow() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "1h 59m", active: true)
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")
        let compactSegments = StatusItemController.orderedSegments(
            trigger: trigger,
            statusSegments: [cpu.valueOnlyMenuBarSegment(), memory.valueOnlyMenuBarSegment()],
            caffeineSegment: caffeine.withoutMenuBarValue()
        )
        let compactWidth = MenuBarStatusContentView.preferredWidth(for: compactSegments)

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: compactWidth
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu, .memory])
        XCTAssertEqual(segments.first?.value, "1h 59m")
        XCTAssertEqual(segments.first?.visualStyle, .symbolBadge)
        XCTAssertEqual(segments.suffix(2).map(\.value), ["90.0%", "90.0%"])
        XCTAssertEqual(segments.suffix(2).map(\.visualStyle), [.valueOnly, .valueOnly])
        XCTAssertLessThanOrEqual(MenuBarStatusContentView.preferredWidth(for: segments), compactWidth)
    }

    func testVisibleSegmentsKeepInlineMetricsOnWideScreens() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment()
        let cpu = makeStatusSegment(kind: .cpu, value: "13.7%")
        let memory = makeStatusSegment(kind: .memory, value: "72.9%")
        let requestedSegments = StatusItemController.orderedSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine
        )
        let wideMaximum = StatusItemController.maximumStatusItemLength(
            screenWidth: 1_512,
            isSleepGuardActive: false
        )

        XCTAssertLessThan(MenuBarStatusContentView.preferredWidth(for: requestedSegments), wideMaximum)

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: wideMaximum
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu, .memory])
        XCTAssertEqual(segments.suffix(2).map(\.visualStyle), [.symbol, .symbol])
    }

    func testVisibleSegmentsWithoutCompactFallbackDropsTrailingStatusInsteadOfCompacting() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment()
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: 104,
            usesCompactFallback: false
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger])
        XCTAssertEqual(segments.first?.visualStyle, .symbol)
        XCTAssertEqual(segments.last?.visualStyle, .symbol)
    }

    func testMaximumStatusItemLengthExpandsWithScreenWidth() {
        XCTAssertEqual(
            StatusItemController.maximumStatusItemLength(screenWidth: nil, isSleepGuardActive: false),
            190
        )
        XCTAssertEqual(
            StatusItemController.maximumStatusItemLength(screenWidth: 1_000, isSleepGuardActive: false),
            190
        )
        XCTAssertGreaterThan(
            StatusItemController.maximumStatusItemLength(screenWidth: 1_512, isSleepGuardActive: false),
            190
        )
        XCTAssertLessThanOrEqual(
            StatusItemController.maximumStatusItemLength(screenWidth: 3_456, isSleepGuardActive: false),
            320
        )
    }

    func testVisibleSegmentsKeepMainCaffeineAndCompactStatusWhenNarrow() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "1h 59m", active: true)
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: 86
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger, .cpu])
        XCTAssertEqual(segments.prefix(2).map(\.kind), [.caffeine, .trigger])
        XCTAssertEqual(segments.first?.visualStyle, .symbolBadge)
        XCTAssertEqual(segments.last?.visualStyle, .valueOnly)
        XCTAssertLessThanOrEqual(MenuBarStatusContentView.preferredWidth(for: segments), 86)
    }

    func testVisibleSegmentsKeepCaffeineWhenNoStatusCanFit() {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "1h 59m", active: true)
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")

        let segments = StatusItemController.visibleSegments(
            trigger: trigger,
            statusSegments: [cpu, memory],
            caffeineSegment: caffeine,
            maximumWidth: 64
        )

        XCTAssertEqual(segments.map(\.kind), [.caffeine, .trigger])
        XCTAssertEqual(segments.first?.visualStyle, .symbolBadge)
        XCTAssertLessThanOrEqual(MenuBarStatusContentView.preferredWidth(for: segments), 64)
    }

    func testCompactCpuMemorySegmentsStackIntoNarrowChip() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%").valueOnlyMenuBarSegment()
        let memory = makeStatusSegment(kind: .memory, value: "90.0%").valueOnlyMenuBarSegment()
        let stackedWidth = MenuBarStatusContentView.preferredWidth(for: [cpu, memory])
        let separatedWidth = MenuBarStatusContentView.preferredWidth(for: [cpu])
            + MenuBarStatusContentView.preferredWidth(for: [memory])

        XCTAssertLessThan(stackedWidth, separatedWidth)
        XCTAssertLessThan(stackedWidth, 60)
    }

    func testCompactCpuMemoryStackHitTestingSplitsRows() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%").valueOnlyMenuBarSegment()
        let memory = makeStatusSegment(kind: .memory, value: "90.0%").valueOnlyMenuBarSegment()
        let segments = [cpu, memory]
        let chipCenterX = MenuBarStatusContentView.preferredWidth(for: segments) / 2

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: chipCenterX, y: 17), in: segments),
            .cpu
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(at: NSPoint(x: chipCenterX, y: 5), in: segments),
            .memory
        )
    }

    func testCompactCpuMemoryStackKeepsMetricIconsVisible() throws {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%").valueOnlyMenuBarSegment()
        let memory = makeStatusSegment(kind: .memory, value: "90.0%").valueOnlyMenuBarSegment()
        let view = MenuBarStatusContentView(segments: [cpu, memory])
        let chip = try XCTUnwrap(view.subviews.first)
        let icons = chip.subviews.compactMap { $0 as? NSImageView }
        let labels = chip.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue)

        XCTAssertEqual(icons.count, 2)
        XCTAssertEqual(labels, ["90.0%", "90.0%"])
    }

    func testCompactSingleAITokenKeepsIconOverValue() throws {
        let ai = makeStatusSegment(kind: .ai, value: "1.44M").valueOnlyMenuBarSegment()
        let view = MenuBarStatusContentView(segments: [ai])
        let chip = try XCTUnwrap(view.subviews.first)

        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSImageView }.count, 1)
        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue), ["1.44M"])
    }

    func testCompactAITokenCanStackWithAnotherMetric() throws {
        let memory = makeStatusSegment(kind: .memory, value: "72%").valueOnlyMenuBarSegment()
        let ai = makeStatusSegment(kind: .ai, value: "1.44M").valueOnlyMenuBarSegment()
        let view = MenuBarStatusContentView(segments: [memory, ai])
        let chip = try XCTUnwrap(view.subviews.first)

        XCTAssertEqual(view.subviews.count, 1)
        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSImageView }.count, 2)
        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue), ["72%", "1.44M"])
    }

    func testCompactCaffeineUsesBadgeInsteadOfDroppingRemainingTime() throws {
        let caffeine = makeCaffeineSegment(value: "15m", active: true).badgeMenuBarSegment()
        let view = MenuBarStatusContentView(segments: [caffeine])
        let chip = try XCTUnwrap(view.subviews.first)

        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSImageView }.count, 1)
        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue), ["15"])
        XCTAssertLessThanOrEqual(
            MenuBarStatusContentView.preferredWidth(for: [caffeine]),
            26
        )
    }

    func testCompactCaffeinePreservesClockRemainingTimeBadge() throws {
        let caffeine = makeCaffeineSegment(value: "1:59", active: true).badgeMenuBarSegment()
        let view = MenuBarStatusContentView(segments: [caffeine])
        let chip = try XCTUnwrap(view.subviews.first)

        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSImageView }.count, 1)
        XCTAssertEqual(chip.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue), ["1:59"])
        XCTAssertLessThanOrEqual(
            MenuBarStatusContentView.preferredWidth(for: [caffeine]),
            26
        )
    }

    func testMainCaffeineBadgePreservesClockRemainingTime() throws {
        let trigger = makeTriggerSegment()
        let caffeine = makeCaffeineSegment(value: "1:59", active: true).badgeMenuBarSegment()
        let view = MenuBarStatusContentView(
            segments: [caffeine, trigger],
            groupsMainCaffeine: true
        )
        let chip = try XCTUnwrap(view.subviews.first)
        let label = try XCTUnwrap(chip.subviews.compactMap { $0 as? NSTextField }.first)
        view.frame = NSRect(
            x: 0,
            y: 0,
            width: MenuBarStatusContentView.preferredWidth(
                for: [caffeine, trigger],
                groupsMainCaffeine: true
            ),
            height: 22
        )
        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.subviews.count, 1)
        XCTAssertEqual(label.stringValue, "1:59")
        XCTAssertGreaterThanOrEqual(label.frame.width + 0.5, label.intrinsicContentSize.width)
    }

    func testStackedLayoutRendersTitleOverValueChips() {
        let cpu = makeStatusSegment(kind: .cpu, value: "5%")
        let memory = makeStatusSegment(kind: .memory, value: "20%")
        let view = MenuBarStatusContentView(segments: [cpu, memory], layoutStyle: .stacked)
        let labels = view.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? NSTextField }
            .map(\.stringValue)

        XCTAssertEqual(labels, ["CPU", "5%", "RAM", "20%"])
    }

    func testStackedLayoutRendersAITokenCountVertically() {
        let ai = makeStatusSegment(kind: .ai, value: "1.44M")
        let view = MenuBarStatusContentView(segments: [ai], layoutStyle: .stacked)
        let labels = view.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? NSTextField }
            .map(\.stringValue)

        XCTAssertEqual(labels, ["AI", "1.44M"])
    }

    func testStackedLayoutUsesThemeAdaptiveTitleColor() {
        let cpu = makeStatusSegment(kind: .cpu, value: "5%")
        let memory = makeStatusSegment(kind: .memory, value: "20%")
        let view = MenuBarStatusContentView(segments: [cpu, memory], layoutStyle: .stacked)
        let labels = view.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? NSTextField }

        XCTAssertEqual(labels[0].textColor, .labelColor)
        XCTAssertEqual(labels[2].textColor, .labelColor)
    }

    func testStackedLayoutUsesSeparateMetricHitTargets() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")
        let segments = [cpu, memory]
        let cpuOnlyWidth = MenuBarStatusContentView.preferredWidth(for: [cpu], layoutStyle: .stacked)

        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: 4, y: 17),
                in: segments,
                layoutStyle: .stacked
            ),
            .cpu
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: 4, y: 5),
                in: segments,
                layoutStyle: .stacked
            ),
            .cpu
        )
        XCTAssertEqual(
            MenuBarStatusContentView.segmentKind(
                at: NSPoint(x: cpuOnlyWidth + 4, y: 10),
                in: segments,
                layoutStyle: .stacked
            ),
            .memory
        )
    }

    func testStackedLayoutIsNarrowerThanInlineMetrics() {
        let cpu = makeStatusSegment(kind: .cpu, value: "90.0%")
        let memory = makeStatusSegment(kind: .memory, value: "90.0%")

        XCTAssertLessThan(
            MenuBarStatusContentView.preferredWidth(for: [cpu, memory], layoutStyle: .stacked),
            MenuBarStatusContentView.preferredWidth(for: [cpu, memory], layoutStyle: .inline)
        )
    }

    func testDropTriggerRendersCustomWaterdropGlyph() {
        let image = MenuBarTriggerIconRenderer.image(
            style: .spill,
            size: 18
        )

        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, NSSize(width: 18, height: 18))
    }

    private func makeTriggerSegment() -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: .trigger,
            title: "Spill",
            shortTitle: "Spill",
            value: "",
            displayText: "",
            usageRatio: 0,
            state: .normal,
            symbolName: "drop.fill"
        )
    }

    private func makeCaffeineSegment(value: String = "", active: Bool = false) -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: .caffeine,
            title: "Caffeine",
            shortTitle: "CAF",
            value: value,
            displayText: value,
            usageRatio: 0,
            state: active ? .active : .unavailable,
            symbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer"
        )
    }

    private func makeStatusSegment(
        kind: MenuBarStatusSegment.Kind,
        value: String
    ) -> MenuBarStatusSegment {
        let title: String
        let shortTitle: String
        let symbolName: String

        switch kind {
        case .cpu:
            title = "CPU"
            shortTitle = "CPU"
            symbolName = "cpu"
        case .memory:
            title = "Memory"
            shortTitle = "MEM"
            symbolName = "memorychip"
        case .caffeine:
            title = "Caffeine"
            shortTitle = "CAF"
            symbolName = "cup.and.saucer"
        case .ai:
            title = "AI"
            shortTitle = "AI"
            symbolName = "sparkles"
        case .sleepGuard:
            title = "Sleep Guard"
            shortTitle = "Sleep"
            symbolName = "moon"
        case .trigger:
            title = "Spill"
            shortTitle = "Spill"
            symbolName = "drop.fill"
        }

        return MenuBarStatusSegment(
            kind: kind,
            title: title,
            shortTitle: shortTitle,
            value: value,
            displayText: value,
            usageRatio: 0,
            state: .normal,
            symbolName: symbolName
        )
    }
}
