#!/bin/bash
#  _______   _______
# |  _____| |  ___  |
# | |       | |   | |    Rolando Ramos Torres (@rolodoom)
# | |       | |___| |    http://rolandoramostorres.com
# |_|       |_______|
#  _         _______
# | |       |  ___  |
# | |       | |   | |    
# | |_____  | |___| |    
# |_______| |_______|    Debian 12 Pro Audio Setup
#


# Exit if any command fails
set -e

# Notify function
notify () {
  echo "--------------------------------------------------------------------"
  echo $1
  echo "--------------------------------------------------------------------"
}


# Function to add a given path to ~/.bash_aliases
add_path_alias() {
    local new_path="$1"  # Path passed as an argument
    local base_name=$(basename "$new_path")  # Extract the last component of the path
    local pattern="export PATH=\"$new_path:\$PATH\""
    local comment="$base_name added to ~/.bash_aliases"

    # Check if the pattern exists in ~/.bash_aliases (commented or uncommented)
    if ! grep -qF "$new_path" ~/.bash_aliases; then
        # Append the new path to ~/.bash_aliases with a descriptive comment
        {
            echo ''
            echo "# $comment"
            echo "$pattern"
        } >> ~/.bash_aliases
        echo "Path $new_path added to ~/.bash_aliases"
    else
        echo "Path $new_path is already present in ~/.bash_aliases"
    fi
}


# ---------------------------
# Enable contrib non-free
# ---------------------------
notify "Enable contrib non-free"
sudo sed -i '/^deb /s/$/ contrib non-free/' /etc/apt/sources.list
# NOTE: to undo use this: sudo sed -i '/^deb /s/ contrib non-free//g' /etc/apt/sources.list


# ---------------------------
# Update system
# ---------------------------
notify "Update the system"
sudo apt update && sudo apt upgrade -y
# Install core dependencies
sudo apt install wget curl -y


# ---------------------------
# Install Liquorix kernel
# https://liquorix.net/
# ---------------------------
notify "Install Liquorix kernel"
curl 'https://liquorix.net/add-liquorix-repo.sh' | sudo bash


# ---------------------------
# Pipewire
# https://wiki.debian.org/PipeWire
# ---------------------------
notify "Install pipewire"
sudo apt install pipewire pipewire-alsa pipewire-audio pipewire-audio-client-libraries pipewire-jack pipewire-pulse libspa-0.2-jack wireplumber -y
# Tell all apps that use JACK to now use the Pipewire JACK
sudo cp /usr/share/doc/pipewire/examples/ld.so.conf.d/pipewire-jack-*.conf /etc/ld.so.conf.d/
sudo ldconfig
# Latency on local user
mkdir -p ~/.config/pipewire
cp /usr/share/pipewire/jack.conf ~/.config/pipewire


# ---------------------------
# GRUB - CPU Governor Performance
# ---------------------------
notify "Modify GRUB options"
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet threadirqs cpufreq.default_governor=performance"/g' /etc/default/grub
sudo update-grub


# ---------------------------
# audio limits
# See https://wiki.linuxaudio.org/wiki/system_configuration for more information.
# ---------------------------
notify "Modify limits.d/audio.conf"
echo '# audio group
@audio           -       rtprio          90
@audio           -       memlock         unlimited' | sudo tee -a /etc/security/limits.d/audio.conf


# ---------------------------
# sysctl.conf
# See https://wiki.linuxaudio.org/wiki/system_configuration for more information.
# ---------------------------
notify "Create /etc/sysctl.d/99-custom.conf"
echo 'vm.swappiness=10
fs.inotify.max_user_watches=600000' | sudo tee /etc/sysctl.d/99-custom.conf
# Apply the changes
sudo sysctl --system


# ---------------------------
# Add the user to the audio group
# ---------------------------
notify "Add $USER to the audio group"
sudo usermod -aG audio $USER


