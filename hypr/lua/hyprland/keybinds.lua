local main_mod = "SUPER"
local scripts = os.getenv("HOME") .. "/.config/hypr/hyprland/scripts"

-- Apps & Launcher
hl.bind(main_mod .. " + space", hl.dsp.exec_cmd("pkill fuzzel || fuzzel"))
hl.bind(main_mod .. " + X", hl.dsp.exec_cmd("flatpak run com.vscodium.codium"))
hl.bind(main_mod .. " + Return", hl.dsp.exec_cmd(scripts .. "/launch_first_available.sh 'kitty -1' 'foot' 'alacritty'"))
hl.bind(main_mod .. " + T", hl.dsp.exec_cmd(scripts .. "/launch_first_available.sh 'kitty -1' 'foot' 'alacritty'"))
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(main_mod .. " + W", hl.dsp.exec_cmd("flatpak run io.gitlab.librewolf-community"))
hl.bind(main_mod .. " + O", hl.dsp.exec_cmd("flatpak run md.obsidian.Obsidian --ozone-platform=x11"))
hl.bind("CTRL + " .. main_mod .. " + V", hl.dsp.exec_cmd(scripts .. "/launch_first_available.sh 'pavucontrol'"))

-- Brightness & Volume (Locked & Repeating)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scripts .. "/brightness.sh --inc"), { locked = true, repeating = true })
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd(scripts .. "/brightness.sh --dec"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scripts .. "/volume_control.sh --toggle"), { locked = true })
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(scripts .. "/volume_control.sh --inc"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(scripts .. "/volume_control.sh --dec"),
	{ locked = true, repeating = true }
)
hl.bind(main_mod .. " + SHIFT + M", hl.dsp.exec_cmd(scripts .. "/volume_control.sh --toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "/volume_control.sh --toggle"), { locked = true })

-- Utilities & Screenshots
hl.bind(
	main_mod .. " + V",
	hl.dsp.exec_cmd("pkill fuzzel || cliphist list | fuzzel --dmenu | cliphist decode | wl-copy")
)
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind(main_mod .. " + SHIFT + A", hl.dsp.exec_cmd("hyprpicker --autocopy"))
hl.bind(main_mod .. " + A", hl.dsp.exec_cmd(scripts .. "/audio_output_switch.sh"))
hl.bind(main_mod .. " + SHIFT + D", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(main_mod .. " + PERIOD", hl.dsp.exec_cmd(scripts .. "/fuzzel-emoji.sh copy"))

-- Window Management
hl.bind(main_mod .. " + Q", hl.dsp.window.close())
hl.bind(main_mod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(main_mod .. " + Right", hl.dsp.focus({ direction = "r" }))
hl.bind(main_mod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(main_mod .. " + Down", hl.dsp.focus({ direction = "d" }))
hl.bind(main_mod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(main_mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(main_mod .. " + ALT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))
hl.bind(main_mod .. " + D", hl.dsp.window.fullscreen({ mode = 1 }))

-- Workspaces (Numerical)
for i = 1, 9 do
	hl.bind(main_mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
end
for i = 1, 9 do
	hl.bind(main_mod .. " + ALT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(main_mod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Workspace Navigation
hl.bind("CTRL + " .. main_mod .. " + Right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + " .. main_mod .. " + Left", hl.dsp.focus({ workspace = "r-1" }))

-- Scroll Workspaces
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "r+1" }))

-- Mouse Window Drag/Resize
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Special Workspace
hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Session & Media
hl.bind(main_mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
