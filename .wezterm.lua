
-- Мы вытаскиваем библиотеку wezterm в локальную переменную для удобства
local wezterm = require 'wezterm'
local act = wezterm.action

local function get_random_image()
  local images_dir = "Z:\\dev\\myself\\dotfiles\\img"
  
  local success, files = pcall(wezterm.glob, images_dir .. "\\*.{jpg,jpeg,png}")
  
  if not success or not files or #files == 0 then
    return nil
  end
  
  math.randomseed(os.time())
  return files[math.random(#files)]
end

-- Это таблица конфигурации
local config = {}

-- В последней версии WezTerm рекомендуется использовать config.resolve_errors
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- --- НАСТРОЙКИ ИЗ ALACRITTY ---

-- 1. Шрифт
config.font = wezterm.font('SauceCodePro Nerd Font', { weight = 'Regular', italic = false })
-- config.font = wezterm.font('JetBrains Mono', { weight = 'Regular', italic = false })
config.font_size = 14.0

-- 2. Рабочая директория
-- Мы используем Lua функцию для получения домашней папки, аналог %USERPROFILE%
local home_dir = wezterm.home_dir
local is_windows = wezterm.target_triple:find('windows') ~= nil

if is_windows then
  config.default_cwd = home_dir .. '\\dev'
else
  config.default_cwd = home_dir .. '/dev'
end

-- 3. Оболочка (Shell) - Cygwin Zsh (только Windows)
-- Мы используем prepend_args, чтобы передать флаги запуска
-- config.default_domain = 'Default' -- Это важно для  /Windows

if is_windows then
  config.default_prog = { 'C:\\cygwin64\\bin\\zsh.exe', '-l', '-i' }

  -- 4. Переменные окружения
  config.set_environment_variables = {
    -- Аналог TERM = "xterm-256color"
    TERM = 'xterm-256color',

    -- Переменная Cygwin, чтобы не менялась директория при запуске
    CHERE_INVOKING = '1',
    SHELL = 'C:\\cygwin64\\bin\\zsh.exe',
  }
end
 -- Цветовая схема (опционально, чтобы было не так скучно)
 config.color_scheme = 'Tokyo Night'

config.window_background_opacity = 0.85
config.text_background_opacity = 0.85
config.win32_system_backdrop = "Acrylic"

local bg_image = get_random_image()
if bg_image then
  config.background = {
    {
      source = { File = bg_image },
      hsb = { brightness = 0.2 },
      repeat_x = "NoRepeat",
      repeat_y = "NoRepeat",
      vertical_align = "Bottom",
      horizontal_align = "Center",
      opacity = 1,
    },
  }
end

local function change_background(window, pane)
  local new_image = get_random_image()
  if new_image then
    local overrides = window:get_config_overrides() or {}
    overrides.background = {
      {
        source = { File = new_image },
        hsb = { brightness = 0.2 },
        repeat_x = "NoRepeat",
        repeat_y = "NoRepeat",
        vertical_align = "Bottom",
        horizontal_align = "Center",
        opacity = 1,
      },
    }
    window:set_config_overrides(overrides)
  end
end

config.keys = {
  {key = '-', mods = 'ALT', action = act.SplitHorizontal{ domain = 'CurrentPaneDomain'}},
  {key = '=', mods = 'ALT', action = act.SplitVertical{ domain = 'CurrentPaneDomain'}},
  { key = 'a', mods = 'ALT', action = act.CloseCurrentPane { confirm = false } },
  { key = 'q', mods = 'CTRL', action = wezterm.action_callback(change_background) },
-- config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
-- config.keys = {
--   -- Разделить окно по вертикали (Ctrl+A затем | )
--   { key = '|', mods = 'LEADER|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
--
--   -- Разделить окно по горизонтали (Ctrl+A затем - )
--   { key = '-', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
--
  -- Переключение между панелями (Ctrl+A затем стрелка)
  { key = 'LeftArrow', mods = 'CTRL', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'CTRL', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'CTRL', action = wezterm.action.ActivatePaneDirection 'Down' },
--
--   -- Закрыть текущую панель (Ctrl+A затем w)
--   { key = 'w', mods = 'LEADER', action = wezterm.action.CloseCurrentPane { confirm = true } },
--
--   -- Новая вкладка (Ctrl+A затем t)
--   { key = 't', mods = 'LEADER', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
}
return config
