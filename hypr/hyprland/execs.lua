hl.on("hyprland.start", function()
	-- Core daemons
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("xsettingsd")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("swaync")
	hl.exec_cmd("waybar")

	-- Polkit
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	hl.exec_cmd(
		"/usr/lib/polkit-kde-authentication-agent-1 || /usr/libexec/polkit-kde-authentication-agent-1 || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1"
	)

	-- Core components
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("dbus-update-activation-environment --all")
	hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk
	--hl.exec_cmd("hyprpm reload")
	hl.exec_cmd("xhost +SI:localuser:root")

	-- Audio
	hl.exec_cmd("easyeffects --gapplication-service")

	-- Clipboard: history
	hl.exec_cmd("wl-paste --watch cliphist store &")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	-- Cursor
	hl.exec_cmd("hyprctl setcursor macOS-BigSur 24")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'macOS-BigSur'")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")

	-- Icons
	hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-red'")

	-- qBittorrent
	hl.exec_cmd("flatpak run org.qbittorrent.qBittorrent")

	-- Vesktop arRPC
	hl.exec_cmd("~/.config/hypr/hyprland/scripts/start_arRPC.sh")
end)
