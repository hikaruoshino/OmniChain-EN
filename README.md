# OmniChain (v7.4.3, English edition)

OmniChain is a Windower 4 addon for Final Fantasy XI. It watches the weapon skills your party uses, and the blood pacts and automaton moves of pets, and uses the first weapon skill (WS) on your priority list that continues the current skillchain. When no chain is open, it uses the top usable WS on your list to start one. It supports all 22 jobs and all 14 weapon types.

This is the English edition of [OmniChain](https://github.com/hikaruoshino/OmniChain), which is written in Japanese. The logic is the same as the Japanese v7.4.3. Messages, command help, the config editor and the data tables use the English names from the game's resources.

## Notice

This addon types weapon skills for you. Third-party tools, Windower included, are not permitted by the FFXI terms of service. Your account may be penalized, and the author takes no responsibility for any harm from using it. Use it at your own risk, and do not leave it running unattended.

I have used the Japanese v7.4.3 in game. This English build has only been run in a simulated environment, because I play on the Japanese client. Some situations (trusts, large alliances) are hard to test alone, so reports are welcome as GitHub issues. After loading, `//omni check` tells you whether every WS name on your list is recognized by the game; the English names are the part most likely to be wrong.

In game with the Japanese build, the Samurai six-step chain (Ageha, Jinpu, Shoha, Shoha, Kasha, Fudo) went through in Temenos, and alliance members' targets could be read.

## Installation

1. Download the repository (Code > Download ZIP) and unzip it. GitHub names the folder `OmniChain-EN-main`; rename it to `OmniChain`. The addon will not load under any other name.
2. Put the `OmniChain` folder in `Windower4/addons/`.
3. In game, run `//lua load OmniChain`. To load it at every login, add `lua load OmniChain` to `scripts/init.txt` in your Windower folder.

When updating, overwrite the files and run `//lua reload OmniChain`. Back up your own `omnichain_config.json` first.

Do not run the Japanese and the English edition together. They share the addon name and the commands.

The only requirement is Windower 4. The libraries used (`luau`, `config`, `texts`, `resources`, `packets`, `json`) all ship with it.

## What it does

- For each job you choose a weapon type and a WS priority list. When TP is at or above the minimum (default 1000), the addon uses the first WS that continues the chain.
- Chain rules follow [BG-Wiki: Skillchain](https://www.bg-wiki.com/ffxi/Skillchain). Light on Light and Darkness on Darkness each chain one more time. Nothing chains after Radiance or Umbra.
- `sc_dict.lua` holds the chain properties of about 220 weapon skills, 31 blood pacts and 12 automaton weapon skills.
- Chains are detected from the action packet (0x028). The chat line `Skillchain: <name>.` is only a fallback. It counts moves by party and alliance members and their pets, by trusts, and by players outside the party when they hit the enemy you are targeting. Enemy moves never open a window.
- Pet skills, WS you have not learned and WS for another weapon type are skipped. A WS that missed does not count as an opener.
- When an automatic WS fails (out of range, not enough TP, interrupted), the reason appears in chat. The same reason is shown at most once per 10 seconds.
- `//omni check` tests whether every WS on your list is usable right now. It also runs on load and on job change.
- The chain HUD shows the time left in the window and the next WS. It is hidden by default; `//omni hud on` shows it. Resize it with the mouse wheel over it, or by dragging the corner marker at the bottom right.
- `OmniChain_GUI.html` opens in a browser and lets you edit each job's weapon type, WS list and minimum TP, then export `omnichain_config.json`.

## How a WS is chosen

The addon acts only while you are engaged. It waits until TP is at the minimum and the delay since your last WS (default 1.2 s) has passed. After the game refuses a WS with "cannot see target", it waits 2 s before trying again.

1. If at least 3 people, you included, are targeting the same enemy, it skips chaining and uses the max-power WS at 1500 TP or more (`//omni focus`, see below).
2. It removes pet skills, WS you have not learned and WS for another weapon.
3. While a chain window is open, it goes down the priority list and uses the first WS that makes a skillchain. With `opener_only`, the first entry is tried last.
4. If nothing connects, it uses the top usable WS when `auto_mode` is `flexible` (the default). Otherwise it does nothing.
5. With no window open, the top usable WS starts a chain. In manual opener mode it waits for an opener instead.
6. If a party member is predicted to use a WS soon that your chosen WS would not let them continue, it is replaced by a WS that would (`//omni toss`).

Chains belong to an enemy. If the enemy with the chain is not your current target, the addon treats it as no window and starts from an opener again.

## Places with many enemies (v7.4)

**Other enemies are ignored.** In places such as the new Limbus, where many enemies are linked and killed one at a time, the people in your party are fighting different enemies. Counting their WS used to overwrite your enemy's chain state, erase it when their chain ended, and make you wait for their windows. Now only WS that land on the enemy you are targeting count.

**No WS out of reach (`//omni reach <distance>`).** Melee WS are used only when the distanceplus distance is 3.5 or less (range 1 to 8, default 3.5; for an enemy whose `model_size` is above 2, the distance is widened by the amount above 2). In game, a distance of 3.4 was within reach. Bows and guns use a distance that includes the enemy's size. distanceplus is a separate Windower addon; OmniChain calculates the same number itself and does not need it.

**Max-power WS (`//omni focus`).** When many people hit the same enemy, tossing and chaining are hard to line up. If at least 3 people, you included, target the same enemy, the addon stops chaining and uses the prime or empyrean WS, at 1500 TP or more.

- Party and alliance members count; trusts do not. People on other enemies do not stop it from switching.
- Change the head count with `//omni focuspeople <n>` (2 to 18, default 3) and the TP with `//omni focustp <TP>` (1000 to 3000, default 1500). `//omni focus off` turns it off.
- Other players' targets are read from `mob.target_index`. In my tests this worked for alliance members too.
- The WS is the prime WS if you wear a prime weapon, otherwise the empyrean WS for your weapon type, otherwise the first usable entry on your list. Dojikiri Yasutsuna uses Tachi: Shoha; that was my own choice.
- I know of no source that ranks WS by damage, so "max-power" here just means the prime or empyrean WS, and another WS may hit harder.

| Weapon type | Prime weapon | Prime WS | Empyrean WS |
| :--- | :--- | :--- | :--- |
| Hand-to-Hand | Varga Purnikawa | Maru Kala | Victory Smite |
| Dagger | Mpu Gandring | Ruthless Stroke | Rudra's Storm |
| Sword | Caliburnus | Imperator | Chant du Cygne |
| Great Sword | Helheim | Fimbulvetr | Torcleaver |
| Axe | Spalirisos | Blitz | Cloudsplitter |
| Great Axe | Laphria | Disaster | Ukko's Fury |
| Scythe | Foenaria | Origin | Quietus |
| Polearm | Gae Buide | Diarmuid | Camlann's Torment |
| Katana | Dokoku | Zesho Meppo | Blade: Hi |
| Great Katana | Kusanagi | Tachi: Mumei | Tachi: Fudo |
| Club | Lorg Mor | Dagda | Dagan |
| Staff | Opashoro | Oshala | Myrkr |
| Archery | Pinaka | Sarv | Jishnu's Radiance |
| Marksmanship | Earp | Terminus | Wildfire |

**Tossing (`//omni toss`).** Some players use the same WS again and again. The addon predicts their next WS and, when it is close, picks a WS that leaves a property that WS can continue. Trusts are excluded.

- A player qualifies if at least 60% of their last 8 WS were the same one. The next time is estimated from the median interval.
- It acts only when their next WS is 2.5 to 8 seconds away. Otherwise your list applies as usual.
- The goal is to leave a property they can continue. Whether they use their WS is up to them.
- In Temenos I tried it 8 times, and the other player continued the chain only once. They use their WS on their own timing, and 8 tries is a small sample, so treat it as a rough guide.
- `//omni toss off` turns it off.

## Playing with trusts (v7.3)

**Waiting for solo chains (`//omni solo`).** Some trusts perform a skillchain on their own, and an automatic WS from you in the middle would break it. When one of the trusts below uses its trigger ability, the addon holds its WS until the solo chain is over. The HUD shows "Waiting on solo chain: name (n s left)". It stops waiting if no first WS comes 12 seconds after the ability, or if 11 seconds pass between two WS.

| Trust | Trigger ability | End of the solo chain |
| :--- | :--- | :--- |
| Iroha / Iroha II | Meditate | Amatsu: Gachirin |
| Noillurie | Sekkanoki | Tachi: Kaiten |
| Gilgamesh | Sekkanoki | unknown (the wait ends when no WS follows within `solo_gap`) |
| Ark GK | Meditate, Hagakure, Sekkanoki | after 2 moves |

Tenzen also does solo chains, but the order changes every time and lasts about 40 seconds, so the addon does not wait for him. Healing and buff moves, such as Iroha's Rise From Ashes, do not count. `//omni solo off` turns the wait off.

**Moves that are not continued.** In my tests, a WS used after these moves did not chain, so the addon starts a new chain from an opener instead:

- Iroha / Iroha II's Gachirin: about 4 tests, WS 3 to 7 seconds later, none chained.
- Selh'teus's moves (Revelation, Luminous Lance): a WS 4 to 5 seconds later did not chain in 13 out of 13. I have not tested other intervals.

Trusts do chain with each other after these moves. The addon reads that result as usual and lets you continue it.

**Minimum wait (`//omni minfollow <sec>`).** The window opens about 3 seconds after a WS lands. A WS used before that does not chain and also breaks the chain for everyone else. So the addon waits `minfollow` seconds after the previous WS, anyone's, before using one. The default and the floor are 4 seconds, up to 8.

The window gets shorter as the chain goes on. The addon assumes 10 seconds minus the number of chains so far, with a floor of 4 seconds, and shortens the wait so that the WS is sent 2 seconds before the window closes (3.3 seconds at the shortest). With `minfollow` at 6, it still uses the WS 5 seconds after the third chain and 4 seconds after the fourth.

If every WS since the opener is yours and you have 3000 TP, it does not wait for `minfollow` and uses the WS 3.3 seconds in, when the window opens, so TP is not wasted. When others joined the chain, it waits as usual.

**Other behavior.**

- Aeonic Light or Darkness counts only while the aftermath is active. To close a Light or Darkness that someone else made, the addon prefers a WS that already has Light or Darkness itself, such as Tachi: Fudo.
- Chainbound: when an enemy is chainbound, the first WS from about 3 seconds later chains whatever the previous property was. The addon waits 3.3 seconds and prefers a WS that makes a Light or Darkness it can continue (Tachi: Kasha for a Samurai). A WS that lands within those 3 seconds neither chains nor counts as an opener.
- A trust's normal attack that arrives in the same packet form as a special move, as Ashera's does, is not read as a WS.
- A trust move wiped by an enemy's shadows is not treated as an opener.
- Jump, High Jump and similar abilities arrive in the same form as WS and are not mistaken for WS.

## Manual opener, opener-only WS and aeonic weapons (v7.2)

**Manual opener mode (`//omni start manual`).** By default (`//omni start auto`), the top WS on your list opens a chain. In manual mode you use the first WS yourself and the addon links the rest. The opener can also be another player's WS. The addon then waits `follow_wait` seconds (default 6, `//omni wait <sec>`, range 0 to 9) after the previous WS lands, instead of acting at once at 1000 TP. If another WS lands while it waits, it re-evaluates from that result and restarts the wait.

The window is 3 to 10 seconds after a WS ([BG-Wiki](https://www.bg-wiki.com/ffxi/Skillchain)) and gets 1 second shorter with each chain. The addon starts at 10 seconds and never waits past 2 seconds before the window closes. If a 6-second wait loses the chain, try `//omni wait 5`.

**Opener-only WS (`opener_only`).** A Samurai chain starts with Tachi: Ageha (Compression, Scission). After Detonation, Ageha and Tachi: Shoha both give Gravitation, and with Ageha at the top of the list the addon used it again. Setting `"opener_only": true` on a job makes the first entry on its list opener-only: during a chain the second and later entries are tried first, and the first entry is used only if none of them connects.

```json
"SAM": {
    "weapon": "Great Katana",
    "opener_only": true,
    "ws_priority": [
        "Tachi: Ageha",
        "Tachi: Shoha",
        "Tachi: Jinpu",
        "Tachi: Kasha",
        "Tachi: Fudo"
    ]
}
```

The sample config that ships with the addon already has this set up for Samurai.

The editor does not handle `opener_only`; add it to `omnichain_config.json` by hand.

**Aeonic weapons.** When you use that WS with your own aeonic weapon, the aftermath adds a Light or Darkness property to it, including the WS that triggers the aftermath. Tachi: Shoha, for example, is Fragmentation and Compression on an ordinary weapon, but Light, Fragmentation and Compression with Dojikiri Yasutsuna. The addon now includes that Light or Darkness when it judges your own WS. All 14 aeonic weapons are covered, from [BG-Wiki: REMA Cheat Sheet](https://www.bg-wiki.com/ffxi/REMA_Cheat_Sheet). Other players' weapons are unknown, so nothing is added to their aeonic WS.

**Also in v7.2.** If you kill the enemy mid-chain and auto-target the next one, the addon no longer continues the old chain; it remembers which enemy each chain belongs to. The chat line `Skillchain: <name>.` can arrive 4 to 7 seconds after the packet and used to overwrite the newer state, so packets are now the source of truth and the chat line is ignored for 10 seconds after a packet.

## Configuration

Open `OmniChain_GUI.html` in a browser, edit each job's weapon type and WS list (the top entry has the highest priority), and put the exported `omnichain_config.json` in the `OmniChain/` folder (or `OmniChain/data/`). Run `//omni reload` in game; the file is also read on job change.

From that file the addon reads `profiles` (weapon type and WS list), `min_tp` and `wait_delay`. Without it, `profiles` uses the built-in defaults, and `min_tp` and `wait_delay` come from `data/settings.xml`. The WS list is not stored in `settings.xml`.

Weapon types must be written exactly as: `Hand-to-Hand`, `Dagger`, `Sword`, `Great Sword`, `Axe`, `Great Axe`, `Scythe`, `Polearm`, `Katana`, `Great Katana`, `Club`, `Staff`, `Archery`, `Marksmanship`. WS names must match the game's English names, for example `Tachi: Shoha` or `Savage Blade`.

Settings in `data/settings.xml`:

| Setting | Default | Meaning |
| :--- | :--- | :--- |
| `enabled` | `true` | Auto skillchain on or off (`//omni on` / `off`) |
| `min_tp` | `1000` | Minimum TP to use a WS |
| `wait_delay` | `1.2` | Seconds to wait after a WS before the next one |
| `start_mode` | `auto` | `auto`: the first WS is automatic. `manual`: you use it (`//omni start`) |
| `follow_wait` | `6.0` | In `manual`, seconds after the previous WS lands before the auto WS (`//omni wait`) |
| `min_follow` | `4.0` | Minimum seconds after anyone's previous WS (`//omni minfollow`) |
| `focus_max` | `true` | Use the max-power WS when many people share a target (`//omni focus`) |
| `focus_people` | `3` | People needed, you included (`//omni focuspeople`) |
| `focus_tp` | `1500` | TP for the max-power WS (`//omni focustp`) |
| `toss` | `true` | Predict a party member's next WS and leave a property they can continue (`//omni toss`) |
| `ws_reach` | `3.5` | Distance at which melee WS may be used (`//omni reach`) |
| `trust_solo` | `true` | Hold WS while a solo-chain trust is working (`//omni solo`) |
| `solo_start_wait` | `12.0` | Seconds to wait for the trust's first WS after its ability (`//omni solo start`) |
| `solo_gap` | `11.0` | Seconds between two trust WS before the solo chain counts as over (`//omni solo gap`) |
| `auto_mode` | `flexible` | `flexible`: use the top usable WS even if nothing connects. Anything else: do nothing |
| `show_hud` | `false` | Show the chain HUD (`//omni hud on`) |
| `debug_logging` | `true` | Write `omnichain_debug.log`. It is on by default; `//omni log off` stops it |

## Commands (`//omni` or `//omnichain`)

| Command | Description |
| :--- | :--- |
| `//omni on` / `//omni off` | Auto skillchain on or off (`enable` / `disable` also work) |
| `//omni start manual\|auto` | You use the first WS / the addon does |
| `//omni wait <sec>` | Wait in manual opener mode (0 to 9, default 6) |
| `//omni minfollow <sec>` | Minimum seconds from the previous WS to the next auto WS (4 to 8, default 4) |
| `//omni focus [on\|off]` | Max-power WS when many people share a target (default on) |
| `//omni focuspeople <n>` | People needed, you included (2 to 18, default 3) |
| `//omni focustp <TP>` | TP for the max-power WS (1000 to 3000, default 1500) |
| `//omni toss [on\|off]` | Predict a party member's next WS and leave a property they can continue (default on) |
| `//omni reach <distance>` | Distance at which melee WS may be used (1 to 8, default 3.5) |
| `//omni solo [on\|off]` | Wait for trusts' solo chains (`start <sec>` and `gap <sec>` tune the waits) |
| `//omni hud [on\|off]` | Show or hide the chain HUD |
| `//omni size <n>` | HUD font size (6 to 40) |
| `//omni reload` | Reload `omnichain_config.json` |
| `//omni status` | Show settings, job and priority list |
| `//omni check` | Check that every WS on the list is usable now |
| `//omni log [on\|off\|clear]` | Turn the log file on or off, or clear it |
| `//omni log tail [n]` | Show the latest log entries in chat |
| `//omni log err [n]` | Show only errors and warnings in chat |

`COMMANDS.txt` has the details.

## License and credits

- Author: hikaruoshino. MIT License (see `LICENSE`).
- Chain data: [BG-Wiki](https://www.bg-wiki.com/) (skillchains, weapon skill pages, blood pacts, automaton weapon skills) and the Windower resources.

## Changelog

The English edition uses the same version numbers as the Japanese one.

- **v7.4.3 (2026-10-28)**: Fixed a one-time freeze of about 0.2 s in combat. Looking up your weapon's name loaded the whole item resource (`res/items.lua`, about 5 MB) the first time, mid-fight. It is now loaded 3 s after load or login, outside combat (if you are engaged, it waits until you disengage). Lighter in big fights: action packets (0x028) of kinds the addon never uses (melee, ranged attacks and their start, magic and its casting start, items) are dropped without being parsed, and less work is done every frame. A WS that is not in the addon's table is no longer picked to continue a skillchain, for Chainbound, or for a toss (before, it was given placeholder properties: Fusion, Gravitation, Fragmentation, Distortion). It may still be used as an opener, and `//omni check` warns about it. Confirmed in game on the Japanese client: with trusts, the WS chosen for Chainbound made Light, and no freeze in combat.
- **v7.4.2 (2026-10-24)**: Fixed the auto WS stopping on big enemies. (1) The `valid_target` pre-check is gone: on big enemies it could stay `false` (or flip between true and false) while a manual WS still worked. Now the addon only waits 2 s right after the game refuses with "cannot see target". (2) The melee reach is the fixed 3.5 (`ws_reach`) plus the amount the enemy's `model_size` is above 2, because big enemies can be hit from farther than 3.5. Enemies with `model_size` 2 or less keep 3.5. Confirmed in game: the auto WS no longer stops against a big enemy (Awoken). Distances were not checked one by one.
- **v7.4.1 (2026-10-19)**: The max-power WS now needs at least 3 people, you included, on the same enemy (it used to need everyone), and alliance members count (`//omni focuspeople`). It is used at 1500 TP instead of 3000 (`//omni focustp`). No WS is used while the enemy cannot be targeted (dropped in v7.4.2).
- **v7.4.0 (2026-10-19)**: WS on other enemies are not counted. Melee WS wait until the distanceplus distance is 3.5 or less (`//omni reach`). Added the max-power WS (`//omni focus`) and tossing (`//omni toss`). At 3000 TP the WS is used 3.3 seconds in. The `minfollow` floor is 4 seconds.
- **v7.3.1 (2026-10-11)**: Chainbound handling fixed. The wait shortens automatically as the chain continues. A trust's normal attack is no longer read as a WS, and a trust move wiped by shadows is no longer an opener.
- **v7.3.0 (2026-10-10)**: Waiting for trusts' solo chains (`//omni solo`). New chains after moves that are not continued. Minimum wait (`//omni minfollow`). Aftermath check. Handling of chainbound, jump abilities and WS of players outside the party. The monitor window and console.log monitor were removed.
- **v7.2.0 (2026-10-09)**: Manual opener mode, `opener_only`, aeonic Light and Darkness (14 weapons), restart when the enemy changes, and a fix for late chat lines overwriting the state.
- **v7.1.0 (2026-10-06)**: Notices for failed WS, `//omni check`, a chain-rule and property-data review against the wiki, HUD resizing, `COMMANDS.txt` and the MIT license.
- **v7.0.3 and earlier**: Official WS names and prime WS for all 14 weapon types, automaton WS and blood pact chains, a larger config editor, and the first release (v6.0.0, 2026-10-01).

## Feedback

A one-line "it works" is welcome too. With a GitHub account you can post from [Issues](../../issues/new/choose).
