local theme = require("hyprland.theme")

local home = os.getenv("HOME")
local gsettings = "gsettings set org.gnome.desktop.interface"
local polkit = table.concat({
	"/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
	"/usr/libexec/polkit-gnome-authentication-agent-1",
	"/usr/lib/polkit-kde-authentication-agent-1",
	"/usr/libexec/polkit-kde-authentication-agent-1",
}, " || ")

local interface = {}
for _, setting in ipairs({
	"cursor-theme '" .. theme.cursor_theme .. "'",
	"cursor-size " .. theme.cursor_size,
	"icon-theme '" .. theme.icon_theme .. "'",
}) do
	interface[#interface + 1] = gsettings .. " " .. setting
end

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd(polkit)
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")

	hl.exec_cmd("qs -p " .. home .. "/.config/qsbar/shell.qml")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("xsettingsd")

	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	hl.exec_cmd(table.concat(interface, "; "))
	hl.exec_cmd("hyprctl setcursor " .. theme.cursor_theme .. " " .. theme.cursor_size)

	hl.timer(function()
		hl.exec_cmd("easyeffects --gapplication-service")
		hl.exec_cmd("flatpak run org.qbittorrent.qBittorrent")
	end, { timeout = 4000, type = "oneshot" })
end)
