# HAB-154: Standing docs audit and tidy-up

## Notes

## Debrief summary

### 2026-07-11

**What went well**
- Reflecting on cross-session collaboration patterns surfaced a concrete, actionable process fix rather than staying abstract — HAB-161 exists because the conversation had a specific, technical target (the script stub's uncontrolled-cost fallback) rather than a vague "communicate better" takeaway.
- Honest mutual critique held up under scrutiny: the user caught that my own "offer 2 alternatives instead of one polished draft" fix-proposal violated the very principle it was proposing to fix. That led to naming "principles" vs. "guidelines" as a real open question (HAB-160) instead of the irony being quietly ignored.

**What was hard or surprising**
- A direct ask for token/tool-usage feedback showed that most of this session's actual waste was self-inflicted (repeated `gh pr create` heredoc failures, a couple of redundant `Read` calls, an unverified subagent "what changed" summary, an unstaged note file) rather than a user-assistant communication problem — worth naming plainly rather than deflecting to environment/tooling causes alone.
- The first environment-level fix offered (keep LM Studio loaded, persist `LINEAR_API_KEY` in the shell profile) was necessary but not sufficient. It didn't surface the deeper structural gap — the script stub's fallback has no cost ceiling — until the user pushed further with "would skipping LM Studio help?" instead of accepting the first answer at face value.

**What to change**
- `skill_router`'s script stub currently falls back to "whatever model the session happens to be" when LM Studio is unreachable, with no cost ceiling. Tracked as HAB-161, deliberately scoped to keep LM Studio as the cost/privacy-preserving first choice for high-frequency local-tier skills (`implement`) rather than removing local routing outright.
- Keep applying the same scrutiny to my own proposals that gets applied to the user's — the "your answer doesn't comply either" catch was the single most useful moment in this thread, and it only happened because the user kept pushing past a first, comfortable answer.
