# Neovim

Owned Lua configuration using lazy.nvim, with no distribution or highlight cache.
Requires **Neovim 0.12+** (current stable), Git, and network access on first launch.

## Run

This repo's `nvim/.config/nvim/` is the complete config. Your existing
`~/.config/nvim` symlink already points here; open a new Neovim process.
For another machine, back up its config before copying this directory:

```sh
cp -R nvim/.config/nvim ~/.config/nvim  # destination must not already exist
nvim
```

lazy.nvim installs plugins automatically. Use `:Lazy restore` to restore the
versions in `lazy-lock.json`; commit that file after intentional updates.
Do not run `:Lazy clean` until you are happy with the migration: old plugin
directories and caches are harmless and are not loaded by this config.

Optional external tools:

- Search: `fzf`, `ripgrep` (`rg`), optionally `fd`.
- Language servers/formatters: install on PATH, or use
  `:MasonInstall lua-language-server gopls pyright ruff stylua goimports`.
  Restart Neovim after installing servers. Nothing auto-installs these tools.
  Pyright needs Node.js; Go tools need Go. `:checkhealth mason` explains prerequisites.
- Treesitter: C compiler, `curl`, `tar`, and `tree-sitter` CLI 0.26.1+.
  Run `:TSInstall lua luadoc vim vimdoc go python markdown markdown_inline`.
  Missing parsers fall back to built-in syntax; no experimental indentation.
- Go debugging: `dlv` (Delve). Browser Markdown preview: its plugin build needs
  network access. TeX: `latexmk` and Skim (macOS) or Zathura (Linux).
- Clipboard integration needs a system clipboard provider; icons need a Nerd Font.

## Layout

```text
init.lua                   startup order only
lua/options.lua            editor options
lua/autocmds.lua           editor events
lua/config/                lazy bootstrap, theme selection, highlight overrides
lua/config/statusline.lua  owned statusline section order and separators
lua/ui/                    native statusline renderer and theme-neutral fallback
lua/themes/onedark/        owned OneDark palette and highlight mappings
colors/dotted-onedark.lua  local colorscheme entry point
lua/plugins/               lazy specs split by concern; remove any unwanted file
lua/configs/               independent plugin options/setup, LSP server settings
lua/keymaps/               actions, Lua presets, keymap-table UI
lua/util/                  owned terminal, platform, runner, and search utilities
after/plugin/              Ctrl-click URL mapping
tests/smoke.lua             headless regression checks
lazy-lock.json             generated plugin version pins (not configuration code)
```

Modules declare their dependencies explicitly; load a plugin's setup module only
after installing/loading that plugin. No module needs NvChad globals or caches.
LSP, completion, formatting, statusline, and theme have separate setup paths.
Formatting on save belongs solely to `configs/conform.lua`.

## Terminal UI

The existing config is extended, not replaced by LazyVim or NvChad:

- A centered dashboard opens on empty interactive startup, never over file
  arguments, stdin, or modified buffers. `:Dashboard` opens it on demand.
- `vi .` or `nvim /path/to/project` opens an empty editable buffer in that
  project's working directory. **Ctrl-E** opens NvimTree when needed.
- A native bufferline shows filenames, modified markers, and close buttons.
  Click to switch; click × or middle-click to close. Modified buffers refuse to
  close until saved/discarded. Tab/Shift-Tab keep their existing buffer bindings.
- Your segmented statusline, selected colorscheme, theme confirmation, Git/LSP
  gutter icons, and transparency policy stay intact.
- Finder and replacement panels share rounded borders and palette roles.
  Replacement defaults to a small widget at the source split’s top right so files remain visible.
  These finder/replacement panels need no additional UI plugin or distribution.

Set `dashboard` or `bufferline` to false in `lua/config/ui.lua` to disable them.
The same file controls finder dimensions and the compact `replace` dimensions.
The dashboard's single-key
actions are local to its buffer; they do not replace your editor mappings.

### Mouse feedback

Clickable controls highlight under the pointer: top file tabs and their bold
numbers, separate × buttons, the dashboard button, Neovim tab-page numbers,
breadcrumbs, **Tools**, and every tool-drawer tab/action (including compact
headers). Dashboard actions, diagnostic rows, menu/theme rows and confirmation
buttons also respond to hover. Leaving a control clears its hover styling;
existing active-tab colors return unchanged.

Hovering never switches files/tabs, closes buffers, runs commands or stops
processes. List rows can be selected/previewed, but accepting still requires a
click or keyboard action. Confirmation hover does not change its safe **No**
keyboard default. Mouse mappings and terminal input continue working normally;
finder and existing theme palettes are not recolored.

## Explorer and run controls

The top bar has separate **▶ File**, **▶ Project** and **󰃤 Debug** controls.
**Space r** runs the focused file (the current package for Go).
**Space R** runs the project from any file in that project, including a library,
test, configuration or documentation file. **▾** selects the project's run target.
The selected project target stays the same when you run a file or focus another
file, including a different application's entry point in the same repository.

