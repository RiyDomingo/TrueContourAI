//
//  MainViewController.swift
//  CyborgRugby
//
//  Main interface for CyborgRugby rugby scrum cap fitting
//

import UIKit
import AVFoundation

class MainViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let heroImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valuePropositionLabel = UILabel()
    private let startScanButton = UIButton()
    private let socialProofStackView = UIStackView()
    private let deviceStatusLabel = UILabel()
    private let resultsButton = UIButton()
    private let featuresStackView = UIStackView()
    private let profileButton = UIButton()
    private let educationButton = UIButton()
    
    private var lastScanResults: CompleteScanResult?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkDeviceCompatibility()
        loadPreviousScanResults()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "CyborgRugby"
        view.backgroundColor = UIColor.systemBackground
        
        // Add settings button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        
        // Add education button to navigation bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "graduationcap"),
            style: .plain,
            target: self,
            action: #selector(showEducationHub)
        )
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeroSection()
        setupTitleSection()
        setupValuePropositionSection()
        setupButtonSection()
        setupSocialProofSection()
        setupFeaturesSection()
        setupInfoSection()
        setupConstraints()
    }
    
    private func setupHeroSection() {
        heroImageView.image = UIImage(systemName: "sportscourt")
        heroImageView.tintColor = .systemGreen
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        heroImageView.layer.cornerRadius = 16
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(heroImageView)
    }
    
    private func setupTitleSection() {
        titleLabel.text = "🏉 Rugby Scrum Cap Fitting"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        subtitleLabel.text = "AI-powered 3D scanning for perfect scrum cap fit"
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .systemGreen
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
    }
    
    private func setupValuePropositionSection() {
        valuePropositionLabel.text = "Free 3D Scan → Perfectly Fitted Scrum Cap"
        valuePropositionLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        valuePropositionLabel.adjustsFontForContentSizeCategory = true
        valuePropositionLabel.textAlignment = .center
        valuePropositionLabel.numberOfLines = 0
        valuePropositionLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        valuePropositionLabel.layer.cornerRadius = 12
        valuePropositionLabel.layer.masksToBounds = true
        valuePropositionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valuePropositionLabel)
    }
    
    private func setupButtonSection() {
        // Main scan button
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "Start Free 3D Head Scan"
            config.image = UIImage(systemName: "camera.viewfinder")
            config.imagePadding = 12
            config.cornerStyle = .large
            config.baseBackgroundColor = .systemGreen
            config.baseForegroundColor = .white
            startScanButton.configuration = config
        } else {
            startScanButton.setTitle("Start Free 3D Head Scan", for: .normal)
            startScanButton.setTitleColor(.white, for: .normal)
            startScanButton.backgroundColor = .systemGreen
            startScanButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
            startScanButton.layer.cornerRadius = 16
            startScanButton.layer.shadowColor = UIColor.black.cgColor
            startScanButton.layer.shadowOffset = CGSize(width: 0, height: 4)
            startScanButton.layer.shadowRadius = 8
            startScanButton.layer.shadowOpacity = 0.15
        }
        startScanButton.addTarget(self, action: #selector(startScanning), for: .touchUpInside)
        startScanButton.accessibilityIdentifier = "home.startScan"
        startScanButton.accessibilityLabel = "Start 3D head scan"
        startScanButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Results button (initially hidden)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "View Previous Results"
            config.image = UIImage(systemName: "clock.arrow.circlepath")
            config.imagePadding = 8
            config.cornerStyle = .large
            resultsButton.configuration = config
        } else {
            resultsButton.setTitle("View Previous Results", for: .normal)
            resultsButton.setTitleColor(.systemGreen, for: .normal)
            resultsButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            resultsButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            resultsButton.layer.cornerRadius = 12
            resultsButton.layer.borderWidth = 1
            resultsButton.layer.borderColor = UIColor.systemGreen.cgColor
        }
        resultsButton.addTarget(self, action: #selector(showPreviousResults), for: .touchUpInside)
        resultsButton.accessibilityIdentifier = "home.previousResults"
        resultsButton.accessibilityLabel = "View previous results"
        resultsButton.isHidden = true
        resultsButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Profile button
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "My Profile"
            config.image = UIImage(systemName: "person.fill")
            config.imagePadding = 8
            config.cornerStyle = .large
            profileButton.configuration = config
        } else {
            profileButton.setTitle("My Profile", for: .normal)
            profileButton.setTitleColor(.systemGreen, for: .normal)
            profileButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            profileButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            profileButton.layer.cornerRadius = 12
            profileButton.layer.borderWidth = 1
            profileButton.layer.borderColor = UIColor.systemGreen.cgColor
        }
        profileButton.addTarget(self, action: #selector(showProfile), for: .touchUpInside)
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Education button
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "Education Hub"
            config.image = UIImage(systemName: "graduationcap")
            config.imagePadding = 8
            config.cornerStyle = .large
            educationButton.configuration = config
        } else {
            educationButton.setTitle("Education Hub", for: .normal)
            educationButton.setTitleColor(.systemGreen, for: .normal)
            educationButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            educationButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            educationButton.layer.cornerRadius = 12
            educationButton.layer.borderWidth = 1
            educationButton.layer.borderColor = UIColor.systemGreen.cgColor
        }
        educationButton.addTarget(self, action: #selector(showEducationHub), for: .touchUpInside)
        educationButton.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(startScanButton)
        contentView.addSubview(resultsButton)
        contentView.addSubview(profileButton)
        contentView.addSubview(educationButton)
    }
    
    private func setupSocialProofSection() {
        socialProofStackView.axis = .horizontal
        socialProofStackView.distribution = .equalSpacing
        socialProofStackView.alignment = .center
        socialProofStackView.spacing = 20
        socialProofStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(socialProofStackView)
        
        // Social proof elements
        let playersLabel = UILabel()
        playersLabel.text = "5,000+ Players"
        playersLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        playersLabel.textAlignment = .center
        playersLabel.textColor = .secondaryLabel
        
        let teamsLabel = UILabel()
        teamsLabel.text = "200+ Teams"
        teamsLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        teamsLabel.textAlignment = .center
        teamsLabel.textColor = .secondaryLabel
        
        let protectionLabel = UILabel()
        protectionLabel.text = "99.8% Accuracy"
        protectionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        protectionLabel.textAlignment = .center
        protectionLabel.textColor = .secondaryLabel
        
        socialProofStackView.addArrangedSubview(playersLabel)
        socialProofStackView.addArrangedSubview(teamsLabel)
        socialProofStackView.addArrangedSubview(protectionLabel)
    }
    
    private func setupFeaturesSection() {
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 16
        featuresStackView.alignment = .fill
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(featuresStackView)
        
        // Feature cards
        let features = [
            ("🎯 Precision Fit", "Custom measurements for your unique head shape"),
            ("🛡️ Rugby Protection", "Position-specific safety recommendations"),
            ("⚡ Fast Process", "Complete scan in under 3 minutes"),
            ("🖨️ 3D Printing", "Professional quality custom scrum caps")
        ]
        
        for (title, description) in features {
            let cardView = createFeatureCard(title: title, description: description)
            featuresStackView.addArrangedSubview(cardView)
        }
    }
    
    private func createFeatureCard(title: String, description: String) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemGray6
        cardView.layer.cornerRadius = 12
        cardView.layer.masksToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
        
        return cardView
    }
    
    private func setupInfoSection() {
        // Device status
        deviceStatusLabel.text = "Checking device compatibility..."
        deviceStatusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        deviceStatusLabel.adjustsFontForContentSizeCategory = true
        deviceStatusLabel.textAlignment = .center
        deviceStatusLabel.numberOfLines = 0
        deviceStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deviceStatusLabel)
    }
    
    private func setupConstraints() {
        // Disable autoresizing masks
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        valuePropositionLabel.translatesAutoresizingMaskIntoConstraints = false
        startScanButton.translatesAutoresizingMaskIntoConstraints = false
        resultsButton.translatesAutoresizingMaskIntoConstraints = false
        socialProofStackView.translatesAutoresizingMaskIntoConstraints = false
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        deviceStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // Hero image
            heroImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            heroImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            heroImageView.widthAnchor.constraint(equalToConstant: 140),
            heroImageView.heightAnchor.constraint(equalToConstant: 140),
            
            // Title section
            titleLabel.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: 25),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Value proposition
            valuePropositionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            valuePropositionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            valuePropositionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            valuePropositionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // Social proof
            socialProofStackView.topAnchor.constraint(equalTo: valuePropositionLabel.bottomAnchor, constant: 25),
            socialProofStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            socialProofStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Buttons
            startScanButton.topAnchor.constraint(equalTo: socialProofStackView.bottomAnchor, constant: 30),
            startScanButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            startScanButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            startScanButton.heightAnchor.constraint(equalToConstant: 60),
            
            resultsButton.topAnchor.constraint(equalTo: startScanButton.bottomAnchor, constant: 16),
            resultsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            resultsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            resultsButton.heightAnchor.constraint(equalToConstant: 50),
            
            profileButton.topAnchor.constraint(equalTo: resultsButton.bottomAnchor, constant: 16),
            profileButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            profileButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            profileButton.heightAnchor.constraint(equalToConstant: 50),
            
            educationButton.topAnchor.constraint(equalTo: profileButton.bottomAnchor, constant: 16),
            educationButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            educationButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            educationButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Features
            featuresStackView.topAnchor.constraint(equalTo: educationButton.bottomAnchor, constant: 30),
            featuresStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            featuresStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Info section
            deviceStatusLabel.topAnchor.constraint(equalTo: featuresStackView.bottomAnchor, constant: 30),
            deviceStatusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            deviceStatusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            deviceStatusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Device Compatibility
    
    private func checkDeviceCompatibility() {
        #if targetEnvironment(simulator)
        deviceStatusLabel.text = "⚠️ Simulator detected - TrueDepth camera not available"
        deviceStatusLabel.textColor = .systemOrange
        startScanButton.isEnabled = false
        startScanButton.backgroundColor = .systemGray
        startScanButton.setTitle("TrueDepth Camera Required", for: .normal)
        #else

        // Check for camera authorization
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            if hasTrueDepthCamera() {
                deviceStatusLabel.text = "✅ Device ready for 3D scanning"
                deviceStatusLabel.textColor = .systemGreen
            } else {
                deviceStatusLabel.text = "❌ Unsupported device — TrueDepth camera required"
                deviceStatusLabel.textColor = .systemRed
                startScanButton.isEnabled = false
                startScanButton.backgroundColor = .systemGray
            }
        case .notDetermined:
            deviceStatusLabel.text = "📷 Camera access required for scanning"
            deviceStatusLabel.textColor = .systemOrange
            requestCameraPermission()
        case .denied, .restricted:
            deviceStatusLabel.text = "❌ Camera access denied - Enable in Settings"
            deviceStatusLabel.textColor = .systemRed
            startScanButton.isEnabled = false
            startScanButton.backgroundColor = .systemGray
        @unknown default:
            deviceStatusLabel.text = "⚠️ Unknown camera status"
            deviceStatusLabel.textColor = .systemOrange
        }
        #endif
    }

    /// Require presence of a TrueDepth front camera.
    private func hasTrueDepthCamera() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) != nil
        #endif
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.checkDeviceCompatibility()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func startScanning() {
        #if targetEnvironment(simulator)
        showSimulatorAlert()
        #else
        // Check camera permission one more time
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            showCameraPermissionAlert()
            return
        }

        let scanningViewController = RefactoredScrumCapScanningViewController()
        scanningViewController.delegate = self
        scanningViewController.modalPresentationStyle = .fullScreen
        present(scanningViewController, animated: true)
        #endif
    }
    
    // showPreviousResults is implemented below to open the list view
    
    @objc private func showProfile() {
        let profileVC = PlayerProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    @objc private func showEducationHub() {
        let educationVC = EducationHubViewController()
        navigationController?.pushViewController(educationVC, animated: true)
    }
    
    @objc private func showSettings() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    // MARK: - Helpers
    
    private func showSimulatorAlert() {
        let alert = UIAlertController(
            title: "Simulator Not Supported",
            message: "CyborgRugby requires a physical iPhone X or later with TrueDepth camera for 3D head scanning.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "CyborgRugby needs camera access to perform 3D head scanning. Please enable camera access in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func updateUI() {
        resultsButton.isHidden = (lastScanResults == nil)
        if #available(iOS 15.0, *), var config = startScanButton.configuration {
            config.title = lastScanResults != nil ? "Start New 3D Scan" : "Start Free 3D Head Scan"
            startScanButton.configuration = config
        } else {
            startScanButton.setTitle(lastScanResults != nil ? "Start New 3D Scan" : "Start Free 3D Head Scan", for: .normal)
        }
    }
    
    private func loadPreviousScanResults() {
        if let saved = ResultsPersistence.load() {
            print("Loaded previous results: \(saved.timestamp)")
            resultsButton.isHidden = false
            deviceStatusLabel.text = "✅ Previous results found (\(DateFormatter.localizedString(from: saved.timestamp, dateStyle: .short, timeStyle: .short)))"
            deviceStatusLabel.textColor = .systemGreen
        }
    }
    
    private func saveScanResults(_ results: CompleteScanResult) {
        lastScanResults = results
        DispatchQueue.global(qos: .userInitiated).async {
            ResultsPersistence.save(result: results)
        }
        UserDefaults.standard.set(Date(), forKey: "LastRugbyScanDate")
        UserDefaults.standard.set(results.overallQuality, forKey: "LastScanQuality")
        updateUI()
    }
    
    private func calculateProtectionAnalysis(from scanResult: CompleteScanResult) -> EarProtectionAnalysis {
        let calculator = RugbyEarProtectionCalculator()
        return calculator.calculateEarProtection(from: scanResult.rugbyFitnessMeasurements)
    }
}

// MARK: - ScrumCapScanningViewControllerDelegate

extension MainViewController: ScrumCapScanningViewControllerDelegate {
    func scrumCapScanningDidCancel(_ controller: RefactoredScrumCapScanningViewController) {
        dismiss(animated: true)
    }
    
    func scrumCapScanning(_ controller: RefactoredScrumCapScanningViewController, didComplete result: CompleteScanResult) {
        // Save results
        saveScanResults(result)
        
        // Show results immediately
        let resultsVC = ScanResultsViewController()
        resultsVC.scanResult = result
        resultsVC.protectionAnalysis = calculateProtectionAnalysis(from: result)
        
        // Replace scanning controller with results
        controller.present(resultsVC, animated: false) {
            // After results are shown, dismiss the whole modal stack
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss(animated: true)
            }
        }
    }
    
    func scrumCapScanning(_ controller: RefactoredScrumCapScanningViewController, didFailWithError error: Error) {
        let alert = UIAlertController(
            title: "Scanning Failed",
            message: "The rugby scanning process failed: \(error.localizedDescription)\n\nPlease ensure you have good lighting and try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            // Stay in scanning mode for retry
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            controller.dismiss(animated: true)
        })
        controller.present(alert, animated: true)
    }
    @objc private func showPreviousResults() {
        let vc = ResultsListViewController(style: .insetGrouped)
        navigationController?.pushViewController(vc, animated: true)
    }
}