# ---------------------------
# Add KXStudio Repository
# ---------------------------
notify "Add KXStudio Repository"
# Install dependencies
sudo apt update && sudo apt install apt-transport-https gpgv
# Install the Repo
wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_11.1.0_all.deb
sudo dpkg -i kxstudio-repos_11.1.0_all.deb
sudo apt update && sudo apt upgrade -y
rm -rf kxstudio-repos_*.deb


# ---------------------------
# Install audio software
# ---------------------------
notify "Install audio software"
# Install the basic software
sudo apt install kxstudio-meta-audio-plugins-vst carla ardour audacity soundconverter dragonfly-reverb lsp-plugins calf-plugins caps dpf-plugins tap-plugins zam-plugins eq10q ebumeter x42-plugins


# ---------------------------
# REAPER
# Note: The instructions below will create a REAPER installation
# at /opt/REAPER
# ---------------------------
# NOTE: When you run this script, there may be a newer version of REAPER available.
# Check https://www.reaper.fm/download.php and update the version numbers below if necessary
notify "Install REAPER"
REAPER_VERSION="729"
# Check the number of digits and extract the correct major version
if [ ${#REAPER_VERSION} -gt 3 ]; then
  REAPER_MAJOR_VERSION="${REAPER_VERSION:0:2}"
else
  REAPER_MAJOR_VERSION="${REAPER_VERSION:0:1}"
fi
# Generate the REAPER_BRANCH based on the major version
REAPER_BRANCH="${REAPER_MAJOR_VERSION}.x"
wget -O reaper.tar.xz "https://www.reaper.fm/files/${REAPER_BRANCH}/reaper${REAPER_VERSION}_linux_x86_64.tar.xz"
mkdir ./reaper
tar -C ./reaper -xf reaper.tar.xz
sudo ./reaper/reaper_linux_x86_64/install-reaper.sh --install /opt --integrate-desktop --usr-local-bin-symlink --quiet
rm -rf ./reaper
rm reaper.tar.xz


# ---------------------------
# MuseScore Studio 4 && Muse Sounds Manager
# Note: The instructions below will install latest MuseScore
# and Muse Sounds Manager Offiicla versions
# ---------------------------
notify "Install MuseScore Studio 4 && Muse Sounds Manager"
wget https://cdn.jsdelivr.net/musescore/v4.4.4/MuseScore-Studio-4.4.4.243461245-x86_64.AppImage
chmod +x MuseScore-Studio*.AppImage
./MuseScore-Studio-*.AppImage install

wget -O Muse_Sounds_Manager_x64.deb https://muse-cdn.com/Muse_Sounds_Manager_x64.deb
sudo apt install ./Muse_Sounds_Manager_x64.deb
rm Muse_Sounds_Manager_x64.deb


# ---------------------------
# Wine (stable)
# This is required for yabridge.
# See https://wiki.winehq.org/Debian for additional information.
# ---------------------------
notify "Install WineHQ (stable)"
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources
sudo apt update
sudo apt install --install-recommends winehq-stable -y
# Winetricks
sudo apt install cabextract winetricks -y
# Base wine packages required for proper plugin functionality
winetricks corefonts
# Make a copy of .wine, as we will use this in the future as the base of
# new wine prefixes (when installing plugins)
cp -r ~/.wine ~/.wine-base


# ---------------------------
# Yabridge
# Detailed instructions can be found at: https://github.com/robbert-vdh/yabridge/blob/master/README.md
# ---------------------------
# NOTE: When you run this script, there may be a newer version of yabridge available.
# Check https://github.com/robbert-vdh/yabridge/releases and update the version numbers below if necessary
notify "Install yabridge"
yabridge_version="5.1.1"
wget -O yabridge.tar.gz "https://github.com/robbert-vdh/yabridge/releases/download/${yabridge_version}/yabridge-${yabridge_version}.tar.gz"
mkdir -p ~/.local/share
tar -C ~/.local/share -xavf yabridge.tar.gz
rm yabridge.tar.gz
add_path_alias "$HOME/.local/share/yabridge"
. ~/.bash_aliases
# Create common VST paths
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
# Add them into yabridge
yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"


# ---------------------------
# FINISHED!
# Now just reboot, and make music!
# ---------------------------
notify "Done - please reboot."