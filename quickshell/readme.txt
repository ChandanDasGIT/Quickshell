current

~/.config/quickshell/
├── shell.qml          # entry point — just wires modules together
├── modules/
│   ├── dock/
│   │   └── Dock.qml
│   ├── bar/
│   │   └── Bar.qml
|   |   └── CenterSection.qml
|   |   └── LeftSection.qml
|   |   └── rightSection.qml
│   └── notifications/
│       └── NotificationCenter.qml

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
