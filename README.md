# Scanly

Native iOS app to scan and manage QR codes quickly, cleanly, and without friction.

> For the full product scope (vision, milestones, and post-MVP roadmap) see [`Scanly Scope QR App.md`](./Scanly%20Scope%20QR%20App.md).

---

## Requirements

- **Xcode:** 26+
- **Minimum iOS:** 26
- **Swift:** 6
- **Homebrew** (to install the development tools)

---

## Setup

Clone the repo and run the install script. It installs local dependencies (SwiftFormat) and copies the `pre-commit` hook:

```bash
./install.sh
```

Then open the project in Xcode:

```bash
open Scanly.xcodeproj
```

---

## Architecture

Clean Architecture + MVVM, split across **two local Swift packages and a thin app target**:

- **`ScanlyEngine`** (SPM package) — framework-facing logic, no SwiftUI. Two layers per feature:
  - **Feature** — pure Swift entities, content parsing, result models. No dependency on UIKit/AVFoundation/SwiftUI.
  - **Infrastructure** — adapters over Apple frameworks (AVFoundation, Vision, SwiftData) behind abstraction protocols (`QRScanning`, `TorchControlling`, `CameraControlling`, `CameraPreviewProviding`, `ImageBarcodeDetecting`, `ScanHistoryRepository`).
- **`ScanlyUI`** (SPM package) — SwiftUI views and view models (`@MainActor`, `@Observable`). Depends on `ScanlyEngine`.
- **`Scanly`** (app target) — thin composition root only: `App/` (dependency wiring, `AppCoordinator`, `AppLauncher`) and `RootTabView`. No feature logic.

Cross-cutting code lives in `ScanlyEngine/Sources/ScanlyEngine/Shared/`:

- **Concurrency** — `LastWriterWinsPusher`, `Sleeper` (reusable primitives for structured concurrency and deterministic tests).
- **Formatting** — `CoordinateFormatter`.
- **Haptics** — `HapticFeedbackControlling` protocol and `UIKitHapticFeedback` adapter over `UIImpactFeedbackGenerator`.
- **Logging** — `OSLog` categories per subsystem.
- **Sound** — `DetectionSoundPlaying` protocol and `SystemSoundDetectionPlayer` adapter.

Test doubles shared between both packages' test bundles live in a dedicated **`ScanlyEngineTestSupport`** library target — test code only, never linked into the app.

### Principles

- SOLID, composition over inheritance, small functions with a single responsibility.
- **Testability is a first-class requirement**: `Infrastructure` layers expose protocols so Apple frameworks can be replaced with spies/stubs in tests.
- Types that cross concurrency boundaries are `Sendable`.

---

## Implemented features

### Scanner

- Live scanning via `AVFoundation` (`AVFoundationQRScanner`).
- QR detection from gallery images via `Vision` (`VisionImageBarcodeDetector`).
- Torch control (`TorchControlling`).
- Debouncing of duplicate detections (`DetectionDebouncer`) and coalescing of state updates (`DetectionStateEmitter` + `LastWriterWinsPusher`).
- Content parser (`QRContentParser`) with support for: URL, text, vCard, Wi-Fi, phone, email, SMS, and geographic location.
- Result inspector with per-field copyable rows (`ScanResultSheet`, `QRType+Inspector`).
- Post-detection flow: session pause while the result sheet is visible, content-based dismiss cooldown (`PostDismissCooldown`), haptic feedback, and detection sound (`SystemSoundDetectionPlayer`).

### History

- Local persistence of scans via `SwiftData` (`SwiftDataScanHistoryRepository` behind the `ScanHistoryRepository` protocol).
- History list, per-scan detail view, and in-list search (`HistorySearch`).

### Logging

`OSLog` by category (`scanner`, etc.). Sensitive content is never logged without an explicit `privacy:` qualifier:

```swift
Logger.scanner.info("QR detected: type \(qrType, privacy: .public)")
```

---

## Testing

- **Framework:** [Swift Testing](https://developer.apple.com/documentation/testing) (`import Testing`, `@Test`, `#expect`).
- **Test layout** — each package owns its bundle: `ScanlyEngine/Tests/ScanlyEngineTests/` and `ScanlyUI/Tests/ScanlyUITests/`, each mirroring its source tree. The app target keeps a minimal `ScanlyTests/` for composition-root integration tests.
- **Hand-written doubles** — no mocking libraries. Shared doubles, fixtures, and async helpers (`QRScannerSpy`, `TorchSpy`, `HapticFeedbackSpy`, `ControllableSleeper`, `InMemoryScanHistoryRepository`, `WaitUntil`, …) live in the `ScanlyEngineTestSupport` target so both packages' bundles can reuse them.
- Concurrency tests are deterministic: time is controlled via an injectable `Sleeper` / `TestClock`.

Run every test bundle (app target + both packages) from the command line:

```bash
./scripts/test.sh                    # auto-picks the first available iPhone simulator
./scripts/test.sh "iPhone 17 Pro"    # pin to a specific simulator
```

Or from Xcode with `⌘U`.

---

## Formatting and hooks

- The `pre-commit` hook runs `swiftformat` over every staged `.swift` file and re-adds it to the commit.
- It is installed automatically by `./install.sh`.
- To format a single file manually:

```bash
./scripts/format.sh path/to/file.swift
```

---

## Project structure

```text
Scanly/
├── Scanly/                      # App target — thin composition root
│   ├── App/                     # AppCoordinator, AppDependencies, AppLauncher
│   ├── ScanlyApp.swift
│   └── RootTabView.swift
├── ScanlyTests/                 # App-target integration tests
├── ScanlyEngine/                # SPM package — domain + framework adapters
│   ├── Package.swift
│   ├── Sources/
│   │   ├── ScanlyEngine/
│   │   │   ├── History/         # Feature/, Infrastructure/
│   │   │   ├── Scanner/         # Feature/, Infrastructure/
│   │   │   └── Shared/          # Concurrency, Formatting, Haptics, Logging, Sound
│   │   └── ScanlyEngineTestSupport/   # Shared test doubles and fixtures
│   └── Tests/ScanlyEngineTests/
├── ScanlyUI/                    # SPM package — SwiftUI views + view models
│   ├── Package.swift
│   ├── Sources/ScanlyUI/        # History/, Scanner/, Previews/
│   └── Tests/ScanlyUITests/
├── scripts/
│   ├── pre-commit
│   ├── format.sh
│   └── test.sh
├── install.sh
└── Scanly.xcodeproj
```
