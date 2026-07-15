# Heavy-tier dimensions

Due the 14th of every quarter-anchor month (Jan/Apr/Jul/Oct), tracked as "not yet done this quarter" — see [ADR-0003](../../../../docs/knowledge/decisions/ADR-0003-two-tier-periodic-code-quality-checkup.md). These three require a full sweep of the whole project; walk them in order.

## 6. Readability & structural clarity

Full sweep for long or deeply-nested methods, high branching, duplicated logic, oversized widgets/notifiers, and unclear names. Optional manual `dart_code_metrics`/DCM cyclomatic-complexity spot-check; if a threshold proves consistently meaningful, note it as a graduation candidate for a future automated check (see `resources/findings-protocol.md`) — do not wire CI here.

*Grounding: cyclomatic complexity has an off-the-shelf Dart tool, `dart_code_metrics`/DCM, confirming this dimension could later graduate to CI ([DCM](https://dcm.dev/docs/metrics/function/cyclomatic-complexity/)).*

## 7. Cross-screen UX consistency

Full-interface heuristic evaluation, single agent-assisted pass (adapted from NN/g's 3–5-evaluator method): apply Nielsen's 10 heuristics, especially #4 "Consistency and standards" — spacing, button styles, terminology, and iOS/Android parity across each slice's `ui/ios` and `ui/android`.

*Grounding: NN/g heuristic evaluation is the closest analog for cross-screen consistency; adapted to a single evaluator here ([NN/g](https://www.nngroup.com/articles/how-to-conduct-a-heuristic-evaluation/)).*

## 8. Accessibility

Manual audit pass: semantic labels on interactive widgets, tap-target sizes, colour contrast, text scaling, and screen-reader traversal — complementing (not replacing) any automated scan.

*Grounding: manual accessibility audits are commonly run quarterly/annually for depth alongside continuous automated scans ([TheWCAG](https://www.thewcag.com/accessibility-audit-guide)).*
