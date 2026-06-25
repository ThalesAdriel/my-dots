#!/bin/sh
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_DIR="$HOME/.config"
HYPR_SCRIPTS="$HOME/.config/hypr/hyprland/scripts"
SELF=$(basename "$0")

FONTS="
adobe-source-han-sans-jp-fonts
adobe-source-han-sans-kr-fonts
adwaita-fonts
gnu-free-fonts
gsfonts
noto-fonts
otf-font-awesome
ttf-jetbrains-mono-nerd
noto-fonts-emoji
ttf-nerd-fonts-symbols
ttf-nerd-fonts-symbols-common
xorg-fonts-encodings
"

APPS="
adw-gtk-theme
bazaar
bluez
bluez-utils
brightnessctl
cliphist
cmake
cpio
curl
fastfetch
ffmpeg
flatpak
fuzzel
gamemode
gcc
git
grim
hyprcursor
hypridle
hyprland-protocols
hyprland-qt-support
hyprlock
hyprpolkitagent
hyprshot
hyprsunset
hyprutils
hyprland-preview-share-picker-git
imagemagick
kitty
nautilus
neovim
networkmanager
network-manager-applet
nmrs
nwg-look
pavucontrol
pipewire
pipewire-alsa
pipewire-pulse
polkit
polkit-gnome
slurp
starship
awww
waybar
wine
wl-clipboard
wireplumber
xdg-desktop-portal
xdg-desktop-portal-hyprland
xdg-user-dirs
xdg-user-dirs-gtk
xdg-utils
gvfs
gvfs-mtp
steam
ffmpegthumbnailer
fish
jre-openjdk
net-tools
xdg-terminal-exec
xorg-xhost
gnome-keyring
eza
xdg-desktop-portal-gtk
"

backup_config() {
    if [ -d "$CONFIG_DIR" ]; then
        BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Backup .config -> $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        cp -r "$CONFIG_DIR"/. "$BACKUP_DIR"
    else
        echo "No .config to back up, skipping"
    fi
}

install_config() {
    echo "Copying dotfiles -> $CONFIG_DIR"
    rsync -av --exclude="$SELF" "$SCRIPT_DIR"/ "$CONFIG_DIR"/
    mkdir -p "$HYPR_SCRIPTS"
    echo "Setting permissions on $HYPR_SCRIPTS"
    chmod -R a+wx "$HYPR_SCRIPTS"
}

install_yay() {
    if command -v yay >/dev/null 2>&1; then
        echo "yay already installed"
        return
    fi
    echo "Installing yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    ( cd "$tmp/yay" && makepkg -si --noconfirm )
    rm -rf "$tmp"
    echo "yay installed"
}

install_fonts() {
    echo "Installing fonts..."
    sudo pacman -S --needed --noconfirm $FONTS
    echo "Updating font cache..."
    fc-cache -fv
}

install_apps() {
    install_yay
    echo "Installing applications..."
    yay -S --needed --removemake --noconfirm $APPS
    echo "Applications installed"
}

post_fixes() {
    echo "Applying post-install fixes..."
    xdg-user-dirs-update
    DISPLAY=:0
    export DISPLAY
    xhost +SI:localuser:root || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" || true
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
        1) install_fonts ;;
        2) install_apps; post_fixes ;;
        3) backup_config; install_config ;;
        4) backup_config; install_config; install_fonts; install_apps; post_fixes ;;
        5) echo "Bye"; exit 0 ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac

    echo "DONE ✔"
}

menu
