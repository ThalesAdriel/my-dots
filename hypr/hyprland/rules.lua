-- Network Manager
hl.window_rule({
	match = { title = "^(Network Manager)$" },
	float = true,
})

-- Waypaper
hl.window_rule({
	match = { title = "^(Waypaper)$" },
	float = true,
})

-- Heroic Games Launcher
hl.window_rule({
	match = { class = "^(com.heroicgameslauncher.hgl)$" },
	float = true,
	center = true,
})

-- Adobe Premiere Pro (Wine/exe)
hl.window_rule({
	match = { class = "^(adobe premiere pro.exe)$" },
	float = true,
})

-- xdg-desktop-portal-gtk
hl.window_rule({
	match = { class = "^(xdg-desktop-portal-gtk)$" },
	float = true,
	center = true,
	size = { "(monitor_w*0.7)", "(monitor_h*0.7)" },
})

-- Steam
hl.window_rule({
	match = {
		class = "^(steamwebhelper)$",
	},
	float = true,
})

hl.window_rule({
	match = {
		class = "^(steam|steamwebhelper)$",
	},
	float = true,
})

-- File/Directory dialogs
hl.window_rule({
	match = { title = "^(Open a File or Directory)(.*)$" },
	float = true,
	center = true,
	size = { "(monitor_w*0.7)", "(monitor_h*0.7)" },
})

-- Save dialog
hl.window_rule({
	match = { title = "^(Enter name of file to save to…)(.*)$" },
	float = true,
	size = { "(monitor_w*0.7)", "(monitor_h*0.7)" },
})

-- mpv
hl.window_rule({
	match = { title = ".*mpv.*" },
	float = true,
})

-- satty (screenshot annotation)
hl.window_rule({
	match = { title = "^(satty)$" },
	float = true,
})

-- gtk4-layer-shell (launchers rápidos)
hl.layer_rule({
	match = { namespace = "gtk4-layer-shell" },
	no_anim = true,
})

-- swaync - control center
hl.layer_rule({
	match = { namespace = "swaync-control-center" },
	blur = true,
	ignore_alpha = 0.5,
	animation = "slide right",
	xray = false,
})

-- swaync - notification window
hl.layer_rule({
	match = { namespace = "swaync-notification-window" },
	ignore_alpha = 0.5,
	xray = false,
})

-- waybar blur
hl.layer_rule({
	match = { namespace = "waybar" },
	blur = true,
})
