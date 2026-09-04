# SalahFocus Architecture

## Boundaries

SalahFocus uses a feature-first architecture with separate domain, data/application and presentation responsibilities.

The two most important platform abstractions are:

```text
PrayerTimesProvider                 PrayerFocusService
├── AlAdhanPrayerTimesProvider      ├── iOS native Screen Time bridge
└── future provider                 └── Android safe basic fallback
```

## Prayer flow

```text
Location + Settings
       │
       ▼
PrayerTimesProvider
       │ monthly calendar
       ▼
PrayerTimesRepository
       │ normalized UTC instants + IANA timezone
       ▼
SQLite cache/history
       │
       ├────────► Home / Tracker
       │
       └────────► PrayerCoordinator
                     │
                     ├── State Machine
                     ├── Notification Planner
                     └── Prayer Focus Service
```

## Offline-first behavior

The repository persists each monthly fetch. A cache row is bound to a source profile made from location, calculation method, Madhhab, high-latitude rule, manual offsets and grace period, so a Düsseldorf cache cannot silently become an Istanbul cache after settings change. API failure does not erase valid cached data. State changes such as confirmation and snooze are persisted locally before UI refresh.

## Time model

Each prayer stores:

- local calendar date
- IANA timezone ID
- scheduled UTC instant
- grace-end UTC instant
- tracking-end UTC instant

This avoids fixed-offset assumptions across DST changes.

## Focus safety

Focus state and native app shielding are deliberately separate. A failure in native shielding cannot corrupt prayer history or make the basic UI unusable. `PrayerFocusPolicy` caps native focus to 90 minutes after grace ends (or the earlier tracking-window end). Turning Focus off cancels all app-owned native schedules and clears shields.

Emergency Unlock:

1. clears native shields,
2. ends active local focus sessions,
3. stores a bypass until the prayer tracking window ends,
4. leaves the prayer status unchanged.
