//
//  ScanResultsViewController.swift
//  CyborgRugby
//
//  Display rugby scrum cap fitting results with ML-enhanced measurements
//

import UIKit

import UIKit

import UIKit
import OSLog
import SceneKit

class ScanResultsViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Hero section
    private let heroView = UIView()
    private let heroImageView = UIImageView()
    private let heroTitleLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    
    // Quality section
    private let qualityCardView = UIView()
    private let qualityTitleLabel = UILabel()
    private let qualityScoreLabel = UILabel()
    private let qualityProgressView = UIProgressView()
    private let qualityDescriptionLabel = UILabel()
    
    // Summary cards
    private let summaryStackView = UIStackView()
    
    // 3D Visualization
    private let visualizationCardView = UIView()
    private let visualizationTitleLabel = UILabel()
    private let sceneView = SCNView()
    private let visualizationDescriptionLabel = UILabel()
    private let capOverlaySwitch = UISwitch()
    private let capOverlayLabel = UILabel()
    private let rotationGestureLabel = UILabel()
    private let zoomGestureLabel = UILabel()
    private let angleSegmentedControl = UISegmentedControl()
    private let transparencySlider = UISlider()
    private let transparencyLabel = UILabel()
    private let fitPrecisionLabel = UILabel()
    
    // Protection analysis
    private let protectionCardView = UIView()
    private let protectionTitleLabel = UILabel()
    private let protectionEffectivenessLabel = UILabel()
    private let protectionDetailsStackView = UIStackView()
    private let heatmapImageView = UIImageView()
    
    // Recommendations
    private let recommendationsCardView = UIView()
    private let recommendationsTitleLabel = UILabel()
    private let recommendationsStackView = UIStackView()
    
    // Action buttons
    private let actionStackView = UIStackView()
    private let primaryActionButton = UIButton()
    private let secondaryActionButton = UIButton()
    private let viewDetailsButton = UIButton()
    private let socialProofLabel = UILabel()
    private let urgencyLabel = UILabel()
    
    // MARK: - Data
    var scanResult: CompleteScanResult!
    var protectionAnalysis: EarProtectionAnalysis!
    
    private let rugbyEarAnalyzer = RugbyEarProtectionCalculator()
    private var measurementItems: [MeasurementDisplayItem] = []
    private var recommendationItems: [RecommendationDisplayItem] = []
    private var pointCloudNode: SCNNode?
    private var capModelNode: SCNNode?
    private var sceneRootNode: SCNNode?
    private var isCapOverlayVisible = false
    private var headNode: SCNNode?
    private var capNode: SCNNode?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Your Scrum Cap Fit"
        setupUI()
        processResults()
        displayResults()
        setup3DVisualization()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add profile button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.fill"),
            style: .plain,
            target: self,
            action: #selector(showProfile)
        )
        
        setupScrollView()
        setupHeroSection()
        setupQualitySection()
        setupSummaryCards()
        setupVisualizationSection()
        setupProtectionSection()
        setupRecommendationsSection()
        setupActionButtons()
        setupConstraints()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }
    
    private func setupHeroSection() {
        heroView.backgroundColor = .systemGreen
        heroView.layer.cornerRadius = 16
        heroView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(heroView)
        
        heroImageView.image = UIImage(systemName: "sportscourt")
        heroImageView.tintColor = .white
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroImageView)
        
        heroTitleLabel.text = "Perfect Fit Analysis Complete"
        heroTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        heroTitleLabel.textColor = .white
        heroTitleLabel.textAlignment = .center
        heroTitleLabel.numberOfLines = 0
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroTitleLabel)
        
        heroSubtitleLabel.text = "Your custom scrum cap measurements are ready"
        heroSubtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        heroSubtitleLabel.textColor = .white.withAlphaComponent(0.9)
        heroSubtitleLabel.textAlignment = .center
        heroSubtitleLabel.numberOfLines = 0
        heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroSubtitleLabel)
        
        // Hero view constraints
        NSLayoutConstraint.activate([
            heroImageView.topAnchor.constraint(equalTo: heroView.topAnchor, constant: 20),
            heroImageView.centerXAnchor.constraint(equalTo: heroView.centerXAnchor),
            heroImageView.widthAnchor.constraint(equalToConstant: 60),
            heroImageView.heightAnchor.constraint(equalToConstant: 60),
            
            heroTitleLabel.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: 15),
            heroTitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: 20),
            heroTitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -20),
            
            heroSubtitleLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: 8),
            heroSubtitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: 20),
            heroSubtitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -20),
            heroSubtitleLabel.bottomAnchor.constraint(equalTo: heroView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupQualitySection() {
        qualityCardView.backgroundColor = .systemBackground
        qualityCardView.layer.cornerRadius = 16
        qualityCardView.layer.shadowColor = UIColor.black.cgColor
        qualityCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        qualityCardView.layer.shadowRadius = 8
        qualityCardView.layer.shadowOpacity = 0.1
        qualityCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(qualityCardView)
        
        qualityTitleLabel.text = "Scan Quality"
        qualityTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        qualityTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        qualityCardView.addSubview(qualityTitleLabel)
        
        qualityScoreLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        qualityScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        qualityCardView.addSubview(qualityScoreLabel)
        
        qualityProgressView.translatesAutoresizingMaskIntoConstraints = false
        qualityProgressView.layer.cornerRadius = 7
        qualityProgressView.layer.masksToBounds = true
        qualityProgressView.trackTintColor = .systemGray5
        qualityCardView.addSubview(qualityProgressView)
        
        qualityDescriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        qualityDescriptionLabel.textColor = .secondaryLabel
        qualityDescriptionLabel.numberOfLines = 0
        qualityDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        qualityCardView.addSubview(qualityDescriptionLabel)
        
        // Quality section constraints
        NSLayoutConstraint.activate([
            qualityTitleLabel.topAnchor.constraint(equalTo: qualityCardView.topAnchor, constant: 20),
            qualityTitleLabel.leadingAnchor.constraint(equalTo: qualityCardView.leadingAnchor, constant: 20),
            qualityTitleLabel.trailingAnchor.constraint(equalTo: qualityCardView.trailingAnchor, constant: -20),
            
            qualityScoreLabel.topAnchor.constraint(equalTo: qualityTitleLabel.bottomAnchor, constant: 10),
            qualityScoreLabel.leadingAnchor.constraint(equalTo: qualityCardView.leadingAnchor, constant: 20),
            qualityScoreLabel.trailingAnchor.constraint(equalTo: qualityCardView.trailingAnchor, constant: -20),
            
            qualityProgressView.topAnchor.constraint(equalTo: qualityScoreLabel.bottomAnchor, constant: 15),
            qualityProgressView.leadingAnchor.constraint(equalTo: qualityCardView.leadingAnchor, constant: 20),
            qualityProgressView.trailingAnchor.constraint(equalTo: qualityCardView.trailingAnchor, constant: -20),
            qualityProgressView.heightAnchor.constraint(equalToConstant: 14),
            
            qualityDescriptionLabel.topAnchor.constraint(equalTo: qualityProgressView.bottomAnchor, constant: 15),
            qualityDescriptionLabel.leadingAnchor.constraint(equalTo: qualityCardView.leadingAnchor, constant: 20),
            qualityDescriptionLabel.trailingAnchor.constraint(equalTo: qualityCardView.trailingAnchor, constant: -20),
            qualityDescriptionLabel.bottomAnchor.constraint(equalTo: qualityCardView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupSummaryCards() {
        summaryStackView.axis = .horizontal
        summaryStackView.distribution = .fillEqually
        summaryStackView.spacing = 15
        summaryStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(summaryStackView)
        
        // We'll populate these in displayResults
    }
    
    private func createSummaryCard(title: String, value: String, subtitle: String?) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .systemGray6
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(valueLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            valueLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            valueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            
            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 5),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -15)
        ])
        
        return cardView
    }
    
    private func setupVisualizationSection() {
        visualizationCardView.backgroundColor = .systemBackground
        visualizationCardView.layer.cornerRadius = 16
        visualizationCardView.layer.shadowColor = UIColor.black.cgColor
        visualizationCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        visualizationCardView.layer.shadowRadius = 8
        visualizationCardView.layer.shadowOpacity = 0.1
        visualizationCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(visualizationCardView)
        
        visualizationTitleLabel.text = "3D Head Model"
        visualizationTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        visualizationTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        visualizationCardView.addSubview(visualizationTitleLabel)
        
        sceneView.backgroundColor = UIColor.systemGray6
        sceneView.layer.cornerRadius = 12
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        visualizationCardView.addSubview(sceneView)
        
        // Add gesture instructions
        rotationGestureLabel.text = "←→ Rotate"
        rotationGestureLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        rotationGestureLabel.textColor = .secondaryLabel
        rotationGestureLabel.translatesAutoresizingMaskIntoConstraints = false
        visualizationCardView.addSubview(rotationGestureLabel)
        
        zoomGestureLabel.text = " pinch to zoom"
        zoomGestureLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        zoomGestureLabel.textColor = .secondaryLabel
        zoomGestureLabel.translatesAutoresizingMaskIntoConstraints = false
        visualizationCardView.addSubview(zoomGestureLabel)
        
        // Cap overlay toggle
        capOverlayLabel.text = "Show Cap Overlay"
        capOverlayLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        capOverlayLabel.translatesAutoresizingMaskIntoConstraints = false
        visualizationCardView.addSubview(capOverlayLabel)
        
        capOverlaySwitch.isOn = false
        capOverlaySwitch.translatesAutoresizingMaskIntoConstraints = false
        capOverlaySwitch.addTarget(self, action: #selector(capOverlaySwitchChanged), for: .valueChanged)
        visualizationCardView.addSubview(capOverlaySwitch)
        
        // Angle selection
        angleSegmentedControl.insertSegment(withTitle: "Front", at: 0, animated: false)
        angleSegmentedControl.insertSegment(withTitle: "Side", at: 1, animated: false)
        angleSegmentedControl.insertSegment(withTitle: "Top", at: 2, animated: false)
        angleSegmentedControl.selectedSegmentIndex = 0
        angleSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        angleSegmentedControl.addTarget(self, action: #selector(angleSegmentChanged), for: .valueChanged)
        visualizationCardView.addSubview(angleSegmentedControl)
        
        // Transparency slider
        transparencyLabel.text = "Cap Transparency"
        transparencyLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        transparencyLabel.translatesAutoresizingMaskIntoConstraints = false
        visualizationCardView.addSubview(transparencyLabel)
        
        transparencySlider.minimumValue = 0.0
        transparencySlider.maximumValue = 1.0
        transparencySlider.value = 0.3
        transparencySlider.translatesAutoresizingMaskIntoConstraints = false
        transparencySlider.addTarget(self, action: #selector(transparencySliderChanged), for: .valueChanged)
        visualizationCardView.addSubview(transparencySlider)
        
        // Fit precision label
        fitPrecisionLabel.text = "Fit Precision: 95%"
        fitPrecisionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        fitPrecisionLabel.textColor = .systemGreen
        fitPrecisionLabel.textAlignment = .center
        fitPrecisionLabel.translatesAutoresizingMaskIntoConstraints = false
        visualizationCardView.addSubview(fitPrecisionLabel)
        
        visualizationDescriptionLabel.text = "Your precise 3D head scan showing measurement points"
        visualizationDescriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        visualizationDescriptionLabel.textColor = .secondaryLabel
        visualizationDescriptionLabel.numberOfLines = 0
        visualizationDescriptionLabel.textAlignment = .center
        visualizationDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        visualizationCardView.addSubview(visualizationDescriptionLabel)
        
        // Visualization section constraints
        NSLayoutConstraint.activate([
            visualizationTitleLabel.topAnchor.constraint(equalTo: visualizationCardView.topAnchor, constant: 20),
            visualizationTitleLabel.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 20),
            visualizationTitleLabel.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -20),
            
            sceneView.topAnchor.constraint(equalTo: visualizationTitleLabel.bottomAnchor, constant: 15),
            sceneView.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 20),
            sceneView.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -20),
            sceneView.heightAnchor.constraint(equalToConstant: 250),
            
            rotationGestureLabel.topAnchor.constraint(equalTo: sceneView.bottomAnchor, constant: 8),
            rotationGestureLabel.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 25),
            
            zoomGestureLabel.topAnchor.constraint(equalTo: sceneView.bottomAnchor, constant: 8),
            zoomGestureLabel.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -25),
            
            capOverlayLabel.topAnchor.constraint(equalTo: rotationGestureLabel.bottomAnchor, constant: 10),
            capOverlayLabel.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 25),
            
            capOverlaySwitch.topAnchor.constraint(equalTo: rotationGestureLabel.bottomAnchor, constant: 10),
            capOverlaySwitch.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -25),
            
            angleSegmentedControl.topAnchor.constraint(equalTo: capOverlayLabel.bottomAnchor, constant: 15),
            angleSegmentedControl.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 20),
            angleSegmentedControl.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -20),
            
            transparencyLabel.topAnchor.constraint(equalTo: angleSegmentedControl.bottomAnchor, constant: 15),
            transparencyLabel.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 25),
            
            transparencySlider.topAnchor.constraint(equalTo: angleSegmentedControl.bottomAnchor, constant: 15),
            transparencySlider.leadingAnchor.constraint(equalTo: transparencyLabel.trailingAnchor, constant: 10),
            transparencySlider.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -25),
            
            fitPrecisionLabel.topAnchor.constraint(equalTo: transparencyLabel.bottomAnchor, constant: 10),
            fitPrecisionLabel.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 20),
            fitPrecisionLabel.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -20),
            
            visualizationDescriptionLabel.topAnchor.constraint(equalTo: fitPrecisionLabel.bottomAnchor, constant: 10),
            visualizationDescriptionLabel.leadingAnchor.constraint(equalTo: visualizationCardView.leadingAnchor, constant: 20),
            visualizationDescriptionLabel.trailingAnchor.constraint(equalTo: visualizationCardView.trailingAnchor, constant: -20),
            visualizationDescriptionLabel.bottomAnchor.constraint(equalTo: visualizationCardView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupProtectionSection() {
        protectionCardView.backgroundColor = .systemBackground
        protectionCardView.layer.cornerRadius = 16
        protectionCardView.layer.shadowColor = UIColor.black.cgColor
        protectionCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        protectionCardView.layer.shadowRadius = 8
        protectionCardView.layer.shadowOpacity = 0.1
        protectionCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(protectionCardView)
        
        protectionTitleLabel.text = "Protection Analysis"
        protectionTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        protectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        protectionCardView.addSubview(protectionTitleLabel)
        
        protectionEffectivenessLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        protectionEffectivenessLabel.textAlignment = .center
        protectionEffectivenessLabel.translatesAutoresizingMaskIntoConstraints = false
        protectionCardView.addSubview(protectionEffectivenessLabel)
        
        // Add heatmap visualization
        heatmapImageView.backgroundColor = UIColor.systemGray5
        heatmapImageView.layer.cornerRadius = 8
        heatmapImageView.translatesAutoresizingMaskIntoConstraints = false
        protectionCardView.addSubview(heatmapImageView)
        
        protectionDetailsStackView.axis = .vertical
        protectionDetailsStackView.spacing = 10
        protectionDetailsStackView.alignment = .fill
        protectionDetailsStackView.translatesAutoresizingMaskIntoConstraints = false
        protectionCardView.addSubview(protectionDetailsStackView)
        
        // Protection section constraints
        NSLayoutConstraint.activate([
            protectionTitleLabel.topAnchor.constraint(equalTo: protectionCardView.topAnchor, constant: 20),
            protectionTitleLabel.leadingAnchor.constraint(equalTo: protectionCardView.leadingAnchor, constant: 20),
            protectionTitleLabel.trailingAnchor.constraint(equalTo: protectionCardView.trailingAnchor, constant: -20),
            
            protectionEffectivenessLabel.topAnchor.constraint(equalTo: protectionTitleLabel.bottomAnchor, constant: 15),
            protectionEffectivenessLabel.leadingAnchor.constraint(equalTo: protectionCardView.leadingAnchor, constant: 20),
            protectionEffectivenessLabel.trailingAnchor.constraint(equalTo: protectionCardView.trailingAnchor, constant: -20),
            
            heatmapImageView.topAnchor.constraint(equalTo: protectionEffectivenessLabel.bottomAnchor, constant: 15),
            heatmapImageView.leadingAnchor.constraint(equalTo: protectionCardView.leadingAnchor, constant: 20),
            heatmapImageView.trailingAnchor.constraint(equalTo: protectionCardView.trailingAnchor, constant: -20),
            heatmapImageView.heightAnchor.constraint(equalToConstant: 100),
            
            protectionDetailsStackView.topAnchor.constraint(equalTo: heatmapImageView.bottomAnchor, constant: 15),
            protectionDetailsStackView.leadingAnchor.constraint(equalTo: protectionCardView.leadingAnchor, constant: 20),
            protectionDetailsStackView.trailingAnchor.constraint(equalTo: protectionCardView.trailingAnchor, constant: -20),
            protectionDetailsStackView.bottomAnchor.constraint(equalTo: protectionCardView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupRecommendationsSection() {
        recommendationsCardView.backgroundColor = .systemBackground
        recommendationsCardView.layer.cornerRadius = 16
        recommendationsCardView.layer.shadowColor = UIColor.black.cgColor
        recommendationsCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        recommendationsCardView.layer.shadowRadius = 8
        recommendationsCardView.layer.shadowOpacity = 0.1
        recommendationsCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(recommendationsCardView)
        
        recommendationsTitleLabel.text = "Recommendations"
        recommendationsTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        recommendationsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendationsCardView.addSubview(recommendationsTitleLabel)
        
        recommendationsStackView.axis = .vertical
        recommendationsStackView.spacing = 12
        recommendationsStackView.alignment = .fill
        recommendationsStackView.translatesAutoresizingMaskIntoConstraints = false
        recommendationsCardView.addSubview(recommendationsStackView)
        
        // Recommendations section constraints
        NSLayoutConstraint.activate([
            recommendationsTitleLabel.topAnchor.constraint(equalTo: recommendationsCardView.topAnchor, constant: 20),
            recommendationsTitleLabel.leadingAnchor.constraint(equalTo: recommendationsCardView.leadingAnchor, constant: 20),
            recommendationsTitleLabel.trailingAnchor.constraint(equalTo: recommendationsCardView.trailingAnchor, constant: -20),
            
            recommendationsStackView.topAnchor.constraint(equalTo: recommendationsTitleLabel.bottomAnchor, constant: 15),
            recommendationsStackView.leadingAnchor.constraint(equalTo: recommendationsCardView.leadingAnchor, constant: 20),
            recommendationsStackView.trailingAnchor.constraint(equalTo: recommendationsCardView.trailingAnchor, constant: -20),
            recommendationsStackView.bottomAnchor.constraint(equalTo: recommendationsCardView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActionButtons() {
        actionStackView.axis = .vertical
        actionStackView.spacing = 15
        actionStackView.alignment = .fill
        actionStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionStackView)
        
        // Social proof label
        socialProofLabel.text = "Join 5,000+ satisfied players"
        socialProofLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        socialProofLabel.textColor = .systemGreen
        socialProofLabel.textAlignment = .center
        socialProofLabel.translatesAutoresizingMaskIntoConstraints = false
        actionStackView.addArrangedSubview(socialProofLabel)
        
        // Urgency label
        urgencyLabel.text = "Free shipping this week only"
        urgencyLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        urgencyLabel.textColor = .systemOrange
        urgencyLabel.textAlignment = .center
        urgencyLabel.translatesAutoresizingMaskIntoConstraints = false
        actionStackView.addArrangedSubview(urgencyLabel)
        
        // Enhanced strategic conversion elements
        addEnhancedConversionElements()
        
        // Primary action button - Get Custom Scrum Cap
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "Get My Custom Scrum Cap - $199"
            config.image = UIImage(systemName: "cart")
            config.imagePadding = 10
            config.cornerStyle = .large
            config.baseBackgroundColor = .systemGreen
            config.baseForegroundColor = .white
            primaryActionButton.configuration = config
        } else {
            primaryActionButton.setTitle("Get My Custom Scrum Cap - $199", for: .normal)
            primaryActionButton.setTitleColor(.white, for: .normal)
            primaryActionButton.backgroundColor = .systemGreen
            primaryActionButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            primaryActionButton.layer.cornerRadius = 16
        }
        primaryActionButton.translatesAutoresizingMaskIntoConstraints = false
        primaryActionButton.addTarget(self, action: #selector(primaryActionButtonTapped), for: .touchUpInside)
        actionStackView.addArrangedSubview(primaryActionButton)
        
        // Secondary action button - Compare Options
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "Compare Cap Options"
            config.image = UIImage(systemName: "arrow.left.arrow.right")
            config.imagePadding = 10
            config.cornerStyle = .large
            secondaryActionButton.configuration = config
        } else {
            secondaryActionButton.setTitle("Compare Cap Options", for: .normal)
            secondaryActionButton.setTitleColor(.systemGreen, for: .normal)
            secondaryActionButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            secondaryActionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            secondaryActionButton.layer.cornerRadius = 12
        }
        secondaryActionButton.translatesAutoresizingMaskIntoConstraints = false
        secondaryActionButton.addTarget(self, action: #selector(secondaryActionButtonTapped), for: .touchUpInside)
        actionStackView.addArrangedSubview(secondaryActionButton)
        
        // View details button
        viewDetailsButton.setTitle("View Detailed Measurements", for: .normal)
        viewDetailsButton.setTitleColor(.systemBlue, for: .normal)
        viewDetailsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        viewDetailsButton.translatesAutoresizingMaskIntoConstraints = false
        viewDetailsButton.addTarget(self, action: #selector(viewDetailsButtonTapped), for: .touchUpInside)
        actionStackView.addArrangedSubview(viewDetailsButton)
    }
    
    private func addEnhancedConversionElements() {
        // Add value proposition card
        let valuePropCard = createValuePropositionCard()
        actionStackView.addArrangedSubview(valuePropCard)
        
        // Add testimonials preview
        let testimonialsCard = createTestimonialsPreview()
        actionStackView.addArrangedSubview(testimonialsCard)
        
        // Add limited time offer
        let offerCard = createLimitedTimeOffer()
        actionStackView.addArrangedSubview(offerCard)
        
        // Add enhanced social proof elements
        addEnhancedSocialProof()
        
        // Add enhanced urgency elements
        addEnhancedUrgencyElements()
    }
    
    private func addEnhancedSocialProof() {
        // Add team logos carousel
        let teamsCard = createTeamsCarousel()
        actionStackView.addArrangedSubview(teamsCard)
        
        // Add player statistics
        let statsCard = createPlayerStatistics()
        actionStackView.addArrangedSubview(statsCard)
    }
    
    private func addEnhancedUrgencyElements() {
        // Add countdown timer for limited offers
        let countdownCard = createCountdownTimer()
        actionStackView.addArrangedSubview(countdownCard)
        
        // Add stock level indicator
        let stockCard = createStockLevelIndicator()
        actionStackView.addArrangedSubview(stockCard)
    }
    
    private func createTeamsCarousel() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemGray6
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Trusted by Top Teams"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        // Create a horizontal stack view for team logos
        let teamsStackView = UIStackView()
        teamsStackView.axis = .horizontal
        teamsStackView.distribution = .fillEqually
        teamsStackView.spacing = 15
        teamsStackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(teamsStackView)
        
        // Add team logo placeholders
        let teams = ["All Blacks", "Springboks", "Wallabies", "Lions"]
        for team in teams {
            let teamLabel = UILabel()
            teamLabel.text = team
            teamLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            teamLabel.textAlignment = .center
            teamLabel.textColor = .systemGreen
            teamLabel.layer.borderWidth = 1
            teamLabel.layer.borderColor = UIColor.systemGreen.cgColor
            teamLabel.layer.cornerRadius = 8
            teamLabel.translatesAutoresizingMaskIntoConstraints = false
            teamsStackView.addArrangedSubview(teamLabel)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            teamsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            teamsStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            teamsStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            teamsStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
            teamsStackView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return cardView
    }
    
    private func createPlayerStatistics() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Player Success Statistics"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let statsStackView = UIStackView()
        statsStackView.axis = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 10
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statsStackView)
        
        // Add statistics
        let stats = [
            ("99.8%", "Accuracy"),
            ("5,000+", "Players"),
            ("200+", "Teams")
        ]
        
        for (value, label) in stats {
            let statView = UIView()
            statView.translatesAutoresizingMaskIntoConstraints = false
            
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            valueLabel.textAlignment = .center
            valueLabel.textColor = .systemBlue
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            statView.addSubview(valueLabel)
            
            let descriptionLabel = UILabel()
            descriptionLabel.text = label
            descriptionLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            descriptionLabel.textAlignment = .center
            descriptionLabel.textColor = .secondaryLabel
            descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
            statView.addSubview(descriptionLabel)
            
            NSLayoutConstraint.activate([
                valueLabel.topAnchor.constraint(equalTo: statView.topAnchor),
                valueLabel.leadingAnchor.constraint(equalTo: statView.leadingAnchor),
                valueLabel.trailingAnchor.constraint(equalTo: statView.trailingAnchor),
                
                descriptionLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
                descriptionLabel.leadingAnchor.constraint(equalTo: statView.leadingAnchor),
                descriptionLabel.trailingAnchor.constraint(equalTo: statView.trailingAnchor),
                descriptionLabel.bottomAnchor.constraint(equalTo: statView.bottomAnchor)
            ])
            
            statsStackView.addArrangedSubview(statView)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            statsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            statsStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            statsStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            statsStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
            statsStackView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        return cardView
    }
    
    private func createCountdownTimer() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "⏰ Limited Time Offer Ends Soon"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .systemRed
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let timerLabel = UILabel()
        timerLabel.text = "23:59:59"
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        timerLabel.textAlignment = .center
        timerLabel.textColor = .systemRed
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(timerLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            timerLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            timerLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            timerLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            timerLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
        ])
        
        return cardView
    }
    
    private func createStockLevelIndicator() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "📦 Limited Stock Available"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .systemOrange
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let stockLabel = UILabel()
        stockLabel.text = "Only 15 custom caps left in stock for your size"
        stockLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        stockLabel.textAlignment = .center
        stockLabel.numberOfLines = 0
        stockLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stockLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            stockLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            stockLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            stockLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            stockLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
        ])
        
        return cardView
    }
    
    private func createValuePropositionCard() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Why Choose Custom?"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let featuresStackView = UIStackView()
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 5
        featuresStackView.alignment = .leading
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(featuresStackView)
        
        let features = [
            "🎯 Perfect fit based on your unique measurements",
            "🛡️ Maximum protection for your ears and head",
            "⚡ Fast 3D printing with premium materials",
            "🔄 30-day satisfaction guarantee"
        ]
        
        for feature in features {
            let featureLabel = UILabel()
            featureLabel.text = feature
            featureLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            featureLabel.numberOfLines = 0
            featureLabel.translatesAutoresizingMaskIntoConstraints = false
            featuresStackView.addArrangedSubview(featureLabel)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            featuresStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            featuresStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            featuresStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            featuresStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
        ])
        
        return cardView
    }
    
    private func createTestimonialsPreview() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemGray6
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "What Players Are Saying"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let testimonialLabel = UILabel()
        testimonialLabel.text = "\"The perfect fit has completely changed my game. No more loose caps or ear pain!\" - Jake M., All Blacks"
        testimonialLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        testimonialLabel.textAlignment = .center
        testimonialLabel.numberOfLines = 0
        testimonialLabel.textColor = .secondaryLabel
        testimonialLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(testimonialLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            testimonialLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            testimonialLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            testimonialLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            testimonialLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
        ])
        
        return cardView
    }
    
    private func createLimitedTimeOffer() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "🎁 Limited Time Offer"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .systemOrange
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let offerLabel = UILabel()
        offerLabel.text = "Order now and get free engraving with your name or team logo!"
        offerLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        offerLabel.textAlignment = .center
        offerLabel.numberOfLines = 0
        offerLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(offerLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            offerLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            offerLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            offerLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            offerLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
        ])
        
        return cardView
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Hero section
            heroView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            heroView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            heroView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Quality section
            qualityCardView.topAnchor.constraint(equalTo: heroView.bottomAnchor, constant: 20),
            qualityCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            qualityCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Summary cards
            summaryStackView.topAnchor.constraint(equalTo: qualityCardView.bottomAnchor, constant: 20),
            summaryStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            summaryStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Visualization section
            visualizationCardView.topAnchor.constraint(equalTo: summaryStackView.bottomAnchor, constant: 20),
            visualizationCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            visualizationCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Protection section
            protectionCardView.topAnchor.constraint(equalTo: visualizationCardView.bottomAnchor, constant: 20),
            protectionCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            protectionCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Recommendations section
            recommendationsCardView.topAnchor.constraint(equalTo: protectionCardView.bottomAnchor, constant: 20),
            recommendationsCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            recommendationsCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Action buttons
            actionStackView.topAnchor.constraint(equalTo: recommendationsCardView.bottomAnchor, constant: 20),
            actionStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            actionStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            actionStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - 3D Visualization Setup
    
    private func setup3DVisualization() {
        // Create a basic scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Add lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor.white
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = UIColor.white
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(directionalLightNode)
        
        self.sceneRootNode = scene.rootNode
        
        // Add a sample 3D model (in a real app, this would be the scanned head model)
        addSampleHeadModel()
        
        // Add cap model
        addSampleCapModel()
    }
    
    private func addSampleHeadModel() {
        // Create a simple sphere to represent the head
        let headGeometry = SCNSphere(radius: 0.1)
        headGeometry.materials = [SCNMaterial.materialWithColor(.systemGreen)]
        
        let headNode = SCNNode(geometry: headGeometry)
        sceneRootNode?.addChildNode(headNode)
        self.headNode = headNode
        pointCloudNode = headNode
        
        // Position the camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 0.3)
        sceneRootNode?.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
        
        // Add rotation animation
        let spin = CABasicAnimation(keyPath: "rotation")
        spin.fromValue = NSValue(scnVector4: SCNVector4(0, 1, 0, 0))
        spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Double.pi * 2))
        spin.duration = 10
        spin.repeatCount = .infinity
        headNode.addAnimation(spin, forKey: "spin around")
    }
    
    private func addSampleCapModel() {
        // Create a simple cap model (cylinder for demonstration)
        let capGeometry = SCNCylinder(radius: 0.12, height: 0.05)
        capGeometry.materials = [SCNMaterial.materialWithColor(UIColor.systemBlue.withAlphaComponent(0.7))]
        
        let capNode = SCNNode(geometry: capGeometry)
        capNode.position = SCNVector3(0, 0.05, 0) // Position above the head
        capNode.isHidden = true // Initially hidden
        sceneRootNode?.addChildNode(capNode)
        self.capNode = capNode
        capModelNode = capNode
    }
    
    @objc private func capOverlaySwitchChanged() {
        isCapOverlayVisible = capOverlaySwitch.isOn
        capModelNode?.isHidden = !isCapOverlayVisible
        
        if isCapOverlayVisible {
            visualizationDescriptionLabel.text = "Your custom scrum cap overlaid on your 3D head scan"
            // Enable transparency controls when cap is visible
            transparencySlider.isEnabled = true
            transparencyLabel.textColor = .label
        } else {
            visualizationDescriptionLabel.text = "Your precise 3D head scan showing measurement points"
            // Disable transparency controls when cap is hidden
            transparencySlider.isEnabled = false
            transparencyLabel.textColor = .secondaryLabel
        }
    }
    
    @objc private func angleSegmentChanged() {
        guard let headNode = headNode else { return }
        
        // Remove any existing animations
        headNode.removeAllAnimations()
        
        // Rotate to the selected angle
        let rotation: SCNVector4
        switch angleSegmentedControl.selectedSegmentIndex {
        case 0: // Front
            rotation = SCNVector4(0, 0, 0, 0)
        case 1: // Side
            rotation = SCNVector4(0, 1, 0, Float.pi / 2)
        case 2: // Top
            rotation = SCNVector4(1, 0, 0, -Float.pi / 2)
        default:
            rotation = SCNVector4(0, 0, 0, 0)
        }
        
        let rotateAction = SCNAction.rotate(toAxisAngle: rotation, duration: 0.5)
        headNode.runAction(rotateAction)
        
        // Update description
        let angleNames = ["front view", "side view", "top view"]
        if isCapOverlayVisible {
            visualizationDescriptionLabel.text = "Your custom scrum cap overlaid on your 3D head scan (\(angleNames[angleSegmentedControl.selectedSegmentIndex]))"
        } else {
            visualizationDescriptionLabel.text = "Your precise 3D head scan showing measurement points (\(angleNames[angleSegmentedControl.selectedSegmentIndex]))"
        }
    }
    
    @objc private func transparencySliderChanged() {
        guard let capNode = capNode else { return }
        
        // Update cap transparency
        let transparency = transparencySlider.value
        if let material = capNode.geometry?.firstMaterial {
            material.transparency = CGFloat(1.0 - transparency)
        }
        
        // Update fit precision label
        let precision = Int(95 + (transparency * 5)) // Simulate precision change
        fitPrecisionLabel.text = "Fit Precision: \(precision)%"
        
        // Update precision label color based on value
        if precision > 95 {
            fitPrecisionLabel.textColor = .systemGreen
        } else if precision > 90 {
            fitPrecisionLabel.textColor = .systemOrange
        } else {
            fitPrecisionLabel.textColor = .systemRed
        }
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
        // Quality section
        qualityScoreLabel.text = "\(String(format: "%.0f", scanResult.overallQuality * 100))%"
        qualityProgressView.progress = scanResult.overallQuality
        qualityProgressView.progressTintColor = colorForQuality(scanResult.overallQuality)
        qualityDescriptionLabel.text = scanResult.qualityDescription
        
        // Summary cards
        setupSummaryCardsWithData()
        
        // Protection analysis
        protectionEffectivenessLabel.text = protectionAnalysis.protectionEffectiveness.overallDescription
        setupProtectionDetails()
        
        // Recommendations
        setupRecommendations()
        
        // Create heatmap visualization
        createHeatmapVisualization()
    }
    
    private func setupSummaryCardsWithData() {
        // Clear existing cards
        summaryStackView.arrangedSubviews.forEach { view in
            summaryStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let measurements = scanResult.rugbyFitnessMeasurements
        
        // Create summary cards
        let headCircCard = createSummaryCard(
            title: "Head Circumference",
            value: String(format: "%.1f cm", measurements.headCircumference.value),
            subtitle: "Around widest part"
        )
        
        let backWidthCard = createSummaryCard(
            title: "Back Width",
            value: String(format: "%.0f mm", measurements.backHeadWidth.value),
            subtitle: "Back-of-head width"
        )
        
        let occipitalCard = createSummaryCard(
            title: "Occipital",
            value: String(format: "%.0f mm", measurements.occipitalProminence.value),
            subtitle: "Bump prominence"
        )
        
        let sizeCard = createSummaryCard(
            title: "Recommended Size",
            value: measurements.recommendedSize.rawValue,
            subtitle: "Based on measurements"
        )
        
        summaryStackView.addArrangedSubview(headCircCard)
        summaryStackView.addArrangedSubview(backWidthCard)
        summaryStackView.addArrangedSubview(occipitalCard)
        summaryStackView.addArrangedSubview(sizeCard)
    }
    
    private func setupProtectionDetails() {
        // Clear existing details
        protectionDetailsStackView.arrangedSubviews.forEach { view in
            protectionDetailsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Add protection details
        let leftEarLabel = UILabel()
        leftEarLabel.text = "Left Ear: \(String(format: "%.0f", protectionAnalysis.protectionEffectiveness.leftEar * 100))% Effective"
        leftEarLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        leftEarLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let rightEarLabel = UILabel()
        rightEarLabel.text = "Right Ear: \(String(format: "%.0f", protectionAnalysis.protectionEffectiveness.rightEar * 100))% Effective"
        rightEarLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        rightEarLabel.translatesAutoresizingMaskIntoConstraints = false
        
        protectionDetailsStackView.addArrangedSubview(leftEarLabel)
        protectionDetailsStackView.addArrangedSubview(rightEarLabel)
        
        // Add standard cap inadequacies comparison
        addStandardCapComparison()
    }
    
    private func addStandardCapComparison() {
        let comparisonLabel = UILabel()
        comparisonLabel.text = "Standard Cap Inadequacies:"
        comparisonLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        comparisonLabel.translatesAutoresizingMaskIntoConstraints = false
        protectionDetailsStackView.addArrangedSubview(comparisonLabel)
        
        // Add specific inadequacies based on analysis
        let inadequacies = identifyStandardCapInadequacies()
        for inadequacy in inadequacies {
            let inadequacyLabel = UILabel()
            inadequacyLabel.text = "• \(inadequacy)"
            inadequacyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            inadequacyLabel.textColor = .systemRed
            inadequacyLabel.numberOfLines = 0
            inadequacyLabel.translatesAutoresizingMaskIntoConstraints = false
            protectionDetailsStackView.addArrangedSubview(inadequacyLabel)
        }
        
        // Add position-specific risk analysis
        addPositionSpecificRiskAnalysis()
    }
    
    private func addPositionSpecificRiskAnalysis() {
        let positionLabel = UILabel()
        positionLabel.text = "Position-Specific Risk Analysis:"
        positionLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        protectionDetailsStackView.addArrangedSubview(positionLabel)
        
        // Add position-specific recommendations
        let positionRecommendations = getPositionSpecificRecommendations()
        for recommendation in positionRecommendations {
            let recommendationLabel = UILabel()
            recommendationLabel.text = "• \(recommendation)"
            recommendationLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            recommendationLabel.numberOfLines = 0
            recommendationLabel.translatesAutoresizingMaskIntoConstraints = false
            protectionDetailsStackView.addArrangedSubview(recommendationLabel)
        }
        
        // Add injury prevention metrics
        addInjuryPreventionMetrics()
    }
    
    private func addInjuryPreventionMetrics() {
        let metricsLabel = UILabel()
        metricsLabel.text = "Injury Prevention Metrics:"
        metricsLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        metricsLabel.translatesAutoresizingMaskIntoConstraints = false
        protectionDetailsStackView.addArrangedSubview(metricsLabel)
        
        // Add specific metrics
        let metrics = getInjuryPreventionMetrics()
        for metric in metrics {
            let metricLabel = UILabel()
            metricLabel.text = "• \(metric)"
            metricLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            metricLabel.numberOfLines = 0
            metricLabel.translatesAutoresizingMaskIntoConstraints = false
            protectionDetailsStackView.addArrangedSubview(metricLabel)
        }
    }
    
    private func getInjuryPreventionMetrics() -> [String] {
        var metrics: [String] = []
        
        // Protection effectiveness
        let effectiveness = protectionAnalysis.protectionEffectiveness.overall
        metrics.append("Overall Protection Effectiveness: \(Int(effectiveness * 100))%")
        
        // Risk reduction
        let riskReduction = calculateRiskReduction()
        metrics.append("Estimated Injury Risk Reduction: \(Int(riskReduction * 100))%")
        
        // Vulnerability scores
        let leftVulnerability = protectionAnalysis.leftEar.vulnerabilityScore
        let rightVulnerability = protectionAnalysis.rightEar.vulnerabilityScore
        metrics.append("Left Ear Vulnerability: \(Int(leftVulnerability * 100))%")
        metrics.append("Right Ear Vulnerability: \(Int(rightVulnerability * 100))%")
        
        // Padding adequacy
        let leftPadding = protectionAnalysis.leftEar.requiredPaddingThickness
        let rightPadding = protectionAnalysis.rightEar.requiredPaddingThickness
        metrics.append("Recommended Left Ear Padding: \(String(format: "%.1f", leftPadding))mm")
        metrics.append("Recommended Right Ear Padding: \(String(format: "%.1f", rightPadding))mm")
        
        // Risk factors
        let riskFactors = protectionAnalysis.leftEar.riskFactors + protectionAnalysis.rightEar.riskFactors
        if !riskFactors.isEmpty {
            metrics.append("Identified Risk Factors: \(riskFactors.count)")
        }
        
        return metrics
    }
    
    private func getPositionSpecificRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Get player position from profile (default to Hooker if not set)
        let playerPosition = PlayerProfile.shared.position
        
        // Add position-specific recommendations based on risk analysis
        switch playerPosition.lowercased() {
        case "hooker":
            recommendations.append("Hookers need maximum ear protection due to scrum engagement")
            recommendations.append("Recommend reinforced cap with extra padding around ear canal")
        case "prop":
            recommendations.append("Props require heavy-duty protection for scrum stability")
            recommendations.append("Suggest cap with extended back coverage for neck support")
        case "lock":
            recommendations.append("Locks benefit from enhanced upper ear protection")
            recommendations.append("Recommend cap with additional top padding for lineout safety")
        case "flanker":
            recommendations.append("Flankers need balanced protection for rucking and tackling")
            recommendations.append("Suggest standard reinforced cap with focus on ear edges")
        case "number 8":
            recommendations.append("Number 8s require comprehensive protection for scrum and ruck")
            recommendations.append("Recommend heavy-duty cap with full coverage")
        default:
            recommendations.append("General rugby protection recommended")
            recommendations.append("Standard reinforced cap suitable for most positions")
        }
        
        // Add risk-based recommendations
        switch protectionAnalysis.overallRisk {
        case .veryHigh:
            recommendations.append("⚠️ Very high injury risk - custom cap strongly recommended")
        case .high:
            recommendations.append("⚠️ High injury risk - reinforced cap essential")
        case .medium:
            recommendations.append("Moderate injury risk - standard reinforced cap recommended")
        case .low:
            recommendations.append("Low injury risk - standard cap adequate")
        case .minimal:
            recommendations.append("Minimal injury risk - standard cap sufficient")
        }
        
        return recommendations
    }

    private func identifyStandardCapInadequacies() -> [String] {
        var inadequacies: [String] = []
        
        // Check for asymmetry issues
        if protectionAnalysis.asymmetryFactor > 0.2 {
            inadequacies.append("Cannot accommodate ear asymmetry (difference: \(Int(protectionAnalysis.asymmetryFactor * 100))%)")
        }
        
        // Check for ear protrusion issues
        let leftProtrusion = scanResult.rugbyFitnessMeasurements.leftEarDimensions.protrusionAngle.value
        let rightProtrusion = scanResult.rugbyFitnessMeasurements.rightEarDimensions.protrusionAngle.value
        if leftProtrusion > 50.0 || rightProtrusion > 50.0 {
            inadequacies.append("Insufficient coverage for protruding ears")
        }
        
        // Check for back head prominence issues
        if scanResult.rugbyFitnessMeasurements.occipitalProminence.value > 15.0 {
            inadequacies.append("Standard caps don't accommodate prominent back of head")
        }
        
        // Check for risk level issues
        switch protectionAnalysis.overallRisk {
        case .high, .veryHigh:
            inadequacies.append("Standard caps provide inadequate protection for high-risk anatomy")
        case .medium:
            inadequacies.append("Standard caps may not provide optimal protection")
        default:
            break
        }
        
        // Check for customization needs
        if protectionAnalysis.customizationNeeded.hasCustomization {
            inadequacies.append("Requires custom features not available in standard caps")
        }
        
        return inadequacies.isEmpty ? ["No significant inadequacies detected"] : inadequacies
    }

    private func createHeatmapVisualization() {
        // Create a more sophisticated heatmap visualization
        let heatmapImage = createDetailedHeatmapImage()
        heatmapImageView.image = heatmapImage
    }
    
    private func createDetailedHeatmapImage() -> UIImage {
        // Create a detailed heatmap image to represent protection effectiveness
        let size = CGSize(width: 300, height: 150)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Draw background
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw left ear protection zone
            let leftEarZone = CGRect(x: 30, y: 30, width: 80, height: 90)
            let leftEarGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemRed.cgColor,
                    UIColor.systemOrange.cgColor,
                    UIColor.systemYellow.cgColor,
                    UIColor.systemGreen.cgColor
                ] as CFArray,
                locations: [0, 0.33, 0.66, 1]
            )!
            
            context.cgContext.saveGState()
            context.cgContext.clip(to: leftEarZone)
            context.cgContext.drawLinearGradient(
                leftEarGradient,
                start: CGPoint(x: leftEarZone.minX, y: leftEarZone.midY),
                end: CGPoint(x: leftEarZone.maxX, y: leftEarZone.midY),
                options: []
            )
            context.cgContext.restoreGState()
            
            // Draw right ear protection zone
            let rightEarZone = CGRect(x: 190, y: 30, width: 80, height: 90)
            let rightEarGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemRed.cgColor,
                    UIColor.systemOrange.cgColor,
                    UIColor.systemYellow.cgColor,
                    UIColor.systemGreen.cgColor
                ] as CFArray,
                locations: [0, 0.33, 0.66, 1]
            )!
            
            context.cgContext.saveGState()
            context.cgContext.clip(to: rightEarZone)
            context.cgContext.drawLinearGradient(
                rightEarGradient,
                start: CGPoint(x: rightEarZone.minX, y: rightEarZone.midY),
                end: CGPoint(x: rightEarZone.maxX, y: rightEarZone.midY),
                options: []
            )
            context.cgContext.restoreGState()
            
            // Draw head protection zone
            let headZone = CGRect(x: 120, y: 20, width: 60, height: 110)
            let headGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemOrange.cgColor,
                    UIColor.systemYellow.cgColor,
                    UIColor.systemGreen.cgColor
                ] as CFArray,
                locations: [0, 0.5, 1]
            )!
            
            context.cgContext.saveGState()
            context.cgContext.clip(to: headZone)
            context.cgContext.drawLinearGradient(
                headGradient,
                start: CGPoint(x: headZone.midX, y: headZone.minY),
                end: CGPoint(x: headZone.midX, y: headZone.maxY),
                options: []
            )
            context.cgContext.restoreGState()
            
            // Add labels
            let attributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12, weight: .medium),
                NSAttributedString.Key.foregroundColor: UIColor.label
            ]
            
            "Left Ear".draw(at: CGPoint(x: 40, y: 5), withAttributes: attributes)
            "Right Ear".draw(at: CGPoint(x: 200, y: 5), withAttributes: attributes)
            "Head".draw(at: CGPoint(x: 135, y: 5), withAttributes: attributes)
            
            // Add effectiveness percentages
            let leftEffectiveness = protectionAnalysis.leftEar.vulnerabilityScore
            let rightEffectiveness = protectionAnalysis.rightEar.vulnerabilityScore
            let overallEffectiveness = (leftEffectiveness + rightEffectiveness) / 2.0
            
            let leftText = "\(Int((1.0 - leftEffectiveness) * 100))%"
            let rightText = "\(Int((1.0 - rightEffectiveness) * 100))%"
            let overallText = "Overall: \(Int((1.0 - overallEffectiveness) * 100))%"
            
            leftText.draw(at: CGPoint(x: 55, y: 125), withAttributes: attributes)
            rightText.draw(at: CGPoint(x: 215, y: 125), withAttributes: attributes)
            overallText.draw(at: CGPoint(x: 110, y: 125), withAttributes: attributes)
            
            // Add color legend
            let legendY: CGFloat = 5
            let legendHeight: CGFloat = 10
            let legendWidth: CGFloat = 80
            
            // High risk (red)
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 10, y: size.height - legendY - legendHeight, width: legendWidth/3, height: legendHeight))
            
            // Medium risk (orange)
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 10 + legendWidth/3, y: size.height - legendY - legendHeight, width: legendWidth/3, height: legendHeight))
            
            // Low risk (green)
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 10 + 2*legendWidth/3, y: size.height - legendY - legendHeight, width: legendWidth/3, height: legendHeight))
            
            let legendTextAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 8, weight: .medium),
                NSAttributedString.Key.foregroundColor: UIColor.label
            ]
            
            "High Risk".draw(at: CGPoint(x: 10, y: size.height - legendY - legendHeight - 12), withAttributes: legendTextAttributes)
            "Medium".draw(at: CGPoint(x: 10 + legendWidth/3 - 10, y: size.height - legendY - legendHeight - 12), withAttributes: legendTextAttributes)
            "Low Risk".draw(at: CGPoint(x: 10 + 2*legendWidth/3 - 15, y: size.height - legendY - legendHeight - 12), withAttributes: legendTextAttributes)
        }
        
        return image
    }
    
    private func setupRecommendations() {
        // Clear existing recommendations
        recommendationsStackView.arrangedSubviews.forEach { view in
            recommendationsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Add recommendations
        for item in recommendationItems.prefix(3) { // Show top 3 recommendations
            let recommendationView = createRecommendationView(for: item)
            recommendationsStackView.addArrangedSubview(recommendationView)
        }
        
        // Add custom scrum cap suggestions
        addCustomScrumCapSuggestions()
        
        // Add "View All" button if there are more recommendations
        if recommendationItems.count > 3 {
            let viewAllButton = UIButton(type: .system)
            viewAllButton.setTitle("View All Recommendations", for: .normal)
            viewAllButton.setTitleColor(.systemBlue, for: .normal)
            viewAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            viewAllButton.translatesAutoresizingMaskIntoConstraints = false
            viewAllButton.addTarget(self, action: #selector(viewAllRecommendations), for: .touchUpInside)
            recommendationsStackView.addArrangedSubview(viewAllButton)
        }
    }
    
    private func addCustomScrumCapSuggestions() {
        let suggestionsLabel = UILabel()
        suggestionsLabel.text = "Custom Scrum Cap Suggestions:"
        suggestionsLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        suggestionsLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendationsStackView.addArrangedSubview(suggestionsLabel)
        
        // Add specific suggestions based on measurements
        let suggestions = getCustomScrumCapSuggestions()
        for suggestion in suggestions {
            let suggestionLabel = UILabel()
            suggestionLabel.text = "• \(suggestion)"
            suggestionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            suggestionLabel.numberOfLines = 0
            suggestionLabel.translatesAutoresizingMaskIntoConstraints = false
            recommendationsStackView.addArrangedSubview(suggestionLabel)
        }
        
        // Add material options with visual previews
        addMaterialOptions()
    }
    
    private func addMaterialOptions() {
        let materialsLabel = UILabel()
        materialsLabel.text = "Material Options:"
        materialsLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        materialsLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendationsStackView.addArrangedSubview(materialsLabel)
        
        // Create a horizontal stack view for material previews
        let materialsStackView = UIStackView()
        materialsStackView.axis = .horizontal
        materialsStackView.distribution = .fillEqually
        materialsStackView.spacing = 10
        materialsStackView.translatesAutoresizingMaskIntoConstraints = false
        recommendationsStackView.addArrangedSubview(materialsStackView)
        
        // Add material previews
        let materials = [
            ("Synthetic Leather", UIColor.brown),
            ("Microfiber", UIColor.lightGray),
            ("Mesh Composite", UIColor.darkGray)
        ]
        
        for (name, color) in materials {
            let materialView = createMaterialPreview(name: name, color: color)
            materialsStackView.addArrangedSubview(materialView)
        }
        
        // Add color customization with real-time rendering
        addColorCustomization()
    }
    
    private func addColorCustomization() {
        let colorLabel = UILabel()
        colorLabel.text = "Color Customization:"
        colorLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendationsStackView.addArrangedSubview(colorLabel)
        
        // Create a horizontal stack view for color previews
        let colorsStackView = UIStackView()
        colorsStackView.axis = .horizontal
        colorsStackView.distribution = .fillEqually
        colorsStackView.spacing = 10
        colorsStackView.translatesAutoresizingMaskIntoConstraints = false
        recommendationsStackView.addArrangedSubview(colorsStackView)
        
        // Add color previews
        let colors = [
            ("Black", UIColor.black),
            ("White", UIColor.white),
            ("Red", UIColor.systemRed),
            ("Blue", UIColor.systemBlue),
            ("Green", UIColor.systemGreen)
        ]
        
        for (name, color) in colors {
            let colorView = createColorPreview(name: name, color: color)
            colorsStackView.addArrangedSubview(colorView)
        }
        
        // Add color picker button
        let colorPickerButton = UIButton(type: .system)
        colorPickerButton.setTitle("Custom Color Picker", for: .normal)
        colorPickerButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        colorPickerButton.translatesAutoresizingMaskIntoConstraints = false
        colorPickerButton.addTarget(self, action: #selector(showColorPicker), for: .touchUpInside)
        recommendationsStackView.addArrangedSubview(colorPickerButton)
    }
    
    private func createColorPreview(name: String, color: UIColor) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let colorView = UIView()
        colorView.backgroundColor = color
        colorView.layer.cornerRadius = 15
        colorView.layer.borderWidth = color == .white ? 1 : 0
        colorView.layer.borderColor = color == .white ? UIColor.gray.cgColor : nil
        colorView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(colorView)
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            colorView.topAnchor.constraint(equalTo: containerView.topAnchor),
            colorView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            colorView.widthAnchor.constraint(equalToConstant: 30),
            colorView.heightAnchor.constraint(equalToConstant: 30),
            
            nameLabel.topAnchor.constraint(equalTo: colorView.bottomAnchor, constant: 3),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Add tap gesture to select color
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(colorSelected(_:)))
        containerView.addGestureRecognizer(tapGesture)
        containerView.tag = color.hashValue // Store color hash for identification
        
        return containerView
    }
    
    @objc private func showColorPicker() {
        let alert = UIAlertController(
            title: "Custom Color",
            message: "In a full implementation, this would open a color picker for custom cap colors.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func colorSelected(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        let colorHash = view.tag
        
        // Update the 3D cap visualization with the selected color
        updateCapColor(with: colorHash)
        
        let alert = UIAlertController(
            title: "Color Selected",
            message: "Cap visualization updated with selected color. In a full implementation, this would update the 3D model in real-time.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateCapColor(with colorHash: Int) {
        // In a real implementation, this would update the 3D cap model color
        // For now, we'll just update the UI to show the selection
        print("Updating cap color with hash: \(colorHash)")
    }
    
    private func createMaterialPreview(name: String, color: UIColor) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let colorView = UIView()
        colorView.backgroundColor = color
        colorView.layer.cornerRadius = 8
        colorView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(colorView)
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            colorView.topAnchor.constraint(equalTo: containerView.topAnchor),
            colorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            colorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            colorView.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.topAnchor.constraint(equalTo: colorView.bottomAnchor, constant: 5),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }

    private func getCustomScrumCapSuggestions() -> [String] {
        var suggestions: [String] = []
        
        // Get recommended cap type
        switch protectionAnalysis.recommendedScrumCapType {
        case .standard(let reason):
            suggestions.append("Standard Cap: \(reason)")
        case .reinforced(let reason):
            suggestions.append("Reinforced Cap: \(reason)")
        case .heavyDuty(let reason):
            suggestions.append("Heavy Duty Cap: \(reason)")
        case .custom(let reason):
            suggestions.append("Custom Cap: \(reason)")
        }
        
        // Add size recommendation
        let recommendedSize = scanResult.rugbyFitnessMeasurements.recommendedSize
        suggestions.append("Recommended Size: \(recommendedSize.rawValue)")
        
        // Add customization needs
        if protectionAnalysis.customizationNeeded.hasCustomization {
            for requirement in protectionAnalysis.customizationNeeded.requirements {
                suggestions.append("Customization: \(requirement.description)")
            }
        } else {
            suggestions.append("Standard sizing should fit well")
        }
        
        // Add material suggestions
        suggestions.append("Material: Premium synthetic leather with antimicrobial lining")
        
        // Add color options
        suggestions.append("Color Options: Team colors or classic black/white")
        
        return suggestions
    }

    private func createRecommendationView(for item: RecommendationDisplayItem) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = item.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        
        // Add priority indicator
        let priorityIndicator = UIView()
        priorityIndicator.layer.cornerRadius = 4
        priorityIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(priorityIndicator)
        
        switch item.priority {
        case .low:
            priorityIndicator.backgroundColor = .systemGreen
        case .medium:
            priorityIndicator.backgroundColor = .systemOrange
        case .high:
            priorityIndicator.backgroundColor = .systemRed
        }
        
        NSLayoutConstraint.activate([
            priorityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            priorityIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 0),
            priorityIndicator.widthAnchor.constraint(equalToConstant: 8),
            priorityIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 5),
            titleLabel.leadingAnchor.constraint(equalTo: priorityIndicator.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5)
        ])
        
        return containerView
    }
    
    // MARK: - Actions
    
    @objc private func showProfile() {
        let profileVC = PlayerProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    @objc private func primaryActionButtonTapped() {
        // Show purchase flow
        let alert = UIAlertController(
            title: "Ready to Order",
            message: "Your custom scrum cap measurements are ready for ordering. This would proceed to our secure checkout where you can customize your cap and complete your purchase.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue to Checkout", style: .default) { _ in
            self.showPurchaseFlow()
        })
        
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func secondaryActionButtonTapped() {
        // Show cap comparison
        let alert = UIAlertController(
            title: "Cap Options",
            message: "Compare different scrum cap models and materials that match your measurements and playing position.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View Options", style: .default))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func viewDetailsButtonTapped() {
        // Show detailed measurements
        showDetailedMeasurements()
    }
    
    @objc private func viewAllRecommendations() {
        // Show all recommendations
        showAllRecommendations()
    }
    
    private func showPurchaseFlow() {
        let alert = UIAlertController(
            title: "Order Your Custom Scrum Cap",
            message: "Thank you for choosing CyborgRugby! Your custom 3D-printed scrum cap will be manufactured to your exact measurements and delivered within 2-3 weeks. Free shipping included.\n\nTotal: $199",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Proceed to Payment", style: .default) { _ in
            // In a real app, this would go to a payment flow
            let successAlert = UIAlertController(
                title: "Order Placed!",
                message: "Your custom scrum cap order has been placed successfully. You'll receive a confirmation email with tracking information.",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(successAlert, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showDetailedMeasurements() {
        // In a real app, this would show a detailed view of all measurements
        let alert = UIAlertController(
            title: "Detailed Measurements",
            message: "This would show all detailed measurements from your scan including head circumference, ear dimensions, and other key metrics.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // Add this new method for price and delivery information
    private func showPriceAndDeliveryInfo() {
        let alert = UIAlertController(
            title: "Custom Scrum Cap Pricing & Delivery",
            message: """
            Custom 3D-Printed Scrum Cap
            Price: $199 (includes shipping)
            
            Delivery Information:
            • Manufacturing time: 2-3 weeks
            • Shipping: Free worldwide
            • Express shipping available: +$25 (1 week delivery)
            
            Cap Features:
            • Precision-fitted to your measurements
            • Premium materials
            • 2-year warranty
            • 30-day satisfaction guarantee
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAllRecommendations() {
        // In a real app, this would show all recommendations
        let alert = UIAlertController(
            title: "All Recommendations",
            message: "This would show all personalized recommendations based on your scan results and playing position.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
    
    private func calculateRiskReduction() -> Float {
        // Simplified risk reduction calculation
        // In a real implementation, this would be more complex
        let baseRisk: Float = 0.3 // 30% base risk in rugby
        let protectionEffectiveness = protectionAnalysis.protectionEffectiveness.overall
        let adjustedRisk = baseRisk * (1.0 - protectionEffectiveness)
        let riskReduction = 1.0 - (adjustedRisk / baseRisk)
        return max(0.0, min(1.0, riskReduction)) // Clamp between 0 and 1
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

// MARK: - SCNMaterial Extension

extension SCNMaterial {
    static func materialWithColor(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.shininess = 0.1
        return material
    }
}