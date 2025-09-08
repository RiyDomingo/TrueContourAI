//
//  Enhanced ViewController for CyborgRugby Integration
//  StandardCyborgExample
//
//  Integrates rugby scrum cap scanning alongside existing StandardCyborg functionality
//

import StandardCyborgUI
import StandardCyborgFusion
import UIKit

class ViewController: UIViewController {
    @IBOutlet private weak var showScanButton: UIButton!
    
    // CyborgRugby Integration
    private var rugbyButton: UIButton!
    private var rugbyResultsButton: UIButton!
    private var lastRugbyResults: CompleteScanResult?
        
    private var lastScene: SCScene?
    private var lastSceneDate: Date?
    private var lastSceneThumbnail: UIImage?
    private var scenePreviewVC: ScenePreviewViewController?
    
    private lazy var documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private lazy var sceneGltfURL = documentsURL.appendingPathComponent("scene.gltf")
    private lazy var sceneThumbnailURL = documentsURL.appendingPathComponent("scene.png")
    private lazy var rugbyResultsURL = documentsURL.appendingPathComponent("rugby_results.json")

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupOriginalUI()
        setupCyborgRugbyUI()
        loadScene()
        loadRugbyResults()
    }
    
    private func setupOriginalUI() {
        showScanButton.layer.borderColor = UIColor.white.cgColor
        showScanButton.imageView?.contentMode = .scaleAspectFill
    }
    
    private func setupCyborgRugbyUI() {
        // Create rugby scanning button
        rugbyButton = UIButton(type: .system)
        rugbyButton.setTitle("🏉 Rugby Scrum Cap Scan", for: .normal)
        rugbyButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        rugbyButton.backgroundColor = UIColor.systemGreen
        rugbyButton.setTitleColor(.white, for: .normal)
        rugbyButton.layer.cornerRadius = 12
        rugbyButton.addTarget(self, action: #selector(startRugbyScanning), for: .touchUpInside)
        
        // Create rugby results button
        rugbyResultsButton = UIButton(type: .system)
        rugbyResultsButton.setTitle("View Rugby Results", for: .normal)
        rugbyResultsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        rugbyResultsButton.backgroundColor = UIColor.systemBlue
        rugbyResultsButton.setTitleColor(.white, for: .normal)
        rugbyResultsButton.layer.cornerRadius = 8
        rugbyResultsButton.addTarget(self, action: #selector(showRugbyResults), for: .touchUpInside)
        rugbyResultsButton.isHidden = true // Hidden until we have results
        
        // Add buttons to view
        view.addSubview(rugbyButton)
        view.addSubview(rugbyResultsButton)
        
        // Setup constraints
        rugbyButton.translatesAutoresizingMaskIntoConstraints = false
        rugbyResultsButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Rugby scan button - positioned above the existing showScanButton
            rugbyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rugbyButton.bottomAnchor.constraint(equalTo: showScanButton.topAnchor, constant: -20),
            rugbyButton.widthAnchor.constraint(equalToConstant: 280),
            rugbyButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Rugby results button - positioned below rugby scan button
            rugbyResultsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rugbyResultsButton.topAnchor.constraint(equalTo: rugbyButton.bottomAnchor, constant: 10),
            rugbyResultsButton.widthAnchor.constraint(equalToConstant: 200),
            rugbyResultsButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - CyborgRugby Integration
    
    @objc private func startRugbyScanning() {
        #if targetEnvironment(simulator)
        let alert = UIAlertController(
            title: "Simulator Unsupported", 
            message: "Rugby scrum cap scanning requires a TrueDepth camera. Please build and run on an iPhone X or later.", 
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
        #else
        
        // Check for TrueDepth camera availability
        guard checkTrueDepthSupport() else {
            let alert = UIAlertController(
                title: "Device Not Supported",
                message: "Rugby scrum cap scanning requires an iPhone X or later with TrueDepth camera.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let rugbyScanningVC = ScrumCapScanningViewController()
        rugbyScanningVC.delegate = self
        rugbyScanningVC.modalPresentationStyle = .fullScreen
        present(rugbyScanningVC, animated: true)
        #endif
    }
    
    @objc private func showRugbyResults() {
        guard let results = lastRugbyResults else { return }
        
        let resultsVC = ScanResultsViewController()
        resultsVC.scanResult = results
        resultsVC.protectionAnalysis = calculateProtectionAnalysis(from: results)
        resultsVC.modalPresentationStyle = .fullScreen
        present(resultsVC, animated: true)
    }
    
    private func checkTrueDepthSupport() -> Bool {
        // Check if device has TrueDepth camera
        // This is a simplified check - in production you'd use AVCaptureDevice
        return !ProcessInfo.processInfo.environment.keys.contains("SIMULATOR_DEVICE_NAME")
    }
    
    private func calculateProtectionAnalysis(from scanResult: CompleteScanResult) -> EarProtectionAnalysis {
        let calculator = RugbyEarProtectionCalculator()
        return calculator.calculateEarProtection(from: scanResult.rugbyFitnessMeasurements)
    }
    
    // MARK: - Rugby Results Persistence
    
    private func saveRugbyResults(_ results: CompleteScanResult) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            // Create a simplified version for JSON serialization
            let rugbyData: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: results.timestamp),
                "overallQuality": results.overallQuality,
                "successfulPoses": results.successfulPoses,
                "totalScanTime": results.totalScanTime,
                "headCircumference": results.rugbyFitnessMeasurements.headCircumference.value,
                "leftEarHeight": results.rugbyFitnessMeasurements.leftEarDimensions.height.value,
                "rightEarHeight": results.rugbyFitnessMeasurements.rightEarDimensions.height.value,
                "recommendedSize": results.rugbyFitnessMeasurements.recommendedSize.rawValue,
                "qualityDescription": results.qualityDescription
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: rugbyData)
            try jsonData.write(to: rugbyResultsURL)
            
            lastRugbyResults = results
            updateRugbyUI()
            
        } catch {
            print("Failed to save rugby results: \(error)")
        }
    }
    
    private func loadRugbyResults() {
        guard FileManager.default.fileExists(atPath: rugbyResultsURL.path) else { return }
        
        do {
            let jsonData = try Data(contentsOf: rugbyResultsURL)
            let rugbyData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            if let data = rugbyData {
                // Create a mock CompleteScanResult for display
                // In production, you'd want a more robust serialization system
                print("Loaded rugby results from: \(data["timestamp"] ?? "unknown")")
                print("Quality: \(data["qualityDescription"] ?? "unknown")")
                print("Recommended size: \(data["recommendedSize"] ?? "unknown")")
                
                // For now, just update UI to show we have results
                updateRugbyUI()
            }
            
        } catch {
            print("Failed to load rugby results: \(error)")
        }
    }
    
    private func updateRugbyUI() {
        let hasResults = FileManager.default.fileExists(atPath: rugbyResultsURL.path)
        rugbyResultsButton.isHidden = !hasResults
        
        if hasResults {
            rugbyButton.setTitle("🏉 New Rugby Scan", for: .normal)
        } else {
            rugbyButton.setTitle("🏉 Rugby Scrum Cap Scan", for: .normal)
        }
    }
    
    // MARK: - Original StandardCyborg functionality (unchanged)
    
    @IBAction private func startScanning(_ sender: UIButton) {
        #if targetEnvironment(simulator)
        let alert = UIAlertController(title: "Simulator Unsupported", message: "There is no depth camera available on the iOS Simulator. Please build and run on an iOS device with TrueDepth", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
        #else
        let scanningVC = ScanningViewController()
        scanningVC.delegate = self
        scanningVC.generatesTexturedMeshes = true
        scanningVC.modalPresentationStyle = .fullScreen
        present(scanningVC, animated: true)
        #endif
    }
    
    @IBAction private func showScan(_ sender: UIButton) {
        guard let scScene = lastScene else { return }
        
        let vc = ScenePreviewViewController(scScene: scScene)
        vc.leftButton.addTarget(self, action: #selector(deletePreviewedSceneTapped), for: UIControl.Event.touchUpInside)
        vc.rightButton.addTarget(self, action: #selector(dismissPreviewedScanTapped), for: UIControl.Event.touchUpInside)
        vc.leftButton.setTitle("Delete", for: UIControl.State.normal)
        vc.rightButton.setTitle("Dismiss", for: UIControl.State.normal)
        vc.leftButton.backgroundColor = UIColor(named: "DestructiveAction")
        vc.rightButton.backgroundColor = UIColor(named: "DefaultAction")
        vc.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        scenePreviewVC = vc
        present(vc, animated: true)
    }
        
    @objc private func deletePreviewedSceneTapped() {
        deleteScene()
        dismiss(animated: true)
    }
    
    @objc private func dismissPreviewedScanTapped() {
        dismiss(animated: false)
    }
    
    @objc private func savePreviewedSceneTapped() {
        saveScene(scene: scenePreviewVC!.scScene, thumbnail: scenePreviewVC?.renderedSceneImage)
        dismiss(animated: true)
    }
    
    // MARK: - Scene I/O
    
    private func loadScene() {
        if
            FileManager.default.fileExists(atPath: sceneGltfURL.path),
            let gltfAttributes = try? FileManager.default.attributesOfItem(atPath: sceneGltfURL.path),
            let dateCreated = gltfAttributes[FileAttributeKey.creationDate] as? Date
        {
            lastScene = SCScene(gltfAtPath: sceneGltfURL.path)
            lastSceneDate = dateCreated
            lastSceneThumbnail = UIImage(contentsOfFile: sceneThumbnailURL.path)
        }
        
        updateUI()
    }
    
    private func saveScene(scene: SCScene, thumbnail: UIImage?) {
        scene.writeToGLTF(atPath: sceneGltfURL.path)
        
        if let thumbnail = thumbnail, let pngData = thumbnail.pngData() {
            try? pngData.write(to: sceneThumbnailURL)
        }
        
        lastScene = scene
        lastSceneThumbnail = thumbnail
        lastSceneDate = Date()
        
        updateUI()
    }
    
    private func deleteScene() {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: sceneGltfURL.path) {
            try? fileManager.removeItem(at: sceneGltfURL)
        }
        
        if fileManager.fileExists(atPath: sceneThumbnailURL.path) {
            try? fileManager.removeItem(at: sceneThumbnailURL)
        }
        
        lastScene = nil
        lastSceneThumbnail = nil
        lastSceneDate = nil
        
        updateUI()
    }
    
    // MARK: - Helpers
        
    private func updateUI() {
        if lastSceneThumbnail == nil {
            showScanButton.layer.borderWidth = 0
            showScanButton.setTitle("no scan yet", for: UIControl.State.normal)
        } else {
            showScanButton.layer.borderWidth = 1
            showScanButton.setTitle(nil, for: UIControl.State.normal)
        }
        
        showScanButton.setImage(lastSceneThumbnail, for: UIControl.State.normal)
    }
}

// MARK: - StandardCyborg Scanning Delegate

extension ViewController: ScanningViewControllerDelegate {
    func scanningViewControllerDidCancel(_ controller: ScanningViewController) {
        dismiss(animated: true)
    }
    
    func scanningViewController(_ controller: ScanningViewController, didScan pointCloud: SCPointCloud) {
        let vc = ScenePreviewViewController(pointCloud: pointCloud, meshTexturing: controller.meshTexturing, landmarks: nil)
        vc.leftButton.addTarget(self, action: #selector(dismissPreviewedScanTapped), for: UIControl.Event.touchUpInside)
        vc.rightButton.addTarget(self, action: #selector(savePreviewedSceneTapped), for: UIControl.Event.touchUpInside)
        vc.leftButton.setTitle("Rescan", for: UIControl.State.normal)
        vc.rightButton.setTitle("Save", for: UIControl.State.normal)
        vc.leftButton.backgroundColor = UIColor(named: "DestructiveAction")
        vc.rightButton.backgroundColor = UIColor(named: "SaveAction")
        scenePreviewVC = vc
        controller.present(vc, animated: false)
    }
}

// MARK: - CyborgRugby Scanning Delegate

extension ViewController: ScrumCapScanningViewControllerDelegate {
    func scrumCapScanningDidCancel(_ controller: ScrumCapScanningViewController) {
        dismiss(animated: true)
    }
    
    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didComplete result: CompleteScanResult) {
        // Save rugby results
        saveRugbyResults(result)
        
        // Show results immediately
        let resultsVC = ScanResultsViewController()
        resultsVC.scanResult = result
        resultsVC.protectionAnalysis = calculateProtectionAnalysis(from: result)
        
        // Replace the scanning controller with results
        controller.present(resultsVC, animated: false)
    }
    
    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didFailWithError error: Error) {
        let alert = UIAlertController(
            title: "Scanning Failed",
            message: "Rugby scanning failed: \(error.localizedDescription)\n\nPlease try again in good lighting with a clear view of your face.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        controller.present(alert, animated: true)
    }
}

private extension URL {
    static let documentsURL: URL = {
        guard let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, false).first
            else { fatalError("Failed to find the documents directory") }
        
        // Annoyingly, this gives us the directory path with a ~ in it, so we have to expand it
        let tildeExpandedDocumentsDirectory = (documentsDirectory as NSString).expandingTildeInPath
        
        return URL(fileURLWithPath: tildeExpandedDocumentsDirectory)
    }()
}