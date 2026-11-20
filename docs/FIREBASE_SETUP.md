# Linking Firebase Authentication to Step Saga

## 1. Firebase console (project: step-saga)
1. Open https://console.firebase.google.com and select **step-saga**.
2. **Build -> Authentication -> Get started**.
3. **Sign-in method** tab -> **Email/Password** -> enable -> Save.
4. (Later) Users appear under **Authentication -> Users** after they register.

## 2. Add packages (project root)
    flutter pub add firebase_auth firebase_database

If versions clash with firebase_core, run `flutter pub upgrade` so all three
FlutterFire packages update together.

## 3. Drop in the code
- lib/services/auth_service.dart   (new)
- lib/screens/login_screen.dart    (replaces your placeholder)
- lib/main.dart                    (adds AuthGate; keeps the landscape lock)

Then do a full rebuild (stop the app, `flutter run`).

## 4. Lock down the Realtime Database
Console -> **Build -> Realtime Database -> Rules**. If the rules are still in
"test mode" anyone on the internet can read and write your data. Use:

    {
      "rules": {
        "players": {
          ".read": "auth != null",
          "$uid": { ".write": "auth != null && auth.uid === $uid" }
        },
        "marketplace": {
          ".read": "auth != null",
          ".write": "auth != null"
        }
      }
    }

- `players/<uid>`: any signed-in user can read (needed for leaderboards), but
  only the owner can write their own profile.
- Tighten `marketplace` writes to admins only before release.

Your ApiController currently calls the marketplace REST endpoint without a
token. Once these rules are live, those calls get 401 unless you append
`?auth=<idToken>` (from `await FirebaseAuth.instance.currentUser!.getIdToken()`)
to the URL. The GET of shop.json from GitHub is unaffected.

## 5. Optional: sign-out button
Add to the Dashboard AppBar:

    actions: [
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => AuthService().signOut(),
      ),
    ],

AuthGate will return the player to the login screen automatically.
(Import '../services/auth_service.dart' in dashboard_screen.dart.)

## Notes
- The keys in firebase_options.dart are identifiers, not secrets. Security
  comes from the Authentication + Rules above.
- Google sign-in later needs your Android SHA-1/SHA-256 added in
  Project settings; Email/Password does not.
