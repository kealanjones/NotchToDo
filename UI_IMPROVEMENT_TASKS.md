# NotchToDo UI Improvement Tasks

A phased implementation plan for UI improvements across Mac, iOS, and Android platforms.

---

## Phase 1: Quick Wins & Critical Fixes
*High impact, low effort improvements that can be completed quickly*

### Mac App
- [ ] **MAC-1.1** Increase task card text contrast - Change title color from `NSColor(calibratedWhite: 0.08, alpha: 1.0)` to darker values for better readability
- [ ] **MAC-1.2** Implement visual undo toast notification - Replace console-only `showUndoNotification` with an animated toast showing "Deleted [item] - Press Cmd+Z to undo"
- [ ] **MAC-1.3** Add search results count indicator - Show "X of Y tasks" when search filter is active
- [ ] **MAC-1.4** Improve drag handle visibility - Increase opacity on hover and add subtle pulse animation on first card open

### iOS App
- [ ] **IOS-1.1** Add pull-to-refresh on task lists - Add `.refreshable` modifier to `TasksView` and `OrbDetailView`
- [ ] **IOS-1.2** Implement swipe actions on task rows - Add swipe-to-complete (leading) and swipe-to-delete (trailing) on `TaskRowView`
- [ ] **IOS-1.3** Unify brand color - Replace hardcoded `Color.blue` with a defined brand color in asset catalog
- [ ] **IOS-1.4** Add haptic feedback - Add haptics for task completion, voice recording start/stop

### Android App
- [ ] **AND-1.1** Fix Orbs navigation icon - Replace `Icons.Default.AccountCircle` with appropriate folder/orb icon
- [ ] **AND-1.2** Add orb color indicator to TaskCard - Show colored dot matching the task's parent orb
- [ ] **AND-1.3** Implement search functionality - Complete the TODO search in `TasksScreen` using `SearchBar`
- [ ] **AND-1.4** Add pull-to-refresh - Add `pullRefresh` modifier to `TasksScreen` and `OrbsScreen`

---

## Phase 2: Core Feature Parity
*Essential features to bring platforms to feature parity*

### Mac App
- [ ] **MAC-2.1** Add keyboard navigation within task cards - Tab between tasks, Space to toggle completion, Enter to open detail
- [ ] **MAC-2.2** Add inline quick-add text field - Add text input at bottom of task card for rapid task entry
- [ ] **MAC-2.3** Add due date quick filters - Add "Today", "This Week", "Overdue" filter chips above task list
- [ ] **MAC-2.4** Implement task grouping by status - Add optional grouping toggle (Outstanding/In Progress/Complete)

### iOS App
- [ ] **IOS-2.1** Enhance TaskRowView density - Add priority indicator, relative due dates ("2d left"), quick-action visibility
- [ ] **IOS-2.2** Add orb change picker in TaskDetailView - Allow moving task between orbs
- [ ] **IOS-2.3** Add task sorting options - Due date, Priority, Created date, Alphabetical sort picker
- [ ] **IOS-2.4** Show orb completion progress - Add `ProgressView` to `OrbRowView` showing tasks completed ratio
- [ ] **IOS-2.5** Expand orb color usage - Color-coded section headers, tinted task row backgrounds

### Android App
- [ ] **AND-2.1** Create OrbDetailScreen - Add screen showing tasks within a specific orb when orb is tapped
- [ ] **AND-2.2** Create TaskDetailScreen - Add screen for viewing/editing task details
- [ ] **AND-2.3** Implement task creation flow - Add orb selection picker when creating new tasks
- [ ] **AND-2.4** Enhance TaskCard component - Add checkbox, due date badge, priority indicator
- [ ] **AND-2.5** Add swipe-to-dismiss for tasks - Implement `SwipeToDismiss` composable for task deletion

---

## Phase 3: Enhanced UX & Polish
*Improved interactions and visual polish*

### Mac App
- [ ] **MAC-3.1** Add batch task operations - Multi-select capability for bulk complete/delete/move
- [ ] **MAC-3.2** Improve scroll momentum - Add velocity-based momentum to spring scroll for more natural feel
- [ ] **MAC-3.3** Add empty state illustrations - Create illustrated empty states when no tasks exist in an orb
- [ ] **MAC-3.4** Enhance priority visual hierarchy - Use filled pill badges instead of subtle borders for high priority

### iOS App
- [ ] **IOS-3.1** Enhance voice input UX - Add audio waveform visualization and confidence indicator
- [ ] **IOS-3.2** Create illustrated empty states - Design and implement empty state illustrations with guidance text
- [ ] **IOS-3.3** Add Focus mode view - Create dedicated view showing only today's tasks across all orbs
- [ ] **IOS-3.4** Add notification badges - Show badge count on Orbs tab for upcoming due dates
- [ ] **IOS-3.5** Polish dark mode - Verify and adjust all colors for proper dark mode appearance

