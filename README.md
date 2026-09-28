![Build Status](https://github.com/gnunn1/tilix/workflows/Build%20Test/badge.svg)
[![Translation status](https://hosted.weblate.org/widgets/tilix/-/svg-badge.svg)](https://hosted.weblate.org/engage/tilix/?utm_source=widget)
# Tilix
A tiling terminal emulator for Linux using GTK+ 3. The Tilix web site for users is available at [https://gnunn1.github.io/tilix-web](https://gnunn1.github.io/tilix-web).

> :warning: **Maintainers Wanted**<br/>
> This project is looking for maintainers!
> At the moment, only very minimal maintenance is done, no new features will be implemented and pull-requests may be reviewed very slowly.
>
> If you are interested in giving Tilix some :heart:, [please chime in](https://github.com/gnunn1/tilix/issues/1700)!

###### Screenshot
![Screenshot](https://gnunn1.github.io/tilix-web/assets/images/gallery/tilix-screenshot-1.png)

### About

Tilix is a tiling terminal emulator which uses the VTE GTK+ 3 widget with the following features:

* Layout terminals in any fashion by splitting them horizontally or vertically
* Terminals can be re-arranged using drag and drop both within and between windows
* Terminals can be detached into a new window via drag and drop
* Tabs or sidebar list current sessions
* Input can be synchronized between terminals so commands typed in one terminal are replicated to the others
* The grouping of terminals can be saved and loaded from disk
* Terminals support custom titles
* Color schemes are stored in files and custom color schemes can be created by simply creating a new file
* Transparent background
* Background images
* [Quake mode](https://github.com/gnunn1/tilix/wiki/Quake-Mode) support (i.e. drop-down terminal)
* Custom hyperlinks
* Automatic (triggered) profile switches based on hostname and directory
* Supports notifications when processes are completed out of view. Requires the Fedora notification patches for VTE
* Experimental trigger support (Requires patched VTE, see [wiki](https://github.com/gnunn1/tilix/wiki/Automatic-(Triggered)-Profile-Switching))
* Experimental badge support (Requires patched VTE, see [wiki](https://github.com/gnunn1/tilix/wiki/Badges))

### Claude Code session status

Tilix can show whether Claude Code is working, waiting for permission, or idle in each tab and in the session sidebar. A tab with split terminals shows the state that needs attention first: Waiting, then Working, then Idle. This integration is optional and uses [Claude Code hooks](https://code.claude.com/docs/en/hooks).

After installing a Tilix build with this feature, merge the following entries into the `hooks` object in `~/.claude/settings.json`. Keep any hooks you already have. Claude Code must run directly in a local Tilix terminal so its hooks inherit `TILIX_ID`.

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

Start a new Claude Code session after saving the settings. To remove the integration, delete these Tilix command entries from `hooks` and leave your other hooks in place.

For a local Meson build that is not installed, the `tilix` command above still runs the system version. Use the absolute path to `build/builddir/tilix` in each hook command. To test alongside an installed Tilix, add `--group=claudedev` to both the launch command and each hook command. The build's CSS also needs its resource bundle ahead of the installed one in `XDG_DATA_DIRS`.

The indicator reflects Claude Code's main turn. Sandbox network permission prompts use a notification hook that fires after about six seconds, so their indicator may briefly remain Working. Waiting can remain visible until another hook runs after permission approval. `Stop` can show Idle while background tasks continue. If Claude Code is killed before `SessionEnd` runs, the indicator remains until another hook updates it or the Tilix terminal closes. SSH, tmux, and multiple Claude Code processes sharing one Tilix terminal are not supported by this integration.

The application was written using GTK 3 and an effort was made to conform to GNOME Human Interface Guidelines (HIG). As a result, it does use CSD (i.e. the GTK HeaderBar)
though it can be disabled if necessary. Other than GNOME, only Unity has been tested officially though users have had success with other desktop environments.

### Dependencies

Tilix requires the following libraries to be installed in order to run:
* GTK 3.18 or later (Tilix 1.8.3 or later, earlier versions supported GTK 3.14)
* GTK VTE 0.46 or later
* dconf
* GSettings
* [Nautilus-Python](https://wiki.gnome.org/Projects/NautilusPython) (Required for Nautilus integration)

### Migrating Settings From Terminix

Terminix was recently re-named to Tilix and as a result the settings key changed. To migrate your settings to Tilix, please perform the following steps:

```
dconf dump /com/gexperts/Terminix/ > terminix.dconf
dconf load /com/gexperts/Tilix/ < terminix.dconf
```
This will export your settings from the Terminix key in dconf and re-import them into the Tilix key.

Note that this will work even after you have uninstalled the Terminix schema, since the user customized settings are available even after the schema got removed, and the
default settings are identical between the two and thus do not matter.

Once you have imported the settings and everything is ok you can clear the old Terminix settings with:
```
dconf reset -f /com/gexperts/Terminix/
```
Finally to copy the bookmarks and custom themes just do:

```
mv ~/.config/terminix ~/.config/tilix
```

### Optional Fonts
In some of the screenshots, the `powerline` statusline shell plugin is used. In order to ensure it works well, you may need to install its [fonts](https://github.com/powerline/fonts)
and ensure Tilix is aware of them. They can be installed via `sudo apt install fonts-powerline` on Debian/Ubuntu and `sudo dnf install powerline-fonts` on Fedora/RedHat-based
Linux distributions.
After installing the fonts, select the "Powerline Symbols" font in Tilix via **Preferences -> Default -> Custom Font**. Sessions are updated automatically.

### Support

If you are having issues with Tilix, feel free to open issues here in github as necessary.

### Localization

Tilix is localized using Weblate, please visit the Weblate hosted [Tilix translations site](https://hosted.weblate.org/projects/tilix/translations) in order to assist
with translations, please do not submit direct pull requests to this repository for translations.

### Building

Tilix is written in [D](https://dlang.org/) and GTK 3 using the gtkd framework. This project uses dub to manage the build process including fetching the dependencies,
thus there is no need to install dependencies manually. The only thing you need to install to build the application is the D tools (compiler and Phobos) along with dub itself.
Note that D supports three [compilers](https://wiki.dlang.org/Compilers) (DMD, GDC and LDC) but Tilix only supports DMD and LDC.

Once you have those installed, compiling the application is a one line command as follows:

```
dub build --build=release
```

The application depends on various resources to function correctly, run `sudo ./install.sh` to build and copy all of the resources to the correct locations. Note this
has only been tested on Arch Linux, use with caution.
Note : `install.sh` will install Tilix to your `/usr` directory. If you are interested in installing Tilix to a custom location, you can specify the `PREFIX` as an
argument to the `install.sh` script (e.g : `./install.sh $HOME/.local` will install Tilix into `$HOME/.local`). However, this requires you to add your `$PREFIX/share`
directory to your `$XDG_DATA_DIRS` environment variable.

Note there is also support for building with the Meson buildsystem, please see the wiki page on [Meson](https://github.com/gnunn1/tilix/wiki/Building-with-Meson)
for more information.

#### Build Dependencies

Tilix depends on the following libraries as defined in dub.json:
* [gtkd](http://gtkd.org/) >= 3.11.0
* gdk-pixbuf-pixdata (Used when building resource file)

### Install Tilix

Tilix is available as [packages](https://gnunn1.github.io/tilix-web/#packages) for a variety of distributions.

#### Uninstall Tilix

This method only applies if you installed Tilix manually using the install instructions. If you installed Tilix from a distribution package then use your package manager
to remove tilix, do not use these instructions.

Download the uninstall.sh script from this repository and then open a terminal (not Tilix!) in the directory where you saved it. First set the executable flag on the script:

```
chmod +x uninstall.sh
```

and then execute it:

```
sudo sh uninstall.sh
```
