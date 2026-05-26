local main_mod = "SUPER"
local scripts = os.getenv("HOME") .. "/.config/hypr/hyprland/scripts"

-- apps
hl.bind(main_mod .. " + space", hl.dsp.exec_cmd("pkill fuzzel || fuzzel"))
hl.bind(main_mod .. " + X", hl.dsp.exec_cmd("flatpak run com.vscodium.codium"))
hl.bind(
	main_mod .. " + Return",
	hl.dsp.exec_cmd(scripts .. "/launch_first_available.sh 'kitty -1' 'foot' 'alacritty' 'wezterm' 'konsole'")
)
hl.bind(
	main_mod .. " + T",
	hl.dsp.exec_cmd(scripts .. "/launch_first_available.sh 'kitty -1' 'foot' 'alacritty' 'wezterm' 'konsole'")
)
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(main_mod .. " + W", hl.dsp.exec_cmd("flatpak run io.gitlab.librewolf-community"))
hl.bind(main_mod .. " + O", hl.dsp.exec_cmd("flatpak run md.obsidian.Obsidian --ozone-platform=x11"))
hl.bind(
	"CTRL + " .. main_mod .. " + V",
	hl.dsp.exec_cmd(scripts .. "/launch_first_available.sh 'pavucontrol-qt' 'pavucontrol'")
)
hl.bind(main_mod .. " + M", hl.dsp.exec_cmd("pkill fuzzel || " .. scripts .. "/fuzzel-sysmenu.sh"))

-- brightness & volume
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
hl.bind(main_mod .. " + ALT + M", hl.dsp.exec_cmd(scripts .. "/volume_control.sh --toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "/volume_control.sh --toggle"), { locked = true })

-- utilities
hl.bind(
	main_mod .. " + V",
	hl.dsp.exec_cmd("pkill fuzzel || cliphist list | fuzzel --dmenu | cliphist decode | wl-copy")
)
hl.bind(main_mod .. " + PERIOD", hl.dsp.exec_cmd("pkill fuzzel || " .. scripts .. "/fuzzel-emoji.sh copy"))
hl.bind(main_mod .. " + A", hl.dsp.exec_cmd(scripts .. "/audio_output_switch.sh"))
hl.bind(main_mod .. " + SHIFT + A", hl.dsp.exec_cmd("hyprpicker --autocopy"))
hl.bind(main_mod .. " + SHIFT + D", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only --freeze"))
hl.bind(
	main_mod .. " + SHIFT + E",
	hl.dsp.exec_cmd(
		"hyprshot -m region --freeze --filename \"$(date '+%Y-%m-%d_%H.%M.%S').png\" --output-folder ~/Pictures/hyprshot --postcommand "
			.. scripts
			.. "/screenshot_edit.sh"
	)
)
hl.bind(
	"Print",
	hl.dsp.exec_cmd(
		"hyprshot --filename \"$(date '+%Y-%m-%d_%H.%M.%S').png\" --freeze --output-folder ~/Pictures/hyprshot"
	),
	{ locked = true }
)
hl.bind(
	"CTRL + Print",
	hl.dsp.exec_cmd(
		"mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
	),
	{ locked = true }
)

-- window
hl.bind(main_mod .. " + Q", hl.dsp.window.close())
hl.bind(main_mod .. " + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(main_mod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(main_mod .. " + Right", hl.dsp.focus({ direction = "r" }))
hl.bind(main_mod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(main_mod .. " + Down", hl.dsp.focus({ direction = "d" }))
hl.bind(main_mod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(main_mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(main_mod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(main_mod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))
hl.bind(main_mod .. " + ALT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))
hl.bind(main_mod .. " + D", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(main_mod .. " + P", hl.dsp.exec_cmd("hyprctl dispatch pin"))
hl.bind(main_mod .. " + Semicolon", hl.dsp.exec_cmd("hyprctl dispatch splitratio -0.1"), { repeating = true })
hl.bind(main_mod .. " + Apostrophe", hl.dsp.exec_cmd("hyprctl dispatch splitratio +0.1"), { repeating = true })
hl.bind(main_mod .. " + Minus", hl.dsp.exec_cmd(scripts .. "/zoom.sh decrease 0.1"), { repeating = true })
hl.bind(main_mod .. " + Equal", hl.dsp.exec_cmd(scripts .. "/zoom.sh increase 0.1"), { repeating = true })
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- workspaces
for i = 1, 9 do
	hl.bind(main_mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(main_mod .. " + ALT + " .. i, hl.dsp.window.move({ workspace = i, silent = true }))
end
hl.bind(main_mod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(main_mod .. " + ALT + 0", hl.dsp.window.move({ workspace = 10, silent = true }))
hl.bind("CTRL + " .. main_mod .. " + Right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + " .. main_mod .. " + Left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(main_mod .. " + Page_Down", hl.dsp.focus({ workspace = "+1" }))
hl.bind(main_mod .. " + Page_Up", hl.dsp.focus({ workspace = "-1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "+1" }))
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "-1" }))
hl.bind(main_mod .. " + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(main_mod .. " + SHIFT + mouse_up", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(main_mod .. " + ALT + S", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent special:magic"))

-- session & media
hl.bind(main_mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(main_mod .. " + SHIFT + L", hl.dsp.exec_cmd("sleep 0.1 && systemctl suspend || loginctl suspend"))
hl.bind("CTRL + SHIFT + ALT + " .. main_mod .. " + Delete", hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"))
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind(main_mod .. " + SHIFT + N", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind(main_mod .. " + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
