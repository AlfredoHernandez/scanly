// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "ScanlyEngine",
	defaultLocalization: "en",
	platforms: [
		.iOS(.v26),
	],
	products: [
		.library(name: "ScanlyEngine", targets: ["ScanlyEngine"]),
		// Test doubles, fixtures, and async helpers shared between
		// ScanlyEngineTests and ScanlyUITests. Test code only — never
		// linked into the app target.
		.library(name: "ScanlyEngineTestSupport", targets: ["ScanlyEngineTestSupport"]),
	],
	targets: [
		.target(name: "ScanlyEngine"),
		.target(name: "ScanlyEngineTestSupport", dependencies: ["ScanlyEngine"]),
		.testTarget(
			name: "ScanlyEngineTests",
			dependencies: ["ScanlyEngine", "ScanlyEngineTestSupport"],
		),
	],
)
