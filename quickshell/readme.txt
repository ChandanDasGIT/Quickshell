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

#Quickshell shortcuts for hyprland.lua
    --QUICKSHELL bindings
        hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("qs ipc call dock toggle"))
        hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("qs ipc call applauncher toggle"))
        hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle"))
        hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call workspaces toggle"))
        hl.bind(ctrlMod .. " + SHIFT + Space", hl.dsp.exec_cmd("quickshell ipc call fileSearch toggle"))


Future:

~/.config/quickshell/
├── shell.qml                  # Entry point — wires components and services together
├── qmldir                     # Optional: registers local directories as a module
├── config/
│   └── Settings.qml           # Global configuration (margins, colors, fonts)
├── services/                  # Background logic, daemons, and IPC handlers
│   ├── AudioService.qml       # PipeWire / Volume bindings
│   ├── NetworkService.qml     # Wi-Fi / Bluetooth status
│   └── MprisService.qml       # Media player tracking
├── common/                    # Reusable atom components / design system
│   ├── CustomButton.qml
│   ├── StyledText.qml
│   └── PopupWindow.qml
└── modules/
    ├── bar/
    │   ├── Bar.qml            # Main bar coordinator container
    │   ├── LeftSection.qml    # Workspaces / App launcher trigger
    │   ├── CenterSection.qml  # Clock / Media ticker
    │   └── RightSection.qml   # System tray, volume, battery
    ├── dock/
    │   └── Dock.qml           # Application dock / taskbar
    ├── notifications/
    │   ├── NotificationCenter.qml
    │   └── NotificationPopup.qml
    └── osd/
        └── VolumeOSD.qml      # On-screen display for volume/brightness
