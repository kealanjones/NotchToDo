TO ADD THE STATUS BAR ICON:

1. Save your green orb icon image as PNG files:
   - StatusBarIcon.png (18x18 or 32x32 pixels)
   - StatusBarIcon@2x.png (36x36 or 64x64 pixels)
   - StatusBarIcon@3x.png (54x54 or 96x96 pixels)

2. Place these files in this directory:
   /Users/kealanjones/Desktop/Notch/NotchToDo/NotchToDo/Assets.xcassets/StatusBarIcon.imageset/

3. The app will automatically load the custom icon when you rebuild.
   If the files are not found, it will fallback to the system mic.circle icon.

Note: The icon will be rendered as a template (monochrome) to match macOS status bar style.
