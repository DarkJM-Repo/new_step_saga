# Basic step counter setup

## 1. Packages
    flutter pub add pedometer permission_handler

## 2. Files
- lib/screens/steps_screen.dart      (new)
- lib/screens/dashboard_screen.dart  (updated: Track Steps now opens StepsScreen)

## 3. Android: android/app/src/main/AndroidManifest.xml
Inside <manifest> (above <application>):

    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>

## 4. iOS: ios/Runner/Info.plist
    <key>NSMotionUsageDescription</key>
    <string>Step Saga counts your steps to power your adventure.</string>

And in ios/Podfile, inside post_install -> build_configurations, add:

    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
      '$(inherited)',
      'PERMISSION_SENSORS=1',
    ]

## 5. Run on a REAL phone
Emulators/simulators have no step sensor, so the count stays at 0. In debug
builds the screen shows a "+100 steps (debug only)" button so you can still
demo the UI; it disappears in release builds.

Do a full rebuild after the native changes (not hot reload).

## How it works / limits
- The phone sensor reports a running total since boot. The screen records the
  first value as a baseline and shows steps since the screen opened.
- Counting only happens while this screen is open, and resets each time.
- Distance uses ~0.762 m per step.

## Natural next steps
- Save steps/distance to players/<uid>/totalMileageKm so leaderboards work.
- Keep a daily total (store date + baseline) so steps persist across sessions.
- Spend steps as in-game currency.
