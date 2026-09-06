#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_DIR="$HOME/.config"
HYPR_SCRIPTS="$CONFIG_DIR/hypr/hyprland/scripts"
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
ttf-jetbrains-mono-nerd
ttf-nerd-fonts-symbols
ttf-nerd-fonts-symbols-common
xorg-fonts-encodings
"

SHELL_PKGS="
quickshell
networkmanager
power-profiles-daemon
upower
pipewire
pipewire-alsa
pipewire-pulse
wireplumber
"

APPS="
adw-gtk-theme
awww
bazaar
brightnessctl
cliphist
curl
eza
fastfetch
ffmpeg
ffmpegthumbnailer
fish
flatpak
fuzzel
gamemode
git
gnome-keyring
gpu-screen-recorder
grim
gvfs
gvfs-mtp
hyprcursor
hypridle
hyprland-preview-share-picker-git
hyprland-protocols
hyprland-qt-support
hyprlock
hyprpolkitagent
hyprshot
hyprsunset
hyprutils
imagemagick
jre-openjdk
kitty
nautilus
ncdu
neovim
nwg-look
pamixer
polkit
rsync
satty
slurp
starship
steam
wine
wl-clipboard
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-desktop-portal-hyprland
xdg-terminal-exec
xdg-user-dirs
xdg-user-dirs-gtk
xdg-utils
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

sync_repos() {
    echo "==> Syncing repositories"
    sudo pacman -Syu --noconfirm
}

install_yay() {
    if have yay; then
        echo "yay already installed"
        return
    fi

    echo "==> Installing yay"
    sudo pacman -S --needed --noconfirm git base-devel

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT INT TERM

    git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)

    rm -rf "$tmp"
    trap - EXIT INT TERM
}

backup_config() {
    [ -d "$CONFIG_DIR" ] || {
        echo "No .config to back up, skipping"
        return
    }

    BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    echo "==> Backing up .config -> $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cp -a "$CONFIG_DIR/." "$BACKUP_DIR/"
}

install_config() {
    have rsync || sudo pacman -S --needed --noconfirm rsync

    echo "==> Copying dotfiles -> $CONFIG_DIR"
    rsync -a --info=stats1 \
        --exclude=".git/" \
        --exclude=".gitignore" \
        --exclude="README*" \
        --exclude="LICENSE*" \
        --exclude="$SELF" \
        "$SCRIPT_DIR/" "$CONFIG_DIR/"

    [ -d "$HYPR_SCRIPTS" ] || return 0

    echo "==> Setting permissions on $HYPR_SCRIPTS"
    find "$HYPR_SCRIPTS" -type d -exec chmod 755 {} +
    find "$HYPR_SCRIPTS" -type f -exec chmod 755 {} +
}

install_fonts() {
    echo "==> Installing fonts"
    sudo pacman -S --needed --noconfirm $FONTS
    echo "==> Updating font cache"
    fc-cache -f
}

install_apps() {
    install_yay

    packages="$SHELL_PKGS $APPS"
    if [ "$WANT_BLUETOOTH" = yes ]; then
        packages="$packages $BLUETOOTH_PKGS"
    fi

    echo "==> Installing packages"
    yay -S --needed --removemake --noconfirm $packages
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
}

post_fixes() {
    echo "==> Applying post-install fixes"

    if have xdg-user-dirs-update; then
        xdg-user-dirs-update
    fi

    if have gsettings; then
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    fi
}

run_fonts() {
    sync_repos
    install_fonts
}

run_apps() {
    ask_bluetooth
    sync_repos
    install_apps
    enable_services
    post_fixes
}

run_config() {
    confirm "This overwrites files in $CONFIG_DIR. A backup is taken first. Continue?" || die "cancelled"
    backup_config
    install_config
}

run_full() {
    confirm "Full install: overwrites $CONFIG_DIR and installs every package listed. Continue?" || die "cancelled"
    ask_bluetooth
    backup_config
    install_config
    sync_repos
    install_fonts
    install_apps
    enable_services
    post_fixes
}

menu() {
    echo "==== Hyprland dotfiles installer ===="
    echo "1) Fonts only"
    echo "2) Programs only"
    echo "3) Config files only"
    echo "4) Full install (config + fonts + programs)"
    echo "5) Quit"
    printf "Choose [1-5]: "
    read -r choice

    case "$choice" in
        1) run_fonts ;;
        2) run_apps ;;
        3) run_config ;;
        4) run_full ;;
        5) echo "Bye"; exit 0 ;;
        *) die "invalid choice" ;;
    esac
}

check_environment

case "${1:-}" in
    fonts) run_fonts ;;
    apps) run_apps ;;
    config) run_config ;;
    full) run_full ;;
    "") menu ;;
    *) die "unknown command '$1'; use fonts, apps, config or full" ;;
esac

echo "DONE!"
