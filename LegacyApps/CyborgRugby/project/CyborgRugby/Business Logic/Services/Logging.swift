import Foundation
import OSLog

enum AppLog {
    static let ui = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "ui")
    static let scan = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "scan")
    static let ml = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "ml")
    static let persistence = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "persistence")
    static let camera = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "camera")
    static let scanning = Logger(subsystem: "com.standardcyborg.CyborgRugby", category: "scanning")
}

