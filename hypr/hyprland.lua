-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- A new Chromium/Helium window belongs to the workspace where that browser
-- already runs, not to whichever workspace happens to be focused.
hl.on("window.open", function(window)
  local class = (window.class or ""):lower()
  if class ~= "chromium" and class ~= "helium" then
    return
  end

  local target
  for _, other in ipairs(hl.get_windows()) do
    if other.address ~= window.address and (other.class or ""):lower() == class and other.workspace then
      target = other.workspace.id
      break
    end
  end

  if target and window.workspace and window.workspace.id ~= target then
    hl.dispatch(hl.dsp.window.move({
      workspace = tostring(target),
      follow = false,
      window = "address:" .. window.address,
    }))
  end
end)
