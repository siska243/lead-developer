# Motion design

Use motion only when it brings UX value: transitions, navigation, onboarding, feedback, micro-interactions, loading, state changes, storytelling, visualizations.

## Decide in this order
1. Should it animate at all? (frequency: a thing seen 100×/day should be fast or not animated)
2. Purpose: orient, give feedback, show relationship, reduce perceived wait.
3. Technology – what the project already has first:

| Context | Options |
|---------|---------|
| Web, simple | CSS transitions/animations, Web Animations API |
| React web | Motion (Framer Motion) if installed or justified |
| React Native / Expo | React Native Reanimated + Gesture Handler (UI thread) |
| Vector / illustrated | Lottie, Rive, SVG animations |
| Custom rendering | Canvas / WebGL |
| Programmatic video | Remotion |

Never add a motion library only for a visual effect.

4. Properties: animate `transform` and `opacity`; avoid layout properties (width, height, top, left) on the main thread.
5. Curve & duration: UI feedback 100–200ms, transitions 200–400ms; ease-out for entering, ease-in for exiting; springs for gestures.
6. Interruptibility: animations can be interrupted/reversed without jumps.

## Performance
No heavy computation or re-renders during animation, never block scroll, no excessive effects. On mobile run animations on the UI/native thread.

## Accessibility
Respect `prefers-reduced-motion` (web) / `AccessibilityInfo.isReduceMotionEnabled` / Reanimated `useReducedMotion` (RN). Motion must never be required to understand a feature.

Use dedicated animation skills/tools when available (build, review, audit animations).
