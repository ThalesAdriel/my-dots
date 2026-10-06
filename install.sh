#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
SELF=$(basename "$0")

FONTS="
adobe-source-han-sans-jp-fonts
adobe-source-han-sans-kr-fonts
adwaita-fonts
gnu-free-fonts
gsfonts
noto-fonts
noto-fonts-emoji
otf-font-awesome
ttf-jetbrains-mono
ttf-nerd-fonts-symbols
"

SHELL_PKGS="
quickshell
greetd
networkmanager
power-profiles-daemon
upower
pipewire-alsa
pipewire-pulse
wireplumber
rtkit
"

APPS="
adw-gtk-theme
awww
bazaar
brightnessctl
cliphist
eza
fastfetch
ffmpeg
ffmpegthumbnailer
fish
flatpak
fuzzel
gamemode
gnome-keyring
gpu-screen-recorder
grim
gvfs-mtp
hypridle
hyprshot
hyprsunset
imagemagick
kitty
libnotify
nautilus
ncdu
nwg-look
polkit
satty
slurp
starship
steam
vis
wl-clipboard
xdg-desktop-portal-gtk
xdg-desktop-portal-hyprland
xdg-terminal-exec
xdg-user-dirs
xdg-user-dirs-gtk
xdg-utils
xsettingsd
"

BLUETOOTH_PKGS="
bluez
bluez-utils
"

SERVICES="
NetworkManager.service
power-profiles-daemon.service
"

WANT_BLUETOOTH=no

