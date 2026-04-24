#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"
HYPR_SCRIPTS="$HOME/.config/hypr/hyprland/scripts"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

print_menu() {
    printf '\n'
    printf '╔══════════════════════════════════════╗\n'
    printf '║         Dotfiles Installer           ║\n'
    printf '╠══════════════════════════════════════╣\n'
    printf '║  1) Install .config (dotfiles)       ║\n'
    printf '║  2) Install fonts                    ║\n'
    printf '║  3) Install packages                 ║\n'
    printf '║  4) Full install (all of the above)  ║\n'
    printf '║  5) Exit                             ║\n'
    printf '╚══════════════════════════════════════╝\n'
    printf 'Choose an option [1-5]: '
}

install_config() {
    echo "Creating backup of .config..."
    if [ -d "$CONFIG_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$CONFIG_DIR"/. "$BACKUP_DIR"
        echo "Backup created at: $BACKUP_DIR"
    fi

    echo "Installing dots into $CONFIG_DIR..."
    rsync -av --exclude="$(basename "$0")" "$SCRIPT_DIR"/ "$CONFIG_DIR"/

    mkdir -p "$HYPR_SCRIPTS"
    echo "Applying permissions to $HYPR_SCRIPTS..."
    chmod -R a+wx "$HYPR_SCRIPTS"

    echo "Applying some fixes..."
    xhost +SI:localuser:root
    export DISPLAY=:0
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

    echo "Config installed ✔"
}

install_fonts() {
    echo "Installing required fonts..."

    sudo pacman -S --needed --noconfirm \
        adobe-source-han-sans-jp-fonts \
        adobe-source-han-sans-kr-fonts \
        adwaita-fonts \
        gnu-free-fonts \
        gsfonts \
        noto-fonts \
        noto-fonts-emoji \
        ttf-nerd-fonts-symbols \
        ttf-nerd-fonts-symbols-common \
        xorg-fonts-encodings

    echo "Updating font cache..."
    fc-cache -fv
    echo "Fonts installed ✔"
}

ensure_yay() {
    if ! command -v yay >/dev/null 2>&1; then
        echo "yay not found. Installing yay..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        echo "yay installed successfully ✔"
    else
        echo "yay already installed"
    fi
}

install_packages() {
    ensure_yay

    echo "Installing required applications..."

    yay -S --needed --removemake --noconfirm \
        adw-gtk-theme \
        bazaar \
        bluez \
        bluez-utils \
        brightnessctl \
        cliphist \
        cmake \
        cpio \
        curl \
        fastfetch \
        ffmpeg \
        flatpak \
        fuzzel \
        gamemode \
        gcc \
        git \
        grim \
        hyprcursor \
        hypridle \
        hyprland-protocols \
        hyprland-qt-support \
        hyprlock \
        hyprpolkitagent \
        hyprshot \
        hyprsunset \
        hyprutils \
        hyprland-preview-share-picker-git \
        imagemagick \
        kitty \
        nautilus \
        neovim \
        networkmanager \
        network-manager-applet \
        nmrs \
        nwg-look \
        pavucontrol \
        pipewire \
        pipewire-alsa \
        pipewire-pulse \
        polkit \
        polkit-gnome \
        slurp \
        starship \
        swappy \
        ttf-jetbrains-mono-nerd \
        waybar \
        waypaper \
        wine \
        wl-clipboard \
        wireplumber \
        xdg-desktop-portal \
        xdg-desktop-portal-hyprland \
        xdg-user-dirs \
        xdg-user-dirs-gtk \
        xdg-utils \
        gvfs \
        gvfs-mtp \
        steam \
        ffmpegthumbnailer \
        fish \
        jre-openjdk \
        net-tools \
        satty \
        xdg-terminal-exec \
        xorg-xhost \
        gnome-keyring \
        eza \
        xdg-desktop-portal-gtk

    echo "Applications installed ✔"

    xdg-user-dirs-update
    echo "User directories created ✔"

    sysytemctl enable NetworkManager.service
}

while true; do
    print_menu
    read -r choice

    case "$choice" in
        1)
            install_config
            ;;
        2)
            install_fonts
            ;;
        3)
            install_packages
            ;;
        4)
            install_config
            install_fonts
            install_packages
            echo "READY ✔"
            ;;
        5)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1-5."
            ;;
    esac
done
