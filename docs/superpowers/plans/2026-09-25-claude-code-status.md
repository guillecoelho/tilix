# Claude Code status implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show Working, Waiting, and Idle for Claude Code in Tilix tabs and the session sidebar.

**Architecture:** Claude Code hooks invoke a status-only Tilix command from a local terminal. `TILIX_ID` identifies that terminal. Tilix keeps the state in memory per terminal, summarizes split terminals per session, and renders the summary in both session views.

**Tech Stack:** D, GtkD/GTK 3, GApplication command-line forwarding, CSS, Claude Code command hooks.

**Spec:** `docs/superpowers/specs/2026-09-25-claude-code-status-design.md`

## Global constraints

- Keep all work local. Do not commit, push, create a fork, or edit the user's `~/.claude/settings.json`.
- Accepted states are exactly `working`, `waiting`, `idle`, and `clear`; invalid input leaves state unchanged.
- A status command requires an existing Tilix instance and a matching `TILIX_ID`; it must not focus a window or create a session.
- State is ephemeral and belongs to a terminal. Split-session priority is Waiting, Working, Idle.
- Local Tilix terminals are in scope. tmux, SSH, and multiple Claude processes in one terminal are out of scope.
- The D toolchain is absent in the current environment; report this honestly if it remains unavailable at verification time.

## Review focus

1. `--claude-status` without `TILIX_ID` must fail without changing the selected terminal. Task 2 includes this CLI check.
2. An invalid state must fail without changing a visible indicator. Task 2 includes this CLI check.
3. A late `SessionEnd` after its terminal closes must not open a new window. Task 2 includes this CLI check.
4. Split terminals with mixed states must always show Waiting, then Working, then Idle. Task 1 tests the priority function; Task 3 checks rendering.
5. A terminal moved to another session must remove its status from the old tab and show it on the new one. Task 2 updates both sessions; Task 3 checks both views.

---

### Task 1: Status model

**Files:**
- Create: `source/gx/tilix/claudestatus.d`

**Interfaces:**
- Produces: `enum ClaudeStatus { NONE, IDLE, WORKING, WAITING }`.
- Produces: `bool parseClaudeStatus(string raw, out ClaudeStatus status)`. `clear` maps to `NONE`.
- Produces: `struct ClaudeSummary { ClaudeStatus status; size_t count; }` and `ClaudeSummary summarizeClaudeStatus(const(ClaudeStatus)[] states)`.

- [ ] **Step 1: Write D unit tests in `claudestatus.d` before implementations.**

```d
unittest {
    ClaudeStatus value;
    assert(parseClaudeStatus("working", value) && value == ClaudeStatus.WORKING);
    assert(parseClaudeStatus("clear", value) && value == ClaudeStatus.NONE);
    assert(!parseClaudeStatus("Working", value));
    assert(!parseClaudeStatus("", value));
    assert(summarizeClaudeStatus([ClaudeStatus.IDLE, ClaudeStatus.WAITING,
        ClaudeStatus.WORKING]).status == ClaudeStatus.WAITING);
    assert(summarizeClaudeStatus([ClaudeStatus.WAITING, ClaudeStatus.WAITING]).count == 2);
    assert(summarizeClaudeStatus([ClaudeStatus.NONE]).status == ClaudeStatus.NONE);
}
```

- [ ] **Step 2: Run `dub test`.** Expect the new tests to fail before implementation. If `dub` is absent, record that and continue with code inspection; do not claim a red test run.
- [ ] **Step 3: Implement exact parsing and priority.** Use an explicit `switch` for accepted strings and a single pass over the input states. Count only terminals with the winning status.

```d
module gx.tilix.claudestatus;
enum ClaudeStatus { NONE, IDLE, WORKING, WAITING }
struct ClaudeSummary { ClaudeStatus status; size_t count; }
bool parseClaudeStatus(string raw, out ClaudeStatus status) {
    status = ClaudeStatus.NONE;
    switch (raw) {
        case "working": status = ClaudeStatus.WORKING; return true;
        case "waiting": status = ClaudeStatus.WAITING; return true;
        case "idle": status = ClaudeStatus.IDLE; return true;
        case "clear": return true;
        default: return false;
    }
}
ClaudeSummary summarizeClaudeStatus(const(ClaudeStatus)[] states) {
    ClaudeSummary result;
    foreach (status; states) {
        if (status > result.status) result = ClaudeSummary(status, 1);
        else if (status == result.status && status != ClaudeStatus.NONE) result.count++;
    }
    return result;
}
```

