# OmniChain (v7.4.1, English edition)

**Auto-skillchain assistant addon for Final Fantasy XI (Windower 4) - all 22 jobs, all 14 weapon types.**

`OmniChain` watches weapon skills used by your party members (and blood pacts / automaton moves) in real time and **automatically picks, from your priority list, a weapon skill that continues the current skillchain**. When there is no chain, it uses the top usable WS in your list to open one.

This is the **English edition** of [OmniChain](https://github.com/hikaruoshino/OmniChain) (the original is in Japanese). It has the same features as the Japanese v7.4.1; every message, command help, weapon type / WS / skillchain name, the config editor and the data tables use the English names from the game's resources.

> **Not verified in game by the author for this English build.** The logic is the same as the Japanese v7.4.1, which the author has used in game, but the English text and English-name tables were produced separately and have only been tested in a simulated environment. Please report problems as GitHub issues.

---

## Main features

* **Automatic skillchains (all 22 jobs, all 14 weapon types)**
  * Set a weapon type and a WS priority list per job. When TP reaches the configured value (default 1000), the addon uses a WS automatically.
  * While a chain window is open (up to 10 s, shorter as the chain continues), the priority list is evaluated from the top and **the first WS that makes a skillchain** is used.
* **Skillchain rules from the wiki** ([BG-Wiki: Skillchain](https://www.bg-wiki.com/ffxi/Skillchain))
  * Properties are matched in the order A1+B1, A1+B2, A1+B3, A2+B1 ... and the first match is used.
  * From the 3rd chain on, only the chain that just occurred is used for the next step.
  * Light->Light / Darkness->Darkness works "one more time"; after Radiance / Umbra nothing chains.
* **Property database (`sc_dict.lua`)**: 220 weapon skills, 31 blood pacts, 12 automaton WS.
* **Chain detection (packets + chat)**: the added-effect message of the action packet (0x028) is used, with the `Skillchain: <name>.` chat line as a fallback (duplicates are ignored). Only party / alliance members and their pets are counted; enemy moves never open a window.
* **Manual opener mode** (`//omni start manual`): you use the first WS, the addon continues the chain (also from someone else's opener).
* **Opener-only WS, aeonic weapons, per-enemy chains**
  * `"opener_only": true` in a job's config makes the first WS in the list opener-only.
  * With an aeonic weapon, the Light / Darkness that aftermath adds is included when judging your WS.
  * A chain is tracked per enemy; after you move to another enemy the addon starts again from an opener.
* **Unusable WS are skipped**: pet skills (cannot use `/ws`), WS you have not learned and WS for another weapon are skipped.
* **Trust support**: trusts' moves count as openers / chain steps, and the addon waits while a trust that aims for a solo skillchain (Iroha, Iroha II, Noillurie, Gilgamesh, Ark GK) is performing one.
* **Max-power WS** (`//omni focus`): when at least 3 people (you included, alliance counted) target the same enemy, the addon stops chaining and uses the strongest WS (prime weapon -> its prime WS, otherwise the empyrean WS for the weapon type).
* **Tosses** (`//omni toss`): predicts a party member's next WS and, when it is close, picks a WS whose property lets them continue.
* **Reach check**: a WS is not used while out of range (melee WS at distance <= 3.5 by the distanceplus number; `//omni reach`). distanceplus is a separate Windower addon that shows the target distance; OmniChain calculates the same number itself and does not need it.
* **Error / warning notices**: WS that do not fire, are out of range, lack TP or are interrupted are reported in chat (identical messages are grouped for 10 s).
* **Web config editor (`OmniChain_GUI.html`)**: open it in a browser, edit each job's weapon type and WS priority and the minimum TP, and export `omnichain_config.json`.

---

## Files

```text
OmniChain/
├── OmniChain.lua            # the addon
├── sc_dict.lua              # skillchain table + WS / blood pact / automaton property database
├── OmniChain_GUI.html       # web config editor (open in a browser)
├── omnichain_config.json    # per-job settings exported by the editor (optional)
├── COMMANDS.txt             # command list
├── README.md                # this document
├── omnichain_debug.log      # generated log (moved to .old.log past 1 MB)
└── data/
    └── settings.xml         # generated settings file
```

---

## Installation

1. Download the files.
2. Put them in your Windower 4 addons folder:
   `Windower4/addons/OmniChain/OmniChain.lua`
   `Windower4/addons/OmniChain/sc_dict.lua`
3. In game, load it:
   `//lua load OmniChain`

When updating from an older version, use `//lua reload OmniChain`.

**Do not run the Japanese and the English edition at the same time** - they use the same addon name and commands. Use one folder named `OmniChain`.

---

## Configuration

### Per-job weapon type and WS priority
1. Open `OmniChain_GUI.html` in a browser and edit each job's weapon type and WS priority list (higher = first).
2. Put the exported `omnichain_config.json` into the `OmniChain/` folder (or `OmniChain/data/`).
3. Run `//omni reload` in game (it is also read automatically on job change).

From `omnichain_config.json` the addon reads `profiles` (weapon type, WS priority), `min_tp` and `wait_delay`. Without a JSON file, `profiles` uses the built-in defaults and `min_tp` / `wait_delay` come from `data/settings.xml` (the WS priority is not stored in `settings.xml`).

Weapon types must be written exactly as: `Hand-to-Hand`, `Dagger`, `Sword`, `Great Sword`, `Axe`, `Great Axe`, `Scythe`, `Polearm`, `Katana`, `Great Katana`, `Club`, `Staff`, `Archery`, `Marksmanship`. WS names must match the English names in the game (for example `Tachi: Shoha`, `Savage Blade`).

Add `"opener_only": true` to a job to make the first WS in its list **opener-only**: during a chain the 2nd and later entries are tried first, and the first entry is used only when none of them connects (for example SAM: open with Tachi: Kasha, and after Detonation use Tachi: Shoha for Gravitation instead of Kasha). Add this by hand to `omnichain_config.json` - the editor does not handle it.

### Main settings (`data/settings.xml`)

| Setting | Default | Description |
| :--- | :--- | :--- |
| `enabled` | `true` | Auto skillchain ON / OFF (`//omni on` / `off`) |
| `min_tp` | `1000` | Minimum TP to use a WS |
| `wait_delay` | `1.2` | Seconds to wait after a WS before the next one |
| `start_mode` | `auto` | `auto`: the first WS is automatic / `manual`: you use the first WS (`//omni start`) |
| `follow_wait` | `6.0` | In `manual`, seconds to wait after the previous WS lands before the auto WS (`//omni wait`) |
| `trust_solo` | `true` | Do not auto-WS while a solo-skillchain trust is performing one (`//omni solo`) |
| `solo_start_wait` | `12.0` | Seconds to wait for the trust's first WS after its ability (`//omni solo start`) |
| `solo_gap` | `11.0` | Seconds to wait from one trust WS to the next; past this the solo chain counts as over (`//omni solo gap`) |
| `auto_mode` | `flexible` | `flexible`: if nothing connects during a window, still use the top usable WS / otherwise: do nothing |
| `debug_logging` | `true` | Write the log file |

---

## Commands (`//omni` or `//omnichain`)

### Basic controls

| Command | Description | Example |
| :--- | :--- | :--- |
| `//omni on` / `//omni off` | Auto skillchain ON / OFF (`enable` / `disable` also work) | `//omni on` |
| `//omni start manual\|auto` | You use the first WS (manual opener) / the addon does | `//omni start manual` |
| `//omni wait <sec>` | Wait before the auto WS in manual opener mode (0-9, default 6) | `//omni wait 5` |
| `//omni minfollow <sec>` | Minimum seconds from the previous WS (anyone's) to the next auto WS (4-8, default 4) | `//omni minfollow 4` |
| `//omni focus [on\|off]` | When at least 3 people (you included) target the same enemy, skip chains and use the max-power WS (default ON) | `//omni focus off` |
| `//omni focuspeople <n>` | Number of people (you included) for the max-power WS (2-18, default 3) | `//omni focuspeople 3` |
| `//omni focustp <TP>` | TP at which the max-power WS is used (1000-3000, default 1500) | `//omni focustp 1500` |
| `//omni toss [on\|off]` | Predict a party member's next WS and pick a WS they can continue (default ON) | `//omni toss off` |
| `//omni reach <distance>` | Distance at which melee WS may be used (1-8, default 3.5; the same number distanceplus shows) | `//omni reach 3.5` |
| `//omni solo [on\|off]` | Wait for trusts' solo chains to finish (`start <sec>` / `gap <sec>` tune the waits) | `//omni solo on` |
| `//omni hud [on\|off]` | Show / hide the chain HUD (chain window, next WS) | `//omni hud on` |
| `//omni size <n>` | HUD font size (6-40). Also by mouse wheel over the HUD or by dragging the bottom-right corner marker; the size is saved | `//omni size 9` |
| `//omni reload` | Reload `omnichain_config.json` | `//omni reload` |
| `//omni status` | Show the current settings, job and priority list | `//omni status` |
| `//omni check` | Check whether the WS in the priority list are usable now | `//omni check` |

### Log

| Command | Description | Example |
| :--- | :--- | :--- |
| `//omni log [on\|off\|clear]` | Toggle / clear the log file | `//omni log clear` |
| `//omni log tail [n]` | Show the latest entries in chat | `//omni log tail 10` |
| `//omni log err [n]` | Show only errors and warnings in chat | `//omni log err` |

See `COMMANDS.txt` for details.

---

## WS selection logic

When TP is at least the minimum and the wait time since the last use has passed, a WS is chosen in this order:

1. **Narrow down to usable WS**: pet skills, WS you have not learned and WS for another weapon are removed.
2. **A chain window is open**: the priority list is evaluated from the top; the **first WS that makes a skillchain** with the current property is used.
3. **Nothing connects**: with `auto_mode` = `flexible` the top usable WS is used (otherwise nothing is used).
4. **No chain window**: the top usable WS opens a chain (in `manual` mode nothing is used - the addon waits for an opener).

### Manual opener mode (`//omni start manual`)
* You use the first WS. If someone else's WS becomes the opener, the addon continues with that property.
* The auto WS waits `follow_wait` seconds (default 6) after the previous WS (anyone's) lands. If another WS lands while waiting, the decision is made again from that result and the wait restarts.
* The chain window is treated as 10 s and as 1 s shorter with each further chain (`auto` mode does the same since v7.3.1).

### Chain rules
* Properties A1, A2, A3 of the first WS and B1, B2, B3 of the second are matched in the order **A1+B1 -> A1+B2 -> A1+B3 -> A2+B1 ...**; the first match is used.
* From the 2nd chain on, only the chain that just occurred is used as A1.
* Light->Light / Darkness->Darkness works one more time and then no WS chains.
* After Radiance / Umbra nothing chains (a Light / Darkness WS stacked on an opener's aeonic Light / Darkness also ends as Light->Light / Darkness->Darkness).
* A chain belongs to an enemy. If the enemy with the chain differs from your current target, the addon behaves as if there is no window and starts from an opener.
* **Aeonic weapons**: when you use that WS with your own aeonic weapon (for example the Shoha of Dojikiri Yasutsuna), the aftermath Light / Darkness is put first in the property list (it also applies to the WS that triggers the aftermath). Other players' weapons are unknown, so it is not added to party members' aeonic WS.
* **Receiving chains**: packets are the source of truth. The `Skillchain: <name>.` chat line can arrive several seconds late, so it is ignored for 10 s after a packet updates the state.

---

## Trusts and solo skillchains

* Trust moves count as openers / chain steps just like a player's WS. Their properties are read from the game resources (`res/monster_abilities.lua`); only moves without a property in the resources (two moves of Mumor II) are filled in by `TRUST_WS_EXTRA` in `sc_dict.lua`. A move without chain properties is not used as an opener.
* **Trusts that aim for a solo skillchain** (Iroha, Iroha II, Noillurie, Gilgamesh, Ark GK): when one of them uses its trigger ability, the addon does not auto-WS until the solo chain is over.

| Trust | Trigger ability | Last move of the solo chain |
| :--- | :--- | :--- |
| Iroha / Iroha II | Meditate | Amatsu: Gachirin |
| Noillurie | Sekkanoki | Tachi: Kaiten |
| Gilgamesh | Sekkanoki | (unknown) |
| Ark GK | Meditate, Hagakure, Sekkanoki | (not fixed; ends after 2 moves) |

* Tenzen also does solo chains, but his order of moves changes each time and lasts about 40 s, so the addon interjects instead of waiting.
* The wait ends when: the last move appears / a Light->Light or Darkness->Darkness chain closes / the trust uses no WS for `solo_gap` seconds / no WS comes `solo_start_wait` seconds after the ability.
* Ark GK's wait is released after 2 moves; your WS continues the chain made by the 2nd.
* Healing and buff moves (for example Iroha's Rise From Ashes) do not count as solo-chain moves.
* While waiting, the HUD shows "Waiting on solo chain: <name> (<n>s left)". The log category is `TRUST_SOLO`.

### Moves that are not continued
After these moves your WS did not chain even when stacked (checked repeatedly in game), so the chain is treated as over and the next one starts from an opener (see `NO_FOLLOW` in `sc_dict.lua`):
* **Iroha / Iroha II's Gachirin** - after the last move of the solo chain or after any other use, a WS 3-7 s later never chained.
* **Selh'teus's moves** (Revelation, Luminous Lance) - a WS 4-5 s later did not chain 13 times out of 13.

Trusts chain with each other after these moves; their result is read as usual and your WS continues it.

### Other behavior
* **Jumps**: abilities such as Jump / High Jump / Super Jump arrive in the same form as WS and are not mistaken for WS.
* **Chainbound**: when an enemy becomes chainbound, the first WS from about 3 s later chains regardless of the previous property. The addon waits 3.3 s and prefers a WS that makes a continuable Light / Darkness. A Light / Darkness made from a Light / Darkness WS is not continued. A WS that lands within 3 s does not chain and does not count as an opener.
* **WS of people outside the party**: against enemies fought together with outsiders, an outsider's WS on the enemy you are targeting also counts toward the chain.

---

## Notes

* Use of external tools is at your own risk.

---

## License and credits

* **Author**: hikaruoshino (English edition prepared by the same author)
* **Environment**: Windower 4, English client
* **Libraries used**: `luau`, `config`, `texts`, `resources`, `packets`, `json`
* **Chain data**: [BG-Wiki](https://www.bg-wiki.com/) (Skillchain, weapon skill pages, blood pacts, automaton weapon skills) and the Windower resources

---

## Changelog

The English edition follows the Japanese release numbers; the notes below are translated from the Japanese changelog.

* **v7.4.1 (2026-10-19)**
  * **New condition for the max-power WS**: changed from "when everyone targets the same enemy" to **"when at least 3 people, you included, target the same enemy"** (people on other enemies are still counted; with only 2, a normal chain is stronger). Change the number with `//omni focuspeople`.
  * **Alliance members are counted** (a10-a15, a20-a25); trusts are not counted.
  * **WS TP is now 1500** (was 3000). Change it with `//omni focustp`.
  * **No WS on untargetable enemies**: when the enemy is not drawn or is too far to target (`valid_target` is `false`), no WS is used.
* **v7.4.0 (2026-10-19)**
  * **WS on other enemies are not counted**: in places where many enemies are linked and killed one by one, a party member's WS on a different enemy used to be counted as your chain. Only moves on the enemy you target are used now.
  * **No WS out of reach**: melee WS only when the distanceplus distance is 3.5 or less (`//omni reach`). Bows and guns use a distance that includes the enemy's size.
  * **Everyone on the same enemy**: use the max-power WS instead of chaining (`//omni focus`). Prime weapon -> its prime WS, otherwise the empyrean WS per weapon type, falling back to the top of the priority list. Dojikiri Yasutsuna uses Tachi: Shoha. Other players' targets are read from `mob.target_index`.
  * **Tosses to party members**: predicts the next WS of someone who uses a fixed WS (60%+ of their last 8) from the median interval and, when it is close (2.5-8 s away), picks a WS whose property they can continue (`//omni toss`). Trusts are excluded.
  * **At TP 3000**: if every WS since the opener is yours, the WS is used when the window opens at 3.3 s without waiting `minfollow`.
  * **`minfollow` floor is 4 s** (range 4-8, default 4).
* **v7.3.1 (2026-10-11)**
  * Chainbound fix: wait 3.3 s, then prefer the WS that makes a continuable Light / Darkness; a WS that lands before the window opens does not count as an opener.
  * Window estimate is "10 s - number of chains" (floor 4 s), and the `minfollow` wait is shortened automatically so the WS lands 2 s before the window closes (minimum 3.3 s).
  * A trust's normal attack that arrives in the same form as a special move is no longer read as a WS.
  * A trust move removed by an enemy shadow is no longer treated as an opener.
* **v7.3.0 (2026-10-10)**
  * Waiting for trusts' solo skillchains (`//omni solo`).
  * Aeonic Light / Darkness is used only while aftermath is active.
  * Support for the window shrinking by 1 s per chain.
  * Moves that are not continued (Iroha's Gachirin, Selh'teus's moves).
  * Minimum wait of 3.3 s after the previous WS (`//omni minfollow`).
  * Chainbound, jump abilities and outsiders' WS are handled.
  * Two Mumor II moves without properties in the resources were filled in; the properties of 111 trusts / 303 moves were compared with the wiki.
  * Development-only features (monitor window, detailed packet logging, console.log monitor) were removed from the public build. File logging and chat warnings remain.
* **v7.2.0 (2026-10-09)**
  * Manual opener mode, opener-only WS, aeonic Light / Darkness, fix for late chat lines overwriting the state, restart from an opener when the enemy changes.
* **v7.1.0 (2026-10-06)**
  * Error / warning notices, new logging, automatic skipping of unusable WS, misses are not openers, wiki-based chain rules, a reviewed property database, `//omni check`, `COMMANDS.txt`.
* **v7.0.x and earlier**
  * Debug log, official WS names and prime WS for all 14 weapon types, a bigger web editor, type-cast protection, automaton WS (12) and blood pacts (30) tracking, and the first release (v6.0.0, 2026-10-01).
