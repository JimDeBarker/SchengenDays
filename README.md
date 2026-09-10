# Schengen Days

An iPhone app and home-screen / lock-screen widget that keeps count of the
90 days in any 180 that a UK citizen may spend in the Schengen area.

The widget shows days left, days used, and either the date you must leave by
(if you are inside the area) or how long you could stay if you entered today.

## Where the days come from

| Source | How | When |
|---|---|---|
| Location | Significant-change and visit monitoring; each fix is reverse-geocoded to a country. Needs "Always" to work in the background. | Ongoing |
| Photos | Date + GPS on every photo in the last year, one geocode per ~10 km per day. Photos never leave the phone. | Past trips |
| Manual | A date range, optional country, and an in/out switch. | Anything else, and corrections |

Manual entries always win. Automatic sources only ever *add* days: one fix
inside the area makes the whole day count, which is how the border counts it.

## Building

Open `SchengenDays.xcodeproj` in Xcode 16 or later and run the `SchengenDays`
scheme. Three targets: the app, `SchengenWidget`, and `SchengenDaysTests`
(pure logic tests on the shared model). The app and widget share data through
the App Group `group.uk.co.losingthethread.SchengenDays`.

```bash
xcodebuild -project SchengenDays.xcodeproj -scheme SchengenDays \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Layout

- `Shared/` — everything both targets need: `DayKey` (a date with no time or
  zone, Julian-day arithmetic), `Schengen` (member list and the 90/180
  numbers), `PresenceLog` (one entry per day with source precedence),
  `RollingWindow` (the maths), `PresenceStore` (the JSON file in the App Group).
- `SchengenDays/` — the app. `Services/` holds the location monitor, the
  photo scanner and the geocode cache; `Features/` the SwiftUI screens.
- `SchengenWidget/` — the WidgetKit extension. Small, medium, and the three
  lock-screen accessory families.
