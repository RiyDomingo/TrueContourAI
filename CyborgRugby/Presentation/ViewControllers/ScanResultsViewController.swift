//
//  ScanResultsViewController.swift
//  CyborgRugby
//
//  Display rugby scrum cap fitting results with ML-enhanced measurements
//

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
    
    // Protection analysis
    private let protectionCardView = UIView()
    private let protectionTitleLabel = UILabel()
    private let protection effectivenessLabel = UILabel()
    private let protectionDetailsStackView = UIStackView()
    
    // Recommendations
    private let recommendationsCardView = UIView()
    private let recommendationsTitleLabel = UILabel()
    private let recommendationsStackView = UIStackView()
    
    // Action buttons
    private let actionStackView = UIStackView()
    private let primaryActionButton = UIButton()
    private let secondaryActionButton = UIButton()
    private let viewDetailsButton = UIButton()
    
    // MARK: - Data
    var scanResult: CompleteScanResult!
    var protectionAnalysis: EarProtectionAnalysis!
    
    private let rugbyEarAnalyzer = RugbyEarProtectionCalculator()
    private var measurementItems: [MeasurementDisplayItem] = []
    private var recommendationItems: [RecommendationDisplayItem] = []
    private var pointCloudNode: SCNNode?
    private var sceneRootNode: SCNNode?
    
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
        visualizationCardView.addSubview(sceneView)
        
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
            sceneView.heightAnchor.constraint(equalToConstant: 200),
            
            visualizationDescriptionLabel.topAnchor.constraint(equalTo: sceneView.bottomAnchor, constant: 15),
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
        
        protection effectivenessLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        protection effectivenessLabel.textAlignment = .center
        protection effectivenessLabel.translatesAutoresizingMaskIntoConstraints = false
        protectionCardView.addSubview(protection effectivenessLabel)
        
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
            
            protection effectivenessLabel.topAnchor.constraint(equalTo: protectionTitleLabel.bottomAnchor, constant: 15),
            protection effectivenessLabel.leadingAnchor.constraint(equalTo: protectionCardView.leadingAnchor, constant: 20),
            protection effectivenessLabel.trailingAnchor.constraint(equalTo: protectionCardView.trailingAnchor, constant: -20),
            
            protectionDetailsStackView.topAnchor.constraint(equalTo: protection effectivenessLabel.bottomAnchor, constant: 15),
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
    }
    
    private func addSampleHeadModel() {
        // Create a simple sphere to represent the head
        let headGeometry = SCNSphere(radius: 0.1)
        headGeometry.materials = [SCNMaterial.materialWithColor(.systemGreen)]
        
        let headNode = SCNNode(geometry: headGeometry)
        sceneRootNode?.addChildNode(headNode)
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
        protection effectivenessLabel.text = protectionAnalysis.protectionEffectiveness.overallDescription
        setupProtectionDetails()
        
        // Recommendations
        setupRecommendations()
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