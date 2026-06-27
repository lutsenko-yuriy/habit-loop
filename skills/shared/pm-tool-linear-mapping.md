# PM Tool: Linear

All Linear-specific details live here. When porting to a different PM tool, replace this file — skill logic stays unchanged.

## Identity

| Setting | Value |
|---|---|
| Tool | Linear |
| Issue prefix | `HAB` |

## Workspace IDs

| Setting | Value |
|---|---|
| Team ID | `2de84a9b-453b-4991-8e09-f88715fa926e` |
| Project ID | `c3afdc26-d306-4f72-bdb3-de9b01060d0f` |

## Operation mapping

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
