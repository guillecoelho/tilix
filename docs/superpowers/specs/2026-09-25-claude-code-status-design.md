# Claude Code status in Tilix

## Purpose

Show the state of a Claude Code CLI running inside Tilix without switching to its tab. A user with several Tilix sessions should be able to identify which Claude session is working, waiting for permission, or idle. The first version uses documented, opt-in Claude Code hooks for setup.

## Visible behavior

- A Tilix tab with a Claude Code process shows a colored dot and label: Working in blue, Waiting in amber, or Idle in gray. The session sidebar shows the same state and colors.
- A tab containing split terminals shows the highest-priority Claude state among its terminals: Waiting, then Working, then Idle. If no terminal has a Claude state, the indicator is hidden. The tooltip identifies the state and, for split sessions, the number of terminals reporting it.
- The indicator does not replace session names, terminal titles, notification counts, or new-output markers.
- A normal Claude Code exit clears its terminal's state. Closing or moving a terminal updates its old and new sessions immediately. An unknown or malformed status does not change the UI.
- This feature reports Claude Code running in a local Tilix terminal. Terminals inside tmux, SSH sessions, and multiple Claude Code processes sharing one terminal are outside the first version's scope because they cannot be mapped unambiguously to a Tilix terminal.

## Data flow

1. Tilix already sets `TILIX_ID` to a terminal UUID in each child shell. It also passes that UUID to a Tilix command launched from the shell.
2. An opt-in entry in Claude Code's user hooks calls `tilix --claude-status=<state>` from that shell. Tilix accepts `working`, `waiting`, `idle`, and `clear` for this command. It rejects the command if there is no existing Tilix instance or no matching terminal UUID; a late hook must not open a new window or change the active terminal.
3. The existing GApplication command-line route finds the terminal by UUID across windows and sends the validated state to it. The terminal stores its state in memory only. Its containing session computes the priority result and emits a status-change event. The tab and sidebar update from that result.
4. A terminal's state is destroyed with the terminal. Layout serialization does not persist Claude state, since Claude Code may not be running when a layout is restored.

## Hook mapping and setup

The README will give an example for merging these commands into `~/.claude/settings.json`, without overwriting existing hooks. The commands are fast, produce no terminal output, and do not block Claude's work if Tilix is unavailable.

| Claude Code event | Tilix state |
| --- | --- |
| `SessionStart` | Idle |
| `UserPromptSubmit` | Working |
| `PermissionRequest` | Waiting |
| `Notification` with `permission_prompt` matcher | Waiting for sandbox network prompts, after Claude Code's notification delay |
| `PostToolUse`, `PostToolUseFailure`, `PermissionDenied` | Working |
| `Stop`, `StopFailure` | Idle |
| `SessionEnd` | Clear |

The state describes the main Claude Code turn. A `Stop` event with background tasks still running may show Idle in this first version. After permission approval, Waiting may remain visible until the next hook fires. Sandbox network prompts can remain Working for about six seconds before their notification hook fires. The setup guide will state these limits.
If Claude Code is killed before `SessionEnd` runs, the state remains until another hook updates it or the terminal closes.

## Implementation boundaries

- `cmdparams.d` and `application.d` validate and route the status-only command. They do not focus windows or create sessions.
- `terminal.d` owns the per-terminal state. `session.d` aggregates split terminals and emits a state change when the visible result changes.
- `appwindow.d` and `sidebar.d` render the status alongside existing tab and sidebar controls. CSS supplies dot colors and preserves readable text in light and dark themes. Status text and tooltips are translatable.
- The README contains the opt-in hook configuration and removal steps. Tilix does not edit Claude Code's settings.

## Verification

- Exercise each CLI state against one terminal, a split session, multiple tabs, a detached window, and an invalid UUID. Confirm priority changes and clearing when Claude or a terminal exits.
- Confirm the hook configuration merges with existing Claude Code hooks and that a stale hook does not start a Tilix window.
- Build with `dub build` and run the project's available tests. If the D compiler or dependencies are absent, report that limit and perform source-level checks without claiming a successful build.
