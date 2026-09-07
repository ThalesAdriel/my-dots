hl.window_rule({
	match = { class = "^(com.heroicgameslauncher.hgl)$" },
	float = true,
	center = true,
})

hl.window_rule({
	match = { class = "^(steam|steamwebhelper)$" },
	float = true,
})

hl.window_rule({
	match = { class = "^(mpv)$" },
	float = true,
})

hl.window_rule({
	match = { class = "^(com\\.gabm\\.satty|satty)$" },
	float = true,
})

hl.window_rule({
	match = { class = "^(xdg-desktop-portal-gtk)$" },
	float = true,
	center = true,
	size = { "(monitor_w*0.7)", "(monitor_h*0.7)" },
})

hl.window_rule({
	match = { title = "^(Open a File or Directory)(.*)$" },
	float = true,
	center = true,
	size = { "(monitor_w*0.7)", "(monitor_h*0.7)" },
})

hl.window_rule({
	match = { title = "^(Enter name of file to save to…)(.*)$" },
	float = true,
	size = { "(monitor_w*0.7)", "(monitor_h*0.7)" },
})

hl.layer_rule({
	match = { namespace = "gtk4-layer-shell" },
	no_anim = true,
})

hl.layer_rule({
	name = "pesqBar-blur",
	match = { namespace = "^pesqBar-blur(-popups)?$" },
	blur = true,
	xray = false,
	ignore_alpha = 0.1,
})

hl.layer_rule({
	name = "pesqBar-blur-popups",
	match = { namespace = "^pesqBar-blur-popups$" },
	blur_popups = true,
})
