-- The greeter's compositor: no binds, so the only ways out are signing in or powering off.
-- The keyboard layout comes from greetd's command line, written by install.sh.
hl.config({
    input = {
        kb_layout = os.getenv("QUICKGREET_KB_LAYOUT") or "us",
        kb_variant = os.getenv("QUICKGREET_KB_VARIANT") or "",
    },
    animations = { enabled = false },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_watchdog_warning = true,
    },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/share/quickgreet/quickgreet; hyprctl dispatch 'hl.dsp.exit()'")
end)
