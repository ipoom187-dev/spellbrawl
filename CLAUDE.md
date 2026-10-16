# Spellbrawl

Single-file HTML deck-building game (`index.html`), rules modelled on a well-known wizard-battle deck-builder (keep that game unnamed in anything players see).
UI and card text are in Thai; card text is always written fresh in Thai, never translated word-for-word.

**Naming (done 2026-10-10):** every card the user had entered under an official name was renamed to an original
English pun name (abilities unchanged, ids unchanged so `art/<id>.png` still works); the official game's name was
removed from the page and README. New cards the user sends from the official game must get an **original name**
too: implement the ability, pick a fresh pun name (no apostrophes — names live in quoted JS strings), and tell the
user the name you chose. Cards whose ability depends on the word "Wand" must keep "Wand" in the new name (`isWand`).
Don't put official card art in `art/`. When replacing names in code, never touch identifiers (a name inside
`offerFriendality` once broke the script).

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
+1 ทอง โจมตีศัตรูแบบสุ่ม 1 คน รับ 2 ดาเมจ ต่อสัตว์อสูรแต่ละใบในกองทิ้งของคุณ
```

Several cards may come in one message, separated by blank lines. Ask only if a line is genuinely ambiguous.
Ignore stray lines like "ชุด 1" (left over from copy-paste). If the copies line is missing, use 2 (1 for Chaos cards) and say so.

### Type mapping (line 1)

| User writes | `type` | Goes in |
|---|---|---|
| คาถา / Spell | `spell` | `MAIN` |
| สัตว์อสูร / Creature | `creature` | `MAIN` |
| สมบัติ / Treasure | `treasure` | `MAIN` |
| พ่อมด / Wizard | `wizard` | `MAIN` |
| สถานที่ / Location | `location` (set `ongoing:1`, effect in `onStart`) | `MAIN` |
| โกลาหล / Chaos / Mayhem | `chaos` (effect in `chaos: async by => …`; pass `by` into `attack` so a player who triggers it gets kill credit). The user writes "Mayhem" (the official term) — always show it as **Chaos / โกลาหล**, never "Mayhem", in names, text and UI | `MAIN` |
| ตำนาน / Legend | `legend` (needs `group` text + `gattack`; make Group Attacks defendable by wrapping them in `attack(null, {to:'all', …})`). "Legend · Wizard/Location" → add `alsoType` (checked with `isType(c, t)`). Legends sit in a 3-card face-up row `G.legendRow` (Willy always starts in it) over a face-down stack `G.legends`; buying empties a slot, refilled at end of turn with that Legend's Group Attack | `LEGENDS` (count ignored) |
| สัตว์รับใช้ / Familiar | `familiar` | `FAMILIARS` (count ignored) |

### How to implement

- Add a `def('<id>', {...})` next to the other cards of the same type. `<id>` is a short lowercase ASCII
  romanisation of the name (e.g. โก๋แบง → `kobang`); tell the user the id, since card art uses `art/<id>.png`.
- Set `name`, `type`, `cost`, `vp`; flat `+N ทอง` goes in `power:N`; add `atk:1` / `def:1` / `ongoing:1` / `draws:1` as the ability implies.
- Attack extras: `noRedirect:true` (can be dodged, never reflected), `tokenPick:n` (killer picks the token from n). Arena / Nacho Arena double attack damage (stacking), Vortex turns a turn's first damaging attack into power, Snack Cart heals on damage. `G.turn.gainToHand` (Dr. Continuum) sends gains to hand; `G.instantWinner` + `G.ending` ends the game with that winner.
- Wizard ability tiles (`TRAITS`, the user's set 1 + set 2, one per player): check with `hasTrait(p, id)` (covers Papa Boner's temporary `p.trait2`; `traitsOf(p)` lists both). Tile hooks: `onCardPlayed(p, card)` (own turn), `activate` + `canActivate` + `actText` + `aiUse` (once-per-turn button, `useTrait`). Engine checks: `cheapTop` (uses `G.gainSrc`), `creatureTop`, `wizardDraw`/`spellDraw` (`G.turn.gainedWiz/gainedSpell`), `treasureLover`, `weirdWand` (+ `weirdwand` starter card). The old placeholder abilities (ember, iron…) are gone; their `hasTrait` checks are now inert. `G.optOut` = a player sitting out a Chaos card (The Cosmic Glyph); `turnOrder()` and `attack` skip them.
- The buying currency is called **ทอง** in all Thai text (renamed from พลัง on 2026-10-16; code still says `power`). If the user writes "+N พลัง", write "+N ทอง". The wizard tile name พลังชีวิตสัตว์อสูร is life force, not currency, and keeps its name.
- A chosen enemy is written **เป้าหมาย** in card text (e.g. "<b>โจมตี:</b> เป้าหมายรับ 5 ดาเมจ"), never "ศัตรูที่เลือก" (changed 2026-10-16). "ผู้เล่นที่เลือก" (may pick yourself) stays as it is.
- Official terms the user may paste: Glyph = `rune`, Wild Magic = Wild Surge (`wild`), Limp Wand = `bent`, Mayhem = Chaos.
- Chaos helpers: `turnOrder()` (turn player first), `handCost(p)`, `gainTopOfMain(p)` (skips/destroys Chaos), `attackOnly(card, owner, self)` (resolve just a card's attack — Chaos O/Q), attack `benign:true` (AI won't defend a helpful "attack" — Chaos S/T).
- Limp Wand: the -1 VP junk card (16 in its own stack, not in `MAIN`); internal id is still `bent`, so use `bent:1` / `gainBent` and `art/bent.png`.
- "ครอบครองได้แค่ 1 ใบ" (each player may own only one) → `unique:1`; buying, free gains and the AI all respect it, and the card shows a "1 ใบ/คน" tag.
- Dead Wizard tokens (`TOKENS`, 38 kinds: the user's set 1 + set 2 mixed, each once; pile = 4 per player): fields `vp` (default -3, see `tokenVP` / `tokensVP(p)`), `now(t, killer)`, `respawn`, `ongoing:1` with text starting "ต่อเนื่อง:", `costUp:[types or 'wild']`. `badToken(k)` = ongoing or worse than -3 (AI gets rid of these first). Special ids checked in code: `nododge` (Chaos attacks), `wandweak` (+3 from the starter Wand). `G.onlyTarget` aims a Group Attack at one player. Set 2 adds `limpDouble` (see `limpVP`), `wand4`, `trophyless`, the `pairA`/`pairB` pair (cancel in `tokensVP`). Helpers: `loseHP(t, n)` (HP loss, not damage), `extraToken(t)` (a token from outside the game), `announceToken(p, k)` (pop-up; call it whenever a player gets a token).
- In Thai card/UI text write the token as **Dead Wizard Token** (or just **Token**), never "เหรียญพ่อมดตาย" / "เหรียญ" (changed 2026-10-11 at the user's request).
- Effects that count Dead Wizard tokens use `tokenCount(p)` (includes Huge Boner); scoring/stealing/removal use `p.tokens`.
- VP that depends on the game state at the end ("จบเกม: มีค่า …") → `vp:0` plus `vpCalc: p => number`; scoring,
  the VP viewer and AI buying use it, and the card shows `★? VP`. Example: `mib`.
- Write `text` in the same style as existing cards (`<b>โจมตี:</b>`, `<b>ป้องกัน:</b>`, `<b>ต่อเนื่อง:</b>`, `<br>` between effects).
- Put the logic in `play: async p => {...}` using the existing helpers: `attack(p, {to, dmg, bent, discard, onKill})`
  (`to`: `choose` `left` `right` `lr` `each` `random` `strongest` `weakest`, or `where` with
  `where: t => bool` to hit every opponent matching a condition; `among: t => bool` limits who `choose` can pick; `onHit: (t, dealt) => …` runs after damage lands with the amount actually dealt (0 if dodged → not called); `onDodge: t => …` runs when a target avoids or reflects the attack; `dmg` may be a function
  `t => number` worked out per target after defence, with `dmgText` for the defence prompt), `draw`, `heal`, `gainBent`, `revealTop`,
  `destroyOwn` (hand or discard), `destroyFromHand(p, n)` (up to n, optional), `discardFromHand`, `gainFromLineup`, `P(p, n)` for power,
  `tokenCount`, `ongoingCount`; this-turn Legend discount → `G.turn.legendDiscount += n` (prices always go through `costFor`). Add a new helper/target only if none fits — and `grep` for the name first: both machines
  add helpers, and a second `function` with the same name silently replaces the first. Same for card ids: `grep "'<id>'"` before choosing one — a second `def` overwrites the first card (this happened to `hocus` / `vortex`); `simulate()` now lists duplicates in `errors`.
- **✲ เปิดใช้** (activated ability): text before ✲ goes in `play` as usual; the part after ✲ goes in
  `activate: async (p, card) => {...}`, with an optional condition `canActivate: p => bool` and `needText`
  (tooltip when it can't be used yet). The player gets a "✲ ใช้" button under the card in the arena and may
  use it once, any time later that turn; unused abilities lapse at end of turn. The AI uses every ✲ it can
  after playing its hand. Example: `storkos`.
- "Ongoing: ทำลายการ์ดใบนี้เพื่อ …" → `ongoing:1` + `sacrifice: async p => {...}`, `sacText` (button tooltip) and
  `aiSacrifice: p => bool` (when the AI should cash it in, checked at the start of its turn). The player gets a
  "ทำลายเพื่อใช้" button under it in their Ongoing row on their turn. Example: `wizardwaste`.
- Ongoing card that defends from the table ("Ongoing - ป้องกัน: ทิ้งใบนี้ออกจากสนาม…") → `ongoing:1, defInPlay:1` (no `def`); it leaves play to the discard pile, then `onDefend` runs. AI uses it after hand defences. Example: `dragonballz`.
- Defence that leaves the hand: `defDiscard:1` (to the discard) (add `defDraw:1` to also draw 1 card before `onDefend`, text "… จั่ว 1 ใบ") or `defTopdeck:1` (face up on top of the deck,
  drawn again next hand, e.g. `lamps`). Each defence card can be used once per turn either way.
- Familiars: build with `fam(id, {...})` (cost 6 / 2 VP defaults); the shared defence is `...REFLECT` (+ `REFLECT_TXT`), `DODGE_DRAW(n)` for dodge-and-draw. Defence extras: `redirect` now bounces the whole effect (damage, Limp Wand, discard), `redirectTimes`, `defBottom`, `aiDefOk(t, src, spec)` (AI skips a costly defence), `onDefend(t, src, card, spec)`. Other hooks: `endBottom` (goes under the deck at end of turn), `allTypes` (counts as every type), `p.drawPenalty`, `G.turn.nextUnblockable`, `c.owner` on familiars. Move cards into a hand with `await toHand(p, c)` (Leviathan Seed check).
- Where a bought/gained card lands is decided in `placeGained(p, c)` (async — always `await` it): Grab-O top-decks, Gift Shop lets a Legend go on top.
- Card pop-ups: `trackMoves()` (run by every `render()`) diffs where each card is and calls `showEvent(card, label, kind)` for public moves — received, passed between players, discarded, destroyed, taken from / put back from the discard — so new cards need nothing extra. Moves that are not a change of place (reveal, defend, ✲) call `showEvent` directly.
  An effect that **reveals** cards to everyone (a hand, several top cards of a deck) calls `showReveal(cards, label)`
  (e.g. `showReveal(t.hand, \`${t.name} เปิดมือ\`)`): one captioned row in the upper middle of every screen (online too, as fx `'rev'`).
  A single revealed card can use `showEvent(c, label, 'reveal')`; `revealTop(p)` already does. Draws and hand↔deck stay hidden; `G.quietMoves` silences end-of-turn cleanup.
