# QRX — MVP Spec

*Working name — final branding TBD. Research basis: `APPS.md` → QR Code Generator (July 2026).*

## Positioning (one line)

**Beautiful branded QR codes that never expire** — every visual aspect customizable, your logo in the middle, no ads, no subscription, no scan limits, fully offline.

## Who it's for

Small brands, creators, and small businesses burned by web generators: trial-to-$40/mo traps, codes that die mid-campaign, hidden scan caps, watermarks. Trust is the product.

## The MVP bet

1. **The create loop is the app** — type content, watch the code restyle live, export. Under a minute from open to print-ready file.
2. **Brand customization is the differentiator** — colors, gradients, module shapes, eye shapes, and a center logo (photo or monogram) with clean knockout. No native app does this well.
3. **Codes are static and honest** — pure math, generated on-device, work forever. Scannability is verified live (Vision decode check) so nobody prints a broken code.

## In / Out

### ✅ In (MVP — this phase)

**Content types**
- URL, plain text, Wi-Fi (SSID/password/security/hidden), contact (vCard), email, phone

**Design (all live-previewed)**
- Foreground: solid color or 2-stop linear gradient with angle
- Background color incl. transparent (for print/dark-mode assets)
- Module shapes: square, rounded, circle (dots), diamond
- Eye shapes: square, rounded, circle, leaf (orientation-aware per corner)
- Optional separate eye ring + pupil colors
- **Center logo**: photo from library or generated monogram (initials + colors); size slider, module knockout, backing shape (none / circle / rounded)
- Error correction auto-raises to High when a logo is present

**Trust & correctness**
- Live **"Scans ✓" badge**: every render is decoded with Vision and compared to the expected payload; warns before anyone exports a broken code
- 100% offline, zero analytics

**Export**
- PNG 2048px + **SVG vector** (print-ready) via share sheet

**Library (Phase 2 — done)**
- SwiftData-backed saved codes: name, live-rendered thumbnail, edit round-trip
  (full builder state restored, including monogram inputs)
- Rename / duplicate-free row actions: rename alert, share PNG from context
  menu, swipe-to-delete
- Store failure surfaces an error screen — never a silent in-memory fallback

**Frames (Phase 2 — done)**
- "SCAN ME" CTA frame: rounded border + filled banner, custom label text and
  color, auto black/white label contrast; identical in PNG and SVG export

**Widgets & Present mode (Phase 3a — done)**
- Home Screen widgets (small/medium) rendering a chosen saved code — scannable,
  always on a white container; user-configurable via AppIntent; pinned codes
  surface first
- Lock Screen accessories that quick-launch the code
- Full-screen **Present mode** (library context menu + `qrx://present/<id>`
  widget deep links) — hand your phone to a guest
- SwiftData store in the App Group container (one-time legacy migration);
  shared `QRXShared` sources compiled into app + widget

### ❌ Out (explicitly deferred)

| Deferred | Why | Target |
|---|---|---|
| iCloud sync of library (CloudKit) | Schema is CloudKit-ready (inline defaults); needs entitlements + signing pass | Phase 3b |
| Share Extension ("make a QR from anything I'm sharing") | Next native surface | Phase 3b |
| Built-in scanner + malicious-URL warning | Separate surface | Phase 3c |
| App Intents / Shortcuts, Wallet passes | After Share Extension | Phase 3c |
| PDF export, batch/CSV | Pro-tier features | Phase 4 |
| Honest dynamic codes + analytics | Needs server; the one justifiable sub | Later |

## Architecture

- `QRCore/` — local Swift package, no app dependencies:
  - `QRMatrix` — payload → bool module grid via `CIQRCodeGenerator` (pixel-sampled, quiet zone cropped)
  - `QRDesign` — codable design model (shapes, fills, logo options); shape → `CGPath` generators shared by renderer, SVG export, and UI swatches
  - `QRLayout` — geometry in module units: eye regions, logo rect, knockout tests
  - `QRRenderer` — CoreGraphics raster render (any pixel size)
  - `QRSVGExporter` — same geometry as vector SVG
- `QRX/` — SwiftUI app: builder screen (live preview + content fields + design panel), Vision scan-check, Transferable PNG/SVG exports

## Monetization (per APPS.md + cross-app philosophy)

Free: all content types, full customization, PNG export, no ads/watermarks ever.
One-time Pro unlock (price TBD): SVG/PDF vector export, batch, frames. Decide exact split at Phase 2.
