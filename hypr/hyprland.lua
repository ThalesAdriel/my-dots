require("hyprland.env")
require("hyprland.general")
-- The layout saved in qsbar's display settings, after general.lua so its rules win for the outputs it names; not there until the first save.
pcall(require, "hyprland.monitors")
require("hyprland.colors")
require("hyprland.rules")
require("hyprland.keybinds")
require("hyprland.execs")