- [ ] **Step 4: Run `dub test` again if the toolchain is available.** Confirm the model tests pass, including mixed states and ties.

### Task 2: Route status to a terminal and summarize its session

**Files:**
- Modify: `source/gx/tilix/cmdparams.d`
- Modify: `source/gx/tilix/application.d`
- Modify: `source/gx/tilix/session.d`
- Modify: `source/gx/tilix/terminal/terminal.d`

**Interfaces:**
- Consumes: `ClaudeStatus` and `parseClaudeStatus` from Task 1.
- Produces: `Terminal.claudeStatus` getter/setter and `onClaudeStatusChange` event.
- Produces: `Session.claudeSummary` getter and `SessionStateChange.CLAUDE_STATUS`.
- Produces: `tilix --claude-status=<working|waiting|idle|clear>` routed by `TILIX_ID`.

- [ ] **Step 1: Write down the exact GUI probe before changing code.** Keep the pure priority tests in Task 1. The repo has no GTK test fixture, so use this command and observation sequence after implementation.

```d
tilix --claude-status=working
tilix --claude-status=waiting
tilix --claude-status=idle
tilix --claude-status=clear
```

- [ ] **Step 2: Add the command option and validation.** Add `CMD_CLAUDE_STATUS`, parse it into `CommandParameters`, and expose both a `hasClaudeStatus` boolean from `vd.contains(CMD_CLAUDE_STATUS)` and the raw `claudeStatus` string. The boolean ensures an empty value is rejected rather than falling through to normal window activation. Register `--claude-status` in `Tilix.addOptions()`. Handle this option before the ordinary action and activation branches in `Tilix.onCommandLine`.

```d
if (cp.hasClaudeStatus) {
    ClaudeStatus state;
    if (!acl.getIsRemote() || cp.terminalUUID.length == 0 ||
        !parseClaudeStatus(cp.claudeStatus, state)) return 2;
    auto terminal = cast(Terminal) findWidgetForUUID(cp.terminalUUID);
    if (terminal is null) return 2;
    terminal.claudeStatus = state;
    return 0;
}
```

- [ ] **Step 3: Store and propagate state.** Add a `ClaudeStatus.NONE` field, getter/setter, and event in `Terminal`. Connect the event in `Session.addTerminal`; disconnect it in `removeTerminalReferences`. The session summary walks `terminals`. Emit `CLAUDE_STATUS` after a terminal changes, joins, leaves, or moves, so both old and new sessions refresh.

```d
@property ClaudeStatus claudeStatus() { return _claudeStatus; }
@property void claudeStatus(ClaudeStatus value) {
    if (_claudeStatus == value) return;
    _claudeStatus = value;
    onClaudeStatusChange.emit(this);
}
@property ClaudeSummary claudeSummary() {
    ClaudeStatus[] states;
    foreach (terminal; terminals) states ~= terminal.claudeStatus;
    return summarizeClaudeStatus(states);
}
```

- [ ] **Step 4: Verify command behavior.** With a running Tilix instance, run `tilix --claude-status=working` from its terminal and confirm the state changes without focus. Repeat with `waiting`, `idle`, and `clear`. Run `env -u TILIX_ID tilix --claude-status=working`, `tilix --claude-status=bogus`, `tilix --claude-status=`, and a stale UUID; each must exit nonzero and leave UI state alone. After closing the last Tilix window, a status command must exit without opening another window.

### Task 3: Render the status in tabs and the sidebar

**Files:**
- Create: `source/gx/tilix/claudestatusindicator.d`
- Modify: `source/gx/tilix/appwindow.d`
- Modify: `source/gx/tilix/sidebar.d`
- Modify: `data/resources/css/tilix.base.css`

**Interfaces:**
- Consumes: `Session.claudeSummary` and `SessionStateChange.CLAUDE_STATUS`.
- Produces: `ClaudeStatusIndicator.update(ClaudeSummary summary)` shared by tab and sidebar. The tab instance follows `SessionTabLabel.updatePositionType` so left and right tabs stay narrow.

- [ ] **Step 1: Build a small shared GTK widget.** Use a dot label and translated text label. Hide the whole widget for `NONE`. Apply `tilix-claude-working`, `tilix-claude-waiting`, or `tilix-claude-idle` to the dot, and set a tooltip with the state and count when more than one terminal reports that state.

