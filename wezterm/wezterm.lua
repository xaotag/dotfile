-- WezTerm 配置 (跨平台)
-- 源: https://github.com/xaotag/dotfile/blob/main/kitty/kitty.conf 的等价翻译
-- 放置: ~/.wezterm.lua  或  ~/.config/wezterm/wezterm.lua
--
-- 平台差异通过 wezterm.target_triple 判断, Windows 特有项做了条件隔离

local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find 'windows' ~= nil
local is_macos = wezterm.target_triple:find 'darwin' ~= nil
local home = os.getenv 'HOME' or os.getenv 'USERPROFILE' or ''

------------------------------------------------------------
-- 字体
------------------------------------------------------------
-- 原 kitty.conf: font_family Maple Mono NF Regular (+ Bold/Italic/BoldItalic)
-- WezTerm 按 weight/style 自动匹配四档字重, 无需分别声明
--
-- 注意: 家族名随安装包不同而异
--   MapleMono-NF-CN.zip      -> "Maple Mono NF CN"   (含中文, 推荐中文环境)
--   MapleMono-NF.zip         -> "Maple Mono NF"
-- 按实际安装的填第一个, 其余作为回退
local HARFBUZZ = { 'ss04', 'ss05', 'zero', 'ss06', 'cv35', 'ss08', 'cv61' }

config.font = wezterm.font_with_fallback {
  { family = 'Maple Mono NF CN', weight = 'Regular', harfbuzz_features = HARFBUZZ },
  { family = 'Maple Mono NF', weight = 'Regular', harfbuzz_features = HARFBUZZ },
  'Symbols Nerd Font Mono',
  'Symbols Nerd Font',
  -- 中文字体回退 (各平台首个命中的生效)
  'Noto Sans Mono CJK SC',
  'Sarasa Mono SC',
  'Microsoft YaHei UI',
  'PingFang SC',
  'WenQuanYi Micro Hei',
}

-- 原配置 font_size 18 (kitty 以 pixel 计, WezTerm 以 point 计)
-- 如需按屏幕密度微调, 用 Ctrl+= / Ctrl+- 后把值写回此处
config.font_size = 12.0

-- 原配置 modify_font underline_position 1
config.underline_position = 1
config.underline_thickness = '1px'

------------------------------------------------------------
-- 光标
------------------------------------------------------------
-- 原配置 cursor_blink_interval 0 (= 不闪烁)
config.default_cursor_style = 'SteadyBlock'
config.cursor_blink_rate = 0
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'

-- 原配置的 cursor_trail 系列为 kitty 独有特效, WezTerm 无对应实现

------------------------------------------------------------
-- 窗口
------------------------------------------------------------
-- 原配置 background_opacity 0.95
config.window_background_opacity = 0.95

-- 保留标准标题栏 (最小化/最大化/关闭)
config.window_decorations = 'TITLE | RESIZE'

config.initial_cols = 120
config.initial_rows = 34
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.color_scheme = 'Tokyo Night Storm'

-- 内边距与装饰的细调 (仅 macOS 生效, 其他平台忽略)
if is_macos then
  config.window_decorations = 'RESIZE | TITLE'
  config.macos_window_background_blur = 20
end

------------------------------------------------------------
-- 渲染后端
------------------------------------------------------------
-- WebGpu 基于 wgpu, 走 Vulkan / Metal / DX12, 字形缓存与多 pane 重绘优于 OpenGL
-- 若驱动异常或出现花屏, 改为 'OpenGL'
config.front_end = 'WebGpu'
config.max_fps = 120
config.animation_fps = 60

-- Windows 专用: WebGpu 电源偏好
if is_windows then
  config.webgpu_power_preference = 'HighPerformance'
  config.webgpu_force_fallback_adapter = false
end

-- 视觉提示音 (代替系统 beep)
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_function = 'EaseIn',
  fade_in_duration_ms = 150,
  fade_out_function = 'EaseOut',
  fade_out_duration_ms = 350,
}

------------------------------------------------------------
-- 图片显示 (Kitty Graphics Protocol)
------------------------------------------------------------
-- 支持 PNG / JPEG / GIF / WebP / BMP / TIFF / ICO, 动图会循环播放
-- 用法:
--   wezterm imgcat image.png
--   wezterm imgcat --width 60% photo.jpg
--   wezterm imgcat --width 400px --height 300px --position 5,10 pic.png
--   cat logo.png | wezterm imgcat
config.enable_kitty_graphics = true
config.term = 'wezterm'

------------------------------------------------------------
-- 交互
------------------------------------------------------------
-- 原配置 detect_urls yes
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- 原配置 mouse_hide_wait 无对应项; 保留默认选区与滚动行为

------------------------------------------------------------
-- 键盘协议
------------------------------------------------------------
-- 原配置 enable_csi_u_key_encoding yes
config.enable_csi_u_key_encoding = true
-- Kitty 键盘协议: 用于区分 Shift+Enter / Alt+Enter 等修饰组合
config.enable_kitty_keyboard = true

------------------------------------------------------------
-- 滚动
------------------------------------------------------------
config.scrollback_lines = 10000
config.enable_scroll_bar = false
config.alternate_buffer_wheel_scroll_speed = 3
config.mouse_wheel_scrolls_tabs = false

------------------------------------------------------------
-- 按键绑定
------------------------------------------------------------
config.keys = {
  -- Alt+Enter: 提交追加消息 (pi / 部分 agent CLI)
  { key = 'Enter', mods = 'ALT', action = act.SendString '\x1b[13;3u' },

  -- 复制粘贴: 用 Ctrl+Shift+C/V, 保留 Ctrl+C 中断
  { key = 'C', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },

  -- 标签页
  { key = 'T', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'W', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },

  -- 窗格
  { key = '"', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '%', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'h', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'l', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'j', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  { key = 'Z', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },

  -- 全屏
  { key = 'Enter', mods = 'CTRL|SHIFT', action = act.ToggleFullScreen },

  -- 字号
  { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = act.ResetFontSize },

  -- 命令面板
  { key = 'P', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
}

config.mouse_bindings = {
  -- 右键粘贴
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
  -- Ctrl+点击 打开链接
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor,
  },
}

------------------------------------------------------------
-- Shell
------------------------------------------------------------
-- 各平台的默认交互 shell
-- 通过 macOS 的 cask 或 Linux 发行版安装时通常无需设置
if is_windows then
  -- Git Bash: 带 -l 读取 ~/.bash_profile, -i 保证交互
  config.default_prog = { 'C:/Program Files/Git/bin/bash.exe', '-li' }
elseif is_macos then
  config.default_prog = { '/bin/zsh', '-l' }
end
-- Linux: 留空, 使用 $SHELL

------------------------------------------------------------
-- 标签栏与窗口框架
------------------------------------------------------------
config.window_frame = {
  font = wezterm.font { family = 'Maple Mono NF CN', weight = 'Regular' },
  font_size = 10.0,
}

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true
config.tab_max_width = 32

------------------------------------------------------------
-- 杂项
------------------------------------------------------------
config.check_for_updates = false
config.automatically_reload_config = true

return config
