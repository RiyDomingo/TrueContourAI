import Foundation

enum ScanQualityTier: Equatable {
    case high
    case medium
    case low
}

struct HomeState: Equatable {
    let status: Status
    let viewData: HomeViewData

    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }
}

enum HomeAction {
    case viewDidLoad
    case viewWillAppear
    case sortChanged(HomeViewModel.ScanSortMode)
    case filterChanged(HomeViewModel.ScanFilterMode)
    case clearFilter
    case scansChangedExternally
}

enum HomeEffect: Equatable {
    case refreshDiagnostics
}

struct HomeViewData: Equatable {
    let scanRows: [HomeScanRowViewData]
    let totalScanCount: Int
    let isEmpty: Bool
    let isFilteredEmpty: Bool
    let canViewLast: Bool
    let selectedSortMode: HomeViewModel.ScanSortMode
    let selectedFilterMode: HomeViewModel.ScanFilterMode
    let subtitleText: String
    let trendText: String?
    let trendAccessibilityText: String?
}

struct HomeScanRowViewData: Equatable {
    let folderURL: URL
    let title: String
    let subtitle: String?
    let qualityTier: ScanQualityTier?
    let confidencePercentText: String?
    let thumbnailURL: URL?
    let isOpenEnabled: Bool
}

final class HomeViewModel {
    struct ScanQualityBadge {
        enum Tier {
            case high
            case medium
            case low
        }

        let tier: Tier
    }

    enum ScanSortMode: Int, Equatable {
        case dateNewest = 0
        case qualityHighest = 1
    }

    enum ScanFilterMode: Int, Equatable {
        case all = 0
        case goodPlus = 1
    }

    struct ScanInsight {
        enum Detail {
            case circumferenceMm(Int)
            case pointCount(Int)
        }

        let qualityBadge: ScanQualityBadge
        let confidencePercent: Int
        let detail: Detail
    }

    struct HomeTrend {
        enum Kind {
            case circumferenceIncrease(Int)
            case circumferenceDecrease(Int)
            case confidenceImproved(Int)
            case confidenceDecreased(Int)
            case stable
        }

        let kind: Kind
    }

    private let scanService: ScanListing
    private var refreshGeneration = 0
    private var allScans: [ScanItem] = []
    private var insightsByFolderPath: [String: ScanInsight] = [:]
    private var qualityScoreByFolderPath: [String: Float] = [:]
    private var qualityBadgeByFolderPath: [String: ScanQualityBadge] = [:]
    private var trend: HomeTrend?
    private var sortMode: ScanSortMode = .dateNewest
    private var filterMode: ScanFilterMode = .all
    private var itemsByFolderPath: [String: ScanItem] = [:]

    private(set) var state: HomeState = .init(
        status: .idle,
        viewData: HomeViewData(
            scanRows: [],
            totalScanCount: 0,
            isEmpty: true,
            isFilteredEmpty: false,
            canViewLast: false,
            selectedSortMode: .dateNewest,
            selectedFilterMode: .all,
            subtitleText: L("home.subtitle"),
            trendText: nil,
            trendAccessibilityText: nil
        )
    ) {
        didSet {
            guard oldValue != state else { return }
            emitStateChange()
        }
    }

    var onStateChange: ((HomeState) -> Void)?
    var onEffect: ((HomeEffect) -> Void)?

    init(scanService: ScanListing) {
        self.scanService = scanService
    }

    var scans: [ScanItem] {
        state.viewData.scanRows.compactMap { itemsByFolderPath[$0.folderURL.path] }
    }

    var totalScanCount: Int {
        state.viewData.totalScanCount
    }

    func send(_ action: HomeAction) {
        switch action {
        case .viewDidLoad:
            refresh(status: .loading)
        case .viewWillAppear:
            refresh()
            emitEffect(.refreshDiagnostics)
        case .sortChanged(let newMode):
            guard sortMode != newMode else { return }
            sortMode = newMode
            rebuildLoadedState()
        case .filterChanged(let newMode):
            guard filterMode != newMode else { return }
            filterMode = newMode
            rebuildLoadedState()
        case .clearFilter:
            guard filterMode != .all else { return }
            filterMode = .all
            rebuildLoadedState()
        case .scansChangedExternally:
            refresh()
            emitEffect(.refreshDiagnostics)
        }
    }

