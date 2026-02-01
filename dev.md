### Quick start (run in Simulator)

1. In Xcode, open the actual Xcode project (not the repo folder):
   - Open `Lifting/Lifting.xcodeproj`

2. Select the scheme + simulator:
   - Top toolbar dropdown (next to the Play button):
     - **Scheme**: `Lifting`
     - **Device**: `iPhone 17 Pro Max (Clone 1)` (or whichever you want)

3. Run:
   - Click the **Play** button, or press `Cmd+R`

If you don’t see the scheme/device dropdown or the Play button:
- Xcode → **View → Show Toolbar**
- Make sure you opened `Lifting/Lifting.xcodeproj` (opening the repo folder won’t show normal Run controls)

### If the app crashes (where to see the failure logs)

#### Xcode Debug Console (best)
- Open: **View → Debug Area → Activate Console** (`Cmd+Shift+Y`)
- Run again (`Cmd+R`)
- When it crashes, the exception + stack trace shows here.

#### Crash reports for the Simulator device
- Xcode → **Window → Devices and Simulators**
- Select your simulator (e.g. `iPhone 17 Pro Max (Clone 1)`)
- Use **Open Console** (live logs) and **View Device Logs** (crash reports)

### If you see a black screen
- First confirm you ran via Xcode (`Cmd+R`). Just opening Simulator doesn’t run the app.
- If it launches then disappears, it likely **crashed**: check the **Xcode Debug Console**.
- If Simulator itself is broken, restart it:
  - Simulator → **Device → Restart**
  - Last resort: **Device → Erase All Content and Settings…**

### Optional: command-line build/test

```bash
bash scripts/ios.sh list
bash scripts/ios.sh build
bash scripts/ios.sh test
```

