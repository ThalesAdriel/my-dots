local default_theme = {
	cursor_theme = "Adwaita",
	cursor_size = 24,
	icon_theme = "Adwaita",
	gtk_theme = "Adwaita",
	color_scheme = "prefer-dark",
	title_buttons = "close",
}
local ok, loaded_theme = pcall(require, "hyprland.theme")
local theme = default_theme
if ok and type(loaded_theme) == "table" then
	theme = {}
	for k, v in pairs(default_theme) do
		theme[k] = v
	end
	for k, v in pairs(loaded_theme) do
		theme[k] = v
	end
end

local home = os.getenv("HOME")
local quickshell_env = "export MALLOC_CONF=narenas:2,background_thread:true; f=/usr/share/glvnd/egl_vendor.d/10_nvidia.json; [ -e $f ] && ! ls -l /sys/class/drm/card[0-9]/device/driver /sys/class/drm/card[0-9][0-9]/device/driver 2>/dev/null | grep -qv '/nvidia$' && export __EGL_VENDOR_LIBRARY_FILENAMES=$f; "
local gsettings = "gsettings set org.gnome.desktop.interface"

local settings = {
	"cursor-theme '" .. theme.cursor_theme .. "'",
	"cursor-size " .. theme.cursor_size,
	"icon-theme '" .. theme.icon_theme .. "'",
}
if theme.gtk_theme then
	settings[#settings + 1] = "gtk-theme '" .. theme.gtk_theme .. "'"
end
for _, key in ipairs({ "color_scheme", "accent_color", "font_name", "monospace_font_name", "font_antialiasing", "font_hinting" }) do
	if theme[key] then
		settings[#settings + 1] = (key:gsub("_", "-")) .. " '" .. theme[key] .. "'"
	end
end
if theme.text_scaling_factor then
	settings[#settings + 1] = string.format("text-scaling-factor %.2f", theme.text_scaling_factor)
end

local interface = {}
for _, setting in ipairs(settings) do
	interface[#interface + 1] = gsettings .. " " .. setting
end
local layouts = { close = "appmenu:close", all = "appmenu:minimize,maximize,close", none = "appmenu:" }
if layouts[theme.title_buttons] then
	interface[#interface + 1] = "gsettings set org.gnome.desktop.wm.preferences button-layout '" .. layouts[theme.title_buttons] .. "'"
end

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")

	hl.exec_cmd(quickshell_env .. "exec qs -p " .. home .. "/.config/qsbar/shell.qml")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("hypridle")
	hl.exec_cmd('f="${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf"; [ -f "$f" ] && exec xsettingsd -c "$f" || exec xsettingsd')

	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	hl.exec_cmd(table.concat(interface, "; "))
	hl.exec_cmd("hyprctl setcursor " .. theme.cursor_theme .. " " .. theme.cursor_size)
end)
