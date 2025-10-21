# Status Bar Icon Setup Instructions

## To Add Your Custom Green Orb Icon:

### Quick Steps:

1. **Save the green orb image** you provided to these files:
   - `StatusBarIcon.png` (recommended: 18x18 or 32x32 pixels)
   - `StatusBarIcon@2x.png` (recommended: 36x36 or 64x64 pixels)
   - `StatusBarIcon@3x.png` (recommended: 54x54 or 96x96 pixels)

   *You can use the same image for all three if needed - just rename it 3 times.*

2. **Place the files here:**
   ```
   /Users/kealanjones/Desktop/Notch/NotchToDo/NotchToDo/Assets.xcassets/StatusBarIcon.imageset/
   ```

3. **Add to Xcode project** (if needed):
   - Open the Xcode project
   - In the Project Navigator, locate `Assets.xcassets`
   - If it's not there, right-click on the `NotchToDo` folder → Add Files to "NotchToDo"
   - Select the `Assets.xcassets` folder
   - Make sure "Copy items if needed" is checked
   - Click "Add"

4. **Rebuild the app** - The custom icon will now appear in the status bar!

### Notes:
- The icon will be rendered as a **template** (monochrome) to match macOS status bar style
- If the custom icon files are not found, the app will fallback to the system `mic.circle` icon
- The icon renders as white in light mode and black in dark mode (standard macOS behavior)

### What's Already Done:
✅ Assets.xcassets folder structure created
✅ Contents.json files configured
✅ AppDelegate updated to load custom icon
✅ Fallback to system icon if custom not found
✅ Build succeeded - ready for custom icon files
