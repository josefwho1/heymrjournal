# Mr Journal test bench: replays each persona's 14 days through the real app code and the real reflection endpoint.
# usage: python3 run.py <label> <site_url> [persona ids...]
import json, sys, time, threading
from playwright.sync_api import sync_playwright
LABEL, SITE = sys.argv[1], sys.argv[2]
ONLY = sys.argv[3:]
EMAIL, PW = "claude-bench@heymrjournal.com", "bench horse battery staple"
P = [p for p in json.load(open('/home/claude/bench/personas.json')) if not ONLY or p['id'] in ONLY]
LIVE = 'https://heymrjournal.com'
results = {}

HOOK = "\nwindow.__mj = { get S(){ return S; }, set S(v){ S = v; }, get editing(){ return editing; }, set editing(v){ editing = v; }, set SIGNED(v){ SIGNED = v; }, reflect, createAccount, authPw, afterAuth, unlockWithPassword, ptext, sb };\n"
def setup_routes(pg):
    def hook(route):
        r = route.fetch(); body = r.text(); i = body.rstrip().rfind('})();')
        route.fulfill(response=r, body=body[:i] + HOOK + body[i:], headers={**r.headers, 'content-type': 'application/javascript'})
    pg.route('**/app.js', hook)
    if SITE.startswith('http://localhost'):
        def fwd(route):
            r = route.fetch(url=LIVE + '/api/reflect', timeout=120000)
            route.fulfill(response=r)
        pg.route('**/api/reflect', fwd)

def signin(pg, create=False):
    return pg.evaluate("""async ([email, pw, create]) => {
      const M = window.__mj;
      if (create) { try { await M.createAccount(email, pw, 'MOUSTACHE'); return 'created'; } catch (e) { if (!/already/i.test(e.message || '')) return 'create-failed: ' + e.message; } }
      const { data, error } = await M.sb.auth.signInWithPassword({ email, password: await M.authPw(email, pw) }); if (error) return 'login ' + error.message;
      const vault = await M.afterAuth(data.session); await M.unlockWithPassword(pw, vault); M.SIGNED = true; return 'ok'; }""", [EMAIL, PW, create])

def run_persona(p, browser):
    ctx = browser.new_context(viewport={'width': 1000, 'height': 900}, timezone_id='Asia/Bangkok'); pg = ctx.new_page()
    setup_routes(pg); metas = []
    pg.on('response', lambda r: metas.append(r) if r.url.endswith('/api/reflect') else None)
    pg.goto(SITE); pg.wait_for_timeout(2000)
    print(p['id'], 'signin', signin(pg), flush=True)
    pg.evaluate("""([name, answers]) => { window.__mj.S = { name, answers, entries: {}, votes: {}, start: '2026-11-01', step: 'home' }; }""", [p['name'], p['answers']])
    out = []
    for i, (pid, text) in enumerate(p['entries']):
        day = f"2026-11-{i+1:02d}"
        n0 = len(metas)
        r = pg.evaluate("""async ([day, pid, text, i]) => {
          const M = window.__mj, S = M.S; const T0 = new Date('2026-11-01T20:00:00+07:00').getTime(); Date.now = () => T0 + i * 864e5;
          S.entries[day] = { blocks: [{ pid, text }], seconds: 300, createdAt: Date.now(), updatedAt: Date.now() };
          M.editing = day; await M.reflect(); const e = S.entries[day];
          return { reflection: e.reflection || null, crisis: !!e.crisis, err: e.reflection ? null : document.querySelector('#rBody').innerText.slice(0, 300),
                   nudges: (S.nudges || []).length, plans: S.plans || [], memory: S.memory || null }; }""", [day, pid, text, i])
        meta = None
        try:
            if len(metas) > n0: meta = metas[-1].json().get('meta')
        except Exception as ex: meta = {'err': str(ex)}
        r.update(day=day, question=pg.evaluate("pid => window.__mj.ptext(pid)", pid), text=text, meta=meta)
        out.append(r)
        print(p['id'], day, 'ok' if r['reflection'] else 'FAIL ' + str(r['err']), meta, flush=True)
    results[p['id']] = {'name': p['name'], 'answers': p['answers'], 'days': out}
    json.dump(results, open(f'/home/claude/bench/out_{LABEL}.json', 'w'), indent=1, ensure_ascii=False)
    ctx.close()

with sync_playwright() as pw:
    b = pw.chromium.launch()
    # make sure the bench account exists
    ctx = b.new_context(); pg = ctx.new_page(); setup_routes(pg); pg.goto(SITE); pg.wait_for_timeout(2000)
    print('account', signin(pg, create=True), flush=True); ctx.close()
    for p in P: run_persona(p, b)
    b.close()
json.dump(results, open(f'/home/claude/bench/out_{LABEL}.json', 'w'), indent=1, ensure_ascii=False)
print('DONE', LABEL)
