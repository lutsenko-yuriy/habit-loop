// HAB-269 WU1 — registers invocation phrases so Siri/Shortcuts can find the two
// voice intents. Apple requires every phrase to include the ${applicationName} token.
//
// A free-text String parameter (habitDescription) cannot appear inside an AppShortcut
// phrase — only AppEntity/AppEnum types can (confirmed via a real build failure during
// the WU0 spike: "Invalid parameter type. AppEntity and AppEnum are the only allowed
// types"). Free text is instead captured via a spoken follow-up question, driven by
// @Parameter's requestValueDialog on MarkShowupDoneIntent itself.

import AppIntents

@available(iOS 16.0, *)
struct HabitLoopShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: TodaysShowupsIntent(),
      phrases: [
        "Which showups should I do today in ${applicationName}",
        "What should I do today in ${applicationName}",
      ],
      shortTitle: "Today's showups",
      systemImageName: "checklist"
    )
    AppShortcut(
      intent: MarkShowupDoneIntent(),
      phrases: [
        "Mark a showup done in ${applicationName}",
        "Mark done in ${applicationName}",
      ],
      shortTitle: "Mark showup done",
      systemImageName: "checkmark.circle"
    )
  }
}