- `G.curCard` is the card whose `play` is resolving right now (null otherwise), so `attack` can tell which card attacked (e.g. `isWand` for The Dirty Wand).
- Ongoing card reacting to its owner playing another card → `onCardPlayed: async (p, card) => …` (runs after that card resolves; `G.turn.types[type]` already counts it). Example: `tentakill`.
- Art: every Chaos card shares one picture, `art/chaos.jpg` (`artKey()`; one entry in the in-game art editor).
  Chaos cards are full-art (picture fills the whole card, 1:2 tall), so `chaos.jpg` is NOT a row in
  `tools/art-prompts.tsv` (that mode crops square); make it with the one-off mode: `-Prompt "…" -Name chaos -Aspect 9:16 -Width 640`.
  `-Retrim` skips board.jpg, mat.jpg and chaos.jpg. New Chaos cards need no art or prompt of their own.
- AI play order: `playFirst:1` casts a card before everything else (e.g. it counts cards still in hand), `playLate:1`
  after everything else (e.g. "if you control another creature" checked on play, like `orc`).
- Add the copy count from line 5 to `MAIN` (main-deck types only).
- Mention balance concerns briefly (e.g. uncapped damage) but implement what the user asked.

## Online play (added 2026-10-11)

Friends play together on separate devices. One browser is the **host** ("สร้างห้อง"): it runs the whole game
(rules, AI seats) exactly as offline. **Guests** join by link (`…#room=CODE`) or code ("เข้าห้องเพื่อน"); they only
draw snapshots the host sends, send their clicks back, and answer questions forwarded to them. Code: the
`/* ---------------- online play` section (`NET`), just above the dev-testing helpers.

