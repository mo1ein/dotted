-- Theme-picker dimensions only; other fzf windows keep their existing size.
return {
  height = 0.425, -- half the previous 0.85 screen-height fraction
  native_rows = 10, -- half the previous native list's 20 rows
  native_width = 64,
  preview_delay = 120,
}
