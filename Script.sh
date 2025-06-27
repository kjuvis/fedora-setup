#!/bin/sh
set -eu
IFS='\n\t'

# ───── Voraussetzungen ─────
command -v dialog >/dev/null 2>&1 || sudo dnf install -y dialog

# ───── Hilfsfunktionen ─────
check_install() {
  pkg="$1"
  if ! rpm -q "$pkg" >/dev/null 2>&1; then
    sudo dnf install -y "$pkg"
  else
    echo "  → $pkg ist bereits installiert"
  fi
}

install_flatpak() {
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  for pkg in "$@"; do
    if ! flatpak list --app | grep -q "$pkg"; then
      flatpak install -y flathub "$pkg"
    else
      echo "  → Flatpak $pkg bereits installiert"
    fi
  done
}

remove_gnome() {
  echo "=> Entferne GNOME-Reste..."
  sudo dnf remove -y \
    gnome-* \
    totem \
    cheese \
    gnome-online-accounts \
    gnome-software \
    gnome-extensions-app \
    epiphany \
    rhythmbox || true
}

apply_kde_theme() {
  echo "=> KDE: Theme, Icons, Cursor, Splash anwenden..."
  kwriteconfig5 --file kdeglobals --group General --key WidgetStyle "Breeze"
  kwriteconfig5 --file kdeglobals --group Icons --key Theme "breeze"
  kwriteconfig5 --file kcminputrc --group Mouse --key cursorTheme "Breeze_Snow"
  kwriteconfig5 --file ksplashrc --group KSplash --key Theme "breeze"
  echo "KDE-Theming angewendet. Abmelden/Neustart empfohlen."
}

do_system() {
  echo "=> Systemupdate & DNF-Konfiguration"
  sudo dnf -y update
  sudo sh -c 'cat > /etc/dnf/dnf.conf' <<EOF
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
fastestmirror=True
max_parallel_downloads=10
EOF
  sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
}

do_flatpak() {
  echo "=> Flatpak-Anwendungen installieren"
  install_flatpak \
    com.github.tchx84.Flatseal \
    org.gimp.GIMP \
    com.spotify.Client \
    org.videolan.VLC \
    com.discordapp.Discord \
    com.github.IsmaelMartinez.teams_for_linux
}

do_zsh() {
  echo "Installing Git and Zsh..."
  sudo dnf install git zsh -y
  echo "Setting Zsh as default shell..."
  chsh -s "$(command -v zsh)"

  echo "Preparing Zsh plugins..."
  mkdir -p ~/.zsh/plugins

  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-completions ~/.zsh/plugins/zsh-completions

  echo "Updating .zshrc with plugin configuration..."
  cat <<'EOF' >> ~/.zshrc
# Plugin Paths
fpath+=~/.zsh/plugins/zsh-completions
# Load Plugins
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
autoload -Uz compinit && compinit
EOF

  echo "Installing FiraCode Nerd Font..."
  mkdir -p ~/.local/share/fonts
  wget -O ~/.local/share/fonts/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
  unzip -o ~/.local/share/fonts/FiraCode.zip -d ~/.local/share/fonts/FiraCode
  fc-cache -fv

  echo "Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y

  echo "Applying Catppuccin Powerline Starship preset..."
  mkdir -p ~/.config
  starship preset catppuccin-powerline -o ~/.config/starship.toml
  echo 'eval "$(starship init zsh)"' >> ~/.zshrc
}

do_codecs() {
  echo "=> Aktivieren von Cisco OpenH264-Repo"
  sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
  echo "=> Ersetze ffmpeg-free durch volles ffmpeg"
  sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
  echo "=> Multimedia-Gruppe aktualisieren (ohne schwache Abhängigkeiten)"
  sudo dnf update -y @multimedia --setopt="install_weak_deps=False" \
    --exclude=PackageKit-gstreamer-plugin
}

do_gaming() {
  echo "=> Gaming Tools und NVIDIA-Treiber"
  check_install steam
  check_install lutris
  dialog --yesno "NVIDIA-Treiber installieren?" 7 50
  if [ "$?" -eq 0 ]; then
    check_install akmod-nvidia
    check_install xorg-x11-drv-nvidia-cuda
  fi
}

do_extras() {
  echo "=> Weitere Programme"
  check_install btop
  check_install obs-studio
  check_install java-latest-openjdk
  check_install java-latest-openjdk-devel
  check_install krita
  check_install fastfetch
  check_install alacritty
  check_install kitty
  check_install stow
}

do_brave_code() {
  echo "=> Brave & VS Code"
  check_install dnf-plugins-core
  sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  check_install brave-browser

  if ! rpm -q code >/dev/null 2>&1; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'cat > /etc/yum.repos.d/vscode.repo' <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf check-update
    sudo dnf install -y code
  fi
}

do_theme() {
  apply_kde_theme
}

do_all() {
  do_system
  remove_gnome
  do_flatpak
  do_zsh
  do_codecs
  do_extras
  do_brave_code
  do_theme
}

# ───── Menü mit dialog ─────
while true; do
  CHOICE=$(dialog --clear --backtitle "Fedora KDE Post‑Install" \
    --menu "Wähle, was installiert werden soll:" 20 60 11 \
    1 "Systemupdate + RPM Fusion" \
    2 "Flatpak-Programme" \
    3 "Zsh, Plugins, Font, Starship" \
    4 "Multimedia-Codecs" \
    5 "Gaming & GPU-Treiber" \
    6 "Weitere Programme" \
    7 "Brave & Visual Studio Code" \
    8 "KDE Theming anwenden" \
    9 "Alles installieren (ohne Gaming)" \
    0 "Beenden" 2>&1 >/dev/tty)

  clear
  case "$CHOICE" in
    1) do_system ;;
    2) do_flatpak ;;
    3) do_zsh ;;
    4) do_codecs ;;
    5) do_gaming ;;
    6) do_extras ;;
    7) do_brave_code ;;
    8) do_theme ;;
    9) do_all ;;
    0) echo "Skript beendet. Viel Spaß mit Fedora KDE!" ; exit 0 ;;
  esac

  echo "\nDrücke eine Taste, um zurück zum Menü zu gelangen..."
  read dummy

done
