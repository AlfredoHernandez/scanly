//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import AVFoundation
import Testing
import Vision

struct AVMetadataObjectTypeBarcodeFormatTests {
	@Test(arguments: [
		(AVMetadataObject.ObjectType.qr, BarcodeFormat.qr),
		(.dataMatrix, .dataMatrix),
		(.pdf417, .pdf417),
		(.aztec, .aztec),
		(.code128, .code128),
		(.code39, .code39),
		(.ean13, .ean13),
		(.ean8, .ean8),
		(.upce, .upce),
	])
	func `maps each supported AVFoundation symbology to its BarcodeFormat`(
		input: AVMetadataObject.ObjectType, expected: BarcodeFormat,
	) {
		#expect(input.barcodeFormat == expected)
	}

	@Test(arguments: [
		AVMetadataObject.ObjectType.face,
		.code93,
		.interleaved2of5,
		.itf14,
	])
	func `unrecognized AVFoundation symbologies fall back to other`(input: AVMetadataObject.ObjectType) {
		#expect(input.barcodeFormat == .other)
	}
}

struct VNBarcodeSymbologyBarcodeFormatTests {
	@Test(arguments: [
		(VNBarcodeSymbology.qr, BarcodeFormat.qr),
		(.dataMatrix, .dataMatrix),
		(.pdf417, .pdf417),
		(.aztec, .aztec),
		(.code128, .code128),
		(.ean13, .ean13),
		(.ean8, .ean8),
		(.upce, .upce),
	])
	func `maps each supported Vision symbology to its BarcodeFormat`(
		input: VNBarcodeSymbology, expected: BarcodeFormat,
	) {
		#expect(input.barcodeFormat == expected)
	}

	@Test(arguments: [
		VNBarcodeSymbology.code39,
		.code39Checksum,
		.code39FullASCII,
		.code39FullASCIIChecksum,
	])
	func `every Vision Code 39 variant collapses into code39`(input: VNBarcodeSymbology) {
		#expect(input.barcodeFormat == .code39)
	}

	@Test(arguments: [
		VNBarcodeSymbology.code93,
		.i2of5,
		.itf14,
	])
	func `unrecognized Vision symbologies fall back to other`(input: VNBarcodeSymbology) {
		#expect(input.barcodeFormat == .other)
	}
}

struct BarcodeFormatMappingConsistencyTests {
	/// Whatever BarcodeFormat a symbology reports must be the same across
	/// the live camera (`AVMetadataObject.ObjectType`) and still-image
	/// (`VNBarcodeSymbology`) code paths — otherwise the same physical
	/// code would be labeled differently depending on which entry point
	/// decoded it.
	@Test(arguments: [
		(AVMetadataObject.ObjectType.qr, VNBarcodeSymbology.qr),
		(.dataMatrix, .dataMatrix),
		(.pdf417, .pdf417),
		(.aztec, .aztec),
		(.code128, .code128),
		(.code39, .code39),
		(.ean13, .ean13),
		(.ean8, .ean8),
		(.upce, .upce),
	])
	func `AV and Vision agree on BarcodeFormat for shared symbologies`(
		av: AVMetadataObject.ObjectType, vision: VNBarcodeSymbology,
	) {
		#expect(av.barcodeFormat == vision.barcodeFormat)
	}
}