Project Run detects the project root and its application commands.
Explicit Make `run`/`dev`/`start` targets take priority, followed by
Node `dev`/`start`/`serve`/`run` scripts with the project's package manager.
Go main packages and `cmd/*` applications, Cargo projects, Python entry scripts,
Django servers and Python packages with `__main__.py` are also detected. Named
Make targets such as `run-server` and `run-worker` replace the corresponding
bare Go commands so their environment and setup are preserved. Nested
Node packages inherit the workspace's package manager. A target menu opens when
several applications are available; your choice is remembered per project for
the current Neovim session. If no project tasks are found, Project Run reports
that instead of executing the focused file.

The bug icon and **Space d R** start debugging the focused file, or
resume an existing session. The toolbar switches its pause/step/restart/stop
controls between the chosen Run and Debug modes. **▾** changes the selected
project application; **▶ File** always runs the focused file independently.

When a replace widget has focus, Run uses that widget's source file. From Tools
or the explorer, it uses the last focused editor in that Neovim tab. Clicking Run
captures its target before scheduling work, so a later focus change cannot pick
another file. **↻** restarts the selected launch, keeping its file/package,
arguments, interpreter and working directory even after changing editor tabs,
closing the original source, or finishing a debug session. **Space d l** reruns
the last resolved debug launch. Active server reruns wait asynchronously for
the old process group to exit before starting a replacement; Stop cancels a
pending restart. Only a new Run/Debug action or target selection
changes the selected configuration.

Project Run and project restart save modified files within that project;
file-only Run and Debug save their own source. Launch skips synchronous format-on-save;
ordinary saves retain the formatting policy. Simple commands run directly with
argv, without an intermediate shell. Python uses the existing project interpreter
directly; uv bootstraps an environment only when a uv project has no environment.
The Light/Dark button saves a bundled appearance choice.

