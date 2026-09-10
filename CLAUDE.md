# Working in this repo

An iPhone app plus WidgetKit widget counting Schengen 90/180 days.
SwiftUI, iOS 17+, Xcode 16+. Same house style as iPodApp.

## Conventions

- All three targets use **file-system-synchronized groups**. Create Swift
  files anywhere under `SchengenDays/`, `SchengenWidget/`, `Shared/` or
  `SchengenDaysTests/` and they are compiled; never hand-edit
  `project.pbxproj` to add a file. `Shared/` is a member of every target, so
  it may import Foundation only: no SwiftUI, WidgetKit, Photos or CoreLocation.
- Dates that mean "a day" are `DayKey`, never `Date`. Convert at the edges
  (photo timestamps, location fixes, pickers) and nowhere else.
- All the 90/180 arithmetic lives in `RollingWindow` and is covered by
  `SchengenDaysTests`. Change the maths there, and add a test.
- `PresenceLog.record` is the only way days get in. Its precedence rule
  (manual wins; automatic sources only add) is deliberate — see the doc
  comment before touching it.
- State objects are `@Observable`; views take them as plain `let` properties.
- Anything the widget needs must go through `PresenceStore` (the App Group
  file). The widget never writes.

## Simulator notes

- Switches inside a scrolling `List` ignore near-instant synthetic taps from
  the simulator MCP tool; pass `duration: 0.15` when tapping them.
- `xcrun simctl location <udid> set 48.8566,2.3522` puts the phone in Paris;
  `xcrun simctl addmedia` accepts JPEGs whose EXIF carries GPS and a date.
