//
//  ScanResultsViewController.swift
//  CyborgRugby
//
//  Display rugby scrum cap fitting results with ML-enhanced measurements
//

import UIKit
import OSLog

class ScanResultsViewController: UIViewController {
    
    // MARK: - UI Components
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentStackView: UIStackView!
    
    @IBOutlet weak var overallQualityView: UIView!
    @IBOutlet weak var qualityLabel: UILabel!
    @IBOutlet weak var confidenceLabel: UILabel!
    @IBOutlet weak var qualityProgressView: UIProgressView!
    
    @IBOutlet weak var measurementsTableView: UITableView!
    @IBOutlet weak var earProtectionView: UIView!
    @IBOutlet weak var recommendationsTableView: UITableView!
    
    @IBOutlet weak var scrumCapSizeLabel: UILabel!
    @IBOutlet weak var headShapeLabel: UILabel!
    @IBOutlet weak var asymmetryLabel: UILabel!
    
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var proceedButton: UIButton!
    
    // MARK: - Data
    
    var scanResult: CompleteScanResult!
    var protectionAnalysis: EarProtectionAnalysis!
    
    private let rugbyEarAnalyzer = RugbyEarProtectionCalculator()
    private var measurementItems: [MeasurementDisplayItem] = []
    private var recommendationItems: [RecommendationDisplayItem] = []
    private var summaryCardsStack: UIStackView?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Scrum Cap Fitting Results"
        setupUI()
        processResults()
        displayResults()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure navigation
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareResults)
        )
        
        // Style overall quality view
        overallQualityView.layer.cornerRadius = 12
        overallQualityView.layer.shadowColor = UIColor.black.cgColor
        overallQualityView.layer.shadowOffset = CGSize(width: 0, height: 2)
        overallQualityView.layer.shadowRadius = 4
        overallQualityView.layer.shadowOpacity = 0.1
        
        // Configure table views
        measurementsTableView.delegate = self
        measurementsTableView.dataSource = self
        measurementsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "MeasurementCell")
        
        recommendationsTableView.delegate = self
        recommendationsTableView.dataSource = self
        recommendationsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "RecommendationCell")
        
        // Dynamic Type for key labels
        qualityLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        qualityLabel.adjustsFontForContentSizeCategory = true
        confidenceLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        confidenceLabel.adjustsFontForContentSizeCategory = true
        scrumCapSizeLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        scrumCapSizeLabel.adjustsFontForContentSizeCategory = true
        headShapeLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        headShapeLabel.adjustsFontForContentSizeCategory = true
        asymmetryLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        asymmetryLabel.adjustsFontForContentSizeCategory = true

        // Style buttons
        styleButtons()

        // Insert summary cards container below overall quality view
        if summaryCardsStack == nil {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.isLayoutMarginsRelativeArrangement = true
            stack.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            summaryCardsStack = stack
            contentStackView.insertArrangedSubview(stack, at: 1) // just after overall quality
        }
    }
    
    private func styleButtons() {
        if #available(iOS 15.0, *) {
            var exportCfg = UIButton.Configuration.tinted()
            exportCfg.title = "Export"
            exportCfg.image = UIImage(systemName: "square.and.arrow.up")
            exportCfg.imagePadding = 6
            exportCfg.cornerStyle = .medium
            exportButton.configuration = exportCfg

            var retryCfg = UIButton.Configuration.tinted()
            retryCfg.title = "Retry"
            retryCfg.image = UIImage(systemName: "arrow.counterclockwise")
            retryCfg.imagePadding = 6
            retryCfg.cornerStyle = .medium
            retryButton.configuration = retryCfg

            var proceedCfg = UIButton.Configuration.filled()
            proceedCfg.title = "Proceed"
            proceedCfg.image = UIImage(systemName: "checkmark.circle.fill")
            proceedCfg.baseBackgroundColor = .systemGreen
            proceedCfg.imagePadding = 6
            proceedCfg.cornerStyle = .large
            proceedButton.configuration = proceedCfg
        } else {
            styleLegacyButton(exportButton, color: .systemBlue)
            styleLegacyButton(retryButton, color: .systemOrange)
            styleLegacyButton(proceedButton, color: .systemGreen)
        }
        exportButton.accessibilityIdentifier = "results.export"
        retryButton.accessibilityIdentifier = "results.retry"
        proceedButton.accessibilityIdentifier = "results.proceed"
    }

    private func styleLegacyButton(_ button: UIButton, color: UIColor) {
        button.layer.cornerRadius = 8
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    }
    
    // MARK: - Data Processing
    
    private func processResults() {
        // Generate protection analysis
        protectionAnalysis = rugbyEarAnalyzer.calculateEarProtection(from: scanResult.rugbyFitnessMeasurements)
        
        // Prepare measurement display items
        prepareMeasurementItems()
        
        // Prepare recommendation items
        prepareRecommendationItems()
    }
    
    private func prepareMeasurementItems() {
        let measurements = scanResult.rugbyFitnessMeasurements
        var items: [MeasurementDisplayItem] = []

        // Add simple real metrics from captured point clouds (if available)
        if let overall = PointCloudMetricsCalculator.aggregate(from: scanResult.individualScans) {
            items.append(MeasurementDisplayItem(
                title: "Point Count (All Poses)",
                value: "\(overall.totalPoints)",
                confidence: 1.0,
                status: .validated
            ))
            items.append(MeasurementDisplayItem(
                title: "BBox Width (mm)",
                value: String(format: "%.1f", overall.width * 1000.0),
                confidence: 1.0,
                status: .validated
            ))
            items.append(MeasurementDisplayItem(
                title: "BBox Height (mm)",
                value: String(format: "%.1f", overall.height * 1000.0),
                confidence: 1.0,
                status: .validated
            ))
            items.append(MeasurementDisplayItem(
                title: "BBox Depth (mm)",
                value: String(format: "%.1f", overall.depth * 1000.0),
                confidence: 1.0,
                status: .validated
            ))

            // Per‑pose metrics (points and bbox in mm) for poses that have clouds
            for pose in HeadScanningPose.allCases {
                if let result = scanResult.individualScans[pose], let cloud = result.pointCloud,
                   let pm = PointCloudMetricsCalculator.compute(for: cloud) {
                    items.append(MeasurementDisplayItem(
                        title: "Pose \(pose.displayName) Points",
                        value: "\(pm.totalPoints)",
                        confidence: 1.0,
                        status: .validated
                    ))
                    items.append(MeasurementDisplayItem(
                        title: "Pose \(pose.displayName) BBox (mm)",
                        value: String(format: "%.1f × %.1f × %.1f",
                                       pm.width * 1000.0,
                                       pm.height * 1000.0,
                                       pm.depth * 1000.0),
                        confidence: 1.0,
                        status: .validated
                    ))
                }
            }
        }

        items.append(contentsOf: [
            MeasurementDisplayItem(
                title: "Head Circumference",
                value: "\(String(format: "%.1f", measurements.headCircumference.value))cm",
                confidence: measurements.headCircumference.confidence,
                status: measurements.headCircumference.validationStatus
            ),
            MeasurementDisplayItem(
                title: "Ear to Ear (Over Top)",
                value: "\(String(format: "%.1f", measurements.earToEarOverTop.value))cm",
                confidence: measurements.earToEarOverTop.confidence,
                status: measurements.earToEarOverTop.validationStatus
            ),
            MeasurementDisplayItem(
                title: "Left Ear Height",
                value: "\(String(format: "%.1f", measurements.leftEarDimensions.height.value))mm",
                confidence: measurements.leftEarDimensions.height.confidence,
                status: measurements.leftEarDimensions.height.validationStatus
            ),
            MeasurementDisplayItem(
                title: "Right Ear Height", 
                value: "\(String(format: "%.1f", measurements.rightEarDimensions.height.value))mm",
                confidence: measurements.rightEarDimensions.height.confidence,
                status: measurements.rightEarDimensions.height.validationStatus
            ),
            MeasurementDisplayItem(
                title: "Back Head Prominence",
                value: "\(String(format: "%.1f", measurements.occipitalProminence.value))mm",
                confidence: measurements.occipitalProminence.confidence,
                status: measurements.occipitalProminence.validationStatus
            )
        ])

        measurementItems = items
    }
    
    private func prepareRecommendationItems() {
        recommendationItems = []
        
        // Add protection recommendations
        recommendationItems.append(RecommendationDisplayItem(
            title: "Scrum Cap Type",
            description: protectionAnalysis.recommendedScrumCapType.description,
            priority: .high,
            category: .protection
        ))
        
        // Add risk level info
        recommendationItems.append(RecommendationDisplayItem(
            title: "Rugby Risk Level",
            description: protectionAnalysis.overallRisk.description,
            priority: priorityFromRiskLevel(protectionAnalysis.overallRisk),
            category: .risk
        ))
        
        // Add customization needs
        if protectionAnalysis.customizationNeeded.hasCustomization {
            for requirement in protectionAnalysis.customizationNeeded.requirements {
                recommendationItems.append(RecommendationDisplayItem(
                    title: "Customization Required",
                    description: requirement.description,
                    priority: .medium,
                    category: .customization
                ))
            }
        }
        
        // Add specific ear recommendations
        for recommendation in protectionAnalysis.leftEar.specificRecommendations {
            recommendationItems.append(RecommendationDisplayItem(
                title: "Left Ear - \(recommendation.category)",
                description: recommendation.description,
                priority: displayPriorityFromRecommendation(recommendation.priority),
                category: .specific
            ))
        }
        
        for recommendation in protectionAnalysis.rightEar.specificRecommendations {
            recommendationItems.append(RecommendationDisplayItem(
                title: "Right Ear - \(recommendation.category)",
                description: recommendation.description,
                priority: displayPriorityFromRecommendation(recommendation.priority),
                category: .specific
            ))
        }
    }
    
    // MARK: - Display Results
    
    private func displayResults() {
        // Overall quality
        qualityLabel.text = scanResult.qualityDescription
        confidenceLabel.text = "\(String(format: "%.0f", scanResult.overallQuality * 100))% Confidence"
        qualityProgressView.progress = scanResult.overallQuality
        qualityProgressView.tintColor = colorForQuality(scanResult.overallQuality)
        
        // Basic measurements
        let measurements = scanResult.rugbyFitnessMeasurements
        scrumCapSizeLabel.text = "Size: \(measurements.recommendedSize.rawValue)"
        headShapeLabel.text = "Shape: \(measurements.headShapeClassification.description)"
        
        let asymmetryText = measurements.asymmetryLevel.description
        asymmetryLabel.text = "Asymmetry: \(asymmetryText)"
        asymmetryLabel.textColor = colorForAsymmetry(measurements.earAsymmetryFactor)
        
        // Update ear protection view
        displayEarProtectionSummary()
        
        // Reload table views
        measurementsTableView.reloadData()
        recommendationsTableView.reloadData()

        // Build summary cards
        buildSummaryCards()

        // Configure buttons based on results
        configureActionButtons()
    }

    private func buildSummaryCards() {
        guard let stack = summaryCardsStack else { return }
        stack.arrangedSubviews.forEach { v in stack.removeArrangedSubview(v); v.removeFromSuperview() }
        let m = scanResult.rugbyFitnessMeasurements
        let cards: [MeasurementCardView] = [
            MeasurementCardView(
                icon: UIImage(systemName: "ruler"),
                title: "Head Circumference",
                value: String(format: "%.1f cm", m.headCircumference.value),
                subtitle: "Around widest part of head"
            ),
            MeasurementCardView(
                icon: UIImage(systemName: "arrow.left.and.right"),
                title: "Back Width",
                value: String(format: "%.0f mm", m.backHeadWidth.value),
                subtitle: "Back-of-head width"
            ),
            MeasurementCardView(
                icon: UIImage(systemName: "arrow.up.and.down"),
                title: "Occipital",
                value: String(format: "%.0f mm", m.occipitalProminence.value),
                subtitle: "Bump prominence"
            ),
            MeasurementCardView(
                icon: UIImage(systemName: "tshirt"),
                title: "Recommended Size",
                value: m.recommendedSize.rawValue,
                subtitle: nil
            )
        ]
        cards.forEach { card in
            card.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(card)
        }
    }
    
    private func displayEarProtectionSummary() {
        // Add protection effectiveness labels to ear protection view
        let leftLabel = UILabel()
        leftLabel.text = "Left Ear: \(String(format: "%.0f", protectionAnalysis.protectionEffectiveness.leftEar * 100))% Effective"
        leftLabel.font = UIFont.systemFont(ofSize: 14)
        leftLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let rightLabel = UILabel()
        rightLabel.text = "Right Ear: \(String(format: "%.0f", protectionAnalysis.protectionEffectiveness.rightEar * 100))% Effective"
        rightLabel.font = UIFont.systemFont(ofSize: 14)
        rightLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let overallLabel = UILabel()
        overallLabel.text = protectionAnalysis.protectionEffectiveness.overallDescription
        overallLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        overallLabel.textAlignment = .center
        overallLabel.translatesAutoresizingMaskIntoConstraints = false
        
        earProtectionView.addSubview(leftLabel)
        earProtectionView.addSubview(rightLabel)
        earProtectionView.addSubview(overallLabel)
        
        NSLayoutConstraint.activate([
            overallLabel.topAnchor.constraint(equalTo: earProtectionView.topAnchor, constant: 16),
            overallLabel.centerXAnchor.constraint(equalTo: earProtectionView.centerXAnchor),
            
            leftLabel.topAnchor.constraint(equalTo: overallLabel.bottomAnchor, constant: 16),
            leftLabel.leadingAnchor.constraint(equalTo: earProtectionView.leadingAnchor, constant: 16),
            
            rightLabel.topAnchor.constraint(equalTo: overallLabel.bottomAnchor, constant: 16),
            rightLabel.trailingAnchor.constraint(equalTo: earProtectionView.trailingAnchor, constant: -16),
            
            leftLabel.bottomAnchor.constraint(equalTo: earProtectionView.bottomAnchor, constant: -16),
            rightLabel.bottomAnchor.constraint(equalTo: earProtectionView.bottomAnchor, constant: -16)
        ])
    }
    
    private func configureActionButtons() {
        // Enable/disable buttons based on result quality
        let isHighQuality = scanResult.overallQuality > 0.7
        
        proceedButton.isEnabled = isHighQuality
        proceedButton.alpha = isHighQuality ? 1.0 : 0.6
        
        if !isHighQuality {
            proceedButton.setTitle("Improve Scan Quality First", for: .normal)
        }
    }
    
    // MARK: - Actions
    
    @IBAction func exportResults(_ sender: UIButton) {
        let activityVC = UIActivityViewController(
            activityItems: [generateExportString()],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    @IBAction func retryScanning(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Retry Scanning",
            message: "This will start a new scanning session. Current results will be lost.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Retry", style: .destructive) { _ in
            self.navigationController?.popToRootViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    @IBAction func proceedToOrdering(_ sender: UIButton) {
        // In production, this would proceed to ordering flow
        let alert = UIAlertController(
            title: "Ready to Order",
            message: "Your measurements are ready for scrum cap ordering. This would proceed to the ordering system.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func shareResults() {
        exportResults(exportButton)
    }
    
    // MARK: - Helper Methods
    
    private func colorForQuality(_ quality: Float) -> UIColor {
        switch quality {
        case 0.8...: return .systemGreen
        case 0.6..<0.8: return .systemYellow
        default: return .systemRed
        }
    }
    
    private func colorForAsymmetry(_ factor: Float) -> UIColor {
        switch factor {
        case 0.0..<0.1: return .systemGreen
        case 0.1..<0.3: return .systemYellow
        default: return .systemOrange
        }
    }
    
    private func priorityFromRiskLevel(_ riskLevel: RugbyRiskLevel) -> DisplayPriority {
        switch riskLevel {
        case .minimal, .low: return .low
        case .medium: return .medium
        case .high, .veryHigh: return .high
        }
    }
    
    private func displayPriorityFromRecommendation(_ priority: SpecificRecommendation.RecommendationPriority) -> DisplayPriority {
        switch priority {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
    
    private func generateExportString() -> String {
        var export = "CyborgRugby Scrum Cap Fitting Results\n"
        export += "Generated: \(DateFormatter.localizedString(from: scanResult.timestamp, dateStyle: .medium, timeStyle: .short))\n\n"
        
        export += "Overall Quality: \(scanResult.qualityDescription)\n"
        export += "Confidence: \(String(format: "%.0f", scanResult.overallQuality * 100))%\n\n"
        
        // Fused output files (if available)
        if let saved = ResultsPersistence.load() {
            if let fusedPts = saved.fusedPointCloudPLY {
                export += "Fused Point Cloud: \(fusedPts)\n"
            }
            if let fusedMesh = saved.fusedMeshPLY {
                export += "Fused Mesh: \(fusedMesh)\n"
            }
            export += "\n"
        }
        
        export += "Measurements:\n"
        for item in measurementItems {
            export += "- \(item.title): \(item.value) (\(item.status.description))\n"
        }
        
        export += "\nRecommendations:\n"
        for item in recommendationItems {
            export += "- \(item.title): \(item.description)\n"
        }
        
        return export
    }
}

// MARK: - Table View Data Source & Delegate

extension ScanResultsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == measurementsTableView {
            return measurementItems.count
        } else {
            return recommendationItems.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == measurementsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MeasurementCell", for: indexPath)
            let item = measurementItems[indexPath.row]
            
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = item.value
            cell.accessoryType = accessoryForConfidence(item.confidence)
            cell.backgroundColor = backgroundColorForStatus(item.status)
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RecommendationCell", for: indexPath)
            let item = recommendationItems[indexPath.row]
            
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = item.description
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.numberOfLines = 0
            cell.backgroundColor = backgroundColorForPriority(item.priority)
            
            return cell
        }
    }
    
    private func accessoryForConfidence(_ confidence: Float) -> UITableViewCell.AccessoryType {
        return confidence > 0.8 ? .checkmark : .none
    }
    
    private func backgroundColorForStatus(_ status: ValidatedMeasurement.ValidationStatus) -> UIColor {
        switch status {
        case .validated: return UIColor.systemGreen.withAlphaComponent(0.1)
        case .estimated: return UIColor.systemYellow.withAlphaComponent(0.1)
        case .interpolated: return UIColor.systemOrange.withAlphaComponent(0.1)
        case .failed: return UIColor.systemRed.withAlphaComponent(0.1)
        }
    }
    
    private func backgroundColorForPriority(_ priority: DisplayPriority) -> UIColor {
        switch priority {
        case .low: return UIColor.clear
        case .medium: return UIColor.systemYellow.withAlphaComponent(0.1)
        case .high: return UIColor.systemOrange.withAlphaComponent(0.1)
        }
    }
}

// MARK: - Display Models

struct MeasurementDisplayItem {
    let title: String
    let value: String
    let confidence: Float
    let status: ValidatedMeasurement.ValidationStatus
}

struct RecommendationDisplayItem {
    let title: String
    let description: String
    let priority: DisplayPriority
    let category: RecommendationCategory
    
    enum RecommendationCategory {
        case protection, risk, customization, specific
    }
}

enum DisplayPriority {
    case low, medium, high
}
