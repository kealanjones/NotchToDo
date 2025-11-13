# How to Find the NotchToDo Target in Xcode

## Step-by-Step Instructions

### 1. Open the Project
- Double-click `NotchToDo.xcodeproj` to open in Xcode
- Or: File → Open → Navigate to the project

### 2. Find the Target in the Project Navigator
The target is in the left sidebar (Project Navigator):

1. **Look at the left sidebar** - this is the Project Navigator
2. You'll see a blue project icon at the top: **NotchToDo** (this is the PROJECT)
3. Click on this blue project icon once to select it

### 3. Open the Target Settings
After clicking the project icon:

1. **Look at the main editor area** (center pane)
2. You'll see a list with two main items:
   - **PROJECT** - "NotchToDo" (blue icon)
   - **TARGETS** - "NotchToDo" (white app icon with blue background)

3. **Click on "NotchToDo" under TARGETS** (the one with the app icon)

### 4. Access Signing & Capabilities
Once you've selected the target:

1. **Look at the top of the main editor area**
2. You'll see tabs like:
   - General
   - **Signing & Capabilities** ← Click this one
   - Build Settings
   - Build Phases
   - Build Rules
   - Info

3. **Click "Signing & Capabilities"** tab

### 5. Enable Signing
In the Signing & Capabilities tab:

1. Find the **"Signing"** section
2. Check ☑ **"Automatically manage signing"**
3. Select your **Team** from the dropdown
   - If you don't have a team, click **"Add Account..."**
   - Sign in with your Apple ID (free for development)

## Visual Guide

```
┌─────────────────────────────────────┐
│ Left Sidebar (Project Navigator)    │
│                                     │
│  📁 NotchToDo (blue icon) ← highlight│
│     Click here                      │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│ Main Editor Area                    │
│                                     │
│  PROJECT                            │
│    📘 NotchToDo                     │
│                                     │
│  TARGETS                            │
│    📱 NotchToDo ← Click this!      │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│ Target Editor (Tabs at top)         │
│                                     │
│ [General] [Signing & Capabilities]  │
│         ↑                           │
│    Click here                       │
└─────────────────────────────────────┘
```

## Quick Alternative Method

If you can't find it:

1. In Xcode, press **⌘1** (Command + 1) to focus the Project Navigator
2. Click the **blue project icon** at the very top
3. In the main area, look for **TARGETS** section
4. Click **NotchToDo** under TARGETS
5. Click **"Signing & Capabilities"** tab at the top

## Troubleshooting

**"I don't see TARGETS section"**
- Make sure you clicked the **blue project icon** in the left sidebar
- Not a folder/file inside the project, but the project itself

**"I see the target but no Signing tab"**
- Make sure you selected the target under "TARGETS" (not "PROJECT")
- The tabs appear when a target is selected

**"Where is the left sidebar?"**
- Press **⌘1** (Command + 1) to toggle Project Navigator
- Or: View → Navigators → Show Project Navigator



