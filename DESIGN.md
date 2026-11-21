---
name: "LAMPOR: Malam Jahanam"
description: "An atmospheric Indonesian folklore horror game UI system built on charred obsidian surfaces, dried-blood crimson accents, and carved serif typography."
---

## Overview

**LAMPOR: Malam Jahanam** is an Indonesian folklore horror game by AstraDev. The UI should feel like an ancient, ominous relic encountered in the dead of night—never a sterile black web dialog. Surfaces evoke charred wood, soot, and dried blood, while typography pairs carved, ceremonial serif headings with crisp, readable body copy and tactile technical keybind badges.

The emotional response is dread, mystery, and ritual weight: sharp corners with subtle iron-like borders, deep vignette depth, and restrained crimson highlights that guide the player's eye without neon clutter.

## Colors

The palette is strictly dark-mode, anchored by deep obsidian-charred surfaces (never pure `#000000`, preventing text halation) and dried-blood crimson accents. Tarnished bone-parchment provides high-contrast legibility for patch notes and legal copy.

```yaml
colors:
  primary: "#FFB4AC"
  on-primary: "#690006"
  primary-container: "#9E1B1B"
  on-primary-container: "#FFEDEA"
  secondary: "#E1BEBB"
  on-secondary: "#3C2D2B"
  secondary-container: "#5A1A17"
  on-secondary-container: "#FFDAD6"
  accent: "#D4433C"
  on-accent: "#060606"
  background: "#170B0A"
  on-background: "#F7DDDA"
  surface: "#1D100F"
  surface-dim: "#120908"
  surface-bright: "#352625"
  surface-container-lowest: "#140A09"
  surface-container-low: "#261817"
  surface-container: "#2A1C1B"
  surface-container-high: "#352625"
  surface-container-highest: "#41312F"
  on-surface: "#F7DDDA"
  on-surface-variant: "#D5BDBB"
  outline: "#8D706D"
  outline-variant: "#59413E"
  error: "#FFB4AB"
  on-error: "#690005"
  scrim: "#0A0505"
```

## Typography

A three-role typographic hierarchy balances folkloric dread with long-form legibility:
- **Cinzel** (`display`, `headline`, `title`) brings carved-stone, ceremonial gravitas to modal titles, game branding (`LAMPOR`), and section headers.
- **Proza Libre** (`body`, `label`) ensures Indonesian patch notes, technical explanations, and copyright notices remain effortless to scan on dark surfaces.
- **Source Code Pro** (`mono`) styles keyboard shortcuts (`Esc`), Godot method/node references (`PauseMenu`, `_on_main_menu_pressed()`), file names (`FIX_NOTES.md`), and version/commit hashes.

```yaml
typography:
  display-lg:
    fontFamily: "Cinzel"
    fontSize: 44px
    fontWeight: 700
    lineHeight: 52px
    letterSpacing: 3px
  display-lg-mobile:
    fontFamily: "Cinzel"
    fontSize: 32px
    fontWeight: 700
    lineHeight: 40px
    letterSpacing: 2px
  headline-lg:
    fontFamily: "Cinzel"
    fontSize: 30px
    fontWeight: 700
    lineHeight: 38px
    letterSpacing: 2px
  headline-md:
    fontFamily: "Cinzel"
    fontSize: 22px
    fontWeight: 600
    lineHeight: 30px
    letterSpacing: 1.5px
  title-lg:
    fontFamily: "Cinzel"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 26px
    letterSpacing: 1px
  body-lg:
    fontFamily: "Proza Libre"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 26px
    letterSpacing: 0px
  body-md:
    fontFamily: "Proza Libre"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 22px
    letterSpacing: 0px
  label-lg:
    fontFamily: "Cinzel"
    fontSize: 14px
    fontWeight: 700
    lineHeight: 20px
    letterSpacing: 2px
  label-sm:
    fontFamily: "Proza Libre"
    fontSize: 12px
    fontWeight: 600
    lineHeight: 16px
    letterSpacing: 0.5px
  mono-sm:
    fontFamily: "Source Code Pro"
    fontSize: 13px
    fontWeight: 500
    lineHeight: 18px
    letterSpacing: 0px
```

## Layout & Spacing

Modals sit centered over a darkened, misty game scene scrim (`scrim` + atmospheric background) on a `1280px` desktop viewport. Internal spacing follows a strict 4px/8px grid so header crests, divider rules, scrollable patch-note entries, and bottom action bars align cleanly.

```yaml
spacing:
  gutter-xs: 4px
  gutter-sm: 8px
  gutter-md: 16px
  gutter-lg: 24px
  gutter-xl: 32px
  section: 48px
  page-margin: 32px
```

## Elevation & Depth

Depth is achieved through **tonal layering, scrims, and fine iron-crimson outlines** rather than bright drop shadows. The game backdrop sits behind a deep vignette scrim; the modal panel uses `surface` with a subtle `outline-variant` border and crimson corner ornaments. Interactive elements (`TUTUP` button, keybind chips) step up to `surface-container-high` or `primary-container` on hover.

## Shapes

Horror UI rejects bubbly pills. Panels and buttons use **sharp, chiseled corners** (`2px` to `4px`), evoking carved wood, iron plates, and ritual tablets.

```yaml
rounded:
  none: 0px
  sm: 2px
  DEFAULT: 4px
  md: 6px
  lg: 8px
  full: 9999px
```

## Motion & Micro-interaction

Interactions feel deliberate and heavy, like an old wooden door or iron latch. Button hover states shift crimson tint and border luminance smoothly; modal entrances decelerate gently out of the fog.

```yaml
motion:
  state-change:
    duration: 150ms
    delay: 0ms
    timingFunction: ease-out
  surface-enter:
    duration: 300ms
    delay: 0ms
    timingFunction: cubic-bezier(0.2, 0, 0, 1)
```

## Voice & Content Strategy

All UI copy is in **Indonesian**, matching the game's setting and existing screens.
- **Tone:** Ominous, formal, and grounded in Indonesian folklore for titles and framing (`CATATAN PEMBARUAN`, `MALAM JAHANAM`, `TUTUP`), while keeping technical patch notes clear and accurate.
- **Capitalisation:** `UPPERCASE` for ceremonial Cinzel headers and primary action buttons (`CATATAN PEMBARUAN`, `HAK CIPTA`, `TUTUP`); sentence case for patch-note descriptions and legal copy.
- **Technical terms:** Preserve exact code/keybind identifiers (`Esc`, `PauseMenu`, `_on_main_menu_pressed()`, `FIX_NOTES.md`, `961bbad254`) inside `mono-sm` inline chips.

## Components

Component implementations live as individual HTML sticker sheet files in
`components/`. Each file contains the canonical, styled HTML components with
`<!-- COMPONENT: name -->` comment markers. Read each file before use.

- **Badge** → `@components/badge.html`: `badge-numeric`, `badge-dot`
- **Button** → `@components/button.html`: `button-primary`, `button-icon`, `button-with-icon`
- **Modal** → `@components/modal.html`: `modal-standard`, `modal-alert`, `modal-drawer`
- **Typography** → `@components/typography.html`: `typography-display`, `typography-body`, `typography-label`
