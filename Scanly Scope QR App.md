# Scanly — iOS App Scope

## 1. Overview

**Nombre:** Scanly  
**Plataforma:** iOS (iPhone)  
**Versión inicial:** 1.0 (MVP)  
**Objetivo:** App nativa de iOS para escanear y gestionar códigos QR de forma rápida, limpia y sin fricción.

---

## 2. Público objetivo

- Usuarios iOS que escanean QR regularmente (restaurantes, pagos, eventos, redes Wi-Fi)
- Usuarios que necesitan historial y organización de sus escaneos
- Usuarios que valoran apps con buen diseño y sin anuncios

---

## 3. Funcionalidades — MVP (v1.0)

### 3.1 Escaneo
- Escaneo en tiempo real con la cámara
- Soporte para QR desde la galería de fotos
- Linterna integrada para ambientes con poca luz
- Detección automática sin necesidad de presionar botón

### 3.2 Tipos de QR soportados
- URL / sitio web
- Texto plano
- Contacto (vCard)
- Red Wi-Fi
- Número de teléfono
- Email
- SMS
- Ubicación geográfica

### 3.3 Historial
- Lista de todos los escaneos previos
- Vista detalle por escaneo (tipo, contenido, fecha/hora)
- Eliminar escaneos individuales o en lote
- Búsqueda dentro del historial

### 3.4 Acciones por resultado
- Abrir URL en Safari
- Copiar contenido al portapapeles
- Compartir resultado (share sheet nativo)
- Guardar contacto en Contacts
- Conectarse a Wi-Fi automáticamente
- Abrir ubicación en Maps

---

## 4. Funcionalidades — Post-MVP (v1.x)

- Favoritos / escaneos guardados
- Generación de códigos QR propios
- Soporte para barcodes (EAN, Code128, etc.)
- Widget de iOS para acceso rápido desde pantalla de inicio
- Exportar historial en CSV
- Scan desde Live Text

---

## 5. Diseño y UX

- Estilo: **Liquid Glass** (iOS 26 design language) — adoptado al 100% en toda la app
- Materiales translúcidos y vibrancy en todas las superficies (sheets, toolbars, cards, bottom bars)
- Modo oscuro soportado desde el inicio (Liquid Glass se adapta automáticamente)
- Fuente del sistema (SF Pro)
- Sin onboarding innecesario — la app abre directo en la cámara
- Accesibilidad: Dynamic Type y VoiceOver
- Sin componentes custom que rompan el lenguaje visual de iOS 26

---

## 6. Arquitectura técnica

- **Lenguaje:** Swift 6
- **UI:** SwiftUI
- **Arquitectura:** Clean Architecture + MVVM
- **Escaneo:** AVFoundation / Vision framework
- **Persistencia:** SwiftData (historial local)
- **Testing:** XCTest (Unit) + XCUITest (UI)
- **Mínimo iOS:** iOS 26

### 6.1 Logging

Capa de logging limpia usando `OSLog` (framework nativo de Apple), sin dependencias externas.

**Estructura:**
- Un `Logger` por subsistema/feature (e.g. `scanner`, `history`, `actions`)
- Niveles semánticos: `.debug`, `.info`, `.error`, `.fault`
- Los logs son visibles en Console.app durante desarrollo y nunca exponen datos sensibles del usuario (contenido de QR se loguea truncado o enmascarado)
- En Release: solo `.error` y `.fault` se persisten; `.debug` e `.info` se omiten automáticamente por el sistema

**Ejemplo de uso:**
```swift
import OSLog

extension Logger {
    static let scanner = Logger(subsystem: "com.scanly.app", category: "scanner")
    static let history = Logger(subsystem: "com.scanly.app", category: "history")
}

// En uso:
Logger.scanner.info("QR detectado: tipo \(qrType, privacy: .public)")
Logger.scanner.error("Fallo al procesar QR: \(error.localizedDescription, privacy: .public)")
```

---

## 7. No incluido en scope (v1.0)

- CI/CD (se configura en una etapa posterior)
- Monetización (definir en futuras iteraciones)
- Generación de QR (Post-MVP)
- Soporte para barcodes
- Modo iPad
- Sincronización con iCloud
- App en Android

---

## 8. Métricas de éxito

- Tiempo de escaneo < 1 segundo en condiciones normales
- Rating objetivo en App Store: ≥ 4.5
- Retención a 7 días: ≥ 40%
- Crash-free rate: ≥ 99.5%

---

## 9. Milestones

| Milestone | Contenido | Estado |
|---|---|---|
| M1 — Setup | Proyecto, arquitectura base, OSLog | Pendiente |
| M2 — Scanner | Escaneo funcional con AVFoundation | Pendiente |
| M3 — Historial | SwiftData + lista + detalle | Pendiente |
| M4 — Acciones | Deep links, share sheet, Wi-Fi | Pendiente |
| M5 — UI/UX | Liquid Glass, dark mode, accesibilidad | Pendiente |
| M6 — QA | Testing, performance, edge cases | Pendiente |
| M7 — Release | App Store submission | Pendiente |

---

## 10. Resolved decisions

This section records decisions taken to disambiguate the scope. Each entry is dated and links to the feature section it affects.

### 10.1 Post-detection flow (affects §3.1, §3.4) — 2026-05-12

When a QR code is recognized, the scanner pipeline must behave as follows. This is a forward-looking specification; the current code only implements item 1 (auto-present via `.sheet(item: $viewModel.latestResult)` in `ScannerView`) and the always-on haptic from item 4. Items 2, 3, and the rest of 4 are pending implementation.

1. **Auto-present.** The `ScanResultSheet` is presented automatically as soon as a valid detection is confirmed by the debouncer. No banner, no extra tap. This matches the scope's "no unnecessary onboarding, zero friction" principle.

   - Multi-code frames: `SessionCore` already keeps only the first metadata object per frame (see `SessionCore.swift:231`). The auto-present rule inherits that behavior — if two QRs appear simultaneously, the one AVFoundation reports first wins. v1.0 does not attempt multi-QR disambiguation.

2. **Pause while sheet is visible.** The `AVCaptureSession` must be fully stopped (not just gated by `latestResult`) while the result sheet is on screen. This saves battery/CPU and avoids dropped frames stacking behind the modal. When the user dismisses the sheet, the session resumes.

   - **Torch:** if the torch is on when the session pauses, it is turned off (hardware requires the session to be running). On session resume, the previous torch state is restored. `ScannerViewModel` must persist `isTorchOn` across the pause/resume cycle.
   - **Gallery picker:** opening the photo picker does **not** pause the live session — it only suspends the live preview visually. Detection in gallery images runs on `VisionImageBarcodeDetector` and is unaffected by the AVFoundation session.

3. **Content-based cooldown on dismiss.** When the sheet is dismissed, a **2-second window starts at the dismiss timestamp** during which any detection whose `rawContent` matches the just-dismissed result is suppressed. Detections with different `rawContent` are honored immediately and present the sheet again.

   - **Anchor:** the timer is anchored to the dismiss timestamp, not the present timestamp. A user who reads the sheet for 10s and then dismisses still gets 2s of immunity before the same QR can re-fire.
   - **Reset rule:** the cooldown does **not** extend on each suppressed detection — it expires 2s after dismiss regardless of how many duplicate frames arrive in between.
   - **Key:** the cooldown is keyed by `rawContent` (exact string match), not by `QRType`, so a re-encoded variant of the same payload is treated as a new scan.
   - **Location:** `DetectionDebouncer` is the **target** for hosting this logic. As of 2026-05-12 the debouncer is a stateless edge-detector with no timer or `rawContent` reference (see `DetectionDebouncer.swift`); adding the cooldown means extending it with a timestamp + last-presented content. Alternative: introduce a separate `PostDismissCooldown` actor and compose it with the debouncer. Decision deferred to the implementation PR.

