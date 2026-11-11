# Bundled theme data

These are unmodified upstream data files, not Neovim configuration or plugins.
They ship with this tree and work without Ghostty, Zed, or extra downloads.

- `ghostty/`: all **819** palettes shipped by **Ghostty v1.4.0**. Its pinned
  `build.zig.zon` uses iTerm2-Color-Schemes release
  `release-20261019-151001-86a776d`.
  [Source archive](https://github.com/mbadolato/iTerm2-Color-Schemes/releases/download/release-20261019-151001-86a776d/ghostty-themes.tgz)
  SHA256: `ab2513e316372c45c9f86e3e511aebdbfa6c39fa03c210096b19152fe288505b`.
- `zed/`: all **11 built-in variants** from
  [Zed v1.26.2 assets/themes](https://github.com/zed-industries/zed/tree/v1.26.2/assets/themes),
  across Ayu, Gruvbox, and One. Each family's original MIT license is retained.
  Zed extension/marketplace themes are not included.
- `vscode/`: all **10 bundled themes** from
  [VS Code 1.144.0](https://github.com/microsoft/vscode/tree/1.144.0/extensions/theme-defaults/themes),
  including the real Dark/Light 2026 definitions and complete include chains.
  The original Microsoft MIT license is retained. ANSI fallbacks are from the
  same version's
  [terminalColorRegistry.ts](https://github.com/microsoft/vscode/blob/1.144.0/src/vs/workbench/contrib/terminal/common/terminalColorRegistry.ts).
  VS Code marketplace themes are not included.
- `notices/`: original Ghostty collection license and complete upstream theme
  credits. Individual themes retain their authors' copyrights/licenses.

`lua/themes/bundled_catalog.lua` indexes names without reading palette contents.
`lua/themes/bundled.lua` is the owned renderer; it parses only selected themes
and keeps at most 16 parsed palettes. Its ANSI-to-syntax mapping for Ghostty is
an adaptation: terminal palettes don't define editor syntax colors. Zed's syntax
colors and font styles are mapped where Neovim has corresponding groups; alpha
colors are blended over the editor background. `lua/themes/vscode.lua` resolves
VS Code's JSONC includes and maps token rules by specificity/order to supported
Neovim roles. TextMate scope-stack selectors aren't applied indiscriminately to
unrelated tokens; unsupported grammar contexts are not claimed as exact matches.
Grammar captures, fonts, layouts,
and application-specific effects differ, so these are not pixel-identical ports.

Use `ghostty-<name>`, `zed-<name>`, and `vscode-<name>` IDs in `:Theme` or
`:colorscheme`. Name collisions are disambiguated with a short hash. Source
backgrounds are preserved in the data; the editor's visibility follows the shared
policy in `lua/config/transparency.lua`. Import settings are in
`lua/config/theme_imports.lua`.

Updates should be deliberate: replace data from a pinned release, retain its
licenses/credits, update this notice and variant metadata, and run the theme tests.
Nothing downloads or silently updates this bundle at startup.
