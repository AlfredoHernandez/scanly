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
