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

Clean Architecture + MVVM with strict layer separation. Each feature lives under `Scanly/Features/<Feature>/` with three folders:

- **Domain** — pure Swift entities, content parsing, result models. No dependency on UIKit/AVFoundation/SwiftUI.
- **Data** — adapters over Apple frameworks (AVFoundation, Vision), abstraction protocols (`QRScanning`, `TorchControlling`, `CameraControlling`, `CameraPreviewProviding`, `ImageBarcodeDetecting`), and their implementations.
- **Presentation** — SwiftUI views and view models (`@MainActor`, `@Observable`).

Cross-cutting code in `Scanly/Shared/`:

- **Concurrency** — `LastWriterWinsPusher`, `Sleeper` (reusable primitives for structured concurrency and deterministic tests).
- **Haptics** — `HapticFeedbackControlling` protocol and `UIKitHapticFeedback` adapter over `UIImpactFeedbackGenerator`.
- **Logging** — `OSLog` categories per subsystem.

### Principles

- SOLID, composition over inheritance, small functions with a single responsibility.
- **Testability is a first-class requirement**: `Data` layers expose protocols so Apple frameworks can be replaced with spies/stubs in tests.
- Types that cross concurrency boundaries are `Sendable`.

---

## Implemented features

### Scanner (`Scanly/Features/Scanner`)

- Live scanning via `AVFoundation` (`AVFoundationQRScanner`).
- QR detection from gallery images via `Vision` (`VisionImageBarcodeDetector`).
- Torch control (`TorchControlling`).
- Debouncing of duplicate detections (`DetectionDebouncer`) and coalescing of state updates (`DetectionStateEmitter` + `LastWriterWinsPusher`).
- Content parser (`QRContentParser`) with support for: URL, text, vCard, Wi-Fi, phone, email, SMS, and geographic location.
- Result inspector with per-field copyable rows (`ScanResultSheet`, `QRType+Inspector`).
- Haptic feedback on detection (`UIKitHapticFeedback`).

### Logging

`OSLog` by category (`scanner`, etc.). Sensitive content is never logged without an explicit `privacy:` qualifier:

```swift
Logger.scanner.info("QR detected: type \(qrType, privacy: .public)")
```

---

## Testing

- **Framework:** XCTest.
- **Test layout** mirrors the source tree under `ScanlyTests/`.
- **Hand-written doubles** — no mocking libraries. Today's doubles live next to the suites that use them:
  - Scanner feature: `QRScannerSpy`, `TorchSpy`, `HapticFeedbackSpy` in `ScanlyTests/Features/Scanner/`.
  - Shared concurrency: `ControllableSleeper` in `ScanlyTests/Shared/Concurrency/`.
- Concurrency tests are deterministic: time is controlled via an injectable `Sleeper`.

Run tests from the command line:

```bash
xcodebuild test \
  -project Scanly.xcodeproj \
  -scheme Scanly \
  -destination 'generic/platform=iOS Simulator'
```

Or pin to a specific simulator if you need reproducibility (`-destination 'platform=iOS Simulator,OS=latest,name=iPhone 16'`).

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
├── Scanly/
│   ├── ScanlyApp.swift
│   ├── ContentView.swift
│   ├── Features/
│   │   └── Scanner/
│   │       ├── Data/
│   │       ├── Domain/
│   │       └── Presentation/
│   └── Shared/
│       ├── Concurrency/
│       ├── Haptics/
│       └── Logging/
├── ScanlyTests/
│   ├── Features/Scanner/
│   └── Shared/Concurrency/
├── scripts/
│   ├── pre-commit
│   └── format.sh
├── install.sh
└── Scanly.xcodeproj
```
