# Step Saga update: ranks, rank-gated shop, armor art, equipment tab

## 1. Install (do these in order)
1. Unzip over your project root (D:\new_step_saga). It adds/replaces:
   - lib/models/shop_model.dart   (adds `price`)
   - lib/models/slots.dart        (NEW, shared slot helpers)
   - lib/services/rank_service.dart   (NEW)
   - lib/services/player_service.dart (replaces)
   - lib/services/auth_service.dart   (replaces)
   - lib/screens/steps_screen.dart, shop_screen.dart, character_screen.dart (replace)
   - assets/images/gear/  (54 armor pictures)
2. pubspec.yaml: Flutter does NOT include sub-folders, so list the gear folder too:

       flutter:
         uses-material-design: true
         assets:
           - assets/images/
           - assets/images/gear/

3. Firestore -> Rules: paste firestore.rules and Publish. NEW: it adds
   players/<uid>/inventory (needed for buying). Without it, Buy fails with
   "permission denied".
4. Upload shop.json to your GitHub shop repo (replace the old shop.json at
   https://raw.githubusercontent.com/Jomarc-Orogo/shop/main/shop.json).
   GitHub's raw links cache for a few minutes.
5. Stop the app, `flutter run` (not hot reload).

No new packages. dashboard_screen.dart and main.dart are unchanged.

## 2. Rank system (lifetime steps on the account)
Rank = total steps ever walked (saved to players/<uid>.lifetimeSteps every
30 s and when you leave Track Steps). Converting steps to gold does NOT reduce
rank.

| Rank      | Lifetime steps | Color  |
|-----------|----------------|--------|
| Newbie    | 0              | grey   |
| Advance   | 50,000         | green  |
| Masterful | 200,000        | blue   |
| Elite     | 600,000        | purple |
| Legendary | 1,500,000      | orange |
| Mythical  | 4,000,000      | red    |

Change the numbers in RankService.thresholds. Rank is by steps only for now;
PvP wins can be added later (e.g. rank = steps + wins x bonus).

Testing ranks fast: in Firestore -> players -> <your uid>, edit the number
field `lifetimeSteps` (e.g. 60000 = Advance). The app updates live.

## 3. Shop rules
- Validation: a player only sees items from 1 tier below to 1 tier above their
  rank (Newbie sees Newbie+Advance, Elite sees Masterful+Elite+Legendary, ...).
  The same check runs again when buying, so it can't be bypassed from the UI.
- Random stock: each day, each slot shows 4 random items from the allowed
  tiers. Seed = today's date + rank + slot, so everyone at the same rank sees
  the same stock that day, and it reshuffles at midnight (phone time).
  Change `_perSlotStock` in shop_screen.dart for more/fewer items.
- shop.json has 324 items: 6 tiers x 9 slots x 6 items, with prices, sockets
  and allowed gem stats. Prices by tier: ~80-190 / 290-740 / 920-2.3k / 2.6k-6.4k
  / 6.5k-16k / 15k-36k gold (10 steps = 1 gold).
- Buying removes the gold and adds the item to players/<uid>/inventory.

## 4. Equipment tab
Character & Equip now shows a slot layout (helm, body armor, pauldrons, gloves,
belt, leggings, boots, necklace, 8 rings) and a backpack. Tap a backpack item
-> Equip; tap an equipped slot -> Unequip. Sockets are drawn as linked circles
on the gear; their colors hint at the gem stat they accept.

## 5. Things I assumed (please check)
- "Class armor pictures" = one picture per armor slot, recolored per rank.
  If you meant per-CLASS art (warrior/mage/...), tell me the classes.
- shop.json now follows your Slot & Socketing rules: allowed gems per slot,
  and sockets of 2/3/3/4/4/5 (body armor, leggings), 1/2/2/3/3/4 (belt),
  2 (helm, gloves, boots) and 1 (pauldrons). Stat IDs: hp_flat,
  hp_regen_flat, hp_regen_%, armor_flat, mp_flat, mp_regen_flat, mp_regen_%,
  ATK_flat, ATK_%, ATK_speed_flat, ATK_speed_%, evasion_%, precision_%,
  movement_speed_flat, resistance_blunt/piercing/slash/elemental.
- The JSON only lists which gems a slot ACCEPTS and how many sockets it has.
  Rules like "no duplicate stats", "only 1 resistance", and "gloves: one ATK +
  one ATK Speed, not flat and % of the same stat" still have to be enforced
  where gems get socketed (Equipment.canSocketGem in game_models.dart).
- Necklaces and rings have 0 sockets and no gems because their rules aren't
  defined yet. Give them sockets/stats in shop.json once you decide.
- No weapon slots yet (your slot list didn't have any).

## 6. Security caveat
Rank, gold and purchases are calculated on the phone, and the rules let a
player edit their own profile, so a determined player could cheat. Fine for a
demo; for release, move step syncing, conversion and buying into Cloud
Functions and lock those fields in the rules.
