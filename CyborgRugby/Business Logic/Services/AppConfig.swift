import Foundation

struct AppConfig: Codable {
    struct Fusion: Codable {
        var cropBelowNeck: Bool
        var neckOffsetMeters: Float
        var outlierSigma: Float
        var decimateRatio: Float
        var preScaleToMillimeters: Bool
    }
    struct Meshing: Codable {
        var resolution: Int
        var smoothness: Int
        var surfaceTrimmingAmount: Int
        var closed: Bool
        var exportOBJZip: Bool
        var exportGLB: Bool
    }

    var fusion: Fusion
    var meshing: Meshing

    static let `default` = AppConfig(
        fusion: Fusion(cropBelowNeck: true, neckOffsetMeters: 0.15, outlierSigma: 3.0, decimateRatio: 1.0, preScaleToMillimeters: true),
        meshing: Meshing(resolution: 6, smoothness: 3, surfaceTrimmingAmount: 4, closed: true, exportOBJZip: true, exportGLB: true)
    )

    static var shared: AppConfig = {
        let url = Bundle.main.url(forResource: "Config", withExtension: "plist")
        if let url = url, let data = try? Data(contentsOf: url) {
            if let cfg = try? PropertyListDecoder().decode(AppConfig.self, from: data) {
                return cfg
            }
        }
        return .default
    }()
}

