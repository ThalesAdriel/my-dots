hl.monitor({
	output = "",
	mode = "1920x1080@165.00Hz",
	position = "auto",
	scale = "1",
})

hl.monitor({
	output = "HDMI-A-1",
	mode = "preferred",
	position = "auto-left",
	scale = "auto",
})

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 5,
		gaps_workspaces = 50,

		border_size = 0,
		resize_on_border = true,
		no_focus_fallback = true,
		allow_tearing = true,

		snap = {
			enabled = true,
		},
	},

	dwindle = {
		preserve_split = true,
		smart_resizing = false,
	},

	decoration = {
		rounding = 4,
		rounding_power = 4,

		dim_inactive = true,
		dim_strength = 0.025,
		dim_special = 0.07,

		blur = {
			enabled = true,
			size = 10,
			passes = 3,

			brightness = 0.8,
			contrast = 1,
			noise = 0.01,
			xray = true,
			popups = true,
			popups_ignorealpha = 0.6,
			input_methods = true,
			input_methods_ignorealpha = 0.8,
		},

		shadow = {
			enabled = true,
			range = 20,
			render_power = 3,
			offset = { 0, 2 },
			color = "rgba(00000010)",
		},
	},

	input = {
		kb_layout = "br",
		kb_variant = "abnt2",
		numlock_by_default = true,
		repeat_delay = 250,
		repeat_rate = 35,

		follow_mouse = 1,
		off_window_axis_events = 2,

		sensitivity = 0.3,
		accel_profile = "flat",

		touchpad = {
			natural_scroll = true,
			disable_while_typing = true,
			clickfinger_behavior = true,
			scroll_factor = 0.5,
		},
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
		allow_session_lock_restore = true,
		session_lock_xray = true,
		initial_workspace_tracking = 0,
		focus_on_activate = true,
	},

	binds = {
		scroll_event_delay = 0,
		hide_special_on_workspace_change = true,
	},
})

hl.curve("expressiveFastSpatial", { type = "bezier", points = { { 0.42, 1.67 }, { 0.21, 0.90 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.52, 0.03 }, { 0.72, 0.08 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "expressiveFastSpatial", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "emphasizedDecel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "border", enabled = false })

hl.animation({ leaf = "layersIn", enabled = true, speed = 2.7, bezier = "emphasizedDecel", style = "popin 93%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.4, bezier = "menu_accel", style = "popin 94%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.5, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.7, bezier = "menu_accel" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.2, bezier = "emphasizedAccel", style = "slidevert" })

hl.animation({ leaf = "fadePopups", enabled = false })