4. **Detection feedback.** Three independent channels:
   - **Haptic** — always on. Already implemented via `UIKitHapticFeedback` and wired through `HapticFeedbackControlling` (in `Shared/Haptics/`).
   - **Visual highlight** — animated overlay drawn on the camera preview around the detected QR's bounding box, played for ~250ms before the sheet appears. Because §10.1.1 says only the first-reported QR wins per frame, the highlight only ever renders one bounding box — no multi-box logic in v1.0.
   - **Confirmation sound** — opt-in via Settings, **off by default**. Respects the iOS silent switch when enabled. Stored in `UserDefaults` under the key **`scanner.detection.sound.enabled`** (string constant `ScannerSettingsKeys.detectionSoundEnabled`). No SwiftData entry, no per-scan persistence.

#### Implications for current code

- `ScannerViewModel` needs an `isPresentingResult` state that drives both the sheet presentation and the session stop/start, plus a `preservedTorchState` flag so torch survives the pause cycle.
- `DetectionDebouncer` (or a new collaborator composed with it) needs a 2s post-dismiss cooldown keyed by `rawContent`, anchored to the dismiss timestamp.
- A new `DetectionVisualFeedbackView` (or overlay layer on `CameraPreviewView`) is required to render the bounding-box highlight. AVFoundation already exposes `AVMetadataMachineReadableCodeObject.corners` — the view needs the bounding rect transformed into preview-layer coordinates.
- A new settings model is needed (`ScannerSettings` or similar) for the sound toggle. The `UserDefaults` key is fixed at `scanner.detection.sound.enabled`; future settings UI consumes the same constant.
- Sound playback should be abstracted behind a protocol (`DetectionSoundPlaying`) to keep parity with `HapticFeedbackControlling` — testability stays first-class.

### 10.2 History persistence policy (affects §3.3) — 2026-05-13

The history feature described in §3.3 is not yet implemented. This entry locks the policy that the SwiftData model and repository must follow.

1. **Auto-save at presentation time.** A scan is persisted at the exact moment the `ScanResultSheet` is presented (the same trigger described in §10.1.1). No "Save" button, no manual confirmation. Only detections rejected by the post-dismiss cooldown (§10.1.3) are **not** persisted — they never become a "scan event" in the user's view of the world. The frame-level debouncer is not "suppression": it is the mechanism that produces a single detection event from many raw frames, and every event it emits is a candidate for persistence.

   - Gallery scans (`VisionImageBarcodeDetector` results) follow the same rule: as soon as the result is shown, it is persisted.
   - **Source of truth.** The SwiftData store is the authoritative source for the history list. The in-memory active session never shows a "pending" or "in-memory only" state. If the save fails, the sheet is still shown for the current scan but the entry is **not** in the history list — neither during the session nor after a relaunch. The error is logged via `OSLog` (`Logger.history.error`); no user-visible toast in v1.0. This is a best-effort save, traded against UX friction.

2. **Upsert keyed by `rawContent` with a scan counter.** A single row per unique `rawContent`. On a duplicate scan, the existing row is updated in place:

   - `lastScannedAt` ← now
   - `scanCount` ← `scanCount + 1`
   - `firstScannedAt` is **immutable** after the initial insert.
   - `rawContent` is the unique key (exact-match string). Whitespace and case are preserved as detected; no normalization. **Known tradeoff:** `HTTP://Example.com` and `http://example.com` create two separate entries with independent scan counts. URL normalization is deliberately deferred to a post-v1.0 enhancement; the explicit-key rule is simpler to reason about and avoids hiding scans from the user.
   - The schema below intentionally stores `rawContent + typeDiscriminator + format` rather than the `QRType` enum directly — `QRType` has associated values that don't map cleanly to SwiftData attributes, so the type is re-parsed via `QRContentParser` on read. `QRContentParser` today branches purely on `rawContent`'s prefix and does not consume `format`; `format` is stored for display-only purposes (the "Format" row in `ScanResultSheet`) and is **not** an input to parser dispatch. If a future parser overhaul keys on `format`, this contract must be revisited.

3. **No content masking, no encryption beyond Data Protection.** Wi-Fi passwords, vCard contents, and any other sensitive payload are stored verbatim. SwiftData's underlying SQLite is encrypted at rest by iOS Data Protection (default class `NSFileProtectionCompleteUntilFirstUserAuthentication`). The app itself does not implement custom encryption. No content is exposed outside the app's sandbox in v1.0 (no iCloud sync — explicitly out of scope per §7).

4. **No retention limit.** History grows unbounded. The user removes entries manually — individually or in batch from the list (§3.3). SwiftData handles thousands of rows comfortably; if performance becomes a concern post-launch a retention setting can be added without schema migration.

5. **Search scope.** The search boundary is defined by an **explicit field enumeration**, independent of what `QRType.inspectorRows` happens to surface in the detail view. The history search bar matches against:
   - `rawContent` (the literal scanned string).
   - Derived fields, exactly: **URL host**, **Wi-Fi SSID**, **phone number**, **email address**, **SMS number**, **formatted latitude/longitude**.
   - **Explicitly excluded from search (even though they appear in the detail view):** Wi-Fi passwords, email subject, email body, SMS body, URL path/query/fragment, individual URL query items. These fields are visible to the user when inspecting a single entry but must never surface a history row by matching against them. The detail-view inspector and the search index are two separate concerns; do not couple them.
   - Search is performed in memory over the full history snapshot for v1.0. No FTS index. Filtering is case-insensitive and diacritic-insensitive.

6. **Default sort.** List is ordered by `lastScannedAt` descending — most recently scanned first. Re-scanning an existing entry moves it to the top. No secondary sort key; ties (sub-millisecond) fall back to insertion order.

#### Proposed schema

```swift
@Model
final class ScanHistoryEntry {
    var id: UUID                    // captured from ScanResult.id; immutable on upsert; drives SwiftUI list-diff stability
    @Attribute(.unique) var rawContent: String
    var typeDiscriminator: String   // QRType.discriminator
    var format: String              // BarcodeFormat.rawValue — display only, not a parser input
    var firstScannedAt: Date
    var lastScannedAt: Date
    var scanCount: Int
}
```

The Domain `ScanResult` stays unchanged; a `ScanHistoryRepository` protocol (in Data) maps between `ScanHistoryEntry` and `ScanResult`, re-parsing `QRType` on read so the Presentation layer never touches SwiftData directly.

**Migration:** v1.0 ships with a single schema version and no migration plan. Any future addition of a non-optional stored property requires defining a `VersionedSchema` and a `MigrationStage`; new fields added before that infrastructure exists must be optional with safe defaults to avoid crash-on-upgrade.

#### Implications for current code

- Add a new `History` feature folder (`Scanly/Features/History/`) with `Domain`, `Data`, `Presentation` mirroring the Scanner layout.
- `ScanHistoryRepository` protocol (Data) with methods:
  - `save(_ result: ScanResult)` — upsert by `rawContent`.
  - `all() -> [ScanResult]` — ordered by `lastScannedAt` desc.
  - `delete(_ entry: ScanResult)` — single-entry deletion.
  - `delete(_ entries: [ScanResult])` — batch deletion for multi-select in the list (required by §3.3 "delete in batch").
  - `deleteAll()` — "Clear history" action.
  - `search(query: String) -> [ScanResult]` — applies the field enumeration from §10.2.5.
  - SwiftData-backed implementation lives behind the protocol so tests use a `Fake`/in-memory variant.
- A new `ScanResultCoordinator` (Presentation) owns both the `latestResult` presentation state and the persistence side-effect via the repository. `ScannerViewModel` delegates to it on detection. The coordinator is the only callsite that calls `repository.save(_:)`; this isolates the side-effect, keeps `ScannerViewModel` focused on scanner-pipeline state, and gives tests a single seam for persistence behavior.
- A new `HistoryListView` + `HistoryDetailView` + `HistoryViewModel` under `Presentation`. The detail view reuses `ScanResultSheet`'s inspector rows (`QRType.inspectorRows`) instead of duplicating logic.
- Search is computed on a `@Query`-loaded snapshot in the view model; no SwiftData predicate gymnastics in v1.0.

### 10.3 Primary action per type in the result sheet (affects §3.4) — 2026-05-13

Today `ScanResultSheet` is read-only: it shows the inspector with per-field copy and nothing else. §3.4 lists six behaviors (Open URL, Copy, Share, Save contact, Connect Wi-Fi, Open Maps) but does not say how they are surfaced. This entry locks the action layout and the per-type mapping.