```d
module gx.tilix.claudestatusindicator;

import std.format;
import gtk.Box;
import gtk.Label;
import gx.i18n.l10n;
import gx.tilix.claudestatus;

class ClaudeStatusIndicator : Box {
    Label dot;
    Label text;
    this() {
        super(Orientation.HORIZONTAL, 4);
        dot = new Label("●");
        text = new Label("");
        add(dot);
        add(text);
        dot.show();
        text.show();
        setNoShowAll(true);
        hide();
    }
    void update(ClaudeSummary summary) {
        auto style = dot.getStyleContext();
        foreach (name; ["tilix-claude-working", "tilix-claude-waiting", "tilix-claude-idle"])
            style.removeClass(name);
        if (summary.status == ClaudeStatus.NONE) { hide(); return; }
        string label;
        string cssClass;
        final switch (summary.status) {
            case ClaudeStatus.NONE: assert(0);
            case ClaudeStatus.IDLE: label = _("Idle"); cssClass = "tilix-claude-idle"; break;
            case ClaudeStatus.WORKING: label = _("Working"); cssClass = "tilix-claude-working"; break;
            case ClaudeStatus.WAITING: label = _("Waiting"); cssClass = "tilix-claude-waiting"; break;
        }
        text.setText(label);
        style.addClass(cssClass);
        setTooltipText(summary.count > 1 ? format(_("%s in %d terminals"), label, summary.count) : label);
        show();
    }
}
```

- [ ] **Step 2: Add CSS colors and connect both views.** Use readable blue for Working, amber for Waiting, and gray for Idle in `tilix.base.css`. Add an indicator to `SessionTabLabel` and `SideBarRow`, update it at creation and on `CLAUDE_STATUS`. In `SessionTabLabel.updatePositionType`, rotate the indicator text with the session name for left and right tabs. Add a targeted sidebar update method; avoid rebuilding its thumbnail for each hook event.

```css
.tilix-claude-working { color: #3584e4; }
.tilix-claude-waiting { color: #e5a50a; }
.tilix-claude-idle { color: #888a85; }
```

- [ ] **Step 3: Verify the UI.** Check single tabs, multiple tabs, left and right vertical tabs, split terminals, and the sidebar. Confirm session names, notification counts, new-output markers, and close buttons remain usable. Move or detach a terminal with status and check both affected sessions. Check a light and a dark GTK theme.

### Task 4: Document setup and verify the complete flow

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the Task 2 command line and Claude Code's documented hook names.
- Produces: opt-in configuration and removal instructions; no automatic settings edits.

- [ ] **Step 1: Add a complete hook configuration example.** Merge the following `hooks` entries into the user's existing `~/.claude/settings.json`; each entry's command is `tilix --claude-status=<state> >/dev/null 2>&1 || true`. Include all events from the spec and tell the user to remove just these entries to disable the integration.

```json
{
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "tilix --claude-status=idle >/dev/null 2>&1 || true"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "tilix --claude-status=working >/dev/null 2>&1 || true"}]}],
    "PermissionRequest": [{"hooks": [{"type": "command", "command": "tilix --claude-status=waiting >/dev/null 2>&1 || true"}]}],
    "Notification": [{"matcher": "permission_prompt", "hooks": [{"type": "command", "command": "tilix --claude-status=waiting >/dev/null 2>&1 || true"}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "tilix --claude-status=working >/dev/null 2>&1 || true"}]}],
    "PostToolUseFailure": [{"hooks": [{"type": "command", "command": "tilix --claude-status=working >/dev/null 2>&1 || true"}]}],
    "PermissionDenied": [{"hooks": [{"type": "command", "command": "tilix --claude-status=working >/dev/null 2>&1 || true"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "tilix --claude-status=idle >/dev/null 2>&1 || true"}]}],
    "StopFailure": [{"hooks": [{"type": "command", "command": "tilix --claude-status=idle >/dev/null 2>&1 || true"}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "tilix --claude-status=clear >/dev/null 2>&1 || true"}]}]
  }
}
```

- [ ] **Step 2: Explain the known limits.** Document local Tilix terminals only, sandbox network permission notifications arriving after about six seconds, waiting lasting until the next hook after permission approval, Stop with background tasks showing Idle, and forced termination leaving a stale state until another hook or terminal close.
- [ ] **Step 3: Verify documentation and build.** Validate the JSON example with `python3 -m json.tool` or another available parser. Run `dub test` and `dub build` if D tooling exists. Inspect the final diff with `git diff --check` and `git status --short`; report any unavailable checks. Do not commit.
