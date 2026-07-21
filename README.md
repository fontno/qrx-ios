# QRX

Beautiful branded QR codes that never expire — an iOS app for creating fully
customized, print-ready QR codes with your logo in the middle. No ads, no
subscription, no scan limits, 100% offline.

## Why

The QR generator market is a trust vacuum: web tools that auto-convert trials
into $40/mo subscriptions, "dynamic" codes that die mid-campaign the moment you
stop paying, hidden scan caps, and watermarks on the free tier. QRX codes are
static — pure math, generated on-device — so they work forever.

## Features

- **Six content types**: URL, plain text, Wi-Fi (with correct `WIFI:` escaping),
  contact card (vCard 3.0), email, phone
- **Full brand customization**, live-previewed: solid or gradient foreground,
  module shapes (square / rounded / dots / diamond), eye shapes (square /
  rounded / circle / leaf with per-corner orientation), independent eye-ring and
  pupil colors, any background including transparent
- **Center logo**: photo (aspect-filled and clipped to circle / rounded rect) or
  a generated monogram badge, with module knockout and automatic error-correction
  boost
- **"SCAN ME" frames**: rounded border + banner with custom text and
  auto-contrast label color
- **Live scannability check**: every render is decoded on-device (Vision, with a
  CoreImage fallback) and compared against the intended payload before the user
  can export a broken code
- **Print-ready export**: 2048px PNG and true-vector SVG that match the raster
  renderer exactly
- **Library**: saved codes with live thumbnails, rename/share/delete, and full
  editor-state restore (SwiftData)

## Architecture

```
QRX/
├── QRCore/            Engine (local SwiftPM package, no app dependencies)
│   ├── QRMatrix       Payload → module grid via CIQRCodeGenerator pixel sampling
│   ├── QRDesign       Codable design model + shape path generators
│   ├── QRLayout       All geometry in module units (eyes, knockout, frames)
│   ├── QRRenderer     CoreGraphics raster renderer
│   └── QRSVGExporter  Vector export sharing QRLayout, so SVG ≡ PNG
├── QRX/               SwiftUI app (builder, library, exports, scan check)
├── QRXTests/          App-target unit tests (Swift Testing)
├── QRXUITests/        UI smoke tests (XCUITest)
└── QRCore/Tests/      Engine tests (Swift Testing)
```

Key decisions:

- **No third-party dependencies.** The QR matrix comes from `CIQRCodeGenerator`,
  sampled at one pixel per module; all styling is custom CoreGraphics on top.
- **One geometry source.** `QRLayout` computes everything in "module units";
  the raster renderer and SVG exporter both consume it, so vector output is
  pixel-identical to the preview.
- **Persistence that fails loudly.** SwiftData models use inline defaults
  (CloudKit-ready), and a store-open failure shows an error screen — never a
  silent in-memory fallback that would masquerade as data loss.

## Testing

69 tests across three targets, run with code coverage via `QRX.xctestplan`.

The centerpiece is a **scannability property test**: for every module-shape ×
eye-shape combination — plus gradients, custom eye colors, transparent
backgrounds, logos with knockout, and frames — the rendered bitmap must decode
back to the exact input payload. The app's core promise, enforced in CI.

```sh
# Engine tests (run from the package — xcodebuild skips local-package test
# targets when invoked against the project)
cd QRCore && xcodebuild -scheme QRCore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# App unit tests + UI smoke tests
xcodebuild -project QRX.xcodeproj -scheme QRX \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Also covered: payload escaping (Wi-Fi/vCard), matrix structure (finder
patterns, valid version sizes), layout geometry, SVG well-formedness and
raster/vector parity, builder-state round-trips, and SwiftData persistence
against isolated in-memory stores.

## Requirements

- Xcode 26.6+, iOS 26.5+

## Roadmap

iCloud sync of the library, Lock Screen widgets for pinned codes (Wi-Fi QR for
guests), Share Extension, built-in scanner with malicious-URL warning, batch
generation. Monetization will be a one-time Pro unlock — never a subscription
holding codes hostage.
