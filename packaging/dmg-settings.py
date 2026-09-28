# dmgbuild settings for the OpenVault disk image.
#
# dmgbuild writes .DS_Store itself: the Finder/AppleScript route for the
# background picture is silently ignored on current macOS.
#
# Paths come from -D defines so the lane can pass absolute ones.

import os.path

application = defines["app"]
appname = os.path.basename(application)

format = "UDZO"
compression_level = 9
size = None

files = [application]
symlinks = {"Applications": "/Applications"}

background = defines["background"]

# Window content is 640x400; the background is drawn larger so resizing still
# shows it.
window_rect = ((200, 120), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 128

# Mirrored in packaging/dmg-background.swift, which draws the arrow between them.
icon_locations = {
    appname: (170, 190),
    "Applications": (470, 190),
}
