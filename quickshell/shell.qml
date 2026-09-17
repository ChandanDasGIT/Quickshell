//@ pragma UseQApplication
import Quickshell
import "modules/dock"
import "modules/bar"
import "modules/wallpaper"
import "modules/applauncher"
import "modules/notifications"

ShellRoot {
    Dock {}
    Bar {}
    AppLauncher {}
    Notifications {}
}
