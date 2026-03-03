// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StandardCyborgFusion",
    platforms: [
        .iOS(.v16), .macOS(.v12)
    ],
    products: [
        .library(
            name: "StandardCyborgFusion",
            type: .dynamic,
            targets: ["StandardCyborgFusion"]
        ),
    ],
    dependencies: [
        .package(name: "scsdk", path: "../scsdk"),
        .package(name: "json", path: "../CppDependencies/json"),
        .package(name: "PoissonRecon", path: "../CppDependencies/PoissonRecon"),
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.4.0"),
        .package(name: "SparseICP", path: "../CppDependencies/SparseICP"),
        .package(name: "Eigen", path: "../CppDependencies/Eigen"),
        .package(name: "nanoflann", path: "../CppDependencies/nanoflann"),
        .package(name: "stb", path: "../CppDependencies/stb"),
        .package(name: "happly", path: "../CppDependencies/happly"),
        .package(name: "tinygltf", path: "../CppDependencies/tinygltf"),
        .package(name: "StandardCyborgUI", path: "../StandardCyborgUI"),
    ],
    targets: [
        .target(
            name: "StandardCyborgFusion",
            dependencies: [
                .product(name: "json", package: "json"),
                .product(name: "scsdk", package: "scsdk"),
                .product(name: "PoissonRecon", package: "PoissonRecon"),
                .product(name: "ZipArchive", package: "ZipArchive"),
                .product(name: "SparseICP", package: "SparseICP"),
                "Eigen",
                "nanoflann",
                "stb",
                "happly",
                "tinygltf",
                "StandardCyborgUI",
            ],
            path: "Sources",
            // resources: [
            //     .process("StandardCyborgFusion/Models/SCEarLandmarking.mlmodel"),
            //     .process("StandardCyborgFusion/Models/SCEarTrackingModel.mlmodel"),
            //     .process("StandardCyborgFusion/Models/SCFootTrackingModel.mlmodel"),
            // ],
            publicHeadersPath: "include",
            cxxSettings: [
                // Always optimize, even for debug builds, in order to be usable while debugging the rest of an app
                .unsafeFlags(["-fobjc-arc", "-Os", "-fno-math-errno", "-ffast-math"]),
                .headerSearchPath("."),
                .headerSearchPath("../libigl/include"),
                .headerSearchPath("StandardCyborgFusion/Algorithm"),
                .headerSearchPath("StandardCyborgFusion/DataStructures"),
                .headerSearchPath("StandardCyborgFusion/EarLandmarking"),
                .headerSearchPath("StandardCyborgFusion/Helpers"),
                .headerSearchPath("StandardCyborgFusion/IO"),
                .headerSearchPath("StandardCyborgFusion/MetalDepthProcessor"),
                .headerSearchPath("StandardCyborgFusion/Private"),
                .headerSearchPath("include/StandardCyborgFusion"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit"),
                .linkedFramework("Security"), // ZipArchive may need Security framework
            ]
        ),
        .testTarget(
            name: "StandardCyborgFusionTests",
            dependencies: ["StandardCyborgFusion"],
            path: "Tests",
            resources: [
                .copy("StandardCyborgFusionTests/Data")
            ],
            cxxSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("PROJECT_DIR", to: "\".\""),
                .unsafeFlags(["-fobjc-arc"]),
                .headerSearchPath("."),
                .headerSearchPath("../libigl/include"),
                .headerSearchPath("../Sources/StandardCyborgFusion/Algorithm"),
                .headerSearchPath("../Sources/StandardCyborgFusion/DataStructures"),
                .headerSearchPath("../Sources/StandardCyborgFusion/Helpers"),
                .headerSearchPath("../Sources/StandardCyborgFusion/IO"),
                .headerSearchPath("../Sources/StandardCyborgFusion/MetalDepthProcessor"),
                .headerSearchPath("../Sources/StandardCyborgFusion/Private"),
                .headerSearchPath("../Sources/include/StandardCyborgFusion"),
            ],
            linkerSettings: [
                .linkedFramework("XCTest"),
            ]
        )
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx17
)

