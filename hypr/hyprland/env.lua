local theme = require("hyprland.theme")

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.env("XCURSOR_THEME", theme.cursor_theme)
hl.env("XCURSOR_SIZE", tostring(theme.cursor_size))

hl.env("XDG_SESSION_DESKTOP", "Hyprland")
