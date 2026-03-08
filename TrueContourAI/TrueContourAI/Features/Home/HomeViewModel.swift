import Foundation

final class HomeViewModel {
    struct ViewState {
        let scans: [ScanService.ScanItem]
        let totalScanCount: Int
        let isEmpty: Bool
        let canViewLast: Bool
        let sortMode: ScanSortMode
        let filterMode: ScanFilterMode
        let trend: HomeTrend?

        var isFilteredEmpty: Bool {
            isEmpty && totalScanCount > 0 && filterMode == .goodPlus
        }
    }

    struct ScanQualityBadge {
        enum Tier {
            case high
            case medium
            case low
        }

        let tier: Tier
    }

    enum ScanSortMode: Int {
        case dateNewest = 0
        case qualityHighest = 1
    }

    enum ScanFilterMode: Int {
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
    var onChange: (() -> Void)?
    private var refreshGeneration: Int = 0

    private(set) var scans: [ScanService.ScanItem] = []
    private(set) var totalScanCount: Int = 0
    private var allScans: [ScanService.ScanItem] = []
    private(set) var isEmpty: Bool = true
    private(set) var canViewLast: Bool = false
    private(set) var insightsByFolderPath: [String: ScanInsight] = [:]
    private var qualityScoreByFolderPath: [String: Float] = [:]
    private var qualityBadgeByFolderPath: [String: ScanQualityBadge] = [:]
    private(set) var trend: HomeTrend?
    private(set) var sortMode: ScanSortMode = .dateNewest
    private(set) var filterMode: ScanFilterMode = .all

    init(scanService: ScanListing) {
        self.scanService = scanService
    }

    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        scanService.listScansAsync { [weak self] items in
            guard let self else { return }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let summaries = self.buildSummaries(for: items)
                let insights = self.buildInsights(for: items, summariesByPath: summaries)
                let qualityScores = self.buildQualityScores(summariesByPath: summaries)
                let qualityBadges = self.buildQualityBadges(summariesByPath: summaries)
                let trend = self.buildTrend(for: items, summariesByPath: summaries)
                DispatchQueue.main.async {
                    guard self.refreshGeneration == generation else { return }
                    self.allScans = items
                    self.insightsByFolderPath = insights
                    self.qualityScoreByFolderPath = qualityScores
                    self.qualityBadgeByFolderPath = qualityBadges
                    self.trend = trend
                    self.applyPresentation()
                    self.canViewLast = self.scanService.resolveLastScanGLTFURL() != nil
                    self.onChange?()
                }
            }
        }
    }

    func updateSortMode(_ newMode: ScanSortMode) {
        guard sortMode != newMode else { return }
        sortMode = newMode
        applyPresentation()
        onChange?()
    }

    func updateFilterMode(_ newMode: ScanFilterMode) {
        guard filterMode != newMode else { return }
        filterMode = newMode
        applyPresentation()
        onChange?()
    }

    func insight(for item: ScanService.ScanItem) -> ScanInsight? {
        insightsByFolderPath[item.folderURL.path]
    }

    func qualityBadge(for item: ScanService.ScanItem) -> ScanQualityBadge? {
        qualityBadgeByFolderPath[item.folderURL.path]
    }

    func makeViewState() -> ViewState {
        .init(
            scans: scans,
            totalScanCount: totalScanCount,
            isEmpty: isEmpty,
            canViewLast: canViewLast,
            sortMode: sortMode,
            filterMode: filterMode,
            trend: trend
        )
    }

    private func buildSummaries(for items: [ScanService.ScanItem]) -> [String: ScanService.ScanSummary] {
        var summaries: [String: ScanService.ScanSummary] = [:]
        summaries.reserveCapacity(items.count)
        for item in items {
            guard let summary = scanService.resolveScanSummary(from: item.folderURL) else { continue }
            summaries[item.folderURL.path] = summary
        }
        return summaries
    }

    private func buildInsights(
        for items: [ScanService.ScanItem],
        summariesByPath: [String: ScanService.ScanSummary]
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
        for items: [ScanService.ScanItem],
        summariesByPath: [String: ScanService.ScanSummary]
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

    private func buildQualityScores(summariesByPath: [String: ScanService.ScanSummary]) -> [String: Float] {
        var scores: [String: Float] = [:]
        scores.reserveCapacity(summariesByPath.count)
        for (path, summary) in summariesByPath {
            scores[path] = min(max(summary.overallConfidence, 0.0), 1.0)
        }
        return scores
    }

    private func buildQualityBadges(summariesByPath: [String: ScanService.ScanSummary]) -> [String: ScanQualityBadge] {
        var badges: [String: ScanQualityBadge] = [:]
        badges.reserveCapacity(summariesByPath.count)
        for (path, summary) in summariesByPath {
            badges[path] = ScanInsightFormatter.makeQualityBadge(from: summary)
        }
        return badges
    }

    private func applyPresentation() {
        totalScanCount = allScans.count
        let filtered: [ScanService.ScanItem]
        switch filterMode {
        case .all:
            filtered = allScans
        case .goodPlus:
            filtered = allScans.filter { item in
                let score = qualityScoreByFolderPath[item.folderURL.path] ?? 0.0
                return score >= 0.8
            }
        }

        switch sortMode {
        case .dateNewest:
            scans = filtered.sorted { $0.date > $1.date }
        case .qualityHighest:
            scans = filtered.sorted { lhs, rhs in
                let lhsScore = qualityScoreByFolderPath[lhs.folderURL.path] ?? -1
                let rhsScore = qualityScoreByFolderPath[rhs.folderURL.path] ?? -1
                if lhsScore == rhsScore {
                    return lhs.date > rhs.date
                }
                return lhsScore > rhsScore
            }
        }
        isEmpty = scans.isEmpty
    }
}

enum ScanInsightFormatter {
    static func makeQualityBadge(from summary: ScanService.ScanSummary) -> HomeViewModel.ScanQualityBadge {
        let confidence = normalizedConfidence(summary.overallConfidence)
        if confidence >= 0.8 {
            return .init(tier: .high)
        } else if confidence >= 0.6 {
            return .init(tier: .medium)
        } else {
            return .init(tier: .low)
        }
    }

    static func makeInsight(from summary: ScanService.ScanSummary) -> HomeViewModel.ScanInsight? {
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
        current: ScanService.ScanSummary,
        previous: ScanService.ScanSummary
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
