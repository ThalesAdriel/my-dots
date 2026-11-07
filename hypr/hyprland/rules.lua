hl.window_rule({
	match = { class = "^(com.heroicgameslauncher.hgl)$" },
	float = false,
})

local steamHandled = {}
local steamTiled = { [""] = true, ["Steam"] = true, ["Steam Big Picture Mode"] = true, ["SteamWebhelper"] = true }

local function floatSteamWindow(w)
	if not w or w.class ~= "steam" or w.mapped == false or steamHandled[w.address] then
		return
	end
	local title = w.title or ""
	if steamTiled[title] or title:match("^about:blank") then
		return
	end
	steamHandled[w.address] = true
	if not w.floating then
		local addr = w.address:match("^0x") and w.address or ("0x" .. w.address)
		hl.dispatch(hl.dsp.window.float({ action = "enable", window = "address:" .. addr }))
	end
end

local function forgetSteamWindow(w)
	if w then
		steamHandled[w.address] = nil
	end
end

hl.on("window.open", function(w)
	forgetSteamWindow(w)
	floatSteamWindow(w)
end)
hl.on("window.title", floatSteamWindow)
hl.on("window.close", forgetSteamWindow)
hl.on("window.destroy", forgetSteamWindow)

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
	name = "qsbar-blur",
	match = { namespace = "^qsbar-blur(-popups|-panel)?$" },
	blur = true,
	xray = true,
	ignore_alpha = 0.1,
})

hl.layer_rule({
	name = "qsbar-blur-popups",
	match = { namespace = "^qsbar-blur-popups$" },
	blur_popups = true,
})

hl.layer_rule({
	name = "qsbar-panel",
	match = { namespace = "^qsbar(-blur)?-panel$" },
	no_anim = true,
})
