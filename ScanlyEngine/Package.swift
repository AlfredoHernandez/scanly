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
	],
	targets: [
		.target(name: "ScanlyEngine"),
		.testTarget(name: "ScanlyEngineTests", dependencies: ["ScanlyEngine"]),
	],
)