- Transport: PeerJS 1.5.4 (WebRTC + free public broker, no account), loaded from unpkg/jsdelivr only when going online.
  Room peer id = `spellbrawl-room-<CODE>`. `?net=bc` swaps in a BroadcastChannel fake so several tabs of one
  browser can be tested offline (Playwright).
- `ME` = the seat this browser shows/controls (0 offline and for the host); always use `meP()` for "you", never
  `G.players[0]`. `render()` seats the others clockwise from `ME`.
- **Every `humanChoose` takes the deciding player first:** `humanChoose(who, title, options, sub)`. Online, the host
  forwards it to `who`'s browser (`NET.askRemote`); offline it is the old modal (`localChoose`). New cards must pass
  the right player (the one whose `isAI` is checked next to it: `p`, `t`, `killer` …), or the question pops up on
  the wrong screen.
- Turn actions go through `doAction(p, a)` (play / buy / activate / trait / sacrifice / playall / end) — the click
  handler and guests' messages both use it.
- Snapshots: `NET.pack(G, viewerSeat)` / `NET.unpack` (cards as id + fields that differ from `DEFS`; tokens from
  `TOKENS`; traits by id). Rivals' hands/decks, the main deck, face-down Legends and the token pile are hidden
  until `G.over`. New state on `G` is sent automatically; keep it plain data (no DOM nodes, Maps, class instances).
