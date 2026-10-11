// Multi-tab online check (host + 2 guests + 1 AI over a BroadcastChannel, ?net=bc).
// Serve the folder first:  python -m http.server 8765   then:  node tools/online-test.js [turns]
// Needs Playwright (npm i playwright). Prints a line every 5 turns, then host vs guest views and any page errors.
const { chromium } = require(process.env.PW || 'playwright');
const URL = 'http://localhost:8765/index.html?net=bc';
const TURNS = +process.argv[2] || 30;
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 1400, height: 900 } });
  const errs = [];
  const mk = async tag => { const p = await ctx.newPage(); p.on('pageerror', e => errs.push(`${tag}: ${e.message}`)); return p; };
  const host = await mk('host');
  await host.goto(URL); await host.fill('#in-name', 'Hosty'); await host.click('#host');
  await host.waitForSelector('#lob-code');
  const code = await host.textContent('#lob-code');
  const guests = [];
  for (const nm of ['Alice', 'Bob']) {
    const g = await mk(nm); await g.goto(URL + '#room=' + code);
    await g.fill('#j-name', nm); await g.click('#j-go'); await g.waitForSelector('.lobby-list'); guests.push(g);
  }
  await host.evaluate(() => { AI_DELAY = 60; });
  await host.selectOption('#lob-ai', '1'); await host.click('#lob-start');
  const pages = [host, ...guests];
  let turns = 0, lastCur = null, lastLog = '', lastChange = Date.now();
  while (turns <= TURNS) {
    const st = await host.evaluate(() => G && { cur: G.cur, over: !!G.over, who: G.players[G.cur].name, hp: G.players.map(p => p.hp).join(','), log: G.log.length + G.log[0]?.msg });
    if (!st) { await sleep(200); continue; }
    if (st.over) { console.log('game over'); break; }
    if (st.cur !== lastCur) { turns++; lastCur = st.cur; if (turns % 5 === 1) console.log('turn', turns, st.who, 'HP', st.hp); }
    if (st.log !== lastLog) { lastLog = st.log; lastChange = Date.now(); } else if (Date.now() - lastChange > 25000) { console.log('STALLED at', st); break; }
    for (const p of pages) {
      if (await p.evaluate(() => !document.querySelector('#modal').hidden && !!document.querySelector('#m-opts [data-i]'))) {
        const n = await p.$$eval('#m-opts [data-i]', els => els.length);
        await p.click(`#m-opts [data-i="${Math.floor(Math.random() * n)}"]`, { timeout: 2000 }).catch(() => {});
        continue;
      }
      if (await p.evaluate(() => { const e = document.querySelector('[data-act="end"]'); return e && !e.disabled; })) {
        const buy = await p.$('.card.buyable[data-act="buy"]');
        if (await p.$('[data-act="play"]')) await p.click('[data-act="play"]', { timeout: 2000 }).catch(() => {});
        else if (buy && Math.random() < .8) await buy.click({ timeout: 2000 }).catch(() => {});
        else await p.click('[data-act="end"]', { timeout: 2000 }).catch(() => {});
      }
    }
    await sleep(120);
  }
  await sleep(500);
  const view = p => p.evaluate(() => G.players.map(x => `${x.name}:${x.hp}hp/${x.hand.length}h/${x.discard.length}d`).join(' '));
  console.log('host ', await view(host));
  console.log('Alice', await view(guests[0]), '| rivals hidden:', await guests[0].evaluate(() => G.players.filter((p, i) => i !== ME).every(p => p.hand.every(c => c.hidden))));
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
