#!/bin/sh
set -eu
IFS='\n\t'

# ───── Voraussetzungen ─────
command -v dialog >/dev/null 2>&1 || sudo dnf install -y dialog
command -v wget >/dev/null 2>&1 || sudo dnf install -y wget
command -v unzip >/dev/null 2>&1 || sudo dnf install -y unzip

echo "install zsh weil sauer auf script hier"
echo "🛠️ Installing Git and Zsh..."
sudo dnf install git zsh -y

echo "⚙️ Setting Zsh as default shell..."
chsh -s $(which zsh)

echo "💡 Preparing Zsh plugins..."
touch ~/.zshrc
mkdir -p ~/.zsh/plugins

git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ~/.zsh/plugins/zsh-completions

echo "📜 Updating .zshrc with plugin configuration..."
cat << 'EOF' >> ~/.zshrc

# Plugin Paths
fpath+=~/.zsh/plugins/zsh-completions

# Load Plugins
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
autoload -Uz compinit && compinit
EOF


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

install_alacritty_config() {
  echo "=> Installiere Alacritty-Konfiguration..."
  mkdir -p ~/.config/alacritty
  cp ./config/alacritty/alacritty.yml ~/.config/alacritty/
  echo "✓ Alacritty-Konfiguration kopiert."
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

do_codecs() {
  echo "=> Aktivieren von Cisco OpenH264-Repo"
  sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
  echo "=> Ersetze ffmpeg-free durch volles ffmpeg"
  sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
}

do_GPU_Driver_Nvidia() {
  echo "=> NVIDIA-Treiber"
  dialog --yesno "NVIDIA-Treiber installieren?" 7 50
  if [ "$?" -eq 0 ]; then
    sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda -y
    
  fi
}

do_extras() {
  echo "=> Weitere Programme"
  sudo dnf install btop obs-studio java-latest-openjdk java-latest-openjdk-devel krita fastfetch steam lutris alacritty stow -y
}

do_brave_code() {
  echo "VS-Code"
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 
  sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo' 
  sudo dnf check-update -y
  sudo dnf install code -y
  echo "Brave"
  sudo dnf install dnf-plugins-core -y
  sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo -y
  sudo dnf install brave-browser -y

}

do_theme() {
  apply_kde_theme
}

do_all() {
  do_system
  remove_gnome
  do_flatpak
  do_codecs
  do_extras
  do_brave_code
  do_theme
  install_alacritty_config
}

# ───── Menü mit dialog ─────
while true; do
  CHOICE=$(dialog --clear --backtitle "Fedora KDE Post‑Install" \
    --menu "Wähle, was installiert werden soll:" 20 60 12 \
    1 "Systemupdate + RPM Fusion" \
    2 "Flatpak-Programme" \
    4 "Multimedia-Codecs" \
    5 "Alacritty Konfiguration kopieren" \
    6 "Weitere Programme" \
    7 "Brave & Visual Studio Code" \
    8 "KDE Theming anwenden" \
    9 "Alles installieren (ohne GPU-Treiber)" \
    10 "GPU-Treiber" \
    0 "Beenden" 2>&1 >/dev/tty)

  clear
  case "$CHOICE" in
    1) do_system ;;
    2) do_flatpak ;;
    4) do_codecs ;;
    5) install_alacritty_config ;;
    6) do_extras ;;
    7) do_brave_code ;;
    8) do_theme ;;
    9) do_all ;;
    10) do_GPU_Driver_Nvidia ;;
    0) echo "Skript beendet. Viel Spaß mit Fedora KDE!" ; exit 0 ;;
  esac

  echo "\nDrücke eine Taste, um zurück zum Menü zu gelangen..."
  read -n1 -r -p ""

done
