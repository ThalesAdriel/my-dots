local M = {}

local known_monitors = {}
local layouts = {}
local ready = false

M.known_monitors = known_monitors
M.layouts = layouts

local function extract_monitor_name(payload)
	if type(payload) == "string" then
		return payload ~= "" and payload or nil
	end
	if type(payload) == "table" then
		local name = payload.name or payload.output or payload.monitor
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	return nil
end

local function extract_workspace_id(payload)
	if type(payload) ~= "table" then
		return nil
	end
	local ws = payload.active_workspace or payload.activeWorkspace or payload.workspace
	if type(ws) == "table" then
		ws = ws.id
	end
	if type(ws) == "number" and ws > 0 then
		return ws
	end
	return nil
end

local function is_callable(v)
	if type(v) == "function" then
		return true
	end
	local mt = getmetatable(v)
	return type(mt) == "table" and type(mt.__call) == "function"
end

local function safe_dispatch(...)
	if type(hl) ~= "table" or not is_callable(hl.dispatch) then
		return false
	end
	local ok = pcall(hl.dispatch, ...)
	return ok
end

local function focus_monitor(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if type(hl) == "table" and hl.dsp ~= nil then
		local ok_fn, fn = pcall(function()
			return hl.dsp.focus
		end)
		if ok_fn and is_callable(fn) then
			local ok, cmd = pcall(fn, { monitor = name })
			if ok and cmd ~= nil then
				return safe_dispatch(cmd)
			end
		end
	end
	return safe_dispatch("focusmonitor", name)
end

local function focus_workspace(ws)
	if ws == nil then
		return false
	end
	if type(hl) == "table" and hl.dsp ~= nil then
		local ok_fn, fn = pcall(function()
			return hl.dsp.focus
		end)
		if ok_fn and is_callable(fn) then
			local ok, cmd = pcall(fn, { workspace = ws })
			if ok and cmd ~= nil then
				return safe_dispatch(cmd)
			end
		end
	end
	return safe_dispatch("workspace", tostring(ws))
end

local function move_workspace_to_monitor(ws_id, target_monitor)
	if not ws_id or type(target_monitor) ~= "string" or target_monitor == "" then
		return false
	end
	if type(hl) == "table" and hl.dsp ~= nil then
		local ok_fn, fn = pcall(function()
			return hl.dsp.workspace and hl.dsp.workspace.move_to_monitor
		end)
		if ok_fn and is_callable(fn) then
			local ok, cmd = pcall(fn, {
				workspace = ws_id,
				monitor = target_monitor,
			})
			if ok and cmd ~= nil then
				return safe_dispatch(cmd)
			end
		end
	end
	return safe_dispatch("moveworkspacetomonitor", tostring(ws_id) .. " " .. target_monitor)
end

local function get_monitors()
	if type(hl) ~= "table" then
		return nil
	end
	local src = hl.get_monitors or hl.monitors
	if is_callable(src) then
		local ok, res = pcall(src)
		if ok and type(res) == "table" then
			return res
		end
	elseif type(src) == "table" then
		return src
	end
	return nil
end

local function get_workspaces()
	if type(hl) ~= "table" then
		return nil
	end
	local src = hl.get_workspaces or hl.workspaces
	if is_callable(src) then
		local ok, res = pcall(src)
		if ok and type(res) == "table" then
			return res
		end
	elseif type(src) == "table" then
		return src
	end
	return nil
end

local function find_fallback_monitor(removed)
	local monitors = get_monitors()
	if monitors then
		local first = nil
		for _, m in ipairs(monitors) do
			local name = extract_monitor_name(m)
			local disabled = type(m) == "table" and m.disabled == true
			if name and name ~= removed and not disabled then
				if type(m) == "table" and m.focused == true then
					return name
				end
				if not first then
					first = name
				end
			end
		end
		return first
	end

	local fallback = nil
	for name, active in pairs(known_monitors) do
		if active and name ~= removed then
			if not fallback or name < fallback then
				fallback = name
			end
		end
	end
	return fallback
end

local function reapply_monitors_config()
	if type(package) ~= "table" or type(package.loaded) ~= "table" then
		return false
	end
	local prev = package.loaded["hyprland.monitors"]
	package.loaded["hyprland.monitors"] = nil
	local ok = pcall(require, "hyprland.monitors")
	if not ok and prev ~= nil then
		package.loaded["hyprland.monitors"] = prev
	end
	return ok
end

local function on_monitor_added(payload)
	local added = extract_monitor_name(payload)
	if added then
		known_monitors[added] = true
	end

	-- Ignore initial monitor discovery during Hyprland startup to avoid redundant DRM modesets (black screen).
	if not ready then
		return {
			added = added,
			reapplied = false,
			skipped = true,
		}
	end

	local reapplied = false
	if added and layouts[added] and type(hl) == "table" and is_callable(hl.monitor) then
		pcall(hl.monitor, layouts[added])
	else
		reapplied = reapply_monitors_config()
		if not reapplied and added and type(hl) == "table" and is_callable(hl.monitor) then
			pcall(hl.monitor, {
				output = added,
				mode = "preferred",
				position = "auto",
				scale = "auto",
			})
		end
	end

	if added then
		focus_monitor(added)
	end

	return {
		added = added,
		reapplied = reapplied,
	}
end

local function on_monitor_removed(payload)
	local removed = extract_monitor_name(payload)
	if removed then
		known_monitors[removed] = nil
	end

	local fallback = find_fallback_monitor(removed)
	local migrated = {}
	local migrated_set = {}

	if fallback then
		local workspaces = get_workspaces()
		if removed and workspaces then
			for _, ws in ipairs(workspaces) do
				if
					type(ws) == "table"
					and ws.monitor == removed
					and type(ws.id) == "number"
					and ws.id > 0
					and not migrated_set[ws.id]
				then
					move_workspace_to_monitor(ws.id, fallback)
					migrated_set[ws.id] = true
					migrated[#migrated + 1] = ws.id
				end
			end
		end

		local active_ws = extract_workspace_id(payload)
		if active_ws and not migrated_set[active_ws] then
			move_workspace_to_monitor(active_ws, fallback)
			migrated_set[active_ws] = true
			migrated[#migrated + 1] = active_ws
		end

		focus_monitor(fallback)
	else
		focus_workspace(1)
	end

	return {
		removed = removed,
		fallback = fallback,
		migrated = migrated,
	}
end

local function register()
	if type(hl) ~= "table" or not is_callable(hl.on) then
		return false
	end
	hl.on("hyprland.start", function()
		if is_callable(hl.timer) then
			hl.timer(function()
				ready = true
			end, { timeout = 2000, type = "oneshot" })
		else
			ready = true
		end
	end)
	hl.on("monitor.added", on_monitor_added)
	hl.on("monitor.removed", on_monitor_removed)
	return true
end

M.extract_monitor_name = extract_monitor_name
M.on_monitor_added = on_monitor_added
M.on_monitor_removed = on_monitor_removed
M.set_ready = function(v)
	ready = v == true
end
M.register = register

register()

return M
