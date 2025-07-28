# 🐧 Fedora Setup

**Fedora Post-Install Script – automatischer System‑Setup für Fedora Workstation**

---

## 🧰 Beschreibung

Dieses Repository enthält Skripte und Konfigurationsdateien, um ein frisch installiertes Fedora‑System nach deinen persönlichen Anforderungen automatisch einzurichten.

---

## 📁 Inhalt & Struktur

- `setup.sh`: Hauptinstallationsskript  
- `config/`: Konfigurationsdateien für Terminal, Shell (z. B. Alacritty, Zsh)  
- Weitere Module oder Ordner für spezifische Tools oder Apps  

---

## ✅ Voraussetzungen

- Vorinstalliertes Fedora (Workstation empfohlen)  
- Terminalzugriff mit **sudo**‑Rechten  
- Grundkenntnisse im Umgang mit der Shell  

---

## 🛠️ Installation & Nutzung

```bash
git clone https://github.com/kjuvis/fedora-setup.git
cd fedora-setup
chmod +x setup.sh  # falls nötig
./setup.sh
