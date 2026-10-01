# Overload DPO — iPhone Dynamic Island & Live Activities Setup

This project is now configured as a hybrid iOS app powered by Capacitor with native **ActivityKit** and **WidgetKit** support for the **Dynamic Island** and **Lock Screen Live Activities**.

---

## What Has Been Configured

1. **Capacitor iOS App**:
   - `capacitor.config.json` configured with Bundle ID `com.overload.fitnessapp`.
   - Web assets auto-synced from `index.html` -> `www/` -> `ios/App/App/public/`.
   - `Info.plist` updated with `NSSupportsLiveActivities = YES` and `NSSupportsLiveActivitiesFrequentUpdates = YES`.

2. **Native Dynamic Island & ActivityKit Code**:
   - `ios/App/App/WorkoutAttributes.swift`: Shared `ActivityAttributes` data model (exercise name, set index, total sets, weight, reps, rest timer timestamp).
   - `ios/App/App/LiveActivityPlugin.swift`: Native Swift Capacitor bridge exposing `startActivity`, `updateActivity`, and `endActivity`.
   - `ios/App/WorkoutWidgets/WorkoutLiveActivityWidget.swift`: SwiftUI Widget implementing:
     - **Dynamic Island Compact Leading**: Mini gym figure & set indicator (`S1`, `S2`, `S3`).
     - **Dynamic Island Compact Trailing**: Real-time live countdown timer (`01:45`) or target weight.
     - **Dynamic Island Minimal**: Mini timer or dumbbell icon.
     - **Dynamic Island Expanded**: Rich multi-column card with exercise name, target reps, current weight, and animated countdown bar.
     - **Lock Screen Banner**: Standalone Live Activity card for the Always-On display.

3. **Web App Integration (`index.html`)**:
   - `LiveActivityBridge` automatically hooks into `renderFocusedExercise()`, `startRestTimer()`, `stopRestTimer()`, and workout completion.

---

## How to Build & Run on Your Mac

### 1. Transfer Project to Your Mac
Copy the project folder to your Mac (via AirDrop, Git repository, or USB drive).

### 2. Install & Sync
In the project directory on your Mac terminal:
```bash
npm install
npm run sync
npx cap open ios
```
This will open the project in **Xcode**.

### 3. Add the Widget Extension Target in Xcode
1. In Xcode, click **File > New > Target...**
2. In the template sheet, search for **Widget Extension** and click **Next**.
3. Configure the target:
   - **Product Name**: `WorkoutWidgets`
   - **Include Live Activity**: ✅ Checked
   - **Include Configuration App Intent**: Unchecked (optional)
4. Click **Finish**, and choose **Activate** if prompted to activate the scheme.

### 4. Link the Swift Files to the Extension Target
1. In the Xcode Project Navigator on the left, expand `App > App` and find `WorkoutAttributes.swift`.
   - In the right-hand **File Inspector** panel, under **Target Membership**, check **BOTH**:
     - `App`
     - `WorkoutWidgetsExtension`
2. Delete the default placeholder widget code in `WorkoutWidgets/WorkoutWidgets.swift` (or delete the file) and replace it with the code from:
   - `ios/App/WorkoutWidgets/WorkoutLiveActivityWidget.swift`
   (Make sure its Target Membership is set to `WorkoutWidgetsExtension`).

### 5. Run the App
1. In the Xcode scheme selector at the top, select **App** and choose any Dynamic Island simulator (e.g., **iPhone 16 Pro**, **iPhone 15 Pro**) or your connected physical iPhone.
2. Press **Cmd + R** to run.
3. In the app:
   - Pick any split or exercise.
   - Start a rest interval or advance sets.
   - Swipe up to go to the Home Screen or Lock Screen — you will immediately see the **Dynamic Island** and **Live Activity** running live!
