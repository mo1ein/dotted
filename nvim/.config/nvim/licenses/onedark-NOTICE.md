# Local OneDark provenance

`colors/dotted-onedark.lua` and `lua/themes/onedark/` are a self-contained port
of the OneDark palette and relevant highlight definitions from
[NvChad/base46](https://github.com/NvChad/base46/tree/267954c8663607823f03a3259bb8deb15688212f),
commit `267954c8663607823f03a3259bb8deb15688212f` (the previously installed version).
The palette's original credit is https://github.com/one-dark.

Source files under `lua/base46/`:

- `themes/onedark.lua`: UI and Base16 palettes.
- `integrations/{defaults,syntax,treesitter,lsp,cmp,git,nvimtree,blankline,mason,whichkey,devicons}.lua`.
- `glassy.lua`: transparency changes for those integrations.
- `term.lua`: terminal palette ordering.
- `integrations/statusline/default.lua`: 36 default statusline color definitions,
  with highlight names renamed to `DottedSt_*`.
- `colors.lua`: derived shades resolved once into color literals.

Port changes: split core/syntax/plugin tables, local palette references, resolve
the default completion style, retain transparent/opaque behavior, and remove
dashboard groups for the removed framework UI. No cache/compiler, theme registry,
configuration globals, autocommands, or upstream modules are needed at runtime.
The loader and theme-selection integration are owned by this configuration.

The 325 editor/plugin and 36 statusline highlight definitions were compared attribute-for-attribute
against upstream in both modes. Fingerprints in `tests/onedark.lua` let the port
be checked without installing or accessing upstream. Terminal colors are also
tested. The native renderer in `lua/ui/statusline.lua` is an owned implementation
of the former default statusline layout, not vendored NvChad UI/GPL renderer code.
This does not recreate the old distribution's other widgets, window layout,
or unintended mixture of jb highlights and OneDark caches.

Original MIT notices from `LICENSE`, `base16-LICENSE`, and `colors.lua` follow in
`onedark-LICENSE.txt`.
