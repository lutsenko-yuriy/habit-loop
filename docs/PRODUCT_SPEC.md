# Product Specification

The app is available in English, French, German, and Russian.

The Habit Loop app allows the user to:
- See an overview on a dashboard of what the user should do today, what they have already done today, and how their pacts are going in general
  - The user must see a todo list of showups that are already done/should be done today
  - The user must see a calendar view centered on today, showing 3 days before and 3 days after. Past and today's slots show completed/failed showups; future slots show upcoming scheduled showups. Each day shows colored dots per showup (green=done, red=failed, grey=upcoming). Today is highlighted with a circle; the selected day has accent color. Tapping a day shows that day's showups in the list below.
  - The user can create a new pact on a separate screen
  - Multiple pacts can be active simultaneously
- Create such pacts to show up
  - Before creating a pact, the user must confirm that they understand the commitment: missing a showup counts as a failure, no exceptions. There is no pausing a pact.
  - The user must define a habit the user wants to develop
  - The user must define the time span when the pact is active (by default it is defined 6 months)
  - The user can define when the pact starts if they don't want to start it today (by default it is today)
  - The user must define a length of a single showup (e.g., 10 minutes of meditating, but not longer than 2 hours)
  - The user must define when they want to show up:
    - They can say that they want to show up every day at some defined time (time is not defined by default for any of these subcases)
    - They can say that they want to show up on some specific weekdays (e.g., Saturday at 4pm, Tuesday at 7pm, etc.)
    - They can say that they want to show up on some specific days of a month (e.g., every 2nd Tuesday of a month or every 25th day of the month, etc.)
  - The user can define when they want to be reminded to show up (by default no reminder, but can be reminded up to 60 minutes before the showup or when the showup starts immediately)
- Track if the user shows up to a pact they defined, on a separate screen
  - The user can see detail of their pact
    - How many showups they made it to
    - How many showups they failed to make it to
    - How many showups left
    - Time details: when the pact started, when the pact ends (with remainder)
    - How long their current streak of showups made is
  - The user can edit an active pact to update its habit name and reminder offset via a 2-step wizard (habit name → reminder); all other pact fields (schedule, dates, showup duration) are immutable after creation
  - The user can stop the pact but has to confirm it clearly
    - The user can give an explanation why they decided to stop the pact
  - The user can still see the details of the pact even after stopping it or after the pact's time has passed
  - On a finished (completed or stopped) pact the user can write or edit a free-form note; the note is pre-populated with the stop reason if one was given
  - The pact detail screen shows showup duration and reminder offset in the Timeline section
  - The user can archive or unarchive a finished (completed or stopped) pact via a button on the pact detail screen; no confirmation is required
    - Archived pacts are hidden from the pact list by default
    - An "Archived pacts (N)" row and an Archived chip appear in the pact list when at least one pact is archived; both are hidden when none are archived; the chip row is animated (AnimatedSize + FadeTransition)
    - The Archived chip and the "Archived pacts (N)" row stay in sync — toggling one toggles the other
    - Sort order in the pact list: active → unarchived completed → unarchived stopped → archived completed → archived stopped
  - The user can view the pact's timeline by tapping "View Timeline" on the pact detail screen (feature flag: `pact_timeline_enabled`)
    - The timeline shows all milestones in chronological order: pact-created anchor, showup streaks, showup groups, noted showups, single tail-zone showups, and a current-state anchor (active) or pact-concluded anchor (stopped/completed)
    - Noted showups and single tail-zone showups are tappable and navigate to the showup detail screen
    - Milestone dots are color-coded by outcome (green = done, red = failed, grey = mixed/pending, teal = anchor); each milestone row places the date or date range in the left column and the outcome label in the right column, divided by the vertical spine
    - Milestone dates use the device's regional date format (e.g. dd/MM/yyyy on European devices, M/d/yyyy on US-region devices)
    - The timeline screen title shows the pact's habit name followed by "– Timeline" (e.g. "Meditate – Timeline")
    - A section header ("Showups from the last N days") separates individually-shown tail-zone showups from grouped milestones above; N defaults to 7 and is configurable via Remote Config (range 7–21)
    - The timeline reloads automatically after returning from the showup detail screen, reflecting any status change immediately
- See the details of a specific showup
  - The user must see the time of the showup
  - The user must see the habit in this showup
  - The user can mark the showup as made or not made
  - If the details of the showup were opened after the showup time (as defined during the pact's creation), the showup is marked as failed
  - The user can leave a note on the showup regardless of the time
  - If a showup was auto-failed (not manually failed) and falls within the tail zone (last N days, controlled by `pact_timeline_no_grouping_tail_period_in_days`), the user can redeem it by writing a note and tapping "Mark as Done (redeem)". The redemption button is always visible when eligible but disabled until a note is saved. Manual fails are not redeemable. The feature is controlled by the `showup_redemption_enabled` kill-switch.
- Be reminded about an upcoming showup
  - A notification with a reminder will appear to the user if they defined a reminder
  - The user can see the showup by clicking on the notification
- Access app information and send feedback
  - Secondary dashboard actions (About, Language) are grouped behind a ⋯ menu button in the nav bar; tapping it shows all enabled items. If exactly one item is enabled, it appears as a standalone icon instead of the ⋯ button (single-item shortcut). About is controlled by the `about_screen_enabled` feature flag.
  - The About screen shows the app icon, app name, version number, build number, and a copyright notice
  - Tapping "Send feedback" opens the team's feedback form in the browser with device model, OS version, and build number pre-filled
  - The version string previously shown under the dashboard title has been removed; version info is now on the About screen

## Remote feature toggles

See @docs/FEATURE_TOGGLES.md.