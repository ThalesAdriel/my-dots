local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/hyprland/scripts"
local qsbar = "qs ipc -p " .. home .. "/.config/qsbar/shell.qml call"
local terminals = "'kitty -1' 'foot' 'alacritty' 'wezterm' 'konsole'"
local shots = home .. "/Pictures/Screenshots"
local stamp = "\"$(date '+%Y-%m-%d_%H.%M.%S').png\""

local locked = { locked = true }
local locked_repeat = { locked = true, repeating = true }
local repeating = { repeating = true }
local mouse = { mouse = true }

local function super(combo)
	return "SUPER + " .. combo
end

local function run(command)
	return hl.dsp.exec_cmd(command)
end

local function script_path(name, args)
	return scripts .. "/" .. name .. (args and " " .. args or "")
end

local function script(name, args)
	return run(script_path(name, args))
end

local function launcher(command)
	return run("pkill fuzzel || " .. command)
end

local function menu(name, args)
	return launcher(script_path(name, args))
end

local function power(action)
	return script("power.sh", action)
end

local function shot(mode, extra)
	return run(
		"mkdir -p "
			.. shots
			.. " && hyprshot -m "
			.. mode
			.. " --freeze --filename "
			.. stamp
			.. " --output-folder "
			.. shots
			.. (extra or "")
	)
end

local function zoom(step)
	return function()
		local factor = hl.get_config("cursor:zoom_factor") or 1
		hl.config({ cursor = { zoom_factor = math.max(1, math.min(3, factor + step)) } })
	end
end

hl.bind(super("space"), launcher("fuzzel"))
hl.bind(super("Return"), script("launch_first_available.sh", terminals))
hl.bind(super("T"), script("launch_first_available.sh", terminals))
hl.bind(super("E"), run("nautilus"))
hl.bind(super("W"), run("flatpak run io.gitlab.librewolf-community"))
hl.bind(super("X"), run("flatpak run com.vscodium.codium"))
hl.bind(super("O"), run("flatpak run md.obsidian.Obsidian --ozone-platform=x11"))
hl.bind(super("M"), menu("fuzzel-sysmenu.sh"))
hl.bind(super("CTRL + V"), script("launch_first_available.sh", "'pavucontrol-qt' 'pavucontrol'"))

hl.bind(super("V"), launcher("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
hl.bind(super("PERIOD"), menu("fuzzel-emoji.sh", "copy"))
hl.bind(super("A"), menu("audio_output_switch.sh"))
hl.bind(super("SHIFT + A"), run("hyprpicker --autocopy"))
hl.bind(super("TAB"), run(qsbar .. " overview toggle"))

hl.bind(super("SHIFT + S"), shot("region"))
hl.bind(super("SHIFT + E"), shot("region", " --postcommand " .. script_path("screenshot_edit.sh")))
hl.bind("Print", shot("output"), locked)
hl.bind("CTRL + Print", run("mkdir -p " .. shots .. " && grim " .. shots .. "/Screenshot_" .. stamp), locked)

hl.bind("XF86MonBrightnessUp", script("brightness.sh", "--inc"), locked_repeat)
hl.bind("XF86MonBrightnessDown", script("brightness.sh", "--dec"), locked_repeat)
hl.bind("XF86AudioRaiseVolume", script("volume_control.sh", "--inc"), locked_repeat)
hl.bind("XF86AudioLowerVolume", script("volume_control.sh", "--dec"), locked_repeat)
hl.bind("XF86AudioMute", script("volume_control.sh", "--toggle"), locked)
hl.bind("XF86AudioMicMute", script("volume_control.sh", "--toggle-mic"), locked)
hl.bind(super("SHIFT + M"), script("volume_control.sh", "--toggle"), locked)
hl.bind(super("ALT + M"), script("volume_control.sh", "--toggle"), locked)

hl.bind(super("SHIFT + P"), run("playerctl play-pause"), locked)
hl.bind(super("SHIFT + N"), run("playerctl next"), locked)
hl.bind(super("SHIFT + B"), run("playerctl previous"), locked)
hl.bind("XF86AudioPlay", run("playerctl play-pause"), locked)
hl.bind("XF86AudioPause", run("playerctl play-pause"), locked)
hl.bind("XF86AudioNext", run("playerctl next"), locked)
hl.bind("XF86AudioPrev", run("playerctl previous"), locked)

hl.bind(super("Q"), hl.dsp.window.close())
hl.bind(super("SHIFT + ALT + Q"), run("hyprctl kill"))
hl.bind(super("F"), hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(super("D"), hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(super("P"), hl.dsp.window.pin())
hl.bind(super("ALT + space"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(super("Left"), hl.dsp.focus({ direction = "l" }))
hl.bind(super("Right"), hl.dsp.focus({ direction = "r" }))
hl.bind(super("Up"), hl.dsp.focus({ direction = "u" }))
hl.bind(super("Down"), hl.dsp.focus({ direction = "d" }))
hl.bind(super("SHIFT + Left"), hl.dsp.window.move({ direction = "l" }))
hl.bind(super("SHIFT + Right"), hl.dsp.window.move({ direction = "r" }))
hl.bind(super("SHIFT + Up"), hl.dsp.window.move({ direction = "u" }))
hl.bind(super("SHIFT + Down"), hl.dsp.window.move({ direction = "d" }))
hl.bind(super("Semicolon"), run("hyprctl dispatch splitratio -0.1"), repeating)
hl.bind(super("Apostrophe"), run("hyprctl dispatch splitratio +0.1"), repeating)
hl.bind(super("Minus"), zoom(-0.1), repeating)
hl.bind(super("Equal"), zoom(0.1), repeating)
hl.bind(super("mouse:272"), hl.dsp.window.drag(), mouse)
hl.bind(super("mouse:273"), hl.dsp.window.resize(), mouse)

for i = 1, 10 do
	local key = i % 10
	hl.bind(super(tostring(key)), hl.dsp.focus({ workspace = i }))
	hl.bind(super("ALT + " .. key), hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(super("CTRL + Right"), hl.dsp.focus({ workspace = "r+1" }))
hl.bind(super("CTRL + Left"), hl.dsp.focus({ workspace = "r-1" }))
hl.bind(super("Page_Down"), hl.dsp.focus({ workspace = "+1" }))
hl.bind(super("Page_Up"), hl.dsp.focus({ workspace = "-1" }))
hl.bind(super("mouse_down"), hl.dsp.focus({ workspace = "+1" }))
hl.bind(super("mouse_up"), hl.dsp.focus({ workspace = "-1" }))
hl.bind(super("SHIFT + mouse_down"), hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(super("SHIFT + mouse_up"), hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(super("S"), hl.dsp.workspace.toggle_special("magic"))
hl.bind(super("ALT + S"), hl.dsp.window.move({ workspace = "special:magic", follow = false }))

hl.bind(super("L"), power("lock"))
hl.bind(super("SHIFT + L"), power("suspend"))
hl.bind("CTRL + SHIFT + ALT + SUPER + Delete", power("poweroff"))
