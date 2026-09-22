//@ pragma UseQApplication
import Quickshell
import "modules/dock"
import "modules/bar"
import "modules/wallpaper"
import "modules/applauncher"
import "modules/notifications"
import "modules/workspace"
import "modules/SearchFiles"

ShellRoot {
    readonly property var _wallpaperInit: Wallpaper.currentPath
    readonly property var _wsPickerInit: WorkspacePicker.pickerVisible

    Dock {}
    Bar {}
    AppLauncher {}
    Notifications {}
    SearchFiles {}
}
