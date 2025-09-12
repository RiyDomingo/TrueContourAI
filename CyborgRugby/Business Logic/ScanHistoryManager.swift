//
//  ScanHistoryManager.swift
//  CyborgRugby
//
//  Scan history management
//

import Foundation

class ScanHistoryManager {
    static let shared = ScanHistoryManager()
    
    private init() {}
    
    // Scan history item
    struct ScanHistoryItem: Codable {
        let id: String
        let date: Date
        let quality: Float
        let duration: Int
        let measurements: ScrumCapMeasurements?
        
        init(date: Date, quality: Float, duration: Int, measurements: ScrumCapMeasurements? = nil) {
            self.id = UUID().uuidString
            self.date = date
            self.quality = quality
            self.duration = duration
            self.measurements = measurements
        }
    }
    
    // Save scan result to history
    func saveScanResult(_ result: CompleteScanResult) {
        var history = loadScanHistory()
        
        let historyItem = ScanHistoryItem(
            date: result.timestamp,
            quality: result.overallQuality,
            duration: Int(result.totalScanTime),
            measurements: result.rugbyFitnessMeasurements
        )
        
        history.append(historyItem)
        
        // Keep only the last 50 scans
        if history.count > 50 {
            history.removeFirst(history.count - 50)
        }
        
        saveScanHistory(history)
    }
    
    // Load scan history
    func loadScanHistory() -> [ScanHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: "ScanHistory") else {
            return []
        }
        
        do {
            let history = try JSONDecoder().decode([ScanHistoryItem].self, from: data)
            return history
        } catch {
            print("Error decoding scan history: \(error)")
            return []
        }
    }
    
    // Save scan history
    private func saveScanHistory(_ history: [ScanHistoryItem]) {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: "ScanHistory")
        } catch {
            print("Error encoding scan history: \(error)")
        }
    }
    
    // Clear scan history
    func clearScanHistory() {
        UserDefaults.standard.removeObject(forKey: "ScanHistory")
    }
    
    // Get scan history count
    func getScanHistoryCount() -> Int {
        return loadScanHistory().count
    }
    
    // Get latest scan
    func getLatestScan() -> ScanHistoryItem? {
        let history = loadScanHistory()
        return history.last
    }
}