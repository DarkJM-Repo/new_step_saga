# Steps -> Gold conversion

## Files
- lib/services/player_service.dart  (new)  rate + balance stream + convert
- lib/screens/steps_screen.dart     (replaces previous version)
- lib/screens/shop_screen.dart      (replaces previous version; keeps slot filters)

No new packages. Dashboard needs no change.

## How it works
- Rate: 10 steps = 1 gold. Change `PlayerService.stepsPerGold` to rebalance.
- "Convert to N gold" appears on the Track Steps screen once you have 10+
  unconverted steps. Tapping it adds N gold to players/<uid>/currency using an
  atomic server-side increment.
- Only whole gold is paid: leftover steps (e.g. 7) stay available and carry
  into the next conversion while the screen is open.
- The gold balance in the Track Steps and Marketplace title bars is live, so
  converting updates both instantly.

## Important
- The dashboard still passes `currentCurrency: 1500` to ShopScreen, but that's
  now only a loading placeholder. The real balance comes from Firebase.
- Accounts created BEFORE you added auth have no profile and start at 0 gold.
  New sign-ups start at 1500 (set in AuthService.signUp). To top up an old
  account: Firebase console -> Realtime Database -> players/<uid> -> add
  `currency: 1500`.
- Steps reset when you leave the Track Steps screen, and any unspent steps are
  lost then. Convert before leaving (or we can add daily persistence next).
- Conversion is calculated on the phone. For a real release, validate it with
  a Cloud Function so players can't edit their own balance; the current rules
  (owner can write their own profile) allow that.
- In debug builds the "+100 steps" button feeds the converter, so you can demo
  earning gold on an emulator.
