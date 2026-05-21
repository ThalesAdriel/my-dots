-- ######## Adições do doc2 ########

-- Network Manager
hl.window_rule({
	match = {
		title = "^(Network Manager)$",
	},
	float = true,
})

-- overskride
hl.window_rule({
	match = {
		title = "^(overskride)$",
	},
	float = true,
})

-- Waypaper
hl.window_rule({
	match = {
		title = "^(Waypaper)$",
	},
	float = true,
})

-- Heroic Games Launcher
hl.window_rule({
	match = {
		class = "^(com.heroicgameslauncher.hgl)$",
	},
	float = true,
})

hl.window_rule({
	match = {
		class = "^(com.heroicgameslauncher.hgl)$",
	},
	center = true,
})

-- Video Downloader
hl.window_rule({
	match = {
		class = "^(com.github.unrud.VideoDownloader)$",
	},
	float = true,
})

hl.window_rule({
	match = {
		class = "^(com.github.unrud.VideoDownloader)$",
	},
	center = true,
})

-- Clipse (clipboard manager)
hl.window_rule({
	match = {
		class = "^(clipse)$",
	},
	float = true,
})

hl.window_rule({
	match = {
		class = "^(clipse)$",
	},
	size = { 622, 652 },
})

-- Adobe Premiere Pro (Wine/exe)
hl.window_rule({
	match = {
		class = "^(adobe premiere pro.exe)$",
	},
	float = true,
})

-- xdg-desktop-portal-gtk
hl.window_rule({
	match = {
		class = "^(xdg-desktop-portal-gtk)$",
	},
	float = true,
})

hl.window_rule({
	match = {
		class = "^(xdg-desktop-portal-gtk)$",
	},
	center = true,
})

hl.window_rule({
	match = {
		class = "^(xdg-desktop-portal-gtk)$",
	},
	size = {
		"(monitor_w*0.7)",
		"(monitor_h*0.7)",
	},
})

-- Steam (janelas secundárias, não a janela principal)
hl.window_rule({
	match = {
		class = "^(steam)$",
		title = "^(?!Steam$).*$", -- negativo: não é a janela principal
	},
	float = true,
})

-- "Open a File or Directory"
hl.window_rule({
	match = {
		title = "^(Open a File or Directory)(.*)$",
	},
	center = true,
})

hl.window_rule({
	match = {
		title = "^(Open a File or Directory)(.*)$",
	},
	size = {
		"(monitor_w*0.7)",
		"(monitor_h*0.7)",
	},
})

-- "Enter name of file to save to…"
hl.window_rule({
	match = {
		title = "^(Enter name of file to save to…)(.*)$",
	},
	float = true,
})

hl.window_rule({
	match = {
		title = "^(Enter name of file to save to…)(.*)$",
	},
	size = {
		"(monitor_w*0.7)",
		"(monitor_h*0.7)",
	},
})

-- mpv
hl.window_rule({
	match = {
		title = ".*mpv.*",
	},
	float = true,
})

-- satty (screenshot annotation)
hl.window_rule({
	match = {
		title = "^(satty)$",
	},
	float = true,
})

-- ######## Layer rules adicionais ########

-- gtk4-layer-shell (launchers rápidos)
hl.layer_rule({
	match = {
		namespace = "gtk4-layer-shell",
	},
	no_anim = true,
})

-- swaync - centro de controle
hl.layer_rule({
	match = {
		namespace = "swaync-control-center",
	},
	blur = true,
})

hl.layer_rule({
	match = {
		namespace = "swaync-control-center",
	},
	ignore_alpha = 0.5,
	animation = "slide right",
})

hl.layer_rule({
	match = {
		namespace = "swaync-control-center",
	},
	xray = false,
})

-- swaync - janela de notificações
hl.layer_rule({
	match = {
		namespace = "swaync-notification-window",
	},
	ignore_alpha = 0.5,
})

hl.layer_rule({
	match = {
		namespace = "swaync-notification-window",
	},
	xray = false,
})

-- waybar blur
hl.layer_rule({
	match = {
		namespace = "waybar",
	},
	blur = true,
})
