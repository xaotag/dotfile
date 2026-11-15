# WezTerm

Cross-platform [WezTerm](https://wezfurlong.org/wezterm/) configuration.

Translated from the `kitty/` configuration in this repository, adapted to WezTerm's
configuration model.

## Install

Copy `wezterm.lua` to one of these locations:

| Platform | Path |
| --- | --- |
| All | `~/.wezterm.lua` |
| Linux / macOS | `~/.config/wezterm/wezterm.lua` |
| Windows | `%USERPROFILE%\.wezterm.lua` |

Symlink instead of copying to keep it in sync with this repository:

```sh
ln -sf "$PWD/wezterm/wezterm.lua" ~/.wezterm.lua
```

## Dependencies

### Font

The configuration expects **Maple Mono NF** (Nerd Font variant, with Chinese glyphs
for CJK environments):

- [Maple Mono releases](https://github.com/subframe7536/maple-font/releases)
- Recommended asset: `MapleMono-NF-CN-unhinted.zip` (includes CJK and Nerd Font icons)

The family name differs by package:

| Asset | Family name |
| --- | --- |
| `MapleMono-NF-CN.zip` | `Maple Mono NF CN` |
| `MapleMono-NF.zip` | `Maple Mono NF` |

The configuration lists `CN` first, then falls back to the plain variant.

Font features enabled: `ss04 ss05 ss06 cv35 cv61 zero` — Maple stylistic sets and
a slashed zero.

### Optional

- `Symbols Nerd Font` — icon fallback when the primary font lacks a glyph

## Platform differences

Windows-only settings are guarded by `wezterm.target_triple`, so the same file works
everywhere.

| Setting | Scope |
| --- | --- |
| `default_prog` → Git Bash | Windows |
| `default_prog` → `/bin/zsh -l` | macOS |
| `default_prog` | unset on Linux (uses `$SHELL`) |
| `webgpu_power_preference` | Windows |
| `webgpu_force_fallback_adapter` | Windows |
| `macos_window_background_blur` | macOS |

## Correspondence with kitty.conf

| kitty | WezTerm | Notes |
| --- | --- | --- |
| `font_family` / `bold_font` / `italic_font` / `bold_italic_font` | `font` + `font_with_fallback` | WezTerm matches weights automatically |
| `font_features +ss04 +ss05 +zero ...` | `harfbuzz_features` | per-font entry |
| `font_size 18` | `font_size = 12.0` | kitty uses pixels, WezTerm uses points |
| `modify_font underline_position 1` | `underline_position` | |
| `underline_exclusion 1` | — | no equivalent |
| `cursor_blink_interval 0` | `cursor_blink_rate = 0` | |
| `cursor_trail` / `cursor_trail_decay` / `cursor_trail_start_threshold` | — | kitty-only animation |
| `background_opacity 0.95` | `window_background_opacity` | |
| `detect_urls yes` | `hyperlink_rules` | |
| `mouse_hide_wait 5` | — | no equivalent |
| `disable_ligatures cursor` | — | WezTerm only supports a global toggle |
| `enable_csi_u_key_encoding yes` | `enable_csi_u_key_encoding` | |
| `paste_actions quote-urls-at-prompt,confirm` | — | no equivalent |

## Beyond the kitty config

Additional settings in this configuration:

- **WebGpu front end** — faster glyph cache and multi-pane redraw than OpenGL
- **Kitty graphics protocol** — inline images via `wezterm imgcat`
- **Kitty keyboard protocol** — proper `Shift+Enter` / `Alt+Enter` handling
- **Pane and tab management keybindings**

## Images

```sh
wezterm imgcat image.png
wezterm imgcat --width 60% photo.jpg
wezterm imgcat --width 400px --height 300px --position 5,10 pic.png
cat logo.png | wezterm imgcat
```

Supported formats: PNG, JPEG, GIF, WebP, BMP, TIFF, ICO. Animated GIF and WebP loop.
Images are rendered as overlays — they do not occupy character cells and do not scroll
with the buffer.

## Keybindings

| Key | Action |
| --- | --- |
| `Ctrl+Shift+C` / `Ctrl+Shift+V` | Copy / paste (`Ctrl+C` still interrupts) |
| `Ctrl+Shift+T` / `Ctrl+Shift+W` | New / close tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Ctrl+Shift+%` / `Ctrl+Shift+"` | Split right / down |
| `Ctrl+Shift+hjkl` | Move focus between panes |
| `Ctrl+Shift+Z` | Toggle pane zoom |
| `Ctrl+Shift+Enter` | Toggle fullscreen |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | Font size up / down / reset |
| `Alt+Enter` | Send `ESC [13;3u` (follow-up submit in some agent CLIs) |
| Right click | Paste |
| `Ctrl+click` | Open link |

## Fallbacks

**Rendering artifacts or crashes** — switch the front end:

```lua
config.front_end = 'OpenGL'
```

**Font not found** — check what WezTerm resolves:

```sh
wezterm ls-fonts
```

**Markdown rendering** — WezTerm has no built-in renderer. Use an external one, for
example `glow` or `mdcat`, piped through the terminal.