NvimTree has icons for file/folder creation, collapse, expand, sort, follow,
move and search. Inputs and dropdowns open beside their toolbar button and stay
on screen. **Ctrl-E** toggles the explorer and preserves its chosen side.
The explorer reveals the current editor file on opening and follows file,
split and tab changes. Its active file keeps a full-row highlight while you
browse; mouse hover and keyboard navigation select rows without a block caret.
Hover never opens files or takes focus. **gF** or the follow icon toggles automatic
reveal. Text inputs and the editor retain their normal cursor.
**/**, **f**, **Ctrl-F** and the search icon toggle search. The search input and
results stay inside the explorer area; **Esc** or another click on the search
icon closes them. Results retain file-type icons, tree colors and the active-file
highlight. **Enter**, **Ctrl-Enter** or clicking a result opens its file in the
editor; folder results expand in the tree. Hover only selects a row.
**g/** closes search from the tree.

Search walks directories in short, cancellable batches without expanding the
whole tree. It shows up to 200 matching paths; narrow the query for more specific
results. **g?**, `:Keymaps` and `:Cheatsheet` list the explorer controls.

**Space u t** opens Tools below all editor splits. Terminal sessions have their
own second row: click **zsh / zsh 2 / …** to switch, or use **]T/[T** in normal
mode. **g+** creates another shell. Hiding Tools preserves its processes.

**Ctrl-R** opens current-file replace; **Ctrl-Shift-R** opens project replace.
**u / Cmd-Z** undo, and **R (Shift-R) / Cmd-Shift-Z** redo. The Command shortcuts
also work in insert mode. This repo's Ghostty config forwards those two Command
shortcuts to Neovim instead of consuming them for terminal tab undo/redo. Reload
Ghostty's config with **Cmd-Shift-comma** after applying it.

Each editor split owns an independent replace widget, with separate fields,
options and matches. Opening one in another split or Neovim tab keeps the others.
Returning to the same split and reopening focuses its existing widget. Closing
one widget leaves the others open.

## Buffers and recent-file switcher

File tabs show a **bold full-size position after the name**, e.g. `main.py [1]`.
**Space 1–9** jumps to that position; `:BufferGo 12` handles higher numbers.
Positions follow the complete file-buffer list, including tabs hidden by a narrow
screen, and do not change just because another file becomes most recently used.
Closing a buffer renumbers later positions. Utility/terminal buffers aren't numbered.
Ghostty uses one font size, so labels are bold, not a different-size font.

**Option-Tab / Option-Shift-Tab** on macOS cycle a popup of recent file buffers
in normal and insert mode. Linux/Windows keep **Ctrl-PageDown / Ctrl-PageUp**.
Repeated presses preview files through a frozen MRU list. **Hold Option** to keep
the popup open indefinitely; **release Option** to choose and dismiss immediately.
There is no inactivity timeout. A local macOS CoreGraphics modifier-flags check
runs only while the popup is open; it doesn't capture keys or change Ghostty.
**Enter** also confirms; **Esc** cancels and restores the original file/view.
Other input confirms and continues normally. Focus changes dismiss safely.
On SSH/non-macOS, modifier release is unavailable: use Enter or another key to
confirm (still no timeout). Intermediate previews don't reorder history.
Only ordinary listed file buffers are included; unsaved edits are preserved.
Tab/Shift-Tab retain sequential navigation in every preset.
The selected row and mouse-hovered row share the workspace's finder-derived
selection palette and update with the theme. Hover only highlights; it does not
change the selected file or the file chosen on Option release.

`:Keymaps`, `:Cheatsheet`, and `:KeymapsWrite` include these controls and scoped
drawer, breadcrumb/menu, dashboard, confirmation, replace and preview shortcuts.
Context-only controls are documented without installing them globally.

These MRU mappings are Neovim-only; Command undo/redo forwarding is described above.
Ctrl-Tab/Ctrl-Option-Tab and macOS Ctrl-Fn-Up/Down are no longer MRU aliases.

## Bottom file-path navigation

The existing statusline's file segment now shows clickable project-relative
breadcrumbs: `dotted > nvim > .config > file.name`. Click a directory to list
its immediate children, including hidden entries, or **Space u B** to open the
current file's directory. The filename segment and dropdown entries show
file-type icons (Markdown, Python, Go, etc.), with a generic icon for unknown types.
Dropdowns align directly above the breadcrumb label's
left edge (not the clicked character), without an absolute-path title. Choosing
a directory applies it to the navigation breadcrumb and moves the same menu
right under that directory; going up moves it back under the parent. Loading
doesn't move it away from that label, and near the right edge it stays on screen.
The open breadcrumb changes color; the menu uses a full-row
selection with no text caret. Hover a row to select it, then click or press Enter
to open it (hover never opens a file). Clicking another breadcrumb replaces the
menu; closing it restores normal breadcrumb and editor-cursor styling.
Breadcrumb hover rows and active segments follow fzf's actual selected-row
colors (including configured color overrides), rather than approximating them
with Vim's Visual selection. File/grep pickers, the theme picker and other menus
keep their original styling. Hovering a breadcrumb label or **Tools** in the
bottom bar highlights just that clickable part; leaving clears the highlight.
Hover never opens anything or moves the editor cursor, and works in normal,
insert and terminal modes without replacing mouse mappings. Directory navigation
does not replace the editor's file; dismissing restores its original breadcrumb.
Use arrows/j/k to select, Enter/l/Right to open or
descend, h/Left/Backspace to go up within the project, and Esc/q to dismiss. File clicks open/focus
the file in the source editor window. Paths with spaces and `%` are escaped.

Directory scans run asynchronously on opening a menu, not in the statusline
renderer. Long paths collapse middle segments; the ellipsis opens the project
root. Parent navigation stops at that root: an explicitly opened directory or
nested cwd takes precedence over an enclosing Git repository. Navigation never
changes cwd or force-discards modified text.
Set `breadcrumbs = false` in `lua/config/ui.lua` for the old filename-only segment.

## Bottom tools

Click **Tools** in the statusline, press **Space u t**, or use `:Tools`.
`:Tools Debug`, `:Tools Output`, `:Tools Problems`, and `:Tools Terminal` select
a tab directly. The drawer starts closed and remembers its selected tab/height
per Neovim tabpage for this session. Its persistent header and content sit below
the editor columns: switching tabs swaps buffers without closing/recreating windows,
cutting across NvimTree, moving the header, or borrowing another plugin's layout.

| Tab | Content |
| --- | --- |
| Debug | Existing DAP program console, including input; scope/REPL icons open the existing debugger views |
| Output | Overseer task stdout/stderr; history selects prior output; + opens the task launcher |
| Problems | Live native diagnostics grouped by file, with Enter/double-click jumps to the editor |
| Terminal | Persistent shells on a second row; history lists shells, + starts another |

Click tab names or use **g1–g4**, **]t / [t** in drawer normal mode.
**gm** or **−** minimizes/restores to a small header/content strip; **gq** or **×**
hides the drawer. **gL** opens its selector, and **g+** creates a terminal.
Press **i** in a terminal/console to type; **Ctrl-x** returns to normal mode.
Normal split-resizing keys work, and the last height is remembered when hidden.
`tools.height` controls the initial height; `tools.enabled = false` disables it.
Problems uses the drawer's own diagnostic buffer so a second window manager
cannot resize/reopen the panel. Trouble is still available separately with
`:Trouble diagnostics`. Esc focuses the editor and q closes the Problems drawer.

Hiding/minimizing does **not** stop shells, tasks, or debugging. Output's **Stop**
and **Rerun** controls are explicit task actions. Use `:OverseerToggle` for full
task management/disposal. Debug's **Stop** or Space d x terminates debugging.
The drawer does not relocate dap-ui's tracked windows: its Debug console shares
the existing buffer, while scopes/watches/stack frames keep their existing layout.

**Space r** keeps the current-file language dispatch and saves before running,
but CLI runs now use persistent asynchronous Output instead of blocking `:!`.
Go runs the current package inside a module, or the current file without one;
Python uses the active/project environment or PATH; uv can bootstrap a missing
project environment. Interactive commands have terminal input. Markdown/Vimtex
keep their specialized actions; Lua runs asynchronously in its interpreter or
a separate headless Neovim process.
Only diagnostics already reported to Neovim appear in Problems; this does not
silently lint every unopened file in a project.

## Git graph and workspace

**Space g G** opens Neogit and its all-reference commit graph. It is lazy-loaded
on demand, uses Unicode graph lanes, bounds the initial history page to 150
commits, and disables background Git file watching. Enter on a commit opens
details/inline diffs; Neogit's status workspace supports explicit staging,
committing, branches, stashes, and other Git actions. `:Neogit` opens status directly.
Side-by-side diffs are not enabled; no extra diff plugin is installed.

Opening the graph does not checkout/reset/stage anything. Neogit's mutation
actions remain available only when explicitly invoked; review their prompts.
Gitsigns and the existing **Space g c / g t** fzf-lua pickers are unchanged.
Workspace plugin specs and version pins are in `lua/plugins/workspace.lua` and
`lazy-lock.json`. No theme, UI distribution, or statusline framework was added.

## Find and replace

| Scope | Key | Command | Behavior |
| --- | --- | --- | --- |
| Current buffer | Space s b | `:Replace` | Edits unsaved buffer contents; never writes automatically |
| Project | Space s r | `:ReplaceProject` | Previews file changes, then explicitly writes them |

Additional normal-mode aliases in every preset:

| Key | Action |
| --- | --- |
| Shift-f (`F`) | Find in the current file |
| Ctrl-Shift-f | Find across the project |
| Ctrl-r | Find & replace in the current file |
| Shift-r (`R`) | Redo |
| Ctrl-Shift-r | Find & replace across the project |

Leader and existing IDE-style shortcuts remain available. `F` opens buffer search; `R` is redo. Buffer replacement also has
Space s b / Space s R aliases. Ctrl-Shift
letters require enhanced keyboard support from the terminal (Ghostty supports it).

**Current buffer:** type the search text, Tab to the replacement field. Matches
are highlighted in the file. The widget is anchored to the top right of the
source split and follows its size. Its four content rows show fields, counts,
and essential controls; **Alt-e** toggles the larger old/new preview when needed.
The source view centers the selected match when navigating.
Enter in Search moves to the next match; Enter in Replace applies the current
replacement. Ctrl-n/Ctrl-p navigate matches, Ctrl-g replaces one, and Ctrl-s or
Ctrl-Enter replaces all. The header has clickable regex/case/word toggles,
previous/next, replace-one/all, expand and close icons.
Alt-r toggles regex, Alt-c case sensitivity, and Alt-w whole-word matching.
Esc leaves insert mode; q/Esc in normal mode closes the panel. Undo in the file
with `u` / Cmd-Z and redo with `R` / Cmd-Shift-Z; each Apply is a separate undo step. Literal, case-insensitive
matching is the default. Regex uses Vim's very-magic syntax and `\1` backreferences;
expression replacements (`\=`) and multiline input aren't supported here.

**Project:** the existing grug-far engine lives in a compact float at the source
split’s top right, with search/replacement, file filters, paths, flags, and live diffs. **Alt-e**
expands/collapses the panel for reviewing more results. Tab scrolls to each field.
Tab cycles fields, Enter/Ctrl-s applies all results, and Ctrl-g syncs the result line
under the cursor in normal mode. Its header has clickable regex/case/word, Apply,
expand and close controls. Alt-r/Alt-c/Alt-w also toggle regex/case/word flags;
g? shows engine help. Normal-mode q/Esc closes it once idle; Ctrl-c aborts a
running operation without opening a mismatched default confirmation. Project regex uses ripgrep
syntax and `$1` captures. The scope defaults to the Git root, then module/project
root, then cwd; edit Paths/Filters to narrow it. Standard ripgrep ignore/hidden
rules apply (change Flags explicitly when needed).

Project apply refuses to overwrite modified loaded project buffers: save those
first. Project replacements write multiple files and are **not** a single
Neovim undo operation; review the live diff first and use version control for
recovery. `:GrugFar` remains available as the underlying engine.

Implementation: `lua/ui/replace.lua`, `lua/util/replace.lua`, and
`lua/configs/replace.lua`. Custom presets inherit the new action unless disabled.
Every preset uses Ctrl-r for buffer replacement. JetBrains also has Cmd-r
on macOS; VS Code also has Cmd-Alt-f.
The existing Ctrl-h split-navigation mapping is not stolen.

## Go debugging

Delve is already installed on this machine at `~/go/bin/dlv` (1.27.2, verified
with Go 1.27.3). On another machine install it explicitly:

```sh
go install github.com/go-delve/delve/cmd/dlv@latest
```

DAP resolves `dlv` from PATH, then `~/go/bin/dlv`; override it in
`lua/config/debug.lua` if needed. The adapter starts in the Go module directory
so compilation works even when Neovim was opened elsewhere. DAP UI opens scopes,
watches, stack frames, and console automatically for a session.
`lua/ui/dap.lua` recovers manually closed panes before reopening the UI, without
resetting watches or the debug session. **Space d u** closes the whole debugger
UI if any panes remain, and opens it on the next press. After config updates,
save your files and fully restart Neovim to replace cached DAP listeners.

| Key | Action |
| --- | --- |
| Space d b | Toggle visible breakpoint ● |
| Space d c | Start/continue; choose a launch configuration |
| Space d o / d i / d O | Step over / into / out |
| Space d e | Inspect a variable/expression (also visual selection) |
| Space d t / d L | Debug nearest / last Go test (Go Treesitter parser required) |
| Space d u / d r | Toggle debugger UI / REPL |
| Space d x | Terminate |

JetBrains-style debug aliases are also available in the **default** and
**jetbrains** presets, without removing any Space d… keys:

| Action | Shortcut (Windows / Linux / macOS) | Additional macOS shortcut |
| --- | --- | --- |
| Start / resume | Shift-F9 / F9 | Ctrl-d / Cmd-Alt-r (jetbrains preset only) |
| Toggle breakpoint | Ctrl-F8 | Cmd-F8 |
| Step over / into / out | F8 / F7 / Shift-F8 | Same |
| Inspect expression (normal or visual mode) | Alt-F8 | Same |
| Stop debugging | Ctrl-Shift-F2 | Cmd-F2 |
| Toggle debugger panes | Alt-5 | Cmd-5 |

The VS Code preset keeps its F5/F9/F10/F11 debug layout. Modified function keys
and Cmd chords need terminal/GUI support; on Mac keyboards you may need **Fn**
to send F-keys rather than media controls. `:Keymaps` and `:Cheatsheet` show the
active shortcuts. Reload mappings with `:lua require("keymaps").setup()` or
restart Neovim. Default keeps Ctrl-d's normal Vim scrolling behavior.

The named configurations are **Go: current package**, **Go: current file**, and
**Go: tests in package**. dap-go's argument/attach profiles remain available;
nvim-dap also reads project `.vscode/launch.json` configurations. Install the Go
Treesitter parser with `:TSInstall go` for nearest-test discovery. Package/test
launches do not depend on that discovery feature. On macOS, allow Developer
Tools access if the OS prompts; debug only trusted code.

`tests/dap_go.lua` copies a tiny Go module into a temporary directory and runs
all three named configurations through real Delve. It verifies breakpoints,
local-variable scopes/evaluation, step into/over/out, and clean termination.

## Python debugging

Python uses **debugpy**, not Delve. It shares the breakpoint, stepping, inspection,
REPL, and debugger-pane keys above; the Go configurations remain unchanged.

1. Open a `.py` file and press **Space d b** on an executable line.
2. Press **Space d c** and choose **Python: current file**.
3. Inspect variables with **Space d e**, step with **Space d o / d i / d O**,
   continue with **Space d c**, and stop with **Space d x**.

**Python: unittest (current file)** runs the current standalone unittest module
under the debugger. `console = "integratedTerminal"` supports programs that read
input; use that terminal pane for program input, not the debugger REPL.

The adapter is installed separately at `~/.local/share/nvim/debugpy` (Python 3.12,
debugpy 1.8.22 tested). It does not install packages into your projects or system
Python. To set it up on another machine, use a supported Python:

```sh
python3 -m venv ~/.local/share/nvim/debugpy
~/.local/share/nvim/debugpy/bin/python -m pip install debugpy
```

The program interpreter is selected separately: explicit
`python.interpreter` in `lua/config/debug.lua`, activated `VIRTUAL_ENV`/Conda,
nearest ancestor's `.venv` or `venv`, then `python3`/`python` on PATH. Your
project's environment does **not** need debugpy installed. `python.adapter` in
the same config overrides the adapter executable; a Mason debugpy installation
is also recognized. No Python debugger plugin is required.

Project `.vscode/launch.json` can supply arguments, module/package launches,
custom working directories, or other project-specific settings. Both `python`
and `debugpy` adapter type names are supported. Test/interpreter code lives in
`lua/configs/dap_python.lua` and `tests/dap_python.lua`.

## Themes

Use **`:Theme`** or **Space → t** for the searchable picker. Move the highlighted
row to preview the theme in the editor. Enter opens an **Are you sure?** box;
choose **Yes, save** (or press y) to save it in config across restarts. The box
defaults to No; No/Esc restores the original theme without saving. Esc in the
picker also restores it. Preview is debounced by 120 ms so fast navigation
doesn't load every intermediate palette. With fzf, type to filter; without it,
the owned floating list supports j/k, arrows, and native `/` search.

The picker is half its former height so more of the editor stays visible.
Adjust `height`, `native_rows`, and `preview_delay` in `lua/config/theme_picker.lua`.

```vim
:Theme
:Theme kanagawa-dragon
:Theme! catppuccin-mocha
:ThemeReset
:colorscheme jb
:colorscheme dotted-onedark
```

`:Theme` opens the confirmed, persistent picker. `:Theme NAME` and `:colorscheme
NAME` switch temporarily; `:Theme! NAME` explicitly saves a named theme without
the dialog. `:ThemeReset` forgets the saved choice and restores the baseline.
Native switching supports Tab completion.

Fresh installations include **886 presets**, plus Neovim's built-ins:

- **819 Ghostty palettes**, the complete bundle shipped with Ghostty 1.4.0.
- **11 Zed built-in variants** from Zed 1.26.2 (Ayu, Gruvbox, and One).
- **10 VS Code built-in themes** from VS Code 1.144.0: Dark/Light 2026, Modern,
  +, classic Visual Studio, and high-contrast variants.
- **46 native Neovim presets** across local OneDark, jb, Tokyo Night, Catppuccin,
  Kanagawa, Rosé Pine, Gruvbox, Nightfox, standalone OneDark, Everforest, Nordic,
  GitHub, Dracula, Oxocarbon, and VS Code.

Filter by `ghostty-`, `zed-`, or `vscode-`, or use `:Theme vscode-dark-2026` /
`:Theme vscode-light-modern`. All ten VS Code variants use their real upstream
definitions, including inherited palettes/token rules—not just a renamed Dark+.
The raw palettes and licenses ship in `themes-data/`; the source apps don't need
to be installed. Ghostty's ANSI palette is mapped to Neovim syntax roles. Zed's
and VS Code's editor/syntax colors and font styles are adapted where equivalent
groups exist, including alpha blending. TextMate scope stacks and application
effects don't all have Neovim equivalents; these aren't pixel-identical UI ports.
Source versions, scope, and credits are in [themes-data/README.md](themes-data/README.md).
Zed/VS Code marketplace extension themes are not included.

The default is **dotted-onedark**, a local port of your previously installed
NvChad OneDark palette and highlight definitions—not another OneDark plugin.
The local theme itself needs no download, framework, or cache. Transparency is
enabled globally; use `:TransparencyToggle` to see its original opaque background
(`#1e222a`). Persist that choice with `enabled = false` in `lua/config/transparency.lua`.
Edit `lua/themes/onedark/palette.lua` or the core/syntax/plugin tables to customize
the port. [Provenance and retained licenses](licenses/onedark-NOTICE.md) document
the source version and scope: matching theme colors, not NvChad's UI layout.

For a version-controlled startup default, edit only `lua/config/theme.lua`:

```lua
-- Startup theme; provider options are defined in config/themes.lua.
return {
  colorscheme = "tokyonight-night",
}
```

Confirmed selections override that baseline through the generated
`lua/config/theme_choice.lua` inside your config. Saving replaces that file
atomically without rewriting `theme.lua` or provider options. A failed save
restores the original preview and reports an error. Use `:ThemeReset` to remove
the override. Older `stdpath("state")/theme` choices remain a startup fallback;
the next save replaces that legacy preference, and reset removes both.

**Add a theme by editing only `lua/config/themes.lua`:** add its `plugin` repo,
public setup `module` (omit if none), `schemes` list, and `opts`. Use `name` if
the repository's basename isn't unique. List light variants under `light`.
Restart for lazy.nvim to install the new provider. Edit a provider's `opts` in
that same file to customize its appearance. Remove a provider to exclude it.
Leave provider-specific transparency options off; the shared policy removes
backgrounds after setup, so toggling off can restore the original palette.

Performance: native catalog plugins are downloaded once, but **only the startup
theme's provider runs at startup** (none for local OneDark or the bundled imports).
Other providers run on first preview/selection and are then reused. Bundled
palette contents aren't parsed until previewed/selected, and the parsed cache is
bounded to 16 palettes. Configure import collections/cache size in
`lua/config/theme_imports.lua`. Preview has one timer only while the picker is
open; closing cancels pending work and closes the timer. There is no background
theme polling, update checking, or loading every palette on startup. A generated completion
index in `stdpath("cache")/theme-index` exposes unloaded schemes to native Tab
completion; unchanged catalogs don't rewrite it. It contains forwarding entries,
not compiled highlights. If a provider is missing, use `:Lazy install` first;
switching themes doesn't start an installer.

### Statusline and transparency

The native statusline matches the former default layout: mode badge, angled
file block, git, centered progress, diagnostics/LSP, workspace and cursor blocks.
OneDark keeps its 36 original definitions. Other themes get distinct badge/file/
workspace blocks and matching separator transitions, derived from their palette.
Filled text blocks are contrast-checked (minimum 4.5:1) rather than inheriting
possibly missing or reversed statusline colors. There is no airline/lualine plugin.
Edit `lua/config/statusline.lua` for layout or `lua/ui/statusline.lua` for content.
Nerd Font glyphs require the same font support as the former UI.

`lua/config/transparency.lua` is the single policy for editor, terminal-buffer,
floating-window, and sidebar backgrounds. It applies on every theme change and
after relevant UI plugins load; user highlight overrides still run last.
`:TransparencyToggle` changes the policy for the current session without changing
the selected theme. Statusline badges, completion menus, selections, and search
matches deliberately keep backgrounds so they remain readable.

Actual opacity is controlled by the terminal (your Ghostty config uses 0.90).
Neovim only removes its opaque fills; it doesn't change terminal settings. Light
palettes still need a light terminal background for readable editor text—otherwise
toggle transparency off when using them. This cannot be inferred reliably from
a colorscheme name or fixed by making black syntax text transparent.

New plugin versions still depend on upstream compatibility; this removes the
distribution conflicts, not bugs in third-party plugins.

## Add a plugin

Create `lua/plugins/example.lua`; lazy.nvim discovers it automatically:

```lua
-- Surround text objects; loaded when a buffer is read or created.
return {
  {
    "kylechui/nvim-surround",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
}
```

Use `cmd`, `keys`, `ft`, or `event` when supported; otherwise omit them to load
at startup. Put larger option tables in `lua/configs/<name>.lua`. Existing
Markdown, TeX, CSV, Go, and DAP tools are isolated in `plugins/languages.lua`
and `plugins/debug.lua`; remove those specs if you don't need them.

## Override a highlight

Add entries to `M.groups` in `lua/config/highlights.lua`:

```lua
M.groups = {
  Comment = { italic = true },
  Normal = { bg = "NONE" },
  MyHint = { link = "DiagnosticHint" },
}
```

Partial overrides preserve other theme attributes. They are applied after every
`ColorScheme` event, without loading another theme or resetting unrelated groups.
To test an edit live: `:lua package.loaded["config.highlights"] = nil; require("config.highlights").setup()`.

## Keys and migration notes

Space is leader. `:Keymaps` shows your active keys. `:KeymapPreset vscode` or
`:KeymapPreset jetbrains` switches layouts; persist with `vim.g.keymap_preset`
before keymap setup in `init.lua`, or `NVIM_KEYMAP_PRESET=vscode nvim`.
Edit `lua/keymaps/presets/*.lua` for keys and `lua/keymaps/actions.lua` for actions.
**Space → ch**, `:Cheatsheet`, or the familiar `:NvCheatsheet` toggles the native
grouped cheatsheet: colored sections, responsive columns, and the active preset's
keys for this OS. Use `/` to search, n/N for matches, j/k or Ctrl-f/Ctrl-b to scroll,
and q/Esc to close. It includes NvimTree's tree-only help/split/tab shortcuts.
`:Cheatsheet vscode` previews another preset; `lua/config/cheatsheet.lua` controls
dimensions and columns. No NvChad code or dependency is needed.
`:Keymaps` / Space → ? shows rendered tables for comparing Linux/macOS keys, with
aligned borders, colored headers/keys, and wrapped cells. Its native renderer in
`lua/ui/keymap_preview.lua` works even without Markdown parsers; it does not show
raw Markdown syntax or load unrelated Markdown plugins. Use j/k to scroll, `/` to
search, and q/Esc to close. `:KeymapsWrite` still exports Markdown. The grouped
cheatsheet is a separate view, not a replacement.
Original JSON presets, including pre-existing edits, are preserved outside the
runtime tree in `docs/nvim-legacy-keymaps/`; they are not loaded.

Buffers now use built-in commands (closing a modified buffer refuses to discard
changes). Terminals use owned Lua code. Cheatsheet opens `:Cheatsheet`; rename uses
native LSP. Only OneDark's palette and highlight definitions were vendored.
Removed the old theme/cache
machinery, NvZone utilities, automatic session restoration, and hologram image
viewer. Your runner, Spotlight search, Markdown keys, and OS-specific keys remain.
No data directories, sessions, parsers, or downloaded plugins were deleted.
Space → t is now the direct theme picker, not a prefix. The old deleted-lines
toggle (`Space t d`) moved to `Space g X`. Terminals remain on Space h / Space v
and Alt-h / Alt-v / Alt-i.

LSP diagnostics use the former gutter icons (󰅙 error,  warning, 󰋼 info, 󰌵 hint),
not E/W/H/I letters. Inline messages, underlines, floats, statusline counts, and
git signs remain enabled. Customize `signs.text` in `lua/configs/lspconfig.lua`.

Git gutter uses thicker ┃ bars for added/changed lines, with your original
󰍵 deleted, ‾ top-deleted, 󱕖 changed/deleted, and ┆ untracked symbols and colored line numbers.
Edit `lua/configs/gitsigns.lua` for symbols or `lua/ui/git_colors.lua` for the
palette-derived gutter colors. Explicit `config.highlights` overrides still win.

## Check

Check the local theme without installing any plugins:

```sh
nvim --headless -u NONE -l ~/.config/nvim/tests/onedark.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/statusline.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/bundled.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/preview.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/colors.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/vscode.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/selection.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/confirm.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/git_colors.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/cheatsheet.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/keymap_table.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/keymap_aliases.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/debug_keymaps.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/python_interpreter.lua
nvim --headless -u NONE -l ~/.config/nvim/tests/replace.lua
```

After installing plugins:

```sh
nvim --headless '+luafile ~/.config/nvim/tests/smoke.lua'
```

`tests/themes.lua` additionally tests all catalog schemes, lazy-loading, native
completion, the picker, and saving/resetting defaults. Run it only with an
isolated `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, and `XDG_STATE_HOME`
with `NVIM_TEST_ISOLATED=1`: it deliberately writes/removes config overrides.
`tests/picker_native.lua` and `tests/picker_fzf.lua` exercise the real confirmation
box, cancellation, and persistence in those isolated directories. Start another
process afterward to verify the saved choice loads on restart.
`tests/diagnostics.lua` checks that all four diagnostic gutter icons render.
`tests/gitsigns.lua` renders Git changes in a disposable repository and verifies
the gutter symbols, colored line numbers, and theme switching.
`tests/appearance.lua` checks contrast, separator geometry, and transparency for
every preset, plus transparency toggling and user override precedence.
`tests/tui.lua` and `tests/startup_tui.lua` check dashboard/bufferline safety and
startup with a real attached terminal UI. `tests/replace_project.lua` tests real
cross-file replacements, unsaved-buffer protection, and single-step in-file undo
inside temporary files. `tests/dap_go.lua` performs the real Go debugging checks
described above; it requires Go and Delve on PATH (or the configured Delve path).
`tests/dap_python.lua` uses real debugpy to check file/unittest launches,
breakpoints, variables, stepping, and a separate project venv without debugpy.
Both adapter tests also reopen a manually closed pane while paused and verify
inspection still works. `tests/dap_ui.lua` covers partial layouts, repeated
open/close events, the UI key action, watch persistence, and unsaved-buffer safety.
`tests/workspace.lua` checks ordinal numbers, fast MRU cycling and path menus;
`tests/recent_keymaps.lua` checks recent-file keys in every preset/platform/mode,
and `tests/recent_terminal.lua` sends encoded Option-Tab/Shift bytes on macOS
through a real Neovim terminal session, including reverse cycling and unchanged plain Tab.
`tests/recent_release.lua` checks the native flags API and uses controlled modifier
state to test hold/release, cancellation and cleanup; it does not synthesize a
physical Option release.
`tests/tools.lua` checks real shells/tasks/diagnostics, rapid tab switching,
and unsaved-window safety. `tests/git_graph.lua` creates a disposable branched
repository and checks graph/commit views without changing HEAD or dirty files.
`tests/tools_layout.lua` checks persistent window/header IDs, full-height
NvimTree compatibility and editor-targeted diagnostic jumps.
`tests/breadcrumbs.lua` checks root boundaries for cwd and directory-argument
projects inside larger repositories, titleless menus and keyboard navigation.
`tests/menu.lua` checks caret hiding, selection styling and restoration after
close, replacement, leaving the menu, buffer deletion and theme changes.
`tests/explorer_selection.lua` checks real tree reveal/following, persistent
active-file and hover row rendering, keyboard selection, the follow toggle,
cursor restoration, menus/search, themes/transparency and closing/reopening.
`tests/tree_search.lua` checks Enter/click opening, unsaved editor text, file and
folder icons/colors, theme changes, hover, folder expansion and empty results.
`tests/picker_selection.lua` checks breadcrumb color inheritance, unchanged
file/grep/theme/tool-menu styling and dark/light theme changes without eager loading.
`tests/finder_colors.lua` compares breadcrumb colors against real fzf terminal
selection output, rather than relying on similarly named highlight groups.
`tests/workspace_tui.lua` attaches a real Neovim UI and checks click-anchored
breadcrumb geometry, repeated mouse tab changes beside NvimTree, absence of
stale terminal paint, keyboard navigation, recent-file keys and small-screen resizing. Run these in isolated
XDG directories with `NVIM_TEST_ISOLATED=1`, just like the theme/UI tests.
`tests/hover_controls.lua` tests real mouse motion over tab captions/numbers,
close buttons, tabpages, every tool action and compact header, dashboard,
diagnostic rows, themes and confirmations; it checks that hover never executes
actions, and that actual clicks still target the right controls.
`tests/output_runner.lua` verifies actual Python/Go runs, quoted paths,
stdout/stderr and explicit task stopping. Run the suite reproducibly after
installing the pinned plugins:

```sh
python3 ~/.config/nvim/tests/run.py --fixture /path/to/dedicated/nvim-test-scratch --full
```

The runner copies the config and installed plugins into that dedicated fixture;
it never points test state/config writes at your live XDG directories. Existing
fixture plugins are reused, not updated. Optional trailing test filenames run a
subset, e.g. `workspace_tui.lua tools.lua`.

Checks Lua syntax, distribution-free specs, theme switching/overrides, presets,
plugin setup, LSP definitions, and reusable split/floating terminals. It exits
nonzero on failure. Interactive checks: `:checkhealth lazy`, `:checkhealth vim.lsp`,
`:ConformInfo`, and `:checkhealth nvim-treesitter`.
