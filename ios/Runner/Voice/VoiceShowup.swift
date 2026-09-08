// HAB-269 WU1 — the model read/written by the native voice (Siri) layer.
// Mirrors ShowupStatus/BreakDerivation's status semantics from the Dart domain layer —
// see docs/ARCHITECTURE.md's Voice section and the plan comment on HAB-269.

import Foundation

struct VoiceShowup: Equatable {
  let id: String
  // Added HAB-269 WU2 — needed to log showup_marked_done's pact_id property
  // and to look up the covering pact's breaks in VoiceShowupStore.
  let pactId: String
  let habitName: String
  let scheduledAt: Date
  let windowEnd: Date
  let status: String // "pending" | "done" | "failed"
  let redeemable: Bool // proxy for "auto-failed, not manually failed" (see PRODUCT_SPEC.md)
}
