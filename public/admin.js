(function(){
'use strict';
const sb = window.supabase.createClient('https://ltvlhtgqyiscftzcfrvq.supabase.co', 'sb_publishable_PM3Nyt5uA7riCy0xMvMD2A_0iadVeYB', { auth: { persistSession: true, autoRefreshToken: true } });
const $ = s => document.querySelector(s);
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const PILOT = 14;
const isTest = e => /^claude-/i.test(e || '');
let D = null, group = 'all', sortKey = 'days_written', sortDir = -1;

const day = d => d ? new Date(d + (String(d).length === 10 ? 'T00:00:00' : '')).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }) : '–';
const ago = d => { if (!d) return '–'; const n = Math.round((new Date(new Date().toDateString()) - new Date(d + 'T00:00:00')) / 864e5); return n <= 0 ? 'today' : n === 1 ? 'yesterday' : n + ' days ago'; };
const dayN = m => { const s = m.start_day || (m.joined_at || '').slice(0, 10); if (!s) return null; return Math.floor((new Date(new Date().toDateString()) - new Date(s + 'T00:00:00')) / 864e5) + 1; };

function gate(msg){ $('#gate').hidden = false; $('#dash').hidden = true; $('#gateMsg').innerHTML = msg; }

async function load(){
  const { data: { session } } = await sb.auth.getSession();
  if (!session) return gate('Sign in to the app first, then come back here.<br><br><a href="/app">Open the app</a>');
  const { data, error } = await sb.rpc('admin_dashboard');
  if (error) return gate(/not_admin/.test(error.message) ? 'This account isn\'t an admin.' : 'Couldn\'t load: ' + esc(error.message));
  D = data; $('#gate').hidden = true; $('#dash').hidden = false; render();
}

function members(){ return (D.members || []).filter(m => !($('#hideTest').checked && isTest(m.email))).filter(m => m.code || m.days_written > 0); }

function render(){
  $('#stamp').textContent = 'Updated ' + new Date(D.generated_at).toLocaleString();
  const ms = members();
  const today = new Date().toISOString().slice(0, 10);
  const wroteToday = ms.filter(m => m.last_day === today).length;
  const active = ms.filter(m => m.days_7 >= 3).length, wrote7 = ms.filter(m => m.days_7 > 0).length;
  const v = D.reflection_votes || {}, vt = (v.up || 0) + (v.down || 0);
  const pilot = ms.filter(m => m.code === 'PILOT' || m.code === 'JOURNAL'), ten = pilot.filter(m => m.days_written >= 10).length;
  const paid = (D.feedback || []).filter(f => f.keep_going && !($('#hideTest').checked && isTest(f.email))).length;
  const tiles = [
    ['Weekly active writers', active, `wrote 3+ days of the last 7 · ${wrote7} wrote at all`],
    ['Members', ms.length, (D.codes || []).map(c => `${c.code} ${c.uses}/${c.max_uses}`).join(' · ')],
    ['Wrote today', wroteToday, `of ${ms.length} members`],
    ['Strangers: 10+ days', ten, `PILOT + JOURNAL · go if 10+ · ${pilot.length} joined`],
    ['Said yes to $5', paid, 'go if 5+ (confirm in Stripe)'],
    ['Reflections 👍', vt ? Math.round(100 * (v.up || 0) / vt) + '%' : '–', `${v.up || 0} up · ${v.down || 0} down`],
    ['Waitlist', (D.waitlist || []).length, 'emails collected'],
  ];
  $('#tiles').innerHTML = tiles.map(t => `<div class="tile"><div class="l">${esc(t[0])}</div><div class="n">${esc(t[1])}</div><div class="s">${esc(t[2])}</div></div>`).join('');
  renderChart(); renderGroups(); renderMembers(); renderFeedback(); renderWaitlist(); renderCodes();
}

