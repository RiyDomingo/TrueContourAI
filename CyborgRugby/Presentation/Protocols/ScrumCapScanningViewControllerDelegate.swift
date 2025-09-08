//
//  ScrumCapScanningViewControllerDelegate.swift
//  CyborgRugby
//
//  Delegate protocol for rugby scrum cap scanning completion
//

import Foundation

protocol ScrumCapScanningViewControllerDelegate: AnyObject {
    /// Called when the user cancels the scanning process
    func scrumCapScanningDidCancel(_ controller: ScrumCapScanningViewController)
    
    /// Called when scanning completes successfully with results
    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didComplete result: CompleteScanResult)
    
    /// Called when scanning fails with an error
    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didFailWithError error: Error)
}

// MARK: - Optional delegate methods
extension ScrumCapScanningViewControllerDelegate {
    func scrumCapScanning(_ controller: ScrumCapScanningViewController, didFailWithError error: Error) {
        // Default implementation - can be overridden
        print("Rugby scanning failed: \(error)")
    }
}