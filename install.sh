#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"
HYPR_SCRIPTS="$HOME/.config/hypr/hyprland/scripts"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

echo "Creating backup of .config..."

if [ -d "$CONFIG_DIR" ]; then
  mkdir -p "$BACKUP_DIR"
  cp -r "$CONFIG_DIR"/. "$BACKUP_DIR"
  echo "Backup criado em: $BACKUP_DIR"
fi

echo "intalling dots from in $CONFIG_DIR..."
rsync -av --exclude="$(basename "$0")" "$SCRIPT_DIR"/ "$CONFIG_DIR"/

mkdir -p "$HYPR_SCRIPTS"

echo " applying permissions $HYPR_SCRIPTS..."

chmod -R a+wx "$HYPR_SCRIPTS"

if ! command -v yay >/dev/null 2>&1; then
  echo "yay not found. Installing yay..."

  sudo pacman -S --needed --noconfirm git base-devel

  git clone https://aur.archlinux.org/yay.git
  cd yay

  makepkg -si --noconfirm

  echo "yay installed successfully ✔"

else
  echo "yay already installed"
fi

echo "Installing required fonts..."

FONTS=(
  adobe-source-han-sans-jp-fonts
  adobe-source-han-sans-kr-fonts
  adwaita-fonts
  gnu-free-fonts
  gsfonts
  noto-fonts
  noto-fonts-emoji
  ttf-nerd-fonts-symbols
  ttf-nerd-fonts-symbols-common
  xorg-fonts-encodings
)

sudo pacman -S --needed --noconfirm "${FONTS[@]}"

echo "Updating font cache..."
fc-cache -fv

echo "Installing required applications..."

APPS=(
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
  swww
  ttf-jetbrains-mono-nerd
  waybar
  waypaper
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
  satty
  xdg-terminal-exec
  xorg-xhost
  gnome-keyring
  eza
  xdg-desktop-portal-gtk
)

yay -S --needed --removemake --noconfirm "${APPS[@]}"

echo "Applications installed ✔"

xdg-user-dirs-update

echo "User directories created ✔"

echo "Applying some fixes"
xhost +SI:localuser:root
export DISPLAY=:0

#sudo systemctl enable NetworkManager

gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

#echo "Installing WhiteSur icons inspired theme..."

#git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git

#cd WhiteSur-icon-theme/

#./install.sh -a -b -t red

echo "READYY ✔"