die() {
    echo "error: $*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

confirm() {
    printf '%s [y/N]: ' "$1"
    read -r reply
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

ask_bluetooth() {
    if confirm "Install bluetooth support and enable its service?"; then
        WANT_BLUETOOTH=yes
    fi
}

check_environment() {
    [ "$(id -u)" -ne 0 ] || die "do not run this as root; it installs into \$HOME and calls sudo itself"
    have sudo || die "sudo is not installed"
    have pacman || die "this installer is for Arch and pacman is not here"
}

check_dotfiles() {
    [ -d "$SCRIPT_DIR/hypr" ] || die "no hypr/ next to $SELF; run it from inside the dotfiles folder"
    have rsync || die "rsync is not installed"
}

install_packages() {
    echo "==> Installing packages"
    sudo pacman -Syu --needed "$@"
}

app_packages() {
    packages="$SHELL_PKGS $APPS"
    if [ "$WANT_BLUETOOTH" = yes ]; then
        packages="$packages $BLUETOOTH_PKGS"
    fi
    echo "$packages"
}

install_config() {
    backup="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -m 700 "$backup"

    echo "==> Copying dotfiles -> $CONFIG_DIR"
    rsync -a --info=stats1 \
        --chmod=D755,F644 \
        --backup --backup-dir="$backup" \
        --exclude=".git/" \
        --exclude=".gitignore" \
        --exclude="README*" \
        --exclude="LICENSE*" \
        --exclude="$SELF" \
        "$SCRIPT_DIR/" "$CONFIG_DIR/"

    if rmdir "$backup" 2>/dev/null; then
        echo "  nothing was replaced, no backup kept"
    else
        echo "  replaced files saved in $backup"
    fi

    echo "==> Marking scripts as executable"
    LC_ALL=C find "$SCRIPT_DIR" -name .git -prune -o -type f -exec \
        awk -v src="$SCRIPT_DIR/" 'FNR == 1 && /^(#!|\177ELF)/ { print substr(FILENAME, length(src) + 1) } { nextfile }' {} + |
        while IFS= read -r file; do
            [ ! -f "$CONFIG_DIR/$file" ] || chmod 755 "$CONFIG_DIR/$file"
        done
}

hypr_input() {
    sed -n "s/^[[:space:]]*$1 = \"\([A-Za-z0-9_,-]*\)\",*\$/\1/p" "$CONFIG_DIR/hypr/hyprland/general.lua" 2>/dev/null | head -n 1
}

install_greeter() {
    echo "==> Installing the login screen (quickgreet)"
    if ! id greeter >/dev/null 2>&1 || ! have Hyprland || ! have qs; then
        echo "  greetd, Hyprland or quickshell is not installed, skipping"
        return
    fi

    sudo rsync -a --delete \
        --chown=root:root \
        --chmod=D755,F644 \
        --exclude="test/" \
        --exclude="README*" \
        --exclude="$SELF" \
        "$CONFIG_DIR/quickgreet/" /usr/share/quickgreet/
    sudo chmod 755 /usr/share/quickgreet/quickgreet
    sudo ln -sf /usr/share/quickgreet/quickgreet /usr/local/bin/quickgreet

    sudo install -d -m 755 -o "$(id -un)" /var/lib/quickgreet
    [ -e /var/lib/quickgreet/quickgreet.json ] || install -m 644 "$CONFIG_DIR/quickgreet/quickgreet.json" /var/lib/quickgreet/
    sudo install -d -m 700 -o greeter -g "$(id -gn greeter)" /var/cache/quickgreet

    greetd_config=/etc/greetd/config.toml
    vt=$(sed -n 's/^vt *= *//p' "$greetd_config" 2>/dev/null | head -n 1)
    layout=$(hypr_input kb_layout)
    [ ! -f "$greetd_config" ] || grep -q quickgreet "$greetd_config" || sudo cp "$greetd_config" "$greetd_config.bak"
    printf '[terminal]\nvt = %s\n\n[default_session]\ncommand = "env QUICKGREET_KB_LAYOUT=%s QUICKGREET_KB_VARIANT=%s Hyprland --config /usr/share/quickgreet/hyprland.lua"\nuser = "greeter"\n' \
        "${vt:-1}" "${layout:-us}" "$(hypr_input kb_variant)" | sudo tee "$greetd_config" >/dev/null
    echo "  keyboard ${layout:-us}, from hypr/hyprland/general.lua"

    sudo systemctl enable greetd.service || echo "  could not enable greetd.service, disable the display manager it replaces first"
}

enable_unit() {
    if systemctl list-unit-files "$1" >/dev/null 2>&1; then
        sudo systemctl enable --now "$1" || echo "  could not enable $1"
    else
        echo "  $1 is not installed, skipping"
    fi
}

enable_services() {
    echo "==> Enabling services"
    for unit in $SERVICES; do
        enable_unit "$unit"
    done

    if [ "$WANT_BLUETOOTH" = yes ]; then
        enable_unit bluetooth.service
    else
        echo "  bluetooth skipped"
    fi

    sudo systemctl disable NetworkManager-wait-online.service || echo "  could not disable NetworkManager-wait-online.service"
}

post_fixes() {
    echo "==> Applying post-install fixes"

    if have xdg-user-dirs-update; then
        xdg-user-dirs-update
    fi

    if have gsettings; then
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    fi

    sudo usermod -aG gamemode "$(id -un)"
    echo "  added to the gamemode group, log out and back in to apply it"
}

run_fonts() {
    install_packages $FONTS
}

run_apps() {
    ask_bluetooth
    install_packages $(app_packages)
    enable_services
    post_fixes
}

run_config() {
    check_dotfiles
    confirm "This overwrites files in $CONFIG_DIR and installs the login screen. Replaced files are backed up first. Continue?" || die "cancelled"
    install_config
    install_greeter
}

run_full() {
    check_dotfiles
    confirm "Full install: overwrites $CONFIG_DIR, installs the login screen and every package listed. Continue?" || die "cancelled"
    ask_bluetooth
    install_packages $FONTS $(app_packages)
    install_config
    install_greeter
    enable_services
    post_fixes
}

run_greeter() {
    have rsync || die "rsync is not installed"
    [ -d "$CONFIG_DIR/quickgreet" ] || die "no quickgreet/ in $CONFIG_DIR; install the config files first"
    confirm "Login screen only: installs greetd if missing, copies $CONFIG_DIR/quickgreet to /usr/share/quickgreet and enables greetd. Continue?" || die "cancelled"
    id greeter >/dev/null 2>&1 || install_packages greetd
    install_greeter
}

menu() {
    echo "==== Hyprland dotfiles installer ===="
    echo "1) Fonts only"
    echo "2) Programs only"
    echo "3) Config files only"
    echo "4) Full install (config + fonts + programs)"
    echo "5) Login screen only"
    echo "6) Quit"
    printf "Choose [1-6]: "
    read -r choice

    case "$choice" in
        1) run_fonts ;;
        2) run_apps ;;
        3) run_config ;;
        4) run_full ;;
        5) run_greeter ;;
        6) echo "Bye"; exit 0 ;;
        *) die "invalid choice" ;;
    esac
}

check_environment

case "${1:-}" in
    fonts) run_fonts ;;
    apps) run_apps ;;
    config) run_config ;;
    full) run_full ;;
    greeter) run_greeter ;;
    "") menu ;;
    *) die "unknown command '$1'; use fonts, apps, config, full or greeter" ;;
esac

echo "DONE!"