#### 10.3.1 Layout

Three visual tiers, top to bottom:

1. **Primary CTA** — one prominent button at the top of the sheet, sized for thumb reach, styled with Liquid Glass tinted material. Exactly one primary action per type (see §10.3.2). Label is type-specific. Tapping fires the action; the sheet stays open so the user can see the result and dismiss intentionally.
2. **Inspector** — the existing `inspectorSection` is preserved unchanged. Per-field `contextMenu` copy stays. This is the granular path.
3. **Secondary actions row** — at the bottom (toolbar or footer), two buttons always visible regardless of type:
   - **Share** — opens the system share sheet with `rawContent` as the activity item (see §10.3.4).
   - **Copy** — copies `rawContent` to the pasteboard. Same content as Share; this is the "copy all" shortcut. Granular copy remains in the inspector for individual fields.

The "Done" toolbar button (`ScanResultSheet.swift:39-42`) stays.

#### 10.3.2 Per-type primary CTA mapping

| `QRType` case | Primary CTA label key | Action |
|---|---|---|
| `.url(URL)` | `scanner.action.open_url` ("Open in Safari") | URL-confirmation alert → `UIApplication.open(url:)` |
| `.wifi(WiFiCredentials)` | `scanner.action.connect_wifi` ("Connect to Wi-Fi") | `NEHotspotConfigurationManager.shared.apply(_:)` |
| `.contact(vCard:)` | `scanner.action.add_contact` ("Add to Contacts") | `CNContactVCardSerialization` → `CNContactViewController.forNewContact(_:)` |
| `.phone(String)` | `scanner.action.call` ("Call") | Open `tel:` URL |
| `.email(EmailPayload)` | `scanner.action.compose_email` ("Compose Email") | `MFMailComposeViewController` prefilled (`mailto:` fallback if mail not configured) |
| `.sms(SMSPayload)` | `scanner.action.send_sms` ("Send Message") | `MFMessageComposeViewController` prefilled (`sms:` fallback if not available) |
| `.location(lat, lon)` | `scanner.action.open_maps` ("Open in Maps") | Build `MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))`, then `MKMapItem(placemark:).openInMaps(launchOptions: nil)` |
| `.text(String)` | `scanner.action.share` ("Share") | Share sheet on `rawContent` (same as the secondary Share button — for plain text the primary collapses onto Share rather than inventing a CTA) |

**Email/SMS prefill rule.** `MFMailComposeViewController` and `MFMessageComposeViewController` are prefilled with **every non-nil field** of their payload: `EmailPayload.address` always; `subject` and `body` only if non-nil and non-empty. Same for `SMSPayload.number` (always) and `body` (if non-nil and non-empty). Nil/empty fields are omitted entirely — they are not surfaced as empty placeholders.

**No persistence side-effects.** Invoking a primary CTA does **not** modify the `ScanHistoryEntry` (§10.2). There is no "last action taken" field, no action counter, no per-action timestamp. The history schema records the scan event only; user behavior after the scan is intentionally not tracked in v1.0.

For `.text`, the primary and secondary Share are intentionally the same action; the prominence in the primary slot signals "this is the most useful thing to do with this scan." We do **not** hide the secondary Share for text — keeping it visible avoids special-casing the layout per type.

#### 10.3.3 URL safety — confirmation alert

Every `.url` open goes through a confirmation alert before `UIApplication.open(url:)` is called. **No exceptions, no allowlists, no heuristics in v1.0.**

- Alert title: `scanner.alert.open_url.title` ("Open this link?")
- Alert message: shows the host on its own line, prominent, followed by the full URL truncated to fit (UI design TBD). Uses the `URLBreakdown.host` value already computed by the inspector.
- Buttons: `scanner.alert.open` (default, opens) and `scanner.alert.cancel` (cancel).
- This is the iOS Camera app's behavior for QR-scanned URLs and is the minimum bar for defense against **quishing**. Heuristic-based "smart" warnings (URL shorteners, IP literals, non-HTTPS) are deliberately deferred to post-v1.0 to avoid false positives/negatives and code complexity.

**Custom / non-http(s) URL schemes.** The alert is shown for any `.url` regardless of scheme (`myapp://`, `ftp://`, etc.). After the user taps Open, `UIApplication.open(_:)` delegates to the OS, which may surface its **own** "Open in App X?" sheet — Scanly does not attempt to detect or suppress that second prompt. Double-confirmation for custom schemes is accepted as the cost of a uniform policy.

**Alert lifecycle vs. sheet dismissal.** While the URL-confirmation alert is presented, the underlying `ScanResultSheet` must be **non-dismissible**: swipe-to-dismiss disabled (`.interactiveDismissDisabled(true)` while alert is up) and the "Done" toolbar button disabled. This prevents the race where the user dismisses the sheet and the alert's "Open" handler then fires against torn-down state. The alert is the foreground modal until the user picks Open or Cancel.

#### 10.3.4 Share content

The Share activity item is always **`rawContent` as `String`**. No type-specific formatting, no `UIActivityItemSource` adapters.

- The share sheet auto-detects URLs and offers "Open in Safari", "Add to Reading List", etc. — letting the system do the work yields better UX than hand-formatted strings.
- For Wi-Fi, location, vCard etc. the recipient receives the raw payload string. This is intentional: it preserves the round-trip (the recipient can paste the string into Scanly or another scanner-aware app).
- Rich `UIActivityItemSource` adapters per type are post-v1.0 candidates.

#### 10.3.5 Wi-Fi connect — entitlement and error handling

`NEHotspotConfigurationManager.shared.apply(_:)` requires the **`com.apple.developer.networking.HotspotConfiguration`** entitlement. This must be added to the Scanly app target before §3.4 Wi-Fi connect can ship. App Store review does not require special justification for this entitlement when the app is a QR scanner — joining a network from a scanned QR is the canonical use case.

Outcome handling. The `WiFiConnecting` adapter normalizes `NEHotspotConfigurationManager`'s callback into a small `Result`-like outcome enum (`connected`, `userCancelled`, `failed(message:)`). The mapping is:

- **`connected`** — completion handler called with `error == nil`, **or** with `NEHotspotConfigurationError.alreadyAssociated` (code 7). The "already associated" error is treated as a success-equivalent and swallowed by the adapter — never surfaced as a failure. The system shows its own "Joining network" UI on the actual-join path; Scanly does nothing extra. The sheet stays open so the user can verify the credentials they scanned.
- **`userCancelled`** — completion handler called with `NEHotspotConfigurationError.userDenied` (code 7 is alreadyAssociated, code 8 is the user-denied variant — verify exact codes at implementation time against the current SDK). Silently no-op; the sheet stays open.
- **`failed(message:)`** — every other error from `NEHotspotConfigurationErrorDomain` (invalid password, internal error, network not found, etc.). The Presentation layer surfaces a localized error message; see the toast note below. No retry button in v1.0; the user re-taps Connect if desired.

**Toast component.** "Surface a localized error message at the bottom of the sheet" requires a non-modal toast/banner overlay. **No such component exists in the codebase today.** Either a new shared `ToastView` (or SwiftUI `.toast(_:)` modifier) must be designed and added to `Scanly/Shared/` before this feature ships, **or** the failure surface must downgrade to an in-line `Text` row at the bottom of the sheet that appears/clears in response to the outcome. The toast option is preferred for UX consistency with future error surfaces (gallery scan failures, permission denials), but it is a prerequisite — Wi-Fi connect cannot ship until the chosen surface exists.

#### 10.3.6 Confirmation policy for other actions

Only URL opening requires a confirmation alert. All other primary CTAs fire directly:

- Wi-Fi connect goes through the **system's own** confirmation UI (the "Join network?" prompt), so an in-app alert would be redundant.
- `tel:` opens the system Call UI **on iPhone**. On Wi-Fi-only iPads (out of scope per §7 but worth noting) `UIApplication.open(_:)` with a `tel:` URL silently fails — no system UI, no error to the app. When iPad support is revisited post-v1.0, the `PhoneCallPlacing` adapter must check `UIApplication.shared.canOpenURL(_:)` first and surface a "Calls not supported on this device" state. For iPhone-only v1.0, direct open is acceptable.
- `sms:` opens the Messages compose UI, which is itself a confirmation surface.
- Maps and Mail compose are non-destructive (the user can cancel inside the sheet they open). `MFMailComposeViewController` exposes **Send** and **Cancel** (Cancel offers a "Save Draft" option); it is not a write-then-confirm surface, but Send is itself the explicit confirmation.
- "Add to Contacts" presents `CNContactViewController` which has its own Done/Cancel buttons.

