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

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "graduationcap"),
            style: .plain,
            target: self,
            action: #selector(showEducationHub)
        )

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
        socialProofStackView.spacing = 12
        socialProofStackView.alignment = .center
        socialProofStackView.distribution = .fillEqually
        socialProofStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(socialProofStackView)

        let items = [
            ("⚡", "30 sec setup"),
            ("🎯", "Better fit"),
            ("🛡️", "Ear safe")
        ]

        for (emoji, text) in items {
            let label = UILabel()
            label.text = "\(emoji) \(text)"
            label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.numberOfLines = 2
            socialProofStackView.addArrangedSubview(label)
        }
    }

    private func setupFeaturesSection() {
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 10
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(featuresStackView)

        let features = [
            "✅ TrueDepth 3D scanning (StandardCyborg engine)",
            "✅ Rugby-specific fit + ear protection analysis",
            "✅ Stores scans in Documents/Scans",
            "✅ Generates scrum cap measurements"
        ]

        for feature in features {
            let label = UILabel()
            label.text = feature
            label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            label.textColor = .label
            label.numberOfLines = 0
            featuresStackView.addArrangedSubview(label)
        }
    }

    private func setupInfoSection() {
        deviceStatusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        deviceStatusLabel.textColor = .secondaryLabel
        deviceStatusLabel.numberOfLines = 0
        deviceStatusLabel.textAlignment = .center
        deviceStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deviceStatusLabel)
    }

    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            heroImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            heroImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            heroImageView.widthAnchor.constraint(equalToConstant: 160),
            heroImageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            valuePropositionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            valuePropositionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            valuePropositionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            valuePropositionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            startScanButton.topAnchor.constraint(equalTo: valuePropositionLabel.bottomAnchor, constant: 18),
            startScanButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            startScanButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            startScanButton.heightAnchor.constraint(equalToConstant: 56),

            resultsButton.topAnchor.constraint(equalTo: startScanButton.bottomAnchor, constant: 12),
            resultsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultsButton.heightAnchor.constraint(equalToConstant: 48),

            profileButton.topAnchor.constraint(equalTo: resultsButton.bottomAnchor, constant: 12),
            profileButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            profileButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            profileButton.heightAnchor.constraint(equalToConstant: 48),

            educationButton.topAnchor.constraint(equalTo: profileButton.bottomAnchor, constant: 12),
            educationButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            educationButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            educationButton.heightAnchor.constraint(equalToConstant: 48),

            socialProofStackView.topAnchor.constraint(equalTo: educationButton.bottomAnchor, constant: 16),
            socialProofStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            socialProofStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            featuresStackView.topAnchor.constraint(equalTo: socialProofStackView.bottomAnchor, constant: 18),
            featuresStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            featuresStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            deviceStatusLabel.topAnchor.constraint(equalTo: featuresStackView.bottomAnchor, constant: 18),
            deviceStatusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            deviceStatusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            deviceStatusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Device Compatibility

    private func checkDeviceCompatibility() {
        #if targetEnvironment(simulator)
        deviceStatusLabel.text = "⚠️ Simulator: TrueDepth scanning requires a real iPhone."
        startScanButton.isEnabled = false
        return
        #else
        let hasTrueDepth = !AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        ).devices.isEmpty

        if !hasTrueDepth {
            deviceStatusLabel.text = "❌ TrueDepth camera not detected. Use an iPhone with Face ID."
            startScanButton.isEnabled = false
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            deviceStatusLabel.text = "✅ Ready for TrueDepth scanning"
            startScanButton.isEnabled = true
        case .notDetermined:
            deviceStatusLabel.text = "⏳ Camera permission needed"
            requestCameraPermission()
        default:
            deviceStatusLabel.text = "⚠️ Camera permission denied — enable in Settings"
            startScanButton.isEnabled = true // allow tap; we’ll show settings prompt
        }
        #endif
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            DispatchQueue.main.async { self?.checkDeviceCompatibility() }
        }
    }

    // MARK: - Actions

    @objc private func startScanning() {
        #if targetEnvironment(simulator)
        showSimulatorAlert()
        #else
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            showCameraPermissionAlert()
            return
        }

        let scanningVC = ScrumCapScanningViewController()
        scanningVC.delegate = self
        scanningVC.modalPresentationStyle = .fullScreen
        present(scanningVC, animated: true)
        #endif
    }

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

    @objc private func showPreviousResults() {
        let vc = ResultsListViewController(style: .insetGrouped)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Helpers

    private func showSimulatorAlert() {
        let alert = UIAlertController(
            title: "Simulator Not Supported",
            message: "CyborgRugby requires a physical iPhone with TrueDepth camera for 3D head scanning.",
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
            resultsButton.isHidden = false
            deviceStatusLabel.text = "✅ Previous results found (\(DateFormatter.localizedString(from: saved.timestamp, dateStyle: .short, timeStyle: .short)))"
        }
    }

    private func saveScanResults(_ results: CompleteScanResult) {
        lastScanResults = results
        ResultsPersistence.save(result: results)
        updateUI()
    }

    private func calculateProtectionAnalysis(from scanResult: CompleteScanResult) -> EarProtectionAnalysis {
        let calculator = RugbyEarProtectionCalculator()
        return calculator.calculateEarProtection(from: scanResult.rugbyFitnessMeasurements)
    }
}

// MARK: - ScrumCapScanningViewControllerDelegate

extension MainViewController: ScrumCapScanningViewControllerDelegate {

    func scrumCapScanningDidCancel(_ controller: ScrumCapScanningViewController) {
        controller.dismiss(animated: true)
    }

    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didComplete result: CompleteScanResult) {
        saveScanResults(result)

        let resultsVC = ScanResultsViewController()
        resultsVC.scanResult = result
        resultsVC.protectionAnalysis = calculateProtectionAnalysis(from: result)

        controller.dismiss(animated: true) { [weak self] in
            self?.navigationController?.pushViewController(resultsVC, animated: true)
        }
    }

    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didFailWithError error: Error) {
        let alert = UIAlertController(
            title: "Scanning Issue",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        controller.present(alert, animated: true)
    }
}
