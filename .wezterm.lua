
-- Мы вытаскиваем библиотеку wezterm в локальную переменную для удобства
local wezterm = require 'wezterm'
local act = wezterm.action

local function get_random_image()
  local images_dir = "Z:\\dev\\myself\\dotfiles\\img"
  local images = {}
  
  for file in io.popen('dir "' .. images_dir .. '" /b'):lines() do
    table.insert(images, images_dir .. "\\" .. file)
  end
  
  if #images == 0 then
    return nil
  end
  
  math.randomseed(os.time())
  return images[math.random(#images)]
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
config.background = {
  {
    source = { File = get_random_image() },
    hsb = { brightness = 0.2 },
    repeat_x = "NoRepeat",
    repeat_y = "NoRepeat",
    vertical_align = "Bottom",
    horizontal_align = "Center",
    opacity = 1,
  },
}

config.keys = {
  {key = '-', mods = 'ALT', action = act.SplitHorizontal{ domain = 'CurrentPaneDomain'}},
{key = '=', mods = 'ALT', action = act.SplitVertical{ domain = 'CurrentPaneDomain'}},
{ key = 'a', mods = 'ALT', action = act.CloseCurrentPane { confirm = false } },
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