function renderChart(){
  const d = D.daily || [], W = 1100, H = 180, pad = 28, max = Math.max(1, ...d.map(x => x.writers));
  const bw = (W - pad * 2) / d.length;
  const bars = d.map((x, i) => { const h = (H - 50) * x.writers / max, xx = pad + i * bw + 3, y = H - 26 - h;
    return `<g><title>${day(x.day)}: ${x.writers} wrote</title><rect x="${xx}" y="${y}" width="${bw - 6}" height="${Math.max(h, x.writers ? 2 : 0)}" rx="4" fill="var(--bar)"/>${x.writers ? `<text x="${xx + (bw - 6) / 2}" y="${y - 6}" text-anchor="middle" font-size="12" fill="var(--ink-2)">${x.writers}</text>` : ''}${i % 3 === 0 || i === d.length - 1 ? `<text x="${xx + (bw - 6) / 2}" y="${H - 8}" text-anchor="middle" font-size="11" fill="var(--ink-3)">${day(x.day)}</text>` : ''}</g>`; }).join('');
  $('#chart').innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="People writing each day"><line x1="${pad}" x2="${W - pad}" y1="${H - 26}" y2="${H - 26}" stroke="var(--rule)"/>${bars}</svg><div class="muted small">Includes test accounts.</div>`;
}

function renderGroups(){
  const gs = ['all', ...new Set(members().map(m => m.code || 'none'))];
  $('#groups').innerHTML = gs.map(g => `<button type="button" data-g="${esc(g)}" class="${g === group ? 'on' : ''}">${g === 'all' ? 'All' : esc(g)}</button>`).join('');
  $('#groups').querySelectorAll('button').forEach(b => b.onclick = () => { group = b.dataset.g; renderGroups(); renderMembers(); });
}

function renderMembers(){
  let ms = members().filter(m => group === 'all' || (m.code || 'none') === group).map(m => ({ ...m, dayN: dayN(m) }));
  ms.sort((a, b) => { const x = a[sortKey], y = b[sortKey]; return (x == null) - (y == null) || (x > y ? 1 : x < y ? -1 : 0) * sortDir; });
  const cols = [['email', 'Member'], ['code', 'Group'], ['dayN', 'Day', 1], ['days_written', 'Days written', 1], ['days_7', 'Last 7', 1], ['last_day', 'Last wrote'], ['words', 'Words', 1], ['reflections', 'Reflections', 1], ['reminder_time', 'Reminder'], ['why', 'Why they came']];
  const head = '<tr>' + cols.map(c => `<th data-k="${c[0]}" class="${c[2] ? 'num' : ''}">${c[1]}${sortKey === c[0] ? (sortDir < 0 ? ' ↓' : ' ↑') : ''}</th>`).join('') + '</tr>';
  const rows = ms.map(m => {
    const dn = m.dayN == null ? '–' : m.dayN > PILOT ? 'done' : `${m.dayN} / ${PILOT}`;
    const span = Math.min(m.dayN || 1, PILOT), pct = Math.min(100, Math.round(100 * m.days_written / Math.max(1, span)));
    const lastCls = !m.last_day ? 'bad' : ago(m.last_day) === 'today' || ago(m.last_day) === 'yesterday' ? 'ok' : 'warn';
    const rem = !m.reminder_time || m.reminder_time === 'none' ? '<span class="muted">none</span>' : esc(m.reminder_time) + (m.reminder_added ? ` <span class="muted small">${esc(m.reminder_added)}</span>` : ' <span class="muted small">not added</span>');
    return `<tr><td>${esc(m.email)}</td><td>${m.code ? `<span class="tag">${esc(m.code)}</span>` : '<span class="muted">–</span>'}</td><td class="num">${dn}</td><td class="num"><span class="barbg"><i style="width:${pct}%"></i></span> ${m.days_written}</td><td class="num">${m.days_7}</td><td class="${lastCls}">${ago(m.last_day)}</td><td class="num">${(m.words || 0).toLocaleString()}</td><td class="num">${m.reflections}</td><td>${rem}</td><td class="wrapcell small">${esc(m.why || '')}</td></tr>`;
  }).join('');
  $('#members').innerHTML = head + (rows || `<tr><td colspan="${cols.length}" class="empty">No members yet.</td></tr>`);
  $('#members').querySelectorAll('th').forEach(th => th.onclick = () => { const k = th.dataset.k; if (sortKey === k) sortDir *= -1; else { sortKey = k; sortDir = -1; } renderMembers(); });
}

function renderFeedback(){
  const f = (D.feedback || []).filter(x => !($('#hideTest').checked && isTest(x.email)));
  $('#feedback').innerHTML = '<tr><th>Member</th><th class="num">Overall</th><th>Useful</th><th>Would pay</th><th>Said yes</th><th>Liked</th><th>Change</th></tr>' +
    (f.map(x => `<tr><td>${esc(x.email)}</td><td class="num">${x.overall ? esc(x.overall) + '/5' : '–'}</td><td>${esc(x.useful || '–')}</td><td>${esc(x.would_pay || '–')}</td><td>${x.keep_going ? '<span class="ok">yes</span>' : x.keep_going === false ? '<span class="muted">no</span>' : '–'}</td><td class="wrapcell small">${esc(x.liked || '')}</td><td class="wrapcell small">${esc(x.suggestions || '')}</td></tr>`).join('') || '<tr><td colspan="7" class="empty">No feedback yet. It arrives at day 14.</td></tr>');
}

function renderWaitlist(){
  const w = D.waitlist || [];
  $('#waitlist').innerHTML = '<tr><th>Email</th><th>Source</th><th>Signed up</th><th>Invited</th></tr>' +
    (w.map(x => `<tr><td>${esc(x.email)}</td><td>${esc(x.source || '–')}</td><td>${day((x.created_at || '').slice(0, 10))}</td><td>${x.invited ? '<span class="ok">yes</span>' : '<span class="muted">no</span>'}</td></tr>`).join('') || '<tr><td colspan="4" class="empty">No sign-ups yet.</td></tr>');
}

function renderCodes(){
  $('#codes').innerHTML = '<tr><th>Code</th><th>For</th><th class="num">Used</th><th>Active</th></tr>' +
    (D.codes || []).map(c => `<tr><td><span class="tag">${esc(c.code)}</span></td><td>${esc(c.note || '')}</td><td class="num">${c.uses} / ${c.max_uses}</td><td>${c.active ? '<span class="ok">yes</span>' : '<span class="muted">no</span>'}</td></tr>`).join('');
}

$('#refresh').onclick = load;
$('#hideTest').onchange = () => D && render();
$('#copyEmails').onclick = async () => { const t = (D.waitlist || []).map(x => x.email).join(', '); try { await navigator.clipboard.writeText(t); $('#copied').textContent = 'Copied ' + (D.waitlist || []).length + ' emails'; } catch (e) { $('#copied').textContent = t; } };
load();
})();
