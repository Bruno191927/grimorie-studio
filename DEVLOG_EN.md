# 🧙‍♂️ Grimoire Studio — Devlog: Premium Finishes, Manufacturing & Rulebook Update

**Date:** October 28, 2026  
**Version:** v0.6.0  
**Branch:** Production / Main (`main`)  

---

## 🌟 Update Overview

This release represents one of the most significant milestones in **Grimoire Studio**'s development. We have evolved the tool from a rapid card prototyping engine into a **complete, all-in-one publishing and design suite for tabletop card games and TCGs (Trading Card Games)**.

With this update, we bridge the entire pipeline: from conceptual card design and mathematical deck balancing, to print-ready professional visual finishes, physical & digital manufacturer export packages, and an integrated rulebook authoring system.

---

## 🚀 Key Highlights

### 1. 🖼️ Automated Art & Database Synchronization (`art_url`)
* **Problem Solved:** Previously, certain cards had empty `art_url` fields in the database/CSV view despite having artworks assigned to their category templates.
* **Instant Bi-directional Sync:** Assigning or replacing an image layer from the Inspector Panel immediately writes the local relative path into the active CSV/database row (`bindingKey` or `art_url`).
* **Smart Template Resolving:** The synchronization routine now inspects visual layers for each card's assigned template, automatically resolving relative paths (`assets/...`) across all rows.
* **Inherited Artwork on Card Creation:** Newly created or cloned cards seamlessly inherit art from their default template or base card, guaranteeing zero blank or broken rows.

---

### 2. 🖨️ Connectors for Manufacturers & Digital Platforms
Grimoire Studio now provides native export presets aligned with industry manufacturing standards:

* **The Game Crafter (TGC):**
  * Poker format: **825 × 1125 px @ 300 DPI** (safe zone + 36 px bleed margin).
  * Automatic `thegamecrafter_manifest.json` metadata generator.
  * Ready-to-follow upload checklist guide.
* **MakePlayingCards (MPC):**
  * International Poker dimensions: **816 × 1110 px @ 300 DPI** (63 × 88 mm + border bleed).
  * Automatically partitioned directories: `fronts/` and `backs/`.
  * Integrated `mpc_order_guide.txt` to avoid alignment and printing issues.
* **Screentop.gg (Browser Virtual Tabletop):**
  * High-performance **Grid Sprite Sheets** optimized for web delivery.
  * Bundled `screentop_asset.json` schema for drag-and-drop import without manual coordinate mapping.

---

### 3. 📖 Rulebook Builder & Printable A5 Booklet
A dedicated screen for writing, designing, and exporting game manuals, accessible from the sidebar navigation or via **`Ctrl + 6`**:

* **Modular Section Management:**
  1. **Cover & Lore:** Game title, credits, lore intro, and pitch.
  2. **Game Components:** Automatic card inventory breakdown grouped by category and factored by copy count (`qty`) directly from the card database.
  3. **Objective & Setup:** Step-by-step game setup and victory conditions.
  4. **Turn Phases:** Structured round phases with titles, descriptions, and sequence order.
  5. **Card Anatomy:** Visual breakdown explaining card elements (cost, category, body text, combat stats).
  6. **Glossary:** Keyword index and gameplay definitions.
  7. **Frequently Asked Questions (FAQ):** Edge cases, timing questions, and clarifications.
* **Printable A5 Booklet PDF Export:**
  * Vector PDF rendering engine formatted for multi-page A5 saddle-stitch booklets.
  * Stylized cover and typography matching the dark aesthetic of the studio.

---

### 4. 🎨 Premium Visual Finishes (Professional TCG Look & Feel)

#### A. Inline Badges, Mana Costs & Symbols
The card text renderer now supports rich inline badge tokens with bilingual syntax (English & Spanish):
* **Numeric Costs:** `{0}` through `{9}`
* **Elements & Mana:** `{fire}` / `{fuego}`, `{water}` / `{agua}`, `{nature}` / `{planta}`, `{light}` / `{luz}`, `{dark}` / `{sombra}`
* **Actions & Combat:** `{tap}` / `{T}` / `{girar}`, `{sword}` / `{espada}`, `{shield}` / `{escudo}`, `{heart}` / `{vida}`, `{skull}` / `{calavera}`, `{star}` / `{estrella}`, `{action}` / `{accion}`
* One-click insertion chips embedded into the Layer Inspector for quick authoring.

#### B. Text Stroke & Exterior Outline
* Native support for customizable stroke outlines on text and numeral layers (`textStrokeWidth` and `textStrokeColor`).
* Two-pass rendering (stroke layer beneath fill layer) ensuring crystal-clear typography over complex artwork and dark backgrounds.

#### C. 3D Holographic Foil Simulation (Shaders)
The interactive 3D Card Inspector now includes simulated collectible foil finishes:
* **Rainbow Foil:** Angle-dependent spectral iridescence across the card surface.
* **Secret Rare Gold:** Reflective metallic gold sheen with specular highlights.
* **Cosmic Prism:** Starburst prism dispersion tailored for legendary and ultra-rare cards.

---

### 5. 📊 Deck Analytics & Game Balance Dashboard (`Ctrl + 5`)
Built specifically for game designers to balance curves and archetypes:
* **Mana / Cost Curve:** Interactive bar charts tracking average costs and turn progression.
* **Type & Category Distribution:** Pie charts detailing ratios of creatures, spells, artifacts, etc.
* **Combat Metrics:** Attack vs. Defense power curves and average stats per cost tier.
* **Smart Balance Warnings:** Automatic flags for overtuned cards or statistical outliers.
* **Starting Hand Simulator (Mulligan):**
  * Monte Carlo opening hand simulations (draw 5, 7, or custom hand sizes).
  * Exact **hypergeometric distribution** calculation to predict opening-turn draw probabilities for key cards.

---

## 🛠️ Technical Quality & Engineering

* **191 Automated Tests Passing (100%):** Unit and widget test suites execute cleanly (`flutter test`).
* **Zero Analyzer Warnings:** Completely clean static analysis with `dart analyze`.
* **Security & Secret Audit:** Verified no credentials, tokens, local configurations, or sensitive keys exist in version control.
* **New Windows Installer:**
  * Native x64 Release build.
  * Packaged into a standalone NSIS installer: `build\windows\x64\runner\Release\Grimoire_Studio_Setup.exe` (18.88 MB).
  * Zero external runtime dependencies or elevated permission requirements.

---

## 🗺️ Roadmap & What's Next

1. **Multilingual Rulebooks:** Side-by-side localization support in the PDF booklet generator.
2. **Custom Foil Masks:** Support for black-and-white UV mask PNGs to specify exact physical foil zones.
3. **AI-Assisted Card Variants:** Generate alternate art and promo frames while preserving structured card stats.

---

*Thank you for supporting Grimoire Studio!* 🎴✨
