Dependencies:

Quickshell (Development version / Git): The core shell environment framework.

Qt 6 (Qt Quick, Qt Qml): Provided natively with Quickshell.

Hyprland: The Wayland compositor required for Quickshell.Hyprland and window management dispatching.

Wayland Protocols & Compositor Support: Specifically supporting wlr-screencopy-unstable-v1 or equivalent screencopy protocols used by ScreencopyView for window previews.

Desktop File Utilities / GLib: Required for DesktopEntries lookup functionality to resolve application icons and IDs.
Qt.formatDateTime support: Uses QML's built-in date/time formatting utilities, which require no external binaries or packages beyond standard Qt QML modules.

QtQuick.Layouts: QML module required for RowLayout elements and layout alignment properties.

Quickshell.Services.Mpris: Quickshell service module imported for media integration.

playerctl: CLI utility invoked via the Process component to query active media player metadata ({{artist}} - {{title}}).

cava: Console audio visualizer CLI tool used to stream spectrum data bars for the audio visualizer block.

Nerd Font: Specifically JetBrainsMono Nerd Font (or any compatible Nerd Font) to correctly render the custom glyphs and icons (󰝚, ⣀, workspace icons, etc.).

Quickshell Services: Quickshell.Services.Pipewire, Quickshell.Services.UPower, Quickshell.Services.SystemTray, and Quickshell.DBusMenu for audio, tray management, and DBus menus.

pavucontrol: PulseAudio/PipeWire volume control utility.

systemd: Standard system management utilities used for power control (poweroff, reboot, suspend, hibernate).

Core Utilities: Standard POSIX/Linux commands used in inline processes (free, cat /proc/stat, bash).

Quickshell.Widgets: QML module required for the IconImage component used to render crisply-scaled tray icons.

StatusNotifier / System Tray Protocol: A running DBus StatusNotifierWatcher implementation (often provided by a notification daemon or desktop environment service) for SystemTray.items to populate.
