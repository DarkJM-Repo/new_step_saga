# Landscape lock: native config

`main.dart` already locks orientation with `SystemChrome.setPreferredOrientations`,
which is enough on both platforms for most devices. For a rock-solid lock (no
portrait flash at startup), also set the native config:

## Android: android/app/src/main/AndroidManifest.xml
Add `android:screenOrientation="sensorLandscape"` to the main `<activity>`:

    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:screenOrientation="sensorLandscape"
        ... >

## iOS: ios/Runner/Info.plist
Replace the iPhone orientation list with landscape only:

    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

(If you also ship on iPad, apply the same to `UISupportedInterfaceOrientations~ipad`.)

After changing native files, stop the app and run a full rebuild (`flutter run`),
not a hot reload/restart.