### Android App
- [ ] **AND-3.1** Add illustrated empty states - Add Lottie animations or Material illustrations for empty task/orb lists
- [ ] **AND-3.2** Implement bottom sheet task creation - Replace FAB navigation with sliding bottom sheet
- [ ] **AND-3.3** Add expandable FAB - Show "Add Task" vs "Add Orb" options on FAB expand
- [ ] **AND-3.4** Group tasks by status/orb - Add grouping headers in `TasksScreen`
- [ ] **AND-3.5** Add sync status indicator - Show persistent sync status in app bar or as snackbar

---

## Phase 4: Advanced Features & Platform-Specific
*Platform-specific enhancements and advanced functionality*

### Mac App
- [ ] **MAC-4.1** Add task templates - Save and reuse common task structures
- [ ] **MAC-4.2** Add global keyboard shortcuts - System-wide shortcuts for quick capture
- [ ] **MAC-4.3** Enhance celebration effects - Add more particle variations and sound effects options
- [ ] **MAC-4.4** Add window snap positions - Predefined screen positions for task cards

### iOS App
- [ ] **IOS-4.1** Create home screen widget - Quick task capture and today's tasks widget
- [ ] **IOS-4.2** Add Siri Shortcuts integration - "Add task to [orb]" voice shortcuts
- [ ] **IOS-4.3** Add task reminder notifications - Local notifications for due dates
- [ ] **IOS-4.4** Port celebration effects - Simplified confetti animation for task completion

### Android App
- [ ] **AND-4.1** Complete widget implementation - Finish `TaskWidgetReceiver` to display actual tasks
- [ ] **AND-4.2** Add voice input support - Implement speech-to-text for task creation
- [ ] **AND-4.3** Expand settings screen - Add theme selection, notifications, default orb preferences
- [ ] **AND-4.4** Add task reminder notifications - Work Manager scheduled notifications for due dates
- [ ] **AND-4.5** Port celebration effects - Add Lottie confetti animation for task completion

---

## Phase 5: Cross-Platform Consistency
*Unifying experience across all platforms*

### Design System
- [ ] **XP-5.1** Create shared color palette - Define orb colors, status colors, priority colors that work across platforms
- [ ] **XP-5.2** Standardize status terminology - Ensure "Outstanding", "In Progress", "Complete" used consistently
- [ ] **XP-5.3** Create shared icon set - Design custom orb icon and task status icons for all platforms
- [ ] **XP-5.4** Document interaction patterns - Create design spec for swipe actions, gestures, animations

### Feature Parity Tracking
| Feature | Mac | iOS | Android | Target |
|---------|:---:|:---:|:-------:|:------:|
| Task Status Colors | ✅ | ✅ | ⬜ | All |
| Swipe Actions | N/A | ⬜ | ⬜ | Mobile |
| Voice Input | ✅ | ✅ | ⬜ | All |
| Empty States | ⬜ | ⬜ | ⬜ | All |
| Search | ✅ | ✅ | ⬜ | All |
| Pull to Refresh | N/A | ⬜ | ⬜ | Mobile |
| Task Detail Edit | ✅ | ✅ | ⬜ | All |
| Celebration Effects | ✅ | ⬜ | ⬜ | All |
| Widgets | N/A | ⬜ | ⬜ | Mobile |

---

## Implementation Priority Matrix

```
                    HIGH IMPACT
                         │
         Phase 1         │         Phase 2
      (Quick Wins)       │    (Core Features)
                         │
   LOW EFFORT ───────────┼─────────── HIGH EFFORT
                         │
         Phase 3         │         Phase 4
        (Polish)         │      (Advanced)
                         │
                    LOW IMPACT
```

---

## Suggested Sprint Allocation

| Sprint | Focus | Tasks |
|--------|-------|-------|
| Sprint 1 | Quick Wins | MAC-1.x, IOS-1.x, AND-1.x |
| Sprint 2 | Android Parity | AND-2.1 through AND-2.5 |
| Sprint 3 | iOS Enhancement | IOS-2.x, IOS-3.1, IOS-3.2 |
| Sprint 4 | Mac Polish | MAC-2.x, MAC-3.x |
| Sprint 5 | Mobile Polish | IOS-3.x, AND-3.x |
| Sprint 6 | Advanced Features | Phase 4 tasks |
| Sprint 7 | Cross-Platform | XP-5.x |

---

## Notes

- Each task ID format: `[PLATFORM]-[PHASE].[NUMBER]`
- Tasks within a phase can be parallelized across developers
- Android needs more work to reach parity with Mac/iOS
- Mac app is most mature; focus on polish and advanced features
- iOS is solid foundation; needs UX enhancements
- Cross-platform tasks should be tackled after individual platforms are stable