    func scanItem(for folderURL: URL) -> ScanItem? {
        itemsByFolderPath[folderURL.path]
    }

    private func refresh(status: HomeState.Status = .loaded) {
        refreshGeneration += 1
        let generation = refreshGeneration
        state = .init(status: status, viewData: state.viewData)
        scanService.listScansAsync { [weak self] items in
            guard let self else { return }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let summaries = self.buildSummaries(for: items)
                let insights = self.buildInsights(for: items, summariesByPath: summaries)
                let qualityScores = self.buildQualityScores(summariesByPath: summaries)
                let qualityBadges = self.buildQualityBadges(summariesByPath: summaries)
                let trend = self.buildTrend(for: items, summariesByPath: summaries)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.refreshGeneration == generation else { return }
                    self.allScans = items
                    self.itemsByFolderPath = Dictionary(uniqueKeysWithValues: items.map { ($0.folderURL.path, $0) })
                    self.insightsByFolderPath = insights
                    self.qualityScoreByFolderPath = qualityScores
                    self.qualityBadgeByFolderPath = qualityBadges
                    self.trend = trend
                    self.rebuildLoadedState()
                }
            }
        }
    }

    private func rebuildLoadedState() {
        let filteredItems: [ScanItem]
        switch filterMode {
        case .all:
            filteredItems = allScans
        case .goodPlus:
            filteredItems = allScans.filter {
                (qualityScoreByFolderPath[$0.folderURL.path] ?? 0.0) >= 0.8
            }
        }

        let sortedItems: [ScanItem]
        switch sortMode {
        case .dateNewest:
            sortedItems = filteredItems.sorted { $0.date > $1.date }
        case .qualityHighest:
            sortedItems = filteredItems.sorted { lhs, rhs in
                let lhsScore = qualityScoreByFolderPath[lhs.folderURL.path] ?? -1
                let rhsScore = qualityScoreByFolderPath[rhs.folderURL.path] ?? -1
                if lhsScore == rhsScore {
                    return lhs.date > rhs.date
                }
                return lhsScore > rhsScore
            }
        }

        let trendDisplay = trend.map(HomeDisplayFormatter.trend)
        let rows = sortedItems.map(makeRowViewData(for:))
        let viewData = HomeViewData(
            scanRows: rows,
            totalScanCount: allScans.count,
            isEmpty: rows.isEmpty,
            isFilteredEmpty: rows.isEmpty && !allScans.isEmpty && filterMode == .goodPlus,
            canViewLast: scanService.resolveLastScanGLTFURL() != nil,
            selectedSortMode: sortMode,
            selectedFilterMode: filterMode,
            subtitleText: L("home.subtitle"),
            trendText: trendDisplay?.compactText,
            trendAccessibilityText: trendDisplay?.accessibilityText
        )
        state = .init(status: .loaded, viewData: viewData)
    }

    private func makeRowViewData(for item: ScanItem) -> HomeScanRowViewData {
        let insight = insightsByFolderPath[item.folderURL.path]
        let badge = qualityBadgeByFolderPath[item.folderURL.path]
        let subtitle = insight.map { HomeDisplayFormatter.insight($0).compactText }
        let confidencePercentText = insight.map { "\($0.confidencePercent)%" }
        return HomeScanRowViewData(
            folderURL: item.folderURL,
            title: item.displayName,
            subtitle: subtitle,
            qualityTier: badge.map(Self.mapTier),
            confidencePercentText: confidencePercentText,
            thumbnailURL: item.thumbnailURL,
            isOpenEnabled: item.sceneGLTFURL != nil
        )
    }

    private static func mapTier(_ tier: ScanQualityBadge) -> ScanQualityTier {
        switch tier.tier {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private func buildSummaries(for items: [ScanItem]) -> [String: ScanSummary] {
        var summaries: [String: ScanSummary] = [:]
        summaries.reserveCapacity(items.count)
        for item in items {
            guard let summary = scanService.resolveScanSummary(from: item.folderURL) else { continue }
            summaries[item.folderURL.path] = summary
        }
        return summaries
    }

    private func buildInsights(
        for items: [ScanItem],
        summariesByPath: [String: ScanSummary]
    ) -> [String: ScanInsight] {
        var insights: [String: ScanInsight] = [:]
        insights.reserveCapacity(items.count)
        for item in items {
            guard let summary = summariesByPath[item.folderURL.path],
                  let insight = ScanInsightFormatter.makeInsight(from: summary) else {
                continue
            }
            insights[item.folderURL.path] = insight
        }
        return insights
    }

    private func buildTrend(
        for items: [ScanItem],
        summariesByPath: [String: ScanSummary]
    ) -> HomeTrend? {
        guard items.count >= 2 else { return nil }
        let newest = items[0]
        let previous = items[1]
        guard let newestSummary = summariesByPath[newest.folderURL.path],
              let previousSummary = summariesByPath[previous.folderURL.path] else {
            return nil
        }
        return ScanInsightFormatter.makeTrend(current: newestSummary, previous: previousSummary)
    }

    private func buildQualityScores(summariesByPath: [String: ScanSummary]) -> [String: Float] {
        var scores: [String: Float] = [:]
        scores.reserveCapacity(summariesByPath.count)
        for (path, summary) in summariesByPath {
            scores[path] = min(max(summary.overallConfidence, 0.0), 1.0)
        }
        return scores
    }

    private func buildQualityBadges(summariesByPath: [String: ScanSummary]) -> [String: ScanQualityBadge] {
        var badges: [String: ScanQualityBadge] = [:]
        badges.reserveCapacity(summariesByPath.count)
        for (path, summary) in summariesByPath {
            badges[path] = ScanInsightFormatter.makeQualityBadge(from: summary)
        }
        return badges
    }

    private func emitStateChange() {
        if Thread.isMainThread {
            onStateChange?(state)
        } else {
            DispatchQueue.main.async { [weak self, state] in
                self?.onStateChange?(state)
            }
        }
    }

    private func emitEffect(_ effect: HomeEffect) {
        if Thread.isMainThread {
            onEffect?(effect)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onEffect?(effect)
            }
        }
    }
}

