# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Tilix is a tiling terminal emulator written in D on GTK 3, using GtkD bindings and VTE.

## Build and test

Meson is the primary build (CI uses it with `ldc2`). The local build directory is `build/builddir`:

```sh
meson setup build/builddir          # once
ninja -C build/builddir             # builds tilix and tilix_test
meson test -C build/builddir --print-errorlogs
```

- Tests are D `unittest` blocks compiled into the `tilix_test` executable. There is no per-test filter: running `build/builddir/tilix_test` runs every `unittest` block.
- dub also works (`dub build --build=release`, `dub test`). CI runs both.
- **Every new `.d` file must be added to `tilix_sources` in `meson.build`.** dub finds files on its own, but Meson does not.
- `dscanner.ini` configures D-Scanner. `.editorconfig` sets style: 4-space indent, OTBS braces, 170-column max line length.

## Running a local build

An uninstalled build loads its resources from `$XDG_DATA_DIRS/tilix/resources/tilix.gresource` (see `findResource` in `source/gx/gtk/resource.d`). Without extra setup it picks up the *installed* resources, so CSS or UI changes under `data/resources/` won't show. Put the build's resource directory ahead of the installed one in `XDG_DATA_DIRS`. GSettings keys come from `data/gsettings/com.gexperts.Tilix.gschema.xml`, so new keys need a compiled schema (`GSETTINGS_SCHEMA_DIR`).

Tilix is a single-instance `GApplication`. A second `tilix` invocation forwards its command line to the running primary instance (`Tilix.onCommandLine` in `application.d`). To run a dev build next to an installed Tilix, use `--group=<name>` or `--new-process`.

## Architecture

Widget hierarchy, top down:

- `source/app.d`: entry point. Parses early args (`--group`, `--new-process`, `--version`) and appends `--terminalUUID=$TILIX_ID` when running inside a Tilix terminal, which lets remote commands target the calling terminal.
- `Tilix` (`application.d`): the `Gtk.Application`. It owns the windows, registers GOptions (names in `cmdparams.d`), and resolves UUIDs to widgets with `findWidgetForUUID`.
- `AppWindow` (`appwindow.d`): hosts sessions in either a `Notebook` of tabs (`SessionTabLabel`) or a `Stack` with the `SideBar` (`sidebar.d`). It also handles Quake mode.
- `Session` (`session.d`): one tab. Terminals are arranged in a tree of `TerminalPaned`, and layouts are serialized to and from JSON (`serializeWidget` etc.) for saved sessions.
- `Terminal` (`terminal/terminal.d`): an `EventBox` wrapping `ExtendedVTE` (`terminal/exvte.d`, a VTE subclass) plus its title bar, search, and menus.

Cross-cutting patterns:

- **Events:** child-to-parent communication uses `GenericEvent!(...)` fields (e.g. `Terminal.onTitleChange`) connected and disconnected in `Session.addTerminal` / `removeTerminalReferences`. Sessions notify the window through `onStateChange` with a `SessionStateChange` value.
- **Actions:** behavior is exposed as GIO actions in groups prefixed `app`, `win`, `session`, `terminal` (constants in `constants.d`). Keyboard shortcuts are GSettings keybindings mapped to these actions. `tilix -a <action>` walks up from the target widget to find a group that has the action.
- **Settings:** GSettings under `com.gexperts.Tilix.*`. `preferences.d` holds the key constants and the `ProfileManager`. The preferences UI lives in `prefeditor/`.
- **Resources:** CSS (`data/resources/css/`) and UI files are compiled into `tilix.gresource`. Style widgets by adding CSS classes rather than inline styling.
- **Optional VTE features:** notifications, triggers, and background-draw need a patched VTE. Gate code on `checkVTEFeature(TerminalFeature.*)` from `gx/gtk/vte.d`.
- **GtkD gaps:** GtkD 3.10 lacks some newer VTE APIs. Declare the C function `extern(C)` in `exvte.d` and wrap it there, as with `vte_terminal_paste_text`.
- **Claude Code status (this fork):** `--claude-status=working|waiting|idle|clear` sets a per-terminal state (`claudestatus.d`). `Session.claudeSummary` aggregates it, and `ClaudeStatusIndicator` renders it in tab labels and sidebar rows. The README documents the Claude Code hook setup.

## Localization

Wrap user-visible strings in `_()` from `gx.i18n.l10n`. Translations are managed on Weblate, so don't edit `po/*.po` by hand. `extract-strings.sh` regenerates the template at release time (see `RELEASE.md`).
