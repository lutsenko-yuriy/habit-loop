from ..agentic.constants import MAX_TOOL_TURNS

_FM_PLAIN = ("RAPID", "MECHANICAL", False, None, False, [], MAX_TOOL_TURNS, "body")
_FM_SESSION_TOOLS = ("RAPID", "MECHANICAL", True, None, False, [], MAX_TOOL_TURNS, "body")
_FM_NO_EFFORT = (None, None, False, None, False, [], MAX_TOOL_TURNS, "body")
_FM_FOCUSED = ("FOCUSED", "ARCHITECTURAL", False, None, False, [], MAX_TOOL_TURNS, "body")
_FM_WITH_CONTEXT = ("RAPID", "MECHANICAL", False, "linear", False, [], MAX_TOOL_TURNS, "body")
_FM_WITH_CONTEXT_AND_RENDER_HTML_VIEW = ("RAPID", "MECHANICAL", False, "linear", True, [], MAX_TOOL_TURNS, "body")
_FM_WITH_TOOLS_LINEAR = ("RAPID", "MECHANICAL", False, None, False, ["linear"], MAX_TOOL_TURNS, "body")
_FM_WITH_TOOLS_GITHUB = ("RAPID", "MECHANICAL", False, None, False, ["github", "files"], MAX_TOOL_TURNS, "body")
