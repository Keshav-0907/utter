# Layout of the installer window, read by dmgbuild (see scripts/make-dmg.sh).
# Positions must match scripts/make-dmg-background.swift.

app = defines.get("app", "build/Utter.app")  # noqa: F821  (dmgbuild provides `defines`)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = "Resources/AppIcon.icns"

background = "Resources/dmg-background.tiff"
window_rect = ((240, 180), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

arrange_by = None
icon_size = 112
text_size = 13
label_pos = "bottom"
show_icon_preview = False
icon_locations = {
    "Utter.app": (170, 185),
    "Applications": (490, 185),
}
