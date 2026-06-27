# PM Tool Mapping

Generic operations → concrete MCP tool calls for the PM tool configured in `project-config.md` (currently Linear).

| Operation | MCP tool | Key parameters |
|---|---|---|
| Fetch issue | `mcp__linear__get_issue` | `id` |
| List issues | `mcp__linear__list_issues` | `project`, `state`, `label`, `assignee` |
| Create issue | `mcp__linear__save_issue` | `title`, `team`, `project`, `state`, `labels`, `priority` |
| Update issue | `mcp__linear__save_issue` | `id`, plus fields to change (e.g. `state`) |
| Move issue to state | `mcp__linear__save_issue` | `id`, `state: "<state name>"` |
| List comments on issue | `mcp__linear__list_comments` | `issueId` |
| Post comment on issue | `mcp__linear__save_comment` | `issueId`, `body` |
| Fetch milestone | `mcp__linear__get_milestone` | `id` |
| List milestones | `mcp__linear__list_milestones` | `project` |
| List issues in milestone | `mcp__linear__list_issues` | `project`, `milestone` |
