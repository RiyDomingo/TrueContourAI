import Foundation
import os

func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

enum Log {
    static let subsystem = "com.standardcyborg.TrueContourAI"
    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let export = Logger(subsystem: subsystem, category: "export")
    static let ml = Logger(subsystem: subsystem, category: "ml")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let camera = Logger(subsystem: subsystem, category: "camera")
    static let scanning = Logger(subsystem: subsystem, category: "scanning")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
