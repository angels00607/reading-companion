# Approved Phase 0 fonts

Original source files in `/fonts` are preserved byte-for-byte from `main`.
FontTools 4.60.2 inspected their binary name tables:

| Source | Family / typographic family | PostScript name |
| --- | --- | --- |
| Manrope-VariableFont_wght.ttf | Manrope ExtraLight / Manrope | Manrope-ExtraLight |
| PapernotesRegular.woff | Papernotes | PapernotesRegular |
| Hello Baby.otf | Hello Baby | HelloBabyRegular |

Manrope has a variable weight axis 200–800 with default 200. App resources use
static 400, 500 and 600 instances generated with FontTools' `instantiateVariableFont`
and `updateFontNames=True`. Verified names: Manrope-Regular, Manrope-Medium,
Manrope-SemiBold. Papernotes is CFF OpenType inside WOFF; its container was
converted to `.otf`. Hello Baby is copied without conversion.
Runtime XCTest checks bundle resources and UIKit registration without fallback.

Manrope is functional typography. Papernotes and Hello Baby remain reserved accent
roles; Phase 0 adds no feature or celebration screens.

Source SHA-256:
- Manrope: `2b7a1ebc80c79246faa1b6e7093c7b91de2a4ceedb9b9a2b2fa05cf9bf8c77cd`
- Papernotes: `8a0e6f141ec32b126003348f4f96bb2d909e2785327635a511cc19075f063157`
- Hello Baby: `e8487716783c7a0510f8f2437d79a7d0097601d4e044236cf71443c42f186dca`
