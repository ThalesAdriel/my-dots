local ok, loaded_theme = pcall(require, "hyprland.theme")
local theme = (ok and type(loaded_theme) == "table") and loaded_theme or {}
local cursor_theme = theme.cursor_theme or "Adwaita"
local cursor_size = theme.cursor_size or 24

local function file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function has_nvidia_gpu()
	return file_exists("/proc/driver/nvidia/version")
		or file_exists("/sys/module/nvidia/version")
		or file_exists("/dev/nvidiactl")
end

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

if has_nvidia_gpu() then
	hl.env("LIBVA_DRIVER_NAME", "nvidia")
	hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
	hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")
	hl.env("NVD_BACKEND", "direct")
end

hl.env("XCURSOR_THEME", cursor_theme)
hl.env("XCURSOR_SIZE", tostring(cursor_size))

hl.env("XDG_SESSION_DESKTOP", "Hyprland")
