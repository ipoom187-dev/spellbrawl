# Spellbrawl

Single-file HTML deck-building game (`index.html`), rules modelled on Epic Spell Wars: Annihilageddon.
All card names, text and characters are original — never copy official card content. UI and card text are in Thai.

## Adding a card — the user's 6-line format

The user sends new cards as 6 lines with no labels, in this order:

1. ประเภท (type)
2. ชื่อ (name)
3. ราคา (cost)
4. VP
5. จำนวน x ใบ (copies in the deck, e.g. `2 ใบ`)
6. ความสามารถ (ability — free text, may run onto further lines)

Example:

```
สัตว์อสูร
โก๋แบง
6
1
2 ใบ
+1 พลัง โจมตีศัตรูแบบสุ่ม 1 คน รับ 2 ดาเมจ ต่อสัตว์อสูรแต่ละใบในกองทิ้งของคุณ
```

Several cards may come in one message, separated by blank lines. Ask only if a line is genuinely ambiguous.

### Type mapping (line 1)

| User writes | `type` | Goes in |
|---|---|---|
| คาถา / Spell | `spell` | `MAIN` |
| สัตว์อสูร / Creature | `creature` | `MAIN` |
| สมบัติ / Treasure | `treasure` | `MAIN` |
| พ่อมด / Wizard | `wizard` | `MAIN` |
| สถานที่ / Location | `location` (set `ongoing:1`, effect in `onStart`) | `MAIN` |
| โกลาหล / Chaos / Mayhem | `chaos` (effect in `chaos: async by => …`; pass `by` into `attack` so a player who triggers it gets kill credit) | `MAIN` |
| ตำนาน / Legend | `legend` (needs `group` text + `gattack`) | `LEGENDS` (count ignored) |
| สัตว์รับใช้ / Familiar | `familiar` | `FAMILIARS` (count ignored) |

### How to implement

- Add a `def('<id>', {...})` next to the other cards of the same type. `<id>` is a short lowercase ASCII
  romanisation of the name (e.g. โก๋แบง → `kobang`); tell the user the id, since card art uses `art/<id>.png`.
- Set `name`, `type`, `cost`, `vp`; flat `+N พลัง` goes in `power:N`; add `atk:1` / `def:1` / `ongoing:1` / `draws:1` as the ability implies.
- Limp Wand: the -1 VP junk card (16 in its own stack, not in `MAIN`); internal id is still `bent`, so use `bent:1` / `gainBent` and `art/bent.png`.
- "ครอบครองได้แค่ 1 ใบ" (each player may own only one) → `unique:1`; buying, free gains and the AI all respect it, and the card shows a "1 ใบ/คน" tag.
- Write `text` in the same style as existing cards (`<b>โจมตี:</b>`, `<b>ป้องกัน:</b>`, `<b>ต่อเนื่อง:</b>`, `<br>` between effects).
- Put the logic in `play: async p => {...}` using the existing helpers: `attack(p, {to, dmg, bent, discard, onKill})`
  (`to`: `choose` `left` `right` `lr` `each` `random` `strongest` `weakest`, or `where` with
  `where: t => bool` to hit every opponent matching a condition; `among: t => bool` limits who `choose` can pick; `onHit: (t, dealt) => …` runs after damage lands with the amount actually dealt (0 if dodged → not called); `dmg` may be a function
  `t => number` worked out per target after defence, with `dmgText` for the defence prompt), `draw`, `heal`, `gainBent`, `revealTop`,
  `destroyOwn`, `discardFromHand`, `gainFromLineup`, `P(p, n)` for power. Add a new helper/target only if none fits.
- Add the copy count from line 5 to `MAIN` (main-deck types only).
- Mention balance concerns briefly (e.g. uncapped damage) but implement what the user asked.

## Testing — keep it fast

The user noticed card additions taking too long, so match the test to the change. Open `index.html` in the
browser pane, reload it after editing, then call the built-in helpers from the console / JS tool
(both turn animations, sound and AI pauses off while running, then restore them):

- `await testCard('<id>', { hp: 10, setup: (p, G) => {...} })` — plays one copy for player 1 in a fresh
  game and returns `before` / `after` snapshots (power, own hp/hand/deck/discard/ongoing/tokens, each
  opponent's hp/hand/discard/bent/tokens). Instant. Use `setup` to arrange the state the card needs.
  Wizard abilities are off by default (Iron Hide etc. would skew numbers); pass `keepTraits: true` to test one.
- `await simulate(3)` — 3 full all-AI games (2, 3, 4 players), ~5 s each. Returns `{ ok, results, errors }`;
  `results[i].bought` counts every card each game ended with.

Which to run:

- Card built only from existing helpers (draw / heal / power / standard attack targets) → `testCard` only.
- Card that adds a new helper, attack target, keyword, or touches turn flow / defence / death → `testCard`
  **and** `simulate(3)`.
- The browser pane may serve a stale snapshot: `location.reload()` can bring back the *old* file. After
  editing, open the file again with `navigate` (file URL) and check `DEFS.<id>` exists before trusting a result
  — a missing id makes `testCard` silently play an empty card.
- Never wrap several long runs in one JS call (the tool times out after ~45 s and the orphaned run keeps
  mutating `G`); one `simulate(3)` per call is fine.

## Repo

- Launchers: `Spellbrawl.cmd` (Windows, CRLF) and `Spellbrawl.command` (macOS, executable bit).
- The user works on both Windows and macOS; `git pull` before editing.