- FX and sounds on the host are forwarded (`NET.wrapFX`) and replayed by guests; pop-ups from `trackMoves` are
  worked out by each guest itself; direct `showEvent` calls are forwarded. A sound only for one player → `soundFor(p, name)`.
- A guest who drops becomes AI (`p.away`) until they rejoin (same tab or same name). If the host closes the page the room ends.
- After changing turn flow, choices or `G` structure, also run the multi-tab check: host + 2 guests with `?net=bc`
  (`tools/online-test.js`, needs Node + Playwright), not only `simulate(3)`.

## Testing — keep it fast

The user noticed card additions taking too long, so match the test to the change. Open `index.html` in the
browser pane, reload it after editing, then call the built-in helpers from the console / JS tool
(both turn animations, sound and AI pauses off while running, then restore them):

- `await testCard('<id>', { hp: 10, setup: (p, G) => {...} })` — plays one copy for player 1 in a fresh
  game and returns `before` / `after` snapshots (power, own hp/hand/deck/discard/ongoing/tokens, each
  opponent's hp/hand/discard/bent/tokens). Instant. Use `setup` to arrange the state the card needs.
  Wizard abilities are off by default (Iron Hide etc. would skew numbers); pass `keepTraits: true` to test one.
- `await simulate(3)` — 3 full all-AI games (2, 3, 4 players), ~5–15 s each (30 s timeout per game). Returns `{ ok, results, errors }`;
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
- Published on GitHub Pages from `main` (root): `index.html` + `art/` are served as-is; art now loads on http(s) too.
- Art: `art/<id>.png|jpg` per card, `art/board.jpg` (table), `art/mat.jpg` (rug under your own seat panel `.you`; same dim slider as the board).
  AI art: `tools/gen-art.ps1` (Windows PowerShell, Google Gemini, key in the user's `GEMINI_API_KEY` env var — never ask for it in chat)
  takes each prompt from `tools/art-prompts.tsv` (style included); `-Only a,b -Force` re-rolls cards, `-Prompt … -Name … -Aspect 16:9` makes a one-off image.
  `art-prompts.tsv` columns: `category` (e.g. `คาถา · Spell`), `id`, `prompt`; rows are grouped by category in the order
  Starter, Wild Surge, Spell, Creature, Treasure, Wizard, Location, Legend, Familiar — add a new card's row at the end of
  its group. Chaos cards have no rows (they share `art/chaos.jpg`). The script only reads `id` and `prompt`.
  Every `prompt` already ends with the full style text (the user copies prompts into other image tools by hand),
  so a new row = scene description + ". " + the text of `tools/art-style.txt`; `gen-art.ps1` no longer appends it.
  The browser pane opens the game as a `data:` snapshot, so `art/` images never load there; ask the user to check art in the real game.
- **Card pictures the user sends** (an image attached in chat + the card name, e.g. "Weird Wand"): run
  `powershell -ExecutionPolicy Bypass -File tools\add-art.ps1 -Image "<attached image path>" -Name "<card name>"` (or `-Id <id>`).
  It centre-crops to square, saves `art/<id>.jpg` at 512×512 and removes older `art/<id>.*`. Chaos cards share
  `art/chaos.jpg` (tall 9:16, not square: don't use add-art.ps1 for it). If the name matches no card, say so and ask
  which card. Then show the saved picture, and tell the user it is not pushed yet. Don't commit/push until the user says "push".
- The user's prompt page "Spellbrawl Art Prompts" (https://claude.ai/artifact/LhbyR22yfaufQNYcDQjnuB) shows each card's
  picture from `art/<id>.jpg` files published with it; the page has `const IMGS = new Set([...])` listing the ids with art.
  After adding pictures, read the artifact, add the ids to `IMGS`, and republish to the same url with
  `files: {"art/<id>.jpg": "art/<id>.jpg"}` for each new or replaced picture.
- The user works on both Windows and macOS; `git pull` before editing.