enum ScanInsightFormatter {
    static func makeQualityBadge(from summary: ScanSummary) -> HomeViewModel.ScanQualityBadge {
        let confidence = normalizedConfidence(summary.overallConfidence)
        if confidence >= 0.8 {
            return .init(tier: .high)
        } else if confidence >= 0.6 {
            return .init(tier: .medium)
        } else {
            return .init(tier: .low)
        }
    }

    static func makeInsight(from summary: ScanSummary) -> HomeViewModel.ScanInsight? {
        let confidence = normalizedConfidence(summary.overallConfidence)
        let confidencePercent = Int((confidence * 100).rounded())
        let detail: HomeViewModel.ScanInsight.Detail

        if let circumference = summary.derivedMeasurements?.circumferenceMm {
            detail = .circumferenceMm(Int(circumference.rounded()))
        } else if summary.pointCountEstimate > 0 {
            detail = .pointCount(summary.pointCountEstimate)
        } else {
            return nil
        }

        return .init(
            qualityBadge: makeQualityBadge(from: summary),
            confidencePercent: confidencePercent,
            detail: detail
        )
    }

    private static func normalizedConfidence(_ value: Float) -> Float {
        min(max(value, 0.0), 1.0)
    }

    static func makeTrend(
        current: ScanSummary,
        previous: ScanSummary
    ) -> HomeViewModel.HomeTrend {
        let confidenceDeltaPercent = Int(((normalizedConfidence(current.overallConfidence) - normalizedConfidence(previous.overallConfidence)) * 100).rounded())

        if let currentCircumference = current.derivedMeasurements?.circumferenceMm,
           let previousCircumference = previous.derivedMeasurements?.circumferenceMm {
            let circumferenceDelta = Int((currentCircumference - previousCircumference).rounded())
            if abs(circumferenceDelta) >= 3 {
                return .init(kind: circumferenceDelta > 0 ? .circumferenceIncrease(abs(circumferenceDelta)) : .circumferenceDecrease(abs(circumferenceDelta)))
            }
        }

        if abs(confidenceDeltaPercent) >= 3 {
            return .init(kind: confidenceDeltaPercent > 0 ? .confidenceImproved(abs(confidenceDeltaPercent)) : .confidenceDecreased(abs(confidenceDeltaPercent)))
        }

        return .init(kind: .stable)
    }
}

