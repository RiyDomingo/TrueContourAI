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
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let rugbyImageView = UIImageView()
    private let startScanButton = UIButton()
    private let infoStackView = UIStackView()
    private let deviceStatusLabel = UILabel()
    private let resultsButton = UIButton()
    
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
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupTitleSection()
        setupImageSection()
        setupButtonSection()
        setupInfoSection()
        setupConstraints()
    }
    
    private func setupTitleSection() {
        titleLabel.text = "🏉 Rugby Scrum Cap Fitting"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        subtitleLabel.text = "AI-powered 3D scanning for perfect scrum cap fit"
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
    }
    
    private func setupImageSection() {
        rugbyImageView.image = UIImage(systemName: "sportscourt")
        rugbyImageView.tintColor = .systemGreen
        rugbyImageView.contentMode = .scaleAspectFit
        rugbyImageView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        rugbyImageView.layer.cornerRadius = 12
        
        contentView.addSubview(rugbyImageView)
    }
    
    private func setupButtonSection() {
        // Main scan button
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "Start 3D Head Scan"
            config.image = UIImage(systemName: "camera.viewfinder")
            config.imagePadding = 8
            config.cornerStyle = .large
            config.baseBackgroundColor = .systemGreen
            config.baseForegroundColor = .white
            startScanButton.configuration = config
        } else {
            startScanButton.setTitle("Start 3D Head Scan", for: .normal)
            startScanButton.setTitleColor(.white, for: .normal)
            startScanButton.backgroundColor = .systemGreen
            startScanButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            startScanButton.layer.cornerRadius = 12
            startScanButton.layer.shadowColor = UIColor.black.cgColor
            startScanButton.layer.shadowOffset = CGSize(width: 0, height: 2)
            startScanButton.layer.shadowRadius = 4
            startScanButton.layer.shadowOpacity = 0.1
        }
        startScanButton.addTarget(self, action: #selector(startScanning), for: .touchUpInside)
        startScanButton.accessibilityIdentifier = "home.startScan"
        startScanButton.accessibilityLabel = "Start 3D head scan"
        
        // Results button (initially hidden)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "View Previous Results"
            config.image = UIImage(systemName: "clock.arrow.circlepath")
            config.imagePadding = 6
            config.cornerStyle = .large
            resultsButton.configuration = config
        } else {
            resultsButton.setTitle("View Previous Results", for: .normal)
            resultsButton.setTitleColor(.systemBlue, for: .normal)
            resultsButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            resultsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            resultsButton.layer.cornerRadius = 8
            resultsButton.layer.borderWidth = 1
            resultsButton.layer.borderColor = UIColor.systemBlue.cgColor
        }
        resultsButton.addTarget(self, action: #selector(showPreviousResults), for: .touchUpInside)
        resultsButton.accessibilityIdentifier = "home.previousResults"
        resultsButton.accessibilityLabel = "View previous results"
        resultsButton.isHidden = true
        
        contentView.addSubview(startScanButton)
        contentView.addSubview(resultsButton)
    }
    
    private func setupInfoSection() {
        infoStackView.axis = .vertical
        infoStackView.spacing = 12
        infoStackView.alignment = .center
        
        // Device status
        deviceStatusLabel.text = "Checking device compatibility..."
        deviceStatusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        deviceStatusLabel.adjustsFontForContentSizeCategory = true
        deviceStatusLabel.textAlignment = .center
        deviceStatusLabel.numberOfLines = 0
        
        // Info items
        let infoItems = [
            "📷 Requires iPhone X or later with TrueDepth camera",
            "⏱️ Takes about 2-3 minutes to complete",
            "📏 Measures head and ear dimensions with ML precision",
            "🛡️ Calculates rugby-specific protection requirements",
            "📊 Provides size recommendations and fitting advice"
        ]
        
        for item in infoItems {
            let label = UILabel()
            label.text = item
            label.font = UIFont.preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 0
            infoStackView.addArrangedSubview(label)
        }
        
        infoStackView.addArrangedSubview(deviceStatusLabel)
        contentView.addSubview(infoStackView)
    }
    
    private func setupConstraints() {
        // Disable autoresizing masks
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        rugbyImageView.translatesAutoresizingMaskIntoConstraints = false
        startScanButton.translatesAutoresizingMaskIntoConstraints = false
        resultsButton.translatesAutoresizingMaskIntoConstraints = false
        infoStackView.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // Title section
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Image
            rugbyImageView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            rugbyImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            rugbyImageView.widthAnchor.constraint(equalToConstant: 120),
            rugbyImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Buttons
            startScanButton.topAnchor.constraint(equalTo: rugbyImageView.bottomAnchor, constant: 40),
            startScanButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            startScanButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            startScanButton.heightAnchor.constraint(equalToConstant: 54),
            
            resultsButton.topAnchor.constraint(equalTo: startScanButton.bottomAnchor, constant: 12),
            resultsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            resultsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            resultsButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Info section
            infoStackView.topAnchor.constraint(equalTo: resultsButton.bottomAnchor, constant: 30),
            infoStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            infoStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
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

        let scanningViewController = ScrumCapScanningViewController()
        scanningViewController.delegate = self
        scanningViewController.modalPresentationStyle = .fullScreen
        present(scanningViewController, animated: true)
        #endif
    }
    
    // showPreviousResults is implemented below to open the list view
    
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
            config.title = lastScanResults != nil ? "Start New 3D Scan" : "Start 3D Head Scan"
            startScanButton.configuration = config
        } else {
            startScanButton.setTitle(lastScanResults != nil ? "Start New 3D Scan" : "Start 3D Head Scan", for: .normal)
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
    func scrumCapScanningDidCancel(_ controller: ScrumCapScanningViewController) {
        dismiss(animated: true)
    }
    
    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didComplete result: CompleteScanResult) {
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
    
    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didFailWithError error: Error) {
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
