# Switching Step Saga from Realtime Database to Cloud Firestore

## 1. Packages (project root)
    flutter pub remove firebase_database
    flutter pub add cloud_firestore

Run `flutter pub upgrade` if the FlutterFire versions clash.
cloud_firestore needs Android minSdk 23 or higher. If the build complains, set
`minSdk = 23` (or `minSdkVersion 23`) in android/app/build.gradle(.kts).
The first build after adding it is slow; that's normal.

## 2. Files (replace existing)
- lib/services/auth_service.dart    sign-up now writes players/<uid> in Firestore
- lib/services/player_service.dart  balance stream + steps->gold use Firestore
- lib/services/api_controller.dart  marketplace create/update/delete use the
                                    `marketplace` collection (GET still reads
                                    the GitHub shop.json, unchanged)

No other screen changes: shop_screen and steps_screen only talk to
PlayerService, so they keep working.

## 3. Firestore rules (Console -> Firestore Database -> Rules)
Paste the contents of firestore.rules and press **Publish**. Until you do, the
database is either in test mode (open to everyone, expires after 30 days) or
production mode (blocks everything). Either way the app won't behave right.

## 4. Data layout
    players/<uid>
      displayName: string
      currency: number          (starts at 1500)
      totalMileageKm: number
      pvpKills: number
      pvpWins: number
      createdAt: timestamp
    marketplace/<auto-id>       (only if you use the admin CRUD calls)

You do NOT need to create these by hand: the player document appears when
someone signs up, and the collection shows up in the console automatically.

## 5. Existing data
- Realtime Database data is NOT copied over automatically. Existing accounts
  (Authentication users) still work, but they won't have a players/<uid>
  document until they earn gold: the first conversion creates it with only
  `currency`. To give an old account its full profile, add the fields above by
  hand in Firestore -> players -> Add document (Document ID = the user's UID
  from Authentication -> Users).
- You can leave the old Realtime Database alone or delete it once everything
  works.

## 6. Quick test
1. Sign up a new hero in the app.
2. Firestore Data tab should show players/<uid> with currency 1500.
3. Convert steps to gold; the `currency` field increases live.