enum HomeDisplayFormatter {
    struct ScanQualityBadgeDisplay {
        let tier: HomeViewModel.ScanQualityBadge.Tier
        let text: String
        let accessibilityText: String
    }

    struct ScanInsightDisplay {
        let compactText: String
        let accessibilityText: String
    }

    struct HomeTrendDisplay {
        let compactText: String
        let accessibilityText: String
    }

    static func qualityBadge(_ badge: HomeViewModel.ScanQualityBadge) -> ScanQualityBadgeDisplay {
        let text: String
        switch badge.tier {
        case .high:
            text = L("home.scan.quality.high")
        case .medium:
            text = L("home.scan.quality.medium")
        case .low:
            text = L("home.scan.quality.low")
        }
        return .init(
            tier: badge.tier,
            text: text,
            accessibilityText: String(format: L("home.scan.badge.accessibility"), text)
        )
    }

    static func insight(_ insight: HomeViewModel.ScanInsight) -> ScanInsightDisplay {
        let badgeDisplay = qualityBadge(insight.qualityBadge)
        let detailText: String
        let accessibilityDetail: String

        switch insight.detail {
        case .circumferenceMm(let value):
            detailText = String(format: L("home.scan.insight.circumference"), value)
            accessibilityDetail = String(format: L("home.scan.insight.accessibility.circumference"), value)
        case .pointCount(let count):
            let countText = abbreviatedPointCount(count)
            detailText = String(format: L("home.scan.insight.points"), countText)
            accessibilityDetail = String(format: L("home.scan.insight.accessibility.points"), countText)
        }

        return .init(
            compactText: String(format: L("home.scan.insight.format"), badgeDisplay.text, insight.confidencePercent, detailText),
            accessibilityText: String(format: L("home.scan.insight.accessibility.format"), badgeDisplay.text, insight.confidencePercent, accessibilityDetail)
        )
    }

    static func trend(_ trend: HomeViewModel.HomeTrend) -> HomeTrendDisplay {
        switch trend.kind {
        case .circumferenceIncrease(let value):
            return .init(
                compactText: String(format: L("home.trend.circumference.increase"), value),
                accessibilityText: String(format: L("home.trend.accessibility.circumference"), value)
            )
        case .circumferenceDecrease(let value):
            return .init(
                compactText: String(format: L("home.trend.circumference.decrease"), value),
                accessibilityText: String(format: L("home.trend.accessibility.circumference"), value)
            )
        case .confidenceImproved(let value):
            return .init(
                compactText: String(format: L("home.trend.confidence.improved"), value),
                accessibilityText: String(format: L("home.trend.accessibility.confidence"), value)
            )
        case .confidenceDecreased(let value):
            return .init(
                compactText: String(format: L("home.trend.confidence.decreased"), value),
                accessibilityText: String(format: L("home.trend.accessibility.confidence"), value)
            )
        case .stable:
            return .init(
                compactText: L("home.trend.stable"),
                accessibilityText: L("home.trend.accessibility.stable")
            )
        }
    }

    private static func abbreviatedPointCount(_ count: Int) -> String {
        if count >= 100_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        }
        if count >= 10_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
