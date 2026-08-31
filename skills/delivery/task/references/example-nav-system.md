# TASK-451: Design unified navigation system for dashboard

## Summary

Design and implement the top-level navigation shell for the unified dashboard. Must support entity switching (orders, customers, inventory, reports), responsive layout, and accessibility compliance.

## Technical Notes

- Use existing design system component library (no new design system work)
- Navigation state persisted to localStorage to preserve context across sessions
- Mobile breakpoints: 320px (phone), 768px (tablet), 1024px+ (desktop)
- WCAG 2.1 AA compliance required for keyboard navigation and screen readers
- Use CSS Grid for main layout; Flexbox for navigation items

## Acceptance Criteria

- [ ] Entity switcher allows switching between all 4 entity types without page reload
- [ ] Active entity highlighted in navigation with visible focus indicator
- [ ] Keyboard navigation works through all nav items (Tab, Enter, Escape)
- [ ] Layout renders correctly at all 3 breakpoints without horizontal scroll
- [ ] Mobile hamburger menu opens and closes on tap
- [ ] Screen reader announces current entity and navigation landmarks

## Additional Information

- Estimated Effort: 3 days
- Assigned To: Sarah Chen
- Due Date: 2024-03-15

## Review

- [ ] Destination confirmed.
- [ ] Human review required.
