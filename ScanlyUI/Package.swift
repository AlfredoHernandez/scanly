// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "ScanlyUI",
	defaultLocalization: "en",
	platforms: [
		.iOS(.v26),
	],
	products: [
		.library(name: "ScanlyUI", targets: ["ScanlyUI"]),
	],
	dependencies: [
		.package(name: "ScanlyEngine", path: "../ScanlyEngine"),
	],
	targets: [
		.target(
			name: "ScanlyUI",
			dependencies: ["ScanlyEngine"],
			resources: [.process("Resources")],
		),
		.testTarget(
			name: "ScanlyUITests",
			dependencies: [
				"ScanlyUI",
				.product(name: "ScanlyEngineTestSupport", package: "ScanlyEngine"),
			],
		),
	],
)
