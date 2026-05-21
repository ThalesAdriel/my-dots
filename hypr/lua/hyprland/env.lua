-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Themes
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "kde")

-- Wayland
-- Tearing
-- hl.env("WLR_DRM_NO_ATOMIC", "1")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Nvidia
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "macOS-BigSur")
