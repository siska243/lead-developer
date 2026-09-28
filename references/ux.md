# UX / UI

Goal: simple, fluid, coherent, professional experience. Never design only the happy path.

## Every screen/component – states
```text
Initial → User action → Feedback → Loading → Success → Error → Empty → Disabled → Offline (if relevant)
```
| State | Minimum |
|-------|---------|
| Loading | Skeleton or spinner consistent with the app; no layout jump; buttons disabled during submit (no double submit) |
| Success | Visible confirmation (toast, inline message, navigation) |
| Error | Human message, what to do next, retry when useful; field-level validation errors; input preserved |
| Empty | Explain why it is empty and the next action |
| Disabled | Visually clear + reason when not obvious |
| Offline | Mobile/PWA: clear status, queued or blocked actions explained |

## Checklist
- Responsive: phone, tablet, desktop; no horizontal scroll; touch targets ≥ 44px.
- Accessibility: semantic HTML / accessibility roles, labels, focus visible and trapped in modals, keyboard navigation, contrast (WCAG AA), alt text, screen-reader announcements for async changes.
- Forms: labels, correct input types/keyboards, autofill, clear validation, preserved input on error.
- Copy: short, consistent with the app vocabulary, no technical errors shown to users.
- Consistency with existing flows: same patterns for same actions.

## Verify
Check the UI in a real browser/device when possible (browser automation or QA skill if available): each state, each breakpoint, keyboard only.
