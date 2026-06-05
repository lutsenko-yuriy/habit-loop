import json
import urllib.request

from .constants import LINEAR_API_URL, LINEAR_PROJECT_ID

_ISSUES_QUERY = f"""
{{
  issues(
    filter: {{ state: {{ type: {{ nin: ["completed", "cancelled"] }} }} }}
    orderBy: updatedAt
    first: 50
  ) {{
    nodes {{
      identifier
      title
      description
      state {{ name type }}
      labels {{ nodes {{ name }} }}
    }}
  }}
}}
"""

_MILESTONES_QUERY = f"""
{{
  project(id: "{LINEAR_PROJECT_ID}") {{
    projectMilestones {{
      nodes {{
        name
        progress
        targetDate
        status
      }}
    }}
  }}
}}
"""

_GET_ISSUE_QUERY = """
query($id: String!) {
  issue(id: $id) {
    id
    identifier
    title
    description
    state { id name type }
    labels { nodes { id name } }
    team { id name }
    comments { nodes { id body createdAt } }
  }
}
"""

_LIST_STATES_QUERY = """
query($teamId: String!) {
  team(id: $teamId) {
    states { nodes { id name type } }
  }
}
"""

_UPDATE_ISSUE_MUTATION = """
mutation($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: {stateId: $stateId}) {
    success
    issue { identifier state { name } }
  }
}
"""

_CREATE_COMMENT_MUTATION = """
mutation($issueId: String!, $body: String!) {
  commentCreate(input: {issueId: $issueId, body: $body}) {
    success
    comment { id }
  }
}
"""


def _linear_graphql(api_key: str, query: str, variables: dict = None) -> dict:
    payload = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(
        LINEAR_API_URL,
        data=payload,
        headers={"Content-Type": "application/json", "Authorization": api_key},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.load(resp)


def fetch_linear_context(api_key: str) -> dict:
    issues_data = _linear_graphql(api_key, _ISSUES_QUERY)
    milestones_data = _linear_graphql(api_key, _MILESTONES_QUERY)
    return {
        "issues": issues_data.get("data", {}).get("issues", {}).get("nodes", []),
        "milestones": (
            milestones_data.get("data", {})
            .get("project", {})
            .get("projectMilestones", {})
            .get("nodes", [])
        ),
    }


def format_linear_context(data: dict) -> str:
    issues = data.get("issues", [])
    milestones = data.get("milestones", [])

    lines = [
        "=== PRE-FETCHED BACKLOG (output this verbatim, then ask the release question) ===",
        "",
        "## Backlog — Habit Loop",
        "",
    ]

    active = next(
        (m for m in milestones if m.get("status") not in ("done", "overdue", "canceled")),
        None,
    )
    lines.append(
        f"### Active milestone: {active['name']} ({active['progress']}% complete)"
        if active
        else "### Active milestone: none"
    )
    lines.append("")

    def _fmt_issue(i: dict) -> str:
        desc = (i.get("description") or "").split("\n")[0].strip()[:120]
        return f"- {i['identifier']}: {i['title']}" + (f" — {desc}" if desc else "")

    bugs = [i for i in issues if any(l["name"] in ("Bug", "Tech Debt") for l in i["labels"]["nodes"])]
    work = [i for i in issues if any(l["name"] in ("Feature", "Improvement") for l in i["labels"]["nodes"])]
    unlabeled = [i for i in issues if not i["labels"]["nodes"]]

    lines.append("### Issues (bugs & tech debt)")
    lines.extend(_fmt_issue(i) for i in bugs) if bugs else lines.append("_(none)_")
    lines.append("")

    lines.append("### Remaining work")
    all_work = work + unlabeled
    lines.extend(_fmt_issue(i) for i in all_work) if all_work else lines.append("_(none)_")
    lines.append("")

    lines.append("=== END PRE-FETCHED BACKLOG ===")
    return "\n".join(lines)


def _execute_linear_tool(name: str, args: dict, api_key: str) -> str:
    try:
        if name == "linear_list_issues":
            data = _linear_graphql(api_key, _ISSUES_QUERY)
            return json.dumps(data.get("data", {}).get("issues", {}).get("nodes", []))

        if name == "linear_get_issue":
            data = _linear_graphql(api_key, _GET_ISSUE_QUERY, {"id": args["identifier"]})
            issue = data.get("data", {}).get("issue")
            return json.dumps(issue) if issue else f"Issue {args['identifier']} not found"

        if name == "linear_update_issue_state":
            identifier, state_name = args["identifier"], args["state_name"]
            issue_data = _linear_graphql(api_key, _GET_ISSUE_QUERY, {"id": identifier})
            issue = issue_data.get("data", {}).get("issue")
            if not issue:
                return f"Issue {identifier} not found"
            team_id = issue["team"]["id"]
            states_data = _linear_graphql(api_key, _LIST_STATES_QUERY, {"teamId": team_id})
            states = states_data.get("data", {}).get("team", {}).get("states", {}).get("nodes", [])
            state = next((s for s in states if s["name"].lower() == state_name.lower()), None)
            if not state:
                return f"State '{state_name}' not found. Available: {[s['name'] for s in states]}"
            result = _linear_graphql(api_key, _UPDATE_ISSUE_MUTATION, {"id": issue["id"], "stateId": state["id"]})
            return json.dumps(result.get("data", {}).get("issueUpdate", {}))

        if name == "linear_create_comment":
            issue_data = _linear_graphql(api_key, _GET_ISSUE_QUERY, {"id": args["identifier"]})
            issue = issue_data.get("data", {}).get("issue")
            if not issue:
                return f"Issue {args['identifier']} not found"
            result = _linear_graphql(api_key, _CREATE_COMMENT_MUTATION, {"issueId": issue["id"], "body": args["body"]})
            return json.dumps(result.get("data", {}).get("commentCreate", {}))

    except Exception as e:
        return f"[linear tool error] {e}"

    return f"Unknown Linear tool: {name}"
