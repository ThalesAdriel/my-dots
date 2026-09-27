local theme = require("hyprland.theme")

local home = os.getenv("HOME")
local gsettings = "gsettings set org.gnome.desktop.interface"

local settings = {
	"cursor-theme '" .. theme.cursor_theme .. "'",
	"cursor-size " .. theme.cursor_size,
	"icon-theme '" .. theme.icon_theme .. "'",
}
-- Only there once a GTK theme has been picked in qsbar settings; until then the session keeps whatever it had.
if theme.gtk_theme then
	settings[#settings + 1] = "gtk-theme '" .. theme.gtk_theme .. "'"
end

local interface = {}
for _, setting in ipairs(settings) do
	interface[#interface + 1] = gsettings .. " " .. setting
end

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")

	hl.exec_cmd("qs -p " .. home .. "/.config/qsbar/shell.qml")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("hypridle")
	-- On the file qsbar settings writes once a theme has been picked there; plain xsettingsd, and whatever config it finds on its own, until then.
	hl.exec_cmd('f="${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf"; [ -f "$f" ] && exec xsettingsd -c "$f" || exec xsettingsd')

	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	hl.exec_cmd(table.concat(interface, "; "))
	hl.exec_cmd("hyprctl setcursor " .. theme.cursor_theme .. " " .. theme.cursor_size)

	hl.timer(function()
		hl.exec_cmd("flatpak run org.qbittorrent.qBittorrent")
	end, { timeout = 4000, type = "oneshot" })
end)
