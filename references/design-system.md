# Design system & existing interface

**Do not create a second visual identity.** A new component must look like it always belonged to the app.
The brand guidelines and the design system are applied **to the letter**: no approximation, no "close enough" color.

## Strict rules
- **One component per purpose.** One Button, one Modal, one Input, one Toast, one Table… with variants. Never a second component doing the same thing (`Button` + `PrimaryButton` + `CustomBtn`). Duplicates already present → use the canonical one, report the others as a separate ticket.
- **Tokens only.** Colors, font families and sizes, spacing, radius, shadows, z-index, breakpoints, durations come from the design tokens / theme / Tailwind config. No hardcoded hex, `px` font size, magic spacing or inline style that bypasses them. A needed value is missing → add it to the tokens (and say so), never inline.
- **Same pattern for the same interaction**: same confirmation dialog, same loading state, same empty state, same form layout, same error display across screens.
- **Icons and illustrations** from the project's icon set only.
- **Copy** follows the app's vocabulary and tone.

## Before creating any UI element
1. Find the design system: tokens (colors, typography, spacing, radius, shadows), theme files, Tailwind config, CSS variables, component library (shadcn, MUI, Vuetify, NativeBase, Tamagui, custom `components/ui`), `DESIGN.md`, Storybook, Figma links.
2. Search for an existing component: button, input, modal/dialog, form, card, menu, navigation, toast, table, empty state, loader, animation.
3. Reuse it. If it lacks a variant, extend it following its API instead of forking it.
4. New component only when nothing fits – built with the existing tokens and patterns.

## Respect
Brand, colors, typography, spacing scale, component APIs, navigation patterns, interaction patterns, icon set, tone of copy, dark mode if supported, responsive breakpoints.

## No design system yet
Extract the implicit one (most-used colors, font sizes, spacing) before adding screens; propose formalizing it as a separate task. Use a design-consultation or UI/UX skill if available.
