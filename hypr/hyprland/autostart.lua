-- Managed by qsbar Settings -> Startup apps.
-- qsbar-autostart: [{"name":"qBittorrent","command":"flatpak run org.qbittorrent.qBittorrent","delay":4,"enabled":true,"minimized":false}]

hl.on("hyprland.start", function()
	hl.timer(function()
		hl.exec_cmd("flatpak run org.qbittorrent.qBittorrent")
	end, { timeout = 4000, type = "oneshot" })
end)
