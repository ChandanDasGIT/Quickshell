make sure the scripts (from .config/scripts) are executable.

//inside the .config/scripts directory:
chmod +x workspace_swap.sh
chmod +x toggle_notes.sh
chmod +x change_wallpaper.sh

#Install quickshell

    1. arch: yay -S quickshell-git
    
    2. fedora: sudo dnf copr enable -y solopasha/hyprland
    
               sudo dnf install -y quickshell

#if update breaks quickshell

    sudo dnf downgrade ~/rpm-backups/quickshell-0.3.1-2.fc44.x86_64.rpm

#wallpaper location:
    ~/Pictures/Wallpapers/

#Required Installs:

    1. Arch:
        sudo pacman -S --needed \
        quickshell qt6-5compat qt6-declarative qt6-wayland qt6-imageformats \
        ttf-jetbrains-mono-nerd papirus-icon-theme \
        pipewire wireplumber upower \
        cava playerctl pavucontrol jq fd fzf xdg-utils merkuro
        
    2. Fedora:
        # Enable Nerd Fonts repo
            sudo dnf copr enable -y che/nerd-fonts

        # Install dependencies
            sudo dnf install -y \
            quickshell \
            qt6-qt5compat qt6-qtdeclarative qt6-qtwayland qt6-qtimageformats \
            nerd-fonts-JetBrainsMono papirus-icon-theme \
            pipewire wireplumber upower \
            cava playerctl pavucontrol jq fd-find fzf xdg-utils merkuro