#### Implications for current code

- **`ScanResultSheet`** must grow a primary CTA region above the existing form. Pass the per-type action through a dedicated `ScanResultActions` view model so the sheet itself stays presentational.
- **New protocols, Data layer** (system-service adapters, all `Sendable`):
  - `URLOpening` — wraps `UIApplication.open(_:)`. Returns `Bool` (the system's success flag).
  - `WiFiConnecting` — wraps `NEHotspotConfigurationManager.apply(_:)`. Returns the normalized outcome enum defined in §10.3.5.
  - `PhoneCallPlacing` — wraps `tel:` URL open via `UIApplication.open(_:)`. Returns the system success flag (false on Wi-Fi-only devices).
  - `MailComposing` — wraps `MFMailComposeViewController` with a `mailto:` URL fallback. **Contract:** the adapter attempts `MFMailComposeViewController` first (gated by `MFMailComposeViewController.canSendMail()`); if false, it falls back to opening `mailto:` via `URLOpening`. If both paths return false, the adapter throws `MailComposingError.notAvailable` so the call site can surface a localized "Email not configured on this device" toast. No silent failure.
  - `MessageComposing` — wraps `MFMessageComposeViewController` with an `sms:` URL fallback. Mirrors `MailComposing`: gated by `MFMessageComposeViewController.canSendText()`, falls back to `URLOpening`, throws `MessageComposingError.notAvailable` if both fail.
  - `MapsOpening` — wraps `MKMapItem.openInMaps(launchOptions:)`. Takes a `(latitude: Double, longitude: Double)` pair; the adapter is the only place that knows about `MKPlacemark` and `CLLocationCoordinate2D`.
- **New protocols, Presentation layer** (view-controller presenters that require a UIKit/SwiftUI host context — these are not Data adapters):
  - `Sharing` — wraps presenting `UIActivityViewController` over `rawContent`. Belongs to Presentation because it owns a view-controller lifecycle and requires a presenting view.
  - `ContactPresenting` — wraps `CNContactViewController.forNewContact(_:)` after parsing the vCard via `CNContactVCardSerialization.contacts(with:)`. Also Presentation: pushes/presents a view controller.
- Each protocol gets a concrete adapter (UIKit/MapKit/MessageUI/NetworkExtension/Contacts) and a test `Spy` mirroring the existing `HapticFeedbackSpy`/`TorchSpy` pattern. The Presentation layer never touches Apple framework calls directly except through the Presentation-layer presenters above.
- **Entitlements:** Scanly.entitlements must add `com.apple.developer.networking.HotspotConfiguration` (for Wi-Fi connect).
- **Info.plist privacy strings:** Add `NSContactsUsageDescription` (unconditionally required — `CNContactViewController.forNewContact(_:)` always requests write access to the store). The string is an English sentence written directly in `Info.plist`, not a key in `Localizable.xcstrings`. Suggested copy: "Scanly adds scanned contacts to your address book."
- **URL-confirmation alert** uses the standard SwiftUI `.alert(_:isPresented:)` modifier; no custom dialog. The host is extracted via `URLBreakdown.host` (already in Domain) — no new parser code. While presented, the underlying sheet sets `.interactiveDismissDisabled(true)` and the "Done" button is disabled (see §10.3.3 lifecycle rule).
- **Toast/banner component** is a prerequisite shared dependency for the Wi-Fi failure surface (see §10.3.5). Lives under `Scanly/Shared/` once designed.
- **Localization keys** for every label above land in `Scanly/Localizable.xcstrings` before the feature ships. Keys are namespaced `scanner.action.*` and `scanner.alert.*` for consistency with existing `scanner.result.*` / `scanner.type.*` namespaces. **Privacy strings (`NSContactsUsageDescription` and similar) are NOT in this file** — they are `Info.plist` value strings.

### 10.5 Observability — crash reporting, analytics, and OSLog (affects §6.1, §8) — 2026-05-13

The scope already calls for OSLog (§6.1) and lists "crash-free rate ≥ 99.5%" and "7-day retention ≥ 40%" as success metrics (§8) without naming a measurement source. This entry locks the observability stack for v1.0 and the abstractions needed to swap backends post-v1.0 without touching call sites.

#### 10.5.1 Crash reporting and non-fatal errors

**v1.0 backend: App Store Connect.** No third-party SDK ships in v1.0. Fatal crashes are captured by iOS automatically when the user has enabled "Share With Developers" — symbolicated reports appear in **Xcode Organizer** and **App Store Connect → Trends/Metrics**. This is sufficient to measure the §8 crash-free rate without adding a dependency, a privacy disclosure, or a consent flow.

**Forward-compatible protocols.** Even though v1.0 does not need an SDK, the app-side observability surface must be introduced **now**, behind protocols, so a Sentry / Firebase Crashlytics / Datadog / Amplitude / PostHog / Mixpanel adapter can be added post-v1.0 by registering a new implementation at the composition root — no changes to call sites. The protocol surface is designed to cover the **union** of common vendor APIs so that any future adapter is a write-once mapping with no impedance mismatch.

Three protocols, all `Sendable`, all in `Scanly/Shared/Observability/`:

```swift
// 1. Error / message capture + correlation context.
public protocol ErrorReporting: Sendable {
    /// Reports a non-fatal error. Fatal crashes are caught by the OS;
    /// this is for recoverable failures (Wi-Fi connect failure, history
    /// save failure, vCard parsing failure, etc.). `occurredAt` defaults
    /// to now; historical errors (MetricKit-delivered crash diagnostics)
    /// pass the original timestamp so vendor adapters can backdate the event.
    func report(_ error: Error, occurredAt: Date, file: StaticString, line: UInt)

    /// Captures a free-form diagnostic message at a given severity.
    /// Maps to Sentry's `captureMessage`, Datadog's `logger.log`,
    /// Crashlytics' `log`. The template is `StaticString` so dynamic
    /// content (user input, scanned payloads) cannot be interpolated
    /// at the call site — privacy invariant enforced at compile time.
    /// Variable correlation must travel via `setTag` or breadcrumbs.
    func captureMessage(_ template: StaticString, level: DiagnosticLevel)

    /// Adds a breadcrumb to the in-memory trail. Future SDK adapters
    /// forward breadcrumbs alongside the next reported error or event.
    func addBreadcrumb(_ message: StaticString, category: BreadcrumbCategory)

    /// Sets correlation metadata that future reports/events inherit.
    /// Maps to Sentry/Datadog `setTag`, Crashlytics `setCustomValue`,
    /// Amplitude/Mixpanel `setUserProperty` (when key is identity-shaped).
    /// `value` may be nil to clear a previously-set tag.
    func setTag(_ key: TagKey, value: String?)

    /// Sets user-correlation context. v1.0 has no accounts so the live
    /// implementation accepts only an anonymous installation ID. The
    /// shape exists so vendor adapters can populate the SDK's user
    /// scope (Sentry `setUser`, Crashlytics `setUserID`, Amplitude
    /// `identify`).
    func setUserContext(_ context: UserContext)

    /// Forces in-flight data to the backend with a bounded timeout.
    /// Called on app background transition by the composition root.
    /// iOS grants ~5s of background runtime per scene-phase transition;
    /// the composer passes a 3-second budget so flushing cannot starve
    /// the app of its remaining backgrounding budget. v1.0 OSLog impl
    /// returns immediately; vendor adapters MUST honor the deadline
    /// and abandon in-flight queues if it elapses.
    func flush(timeout: Duration) async
}

// 2. Product analytics — typed events + identity lifecycle.
public protocol AnalyticsTracking: Sendable {
    /// Records a typed product event. v1.0 ships a no-op implementation;
    /// the protocol exists so call sites can be instrumented without
    /// committing to a vendor.
    func track(_ event: AnalyticsEvent)

    /// Associates subsequent events with a user / installation identity.
    /// Maps to Amplitude `identify`, Mixpanel `identify`, PostHog `identify`,
    /// Crashlytics `setUserID`. v1.0 no-op; Scanly has no accounts but the
    /// shape is reserved for future auth.
    func identify(userID: String, traits: [TagKey: String])

    /// Clears the current identity (logout). v1.0 no-op.
    /// Maps to Amplitude `setUserId(nil)+reset()`, Mixpanel `reset`,
    /// PostHog `reset`.
    func reset()

    /// Forces queued events to the backend with a bounded timeout.
    /// Same contract as `ErrorReporting.flush(timeout:)`.
    func flush(timeout: Duration) async
}

// 3. Performance spans / transactions — frame-rate, latency, custom timings.
public protocol PerformanceTracking: Sendable {
    /// Starts a named span, optionally as a child of an open span.
    /// Parent/child hierarchy is required by Sentry transactions and
    /// Datadog RUM (`startView` → `addResource`). `parent == nil` starts
    /// a root span. Returned token is closed via `finish(_:outcome:)`.
    /// Maps to Sentry transactions/child spans, Datadog RUM resources/views,
    /// Firebase Performance traces, OSLog signposts (v1.0 default).
    func beginSpan(
        _ name: SpanName,
        parent: SpanToken?,
        attributes: [SpanAttribute: String]
    ) -> SpanToken

    /// Closes a span. Outcome is recorded against the span's name+attributes.
    /// Closing a parent before its children is a programming error; the
    /// default implementation logs a `.fault` but does not crash.
    func finish(_ token: SpanToken, outcome: SpanOutcome)
}
```

Supporting types — **all closed enums or struct value types** to prevent stringly-typed leakage:

- `DiagnosticLevel` — `.debug`, `.info`, `.warning`, `.error`. Maps 1:1 to vendor severity ladders.
- `BreadcrumbCategory` — `.navigation`, `.userAction`, `.system`, `.network`. Mirrors Sentry's category convention.
- `TagKey` — closed enum of allowed correlation keys (e.g. `.buildNumber`, `.experimentVariant`, `.deviceClass`) **plus a single escape hatch**: `case custom(String)`. Call sites in `Features/` may use **only the typed cases**; `.custom` is reserved for vendor adapters that need to forward vendor-specific context (Sentry's `BrowserContext`, Datadog's RUM session attributes, etc.). The linter / review checklist rejects `.custom` outside `Shared/Observability/Adapters/`.
- `UserContext` — `struct` with `installationID: UUID` (the only field in v1.0; opaque, locally generated, persisted in Keychain). Email/account fields are intentionally absent.
- `AnalyticsEvent` — closed enum with associated values for parameters, mirroring `QRType`'s shape. Adding a vendor SDK = one implementation that pattern-matches over cases.
- `SpanName` — closed enum (e.g. `.scanDetection`, `.historySearch`, `.galleryDetection`). Same rationale as `TagKey`.
- `SpanAttribute` — closed enum of allowed dimensions (e.g. `.qrType`, `.format`, `.cacheHit`).
- `SpanOutcome` — `.ok`, `.cancelled`, `.failed(reason:)`. Reason is a closed enum, never a free-form string.
- `SpanToken` — `struct SpanToken: Sendable, Hashable { let id: UUID }`. The token carries only a stable correlation key; per-vendor state lives inside the `PerformanceTracking` implementation, keyed on `id`. This avoids existentials/type-erasure and keeps the token a pure value. `SignpostPerformanceTracker` holds an internal `[UUID: SignpostHandle]` map (under an `actor` or `Mutex`) where `SignpostHandle` pairs the `SpanName` (carrying the `StaticString` needed by `OSSignposter.endInterval`) with the `OSSignpostIntervalState` returned from `beginInterval`. `finish(_:)` looks up the handle by token id, calls `endInterval(handle.name.signpostName, handle.state)` on the tracker's `OSSignposter`, and removes the entry.

**Privacy invariants (apply to all three protocols):**

- `Error` instances passed to `report(_:)` must be Scanly's typed errors (`WiFiConnectError`, `HistorySaveError`, `ScannerError`, etc.) — **never** an `NSError` carrying user content. Foundation/UIKit errors are mapped to typed Scanly errors at the adapter boundary before reporting.
- `captureMessage(_:level:)` strings must not interpolate `rawContent`, payload field values, or `Error.localizedDescription`. Reviewers reject violations.
- `BreadcrumbCategory.userAction` breadcrumbs describe **the action**, not the content (e.g., "url_action_invoked", not "opened https://...").
- `AnalyticsEvent` associated values must not contain raw scanned content — only discriminator-level information (`QRType.discriminator`, `BarcodeFormat.rawValue`).
- `setTag(_:value:)` values are short, non-PII strings (build number, A/B variant).

**v1.0 default implementations** (all in `Scanly/Shared/Observability/`):

- **`actor OSLogErrorReporter`** implements `ErrorReporting`. Actor isolation is the chosen concurrency mechanism — it serializes mutations to the breadcrumb ring buffer, the tags dictionary, and the user context. (`Sendable` alone does not make mutation safe; an `actor` does without requiring manual locking.)
  - `report(_:occurredAt:file:line:)` writes the typed error's case name to `Logger.observability` at `.error` level with the privacy rules in §10.5.3. `occurredAt` is included as a tag for historical (MetricKit-delivered) errors.
  - `captureMessage(_:level:)` writes the `StaticString` template to `Logger.observability` at the OSLog level corresponding to `DiagnosticLevel`.
  - Breadcrumbs are held in a bounded ring buffer (last 50) inside the actor; on `report(_:occurredAt:file:line:)` the buffer is logged once and cleared. No persistence, no network.
  - `setTag(_:value:)` and `setUserContext(_:)` mutate actor-isolated state; future adapters override this with vendor calls.
  - `flush(timeout:)` returns immediately (OSLog is synchronous); the `timeout` parameter is honored as a no-op contract.
- `NoOpAnalyticsTracker` implements `AnalyticsTracking` with empty methods (`track`, `identify`, `reset`, `flush` all no-ops). v1.0 has no analytics. The protocol exists for future use.
- **`actor SignpostPerformanceTracker`** implements `PerformanceTracking` using `OSSignposter` against `Logger.observability`. Spans show up in Instruments without any third-party tooling.
  - Owns an internal `[UUID: SignpostHandle]` map (actor-isolated) where `SignpostHandle` wraps the `SpanName` and the `OSSignpostIntervalState` returned by `OSSignposter.beginInterval(_:_:)`.
  - `beginSpan(_:parent:attributes:)` calls `signposter.beginInterval(name.signpostName, id:)` (generating a fresh `OSSignpostID`), stores the handle, and returns a `SpanToken` carrying a new `UUID`. The `parent: SpanToken?` parameter is **ignored** by the signpost implementation (signposts are flat). It is accepted to keep call sites identical across implementations; Sentry/Datadog adapters use it for hierarchy.
  - `finish(_:outcome:)` looks up the handle by `token.id`, calls `signposter.endInterval(handle.name.signpostName, handle.state, "outcome=\(outcome)")`, and removes the entry. Closing an unknown token logs a `.fault`.

**Vendor-adapter pattern (post-v1.0).** A future adapter (e.g. `SentryErrorReporter`) implements the same protocol, owns the SDK lifecycle, and is wired in `ObservabilityComposer` instead of the default — no instrumented call site changes anywhere in the app. Adapters are responsible for mapping closed-enum cases to vendor strings (e.g., `BreadcrumbCategory.navigation` → Sentry's `"navigation"`).

**Composition root.** A single type (`ObservabilityComposer`, in `Scanly/Shared/Observability/`) builds the three implementations at app launch and exposes them via SwiftUI environment values (`@Environment(\.errorReporter)`, `@Environment(\.analytics)`, `@Environment(\.performance)`). The composer also wires:

- **Backgrounding via `ScenePhase`** (not `UIScene.didEnterBackgroundNotification`). `ScanlyApp` reads `@Environment(\.scenePhase)` and uses `.onChange(of: scenePhase)` on the root scene: when the phase transitions to `.background`, the app body calls `await composer.flushObservability(timeout: .seconds(3))`, which fans out to `ErrorReporting.flush(timeout:)` and `AnalyticsTracking.flush(timeout:)` concurrently. This avoids importing UIKit at the composition site and is the idiomatic hook for a pure-SwiftUI `@main App`.
- App launch → reads/creates the `installationID` UUID from Keychain (via injectable `InstallationIDStore`) and calls `setUserContext(_:)` on the error reporter.
- Build number / scheme → `setTag(.buildNumber, value: ...)` once at launch.

Tests inject spies through the same environment keys.

#### 10.5.2 Analytics in v1.0 — none

No third-party analytics SDK. No custom event collection beyond `OSLog`. The §8 retention / DAU metrics are read from **App Store Connect → App Analytics**, which provides them anonymously when the user opts into "Share With Developers" — no app-side code required.

If a future iteration adds analytics, the `AnalyticsTracking` protocol from §10.5.1 is the integration point.

#### 10.5.3 OSLog policy — locked rules

Tightens §6.1 with non-negotiable rules:

1. **Subsystem:** all loggers use `io.alfredohdz.Scanly` (already defined in `Logger+Subsystems.swift:8`). No second subsystem.

2. **Categories: one per feature.** `scanner`, `history`, `actions`, `observability`. Domain-specific sub-features do **not** get their own category — they share their feature's category. Categories are defined on `Logger` extensions, one per feature, mirroring the existing `Logger.scanner`.

3. **Privacy rules — non-negotiable:**
   - `rawContent` (the literal scanned QR string) is **never** logged without an explicit privacy qualifier. Default is `.private`, and the redacted form is used in dashboards.
   - Wi-Fi passwords, vCard contents, email/SMS bodies, and phone numbers fall under the same rule — `.private` only.
   - **Allowed as `.public`:** `QRType.discriminator` (the case name without associated values, already designed for this purpose — see `QRType.swift:18`), `BarcodeFormat.rawValue`, `URLBreakdown.host` (host is considered low-sensitivity for diagnostic value; full URL stays `.private`).
   - **Allowed as `.public`:** error type names and HTTP status codes, never error messages that wrap user content.
   - Reviewers must reject any PR that interpolates `rawContent`, payload field values, or `Error.localizedDescription` into a log line without an explicit privacy qualifier.

4. **Level semantics — fixed:**
   - `.debug` — pipeline-level traces, frame counts, debouncer state transitions. Stripped in Release builds by OSLog itself.
   - `.info` — feature-level lifecycle: scan event, save success, action invoked. Stripped in Release builds.
   - `.notice` — **not used**. Default mid-level emits noisy logs in Release; we keep the distinction binary (info vs. error).
   - `.error` — recoverable failures that produced a degraded UX or required user action. Persisted by the system in Release. Examples: history save failure, Wi-Fi connect failure, vCard parse failure.
   - `.fault` — invariants violated or unexpected state that suggests a bug. Persisted in Release. Pairs with `assertionFailure` in debug builds.

5. **Anti-pattern catalog (rejected on review):**
   - `Logger.scanner.info("Scanned: \(rawContent)")` — leaks content.
   - `Logger.scanner.error("\(error)")` — `Error`'s default interpolation calls `localizedDescription`, which can include user content. Always wrap: `"\(error, privacy: .private)"` or extract a typed code.
   - Logging from a tight per-frame callback at `.info` level — use `.debug` and rely on the Release strip-out.
   - Logging the same event in multiple categories ("scanner" and "history" for the same save).

#### 10.5.4 Success metrics §8 — sources

Each metric in §8 gets an explicit measurement source. No metric remains aspirational without a dashboard.

| §8 metric | Source | App-side requirement |
|---|---|---|
| Crash-free rate ≥ 99.5% | App Store Connect → Trends → Crashes, cross-checked with Xcode Organizer | None (system-captured) |
| Rating ≥ 4.5 | App Store Connect → App Information → Ratings & Reviews | None |
| 7-day retention ≥ 40% | App Store Connect → App Analytics → Retention | None (requires user "Share With Developers" opt-in) |
| Scan time < 1s | Manual instrumentation in development; not measured in production for v1.0 | `PerformanceTracking.beginSpan(.scanDetection, parent: nil, attributes: ...)` in `AVFoundationQRScanner`. The default `SignpostPerformanceTracker` surfaces it in Instruments. When a vendor performance backend ships post-v1.0, the same call site forwards to Firebase Performance / Sentry / Datadog without changes. |

**No SLO alerting in v1.0.** The metrics above are observed via dashboards and reviewed periodically, not paged on. Alerting infrastructure is a post-v1.0 concern that arrives with the eventual analytics/observability SDK.

#### 10.5.5 MetricKit — additional native data source

Beyond App Store Connect dashboards, iOS exposes **MetricKit** (`import MetricKit`), which delivers daily payloads of crash reports (`MXCrashDiagnostic`), hang reports (`MXHangDiagnostic`), CPU/disk/memory diagnostics, and aggregated performance metrics (`MXMetricPayload`) directly to the running app. This is a v1.0 free-tier observability source — no SDK, no entitlement, no privacy disclosure beyond the existing "Share With Developers" opt-in.

**Wiring.** A new type `MetricKitSubscriber` (`NSObject` subclass, in `Scanly/Shared/Observability/`) conforms to `MXMetricManagerSubscriber` and is registered at app launch via `MXMetricManager.shared.add(_:)`. It receives `didReceive(_ payloads: [MXMetricPayload])` callbacks (daily aggregated metrics) and `didReceive(_ payloads: [MXDiagnosticPayload])` callbacks (crashes/hangs/CPU/disk diagnostics) and forwards them to the `ErrorReporting` protocol:

- `MXCrashDiagnostic` → wrap as a typed `CrashDiagnosticError` that carries the original `timeStampBegin` from the payload, then call `errorReporter.report(crashError, occurredAt: timeStampBegin, file: #fileID, line: #line)`. The historical timestamp prevents vendor adapters from misattributing the crash to the current session.
- `MXHangDiagnostic` → `errorReporter.captureMessage("hang_diagnostic_received", level: .warning)` preceded by `setTag(.hangDurationMs, value: ...)`. Hang reports are also historical; the timestamp is set via tag for the same reason.
- `MXMetricPayload` aggregated values (application launch metrics, scroll metrics, etc.) → logged to `Logger.observability` at `.debug` level so they are stripped from Release builds automatically. The OSLog category is the persistence mechanism — no separate file, no `UserDefaults`. Developers inspect them via Console.app or the unified log archive.

**Subscriber lifetime.** `ObservabilityComposer` holds `MetricKitSubscriber` as a strong stored property for the lifetime of the app. `MXMetricManager.shared.add(_:)` does not retain its subscribers; if the subscriber is created as a local variable in the launch path it is silently deallocated and no payloads arrive. The composer's `deinit` is not relied upon to call `MXMetricManager.shared.remove(_:)` — the app process termination is the only valid lifecycle for the subscriber.

**Why this matters even without an SDK.** Once a vendor adapter is added post-v1.0, MetricKit payloads are already plumbed through `ErrorReporting` — the vendor sees them automatically. v1.0 ships the plumbing; v2.0 swaps the backend.

### 10.6 Permissions UX (affects §3.1, §5, §10.3) — 2026-05-13

Camera permission is mission-critical: without it, Scanly cannot perform its primary function. Contacts is needed for "Add to Contacts" (§10.3.2). Photos is **not** a permission Scanly needs. This entry locks the request timing, the denied/restricted UX, the revocation flow, and reconciles a deliberate exception to §5's "no unnecessary onboarding" principle.

#### 10.6.1 Camera permission

**Existing implementation** (`SessionCore.ensurePermission()`) reads `AVCaptureDevice.authorizationStatus(for: .video)` with three switch arms: `.authorized` (early return), `.notDetermined` (calls `AVCaptureDevice.requestAccess(for: .video)`), and a **combined `case .denied, .restricted:`** that throws `QRScannerError.permissionDenied`, plus `@unknown default`. Today the error type does not distinguish the two terminal states. §10.6 keeps that AVFoundation-layer error unified (no change to `SessionCore`) and introduces the split **only at the UX layer**, via the new `CameraPermissionMonitoring` protocol described below. The presentation views read the typed `CameraPermissionStatus` from the monitor, not from `SessionCore`'s thrown error.

**Single owner of `AVCaptureDevice.requestAccess(for: .video)`.** With the priming screen in place, `CameraPermissionMonitoring.requestAccess()` becomes the **only intended caller** of the system prompt. To prevent the two paths from racing:

- `ScannerViewModel` does not call `SessionCore.start()` while `permissionState == .notDetermined`. The priming screen owns the entire transition from `.notDetermined` to a terminal state.
- After the user taps Continue and the monitor reports the new status, the view model transitions to `preview` (if granted) or `denied` (if not) and only then calls `SessionCore.start()`.
- `SessionCore.ensurePermission()`'s `.notDetermined` arm stays as a **backstop** for unexpected entry paths (programmatic call sites, future re-entry from gallery flow, etc.) — it is no longer the designed prompt callsite. If it ever fires in production, it indicates a state-machine bug worth investigating.

##### Request timing — first-launch priming

Camera access is requested with a **single-screen priming step shown only on the very first launch** before the system prompt fires:

1. **On app launch**, `ScannerViewModel` checks `AVCaptureDevice.authorizationStatus(for: .video)`:
   - `.authorized` → go directly to the camera preview. No priming, no prompt. This is what every launch after the first looks like.
   - `.denied` / `.restricted` → go to the denied screen (§10.6.1.2). No priming.
   - `.notDetermined` → present the **priming screen**.

2. **Priming screen** (`CameraPermissionPrimingView`, a new file under `Scanly/Features/Scanner/Presentation/`):
   - One screen, one purpose: a camera icon, a one-line headline (`scanner.permission.priming.title`: "Scan QR codes"), a 2–3-line rationale (`scanner.permission.priming.body`: "Scanly uses the camera to detect QR codes in real time. Your scans stay on this device."), one prominent **Continue** button.
   - Tap **Continue** → calls `AVCaptureDevice.requestAccess(for: .video)`. On the result:
     - `true` → transition to the camera preview.
     - `false` → transition to the denied screen.
   - No "Skip" / "Not now" button. The user either continues or backgrounds the app — there is no in-app path that defers the decision indefinitely.

3. The priming screen is **single-shot**: once the user has responded (status is no longer `.notDetermined`), it never appears again for the lifetime of that install. After a reinstall iOS returns `.notDetermined` and priming reappears, which is the desired behavior — a fresh install genuinely is a first launch.

**Reconciliation with §5 ("sin onboarding innecesario").** §5 forbids feature-tour or marketing onboarding — celebratory walk-throughs that delay the user from the core task. A one-time permission rationale that is required to unlock the core task is **not** that. The priming screen is scoped to:
- one screen only,
- shown at most once per install,
- exists only for camera (no priming for contacts, no priming for any other surface),
- copy is rationale-only, never a feature tour.

Anything beyond this scope re-triggers the §5 prohibition.

##### Denied vs. restricted UX

The current `QRScannerError.permissionDenied` collapses `.denied` and `.restricted` into one error. **§10.6 splits them in the UX layer**, even if the underlying error code stays unified:

- **`.denied`** — the user said No. Show **`CameraDeniedView`**:
  - Camera-slash icon.
  - Headline: `scanner.permission.denied.title` ("Camera access turned off").
  - Body: `scanner.permission.denied.body` ("Scanly needs camera access to scan QR codes. You can turn it back on in Settings.").
  - Primary CTA: `scanner.permission.denied.open_settings` ("Open Settings") → calls `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`.
  - This view fills the camera area; the toolbar / gallery picker remain reachable so the user can still scan from photos (which needs no permission — §10.6.3).
- **`.restricted`** — the device is locked down by parental controls, Screen Time, or MDM. The user cannot change it from Settings, so the "Open Settings" CTA would be misleading. Show **`CameraRestrictedView`**:
  - Same icon as denied.
  - Headline: `scanner.permission.restricted.title` ("Camera access restricted").
  - Body: `scanner.permission.restricted.body` ("Camera access is restricted on this device. Contact your device administrator or check Screen Time settings.").
  - **No** "Open Settings" button. The gallery picker stays reachable.
  - **Deliberate omission:** no "Learn more" link to Apple's parental controls support article, no MDM-administrator deep link. MDM-managed users do have legitimate paths to request profile changes, but surfacing them inside the app adds copy and link maintenance for a small audience. A "Learn more" link is a post-v1.0 candidate; the v1.0 stance is to keep the screen minimal and let the user discover the path through Settings on their own.

The two views share a base layout to avoid drift; differentiate via the displayed strings and the presence/absence of the CTA button.

##### Revocation while running

When the app returns to foreground, re-check authorization status and switch the view accordingly:

- `ScannerView` observes `@Environment(\.scenePhase)` (already needed for the observability flush — §10.5.1). Note that `.scenePhase` transitions in both directions: `.background` triggers the observability flush; `.active` triggers the permission re-check. They are independent hooks on the same `.onChange(of: scenePhase)` modifier.
- **Transitions covered.** `.onChange(of: scenePhase)` fires on any phase change, so the re-check runs on both `background → active` (foreground after a backgrounded interval) **and** `inactive → active` (foreground after a brief interruption such as Control Center pull-down, Notification Center swipe, or the iOS camera-access quick toggle, which can leave the app `.inactive` without ever transitioning to `.background`). The Control Center camera toggle is the practical motivator: changing privacy settings via Control Center does **not** always kill the process, so the inactive-active path is the one that catches it.
- On any transition to `.active`, the view model calls a `CameraPermissionMonitor` (new protocol in `Data`) which reads `AVCaptureDevice.authorizationStatus(for: .video)` and publishes the current status to the view model. If the status now indicates denial/restriction, the camera preview is replaced with the appropriate view from §10.6.1.2.
- The reverse transition (denied → authorized while app is in background, then user returns) is **also handled**: re-running the check on `.active` finds `.authorized` and restores the preview. No app relaunch required.
- iOS typically kills the app process when the user changes a privacy setting in **Settings**, so this code path is the edge case for users who change settings via Control Center toggles or Screen Time without triggering a relaunch.

**Protocol shape** so the permission status is testable without hitting `AVCaptureDevice`:

```swift
public protocol CameraPermissionMonitoring: Sendable {
    func currentStatus() -> CameraPermissionStatus
    func requestAccess() async -> Bool
}

public enum CameraPermissionStatus: Sendable, Equatable {
    case notDetermined, authorized, denied, restricted
}
```

The live adapter wraps `AVCaptureDevice.authorizationStatus(for: .video)` and `AVCaptureDevice.requestAccess(for: .video)`; a `CameraPermissionSpy` lives in `ScanlyTests/Features/Scanner/`.

#### 10.6.2 Contacts permission

Contacts access is required for the vCard "Add to Contacts" CTA (§10.3.2). The permission is requested **in-context**, not at launch and not via priming:

- On the first tap of "Add to Contacts" with a vCard scan, `CNContactViewController.forNewContact(_:)` is presented. iOS surfaces the contacts-permission prompt the first time the user attempts to save. No app-side priming.
- If the user denies, the next "Add to Contacts" tap shows an alert with `scanner.permission.contacts.denied.title` ("Contacts access turned off") / `body` / "Open Settings" / "Cancel". The deep link is `UIApplication.openSettingsURLString`, same pattern as camera denial.
- **Alert collision with §10.3.3.** §10.3.3 introduced a URL-confirmation alert that makes `ScanResultSheet` non-dismissible while presented. SwiftUI allows only one active `.alert` per view, so a contacts-denied alert presented on the same sheet would be silently dropped if the URL alert is already up. Resolution: the **"Add to Contacts" primary CTA is disabled while any other alert is active on the sheet**. The view model exposes a single `activeAlert` enum (`.none`, `.urlConfirmation(URL)`, `.contactsDenied`, ...) bound to one `.alert(_:isPresented:)` modifier; mutually-exclusive presentation is enforced by the enum. CTAs that would present a competing alert are non-interactive while `activeAlert != .none`.
- `.restricted` for contacts follows the same split as camera: hide the "Open Settings" CTA and show restricted-specific copy.
- `NSContactsUsageDescription` is in `Info.plist` (per §10.3 implications) with the English copy "Scanly adds scanned contacts to your address book." Localization for Info.plist strings lives in **`InfoPlist.xcstrings`** (the file already exists alongside `NSCameraUsageDescription` — see the project's `Scanly/InfoPlist.xcstrings`), **not** `Localizable.xcstrings`. The Spanish variant ships at the same time, added directly to `InfoPlist.xcstrings`.

#### 10.6.3 Photos — no permission required

Gallery scanning is implemented via **`PhotosPicker`** (already present in `ScannerView.swift:13` and `:238`), which is the SwiftUI wrapper over `PHPickerViewController`. Both run **out-of-process**: the picker UI is rendered by a separate system process and the app receives only the items the user explicitly picks. **No `NSPhotoLibraryUsageDescription` is required and none is added to `Info.plist`.** This is a privacy-positive default that we intentionally rely on.

Implications:

- No `PhotosPicker` configuration touches `PHPhotoLibrary.requestAuthorization(_:)` — that API is for apps that need broad library access, which Scanly does not.
- If a future feature needs broader access (e.g., scanning every photo in a library in bulk), the cost is one new privacy disclosure string and a new explicit permission flow. v1.0 deliberately avoids this surface.
- The "deny photos access" UX therefore **does not exist** in v1.0. `PhotosPicker` never surfaces a per-app permission prompt — that is the design of `PHPickerViewController`. If the user dismisses the picker without selecting an image, the picker simply returns no items and the scanner view continues operating as if no image was selected.

#### 10.6.4 Permissions Scanly does NOT request

To prevent scope creep and accidental permission requests, v1.0 explicitly does **not** use:

| Permission | Reason |
|---|---|
| Location | Scanned location QRs open in Maps via `MKMapItem` — we never read the device's location. |
| Notifications | No push, no local notifications in v1.0. |
| Microphone | No audio capture. |
| Calendar / Reminders | Not used by any QR type in scope. |
| Health / Motion | Out of scope. |
| Tracking (App Tracking Transparency) | No third-party SDKs, no analytics, no ad networks (§10.5.2). **v1.0 only** — revisit when any analytics vendor requiring `ATTrackingManager` (e.g., Amplitude with IDFA collection enabled) is added via §10.5.1. |
| Bluetooth | No BLE peripherals. |

**Info.plist hygiene.** No usage-description string is added to `Info.plist` for any row in the table above — including `NSUserTrackingUsageDescription` (the ATT-shaped string that App Tracking Transparency requires). ATT does follow the `*UsageDescription` naming pattern despite being a runtime API rather than a system-prompt permission, so it is included in this exclusion explicitly. Adding any of these strings later is a code-review-blocker that must be justified in the PR description.

#### Implications for current code (Permissions)

- **New views (Presentation):** `CameraPermissionPrimingView`, `CameraDeniedView`, `CameraRestrictedView`, all under `Scanly/Features/Scanner/Presentation/`. They share a base layout / shared private subview.
- **`ScannerView`** branches at the top level between four states: `priming`, `preview`, `denied`, `restricted`. Today it shows the preview unconditionally; this branch lives in `ScannerViewModel` and the view picks the body via a `switch`.
- **`ScannerViewModel`** gains a `CameraPermissionMonitoring` dependency and a published `permissionState` value. On `init` it reads the current status. On `.scenePhase == .active` it re-reads.
- **New protocol:** `CameraPermissionMonitoring` (Data) + `LiveCameraPermissionMonitor` adapter + `CameraPermissionSpy` test double.
- **Existing `SessionCore.ensurePermission()` stays** — it is the source of truth at the AVFoundation layer. The new monitor is the *presentation-layer* observation surface that drives view branching. They wrap the same `AVCaptureDevice` calls but serve different consumers.
- **Localization keys** added to `Localizable.xcstrings` under the `scanner.permission.*` namespace: `priming.title`, `priming.body`, `priming.continue`, `denied.title`, `denied.body`, `denied.open_settings`, `restricted.title`, `restricted.body`, `contacts.denied.title`, `contacts.denied.body`, `contacts.denied.open_settings`, `contacts.denied.cancel`. All translated to Spanish (the existing locale).
- **No new entitlements are added by §10.6 specifically.** Camera and contacts entitlements are implicit via the Info.plist usage descriptions; no `Scanly.entitlements` change is required for this section. The Hotspot Configuration entitlement added by §10.3.5 is unrelated and stays.
- **Tests** cover: priming view shown only when `.notDetermined`; `Continue` button calls `requestAccess` once and transitions on the result; denied/restricted views render the right copy and (for denied) wire the Open Settings button; `.scenePhase` change re-queries the monitor and swaps the view state when the underlying status changes; gallery picker remains reachable in all four states.

#### Implications for current code (Observability)

- **New folder:** `Scanly/Shared/Observability/`. Initial files:
  - `ErrorReporting.swift`, `AnalyticsTracking.swift`, `PerformanceTracking.swift` — the three protocols.
  - `DiagnosticLevel.swift`, `BreadcrumbCategory.swift`, `TagKey.swift`, `UserContext.swift`, `AnalyticsEvent.swift`, `SpanName.swift`, `SpanAttribute.swift`, `SpanOutcome.swift`, `SpanToken.swift` — the closed-enum/struct surface.
  - `OSLogErrorReporter.swift`, `NoOpAnalyticsTracker.swift`, `SignpostPerformanceTracker.swift` — v1.0 default implementations.
  - `MetricKitSubscriber.swift` — wires `MXMetricManager` payloads through `ErrorReporting` (§10.5.5).
  - `ObservabilityComposer.swift` — composition root, builds the three live implementations and the MetricKit subscriber.
  - `Environment+Observability.swift` — SwiftUI environment keys for `errorReporter`, `analytics`, `performance`.
- **`Logger+Subsystems.swift`** gains `Logger.history`, `Logger.actions`, `Logger.observability` alongside the existing `Logger.scanner`. All four point to the same subsystem.
- **`ScanlyApp.swift`** instantiates `ObservabilityComposer` at launch, injects the three protocols via `.environment(...)` on the root view, registers `MetricKitSubscriber` with `MXMetricManager.shared`, and uses `ScenePhase.onChange` on the root scene (as detailed in §10.5.1 above) to call `flush()` on the error reporter and analytics tracker when the phase transitions to `.background`. The handler stays inside the SwiftUI `App` body — no UIKit notification observation is registered at the composition site.
- **Tests** override the environment keys with spies that record calls. Pattern mirrors `HapticFeedbackSpy`/`TorchSpy` already in `ScanlyTests/Features/Scanner/`. New spies live under `ScanlyTests/Shared/Observability/`.
- **Typed errors** for Scanly features. The existing `QRScannerError` is the template; add `HistorySaveError`, `WiFiConnectError`, `VCardParseError`, etc., as their features land. `ErrorReporting.report(_:)` accepts these typed errors only — Foundation/UIKit errors are wrapped at the adapter boundary.
- **Keychain storage** for the installation UUID (`UserContext.installationID`). A tiny `InstallationIDStore` protocol in `Shared/Observability/` keeps the Keychain dependency injectable for tests.
- **No vendor SDK, no `Info.plist` privacy strings, no entitlements** added for v1.0 observability. MetricKit is system-provided and gated by the existing "Share With Developers" opt-in.
- **Vendor swap is a single-file change post-v1.0.** Adding Sentry/Crashlytics/Datadog/Amplitude means writing one new implementation of the relevant protocol (or all three) and changing one line in `ObservabilityComposer`. No instrumented call site changes anywhere in `Features/`.
- **Audit existing call sites:** the `Logger.scanner` calls currently in `AVFoundationQRScanner`, `ScannerViewModel`, etc., must be audited against the §10.5.3 privacy rules before §10.5 is considered complete. Any log line interpolating `rawContent` or payload fields without a privacy qualifier is a bug to fix in this branch's follow-up.
