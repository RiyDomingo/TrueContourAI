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
    
    // Scan history item - simplified to avoid Codable issues
    struct ScanHistoryItem: Codable {
        let id: String
        let date: Date
        let quality: Float
        let duration: Int
        // Store essential measurement data instead of complex objects
        let headCircumference: Float?
        let leftEarHeight: Float?
        let rightEarHeight: Float?
        
        // Simplified initializer that doesn't depend on external types
        init(id: String, date: Date, quality: Float, duration: Int, 
             headCircumference: Float?, leftEarHeight: Float?, rightEarHeight: Float?) {
            self.id = id
            self.date = date
            self.quality = quality
            self.duration = duration
            self.headCircumference = headCircumference
            self.leftEarHeight = leftEarHeight
            self.rightEarHeight = rightEarHeight
        }
    }
    
    // Save scan result to history - simplified to avoid dependency on CompleteScanResult
    func saveScan(id: String, date: Date, quality: Float, duration: Int, 
                  headCircumference: Float?, leftEarHeight: Float?, rightEarHeight: Float?) {
        // Input validation
        guard !id.isEmpty, quality >= 0.0 && quality <= 1.0, duration > 0 else {
            #if DEBUG
            print("Invalid scan data provided to saveScan")
            #endif
            return
        }
        
        var history = loadScanHistory()
        
        let historyItem = ScanHistoryItem(
            id: id,
            date: date,
            quality: quality,
            duration: duration,
            headCircumference: headCircumference,
            leftEarHeight: leftEarHeight,
            rightEarHeight: rightEarHeight
        )
        
        history.append(historyItem)
        
        // Keep only the last 50 scans to prevent unbounded growth
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
            return history.sorted { $0.date > $1.date } // Return most recent first
        } catch {
            // Log error properly instead of using print
            #if DEBUG
            print("Error decoding scan history: \(error)")
            #endif
            return []
        }
    }
    
    // Save scan history
    private func saveScanHistory(_ history: [ScanHistoryItem]) {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: "ScanHistory")
        } catch {
            // Log error properly instead of using print
            #if DEBUG
            print("Error encoding scan history: \(error)")
            #endif
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