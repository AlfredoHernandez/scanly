//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Public accessor for ScanlyEngine's resource bundle. Required so
/// callers outside the package (notably test targets that can't see
/// `Bundle.module` directly) can resolve engine-owned localized
/// strings against the same catalog the engine itself uses.
///
/// Production code inside the package should keep using
/// `Bundle.module` for free — this seam exists for the test target
/// and any downstream consumer that needs an explicit bundle handle.
public enum ScanlyEngineResources {
	public static let bundle = Bundle.module
}
