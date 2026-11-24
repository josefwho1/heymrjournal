import json, html
B=json.load(open('/home/claude/bench/out_before.json'))
A=json.load(open('/home/claude/bench/out_after.json'))
try:
    A2=json.load(open('/home/claude/bench/out_after2.json')); A.update(A2)
except Exception: pass
e=lambda s: html.escape(str(s or ''))
def cost(d):
    ti=to=n=0
    for p in d.values():
        for x in p['days']:
            m=x.get('meta') or {}
            if m.get('inp'): ti+=m['inp']; to+=m['out']; n+=1
    return n, ti/n, to/n, (ti/n*2+to/n*10)/1e6
def refl(x):
    r=x.get('reflection')
    if not r: return '<p class="fail">No reflection (request failed)</p>'
    if r.get('crisis'): return f'<div class="sec crisis"><h5>Crisis mode</h5><p>{e(r.get("summary"))}</p></div>'
    out=f'<div class="sec"><h5>Summary</h5><p>{e(r.get("summary"))}</p></div>'
    for k,l in [('insights','Insights'),('patterns','Patterns')]:
        if r.get(k): out+=f'<div class="sec"><h5>{l}</h5><ul>{"".join(f"<li>{e(i)}</li>" for i in r[k])}</ul></div>'
    if r.get('questions'): out+=f'<div class="sec q"><h5>Questions</h5><ol>{"".join(f"<li>{e(i)}</li>" for i in r["questions"])}</ol></div>'
    n=r.get('nudge'); nt=n.get('text') if isinstance(n,dict) else n
    if nt: out+=f'<div class="sec nudge"><h5>Talk-to-someone nudge</h5><p>{e(nt)}</p></div>'
    m=x.get('meta') or {}
    if m.get('inp'): out+=f'<p class="meta">{m["inp"]:,} in · {m["out"]:,} out · ${(m["inp"]*2+m["out"]*10)/1e6:.3f}</p>'
    return out
def mem(m):
    if not m: return ''
    pe=''.join(f'<li><b>{e(v["name"])}</b> ({e(v.get("relation"))}): {len(v["days"])} entries. {e(" | ".join(n["note"] for n in v.get("notes",[])[-2:]))}</li>' for v in m.get('people',{}).values())
    th=''.join(f'<li><b>{e(v["label"])}</b>: {len(v["days"])} entries</li>' for v in sorted(m.get('themes',{}).values(), key=lambda v:-len(v['days'])))
    tr=''.join(f'<li class="{"done" if t.get("closed") else ""}">{e(t["text"])}{" (resolved "+t["closed"][-2:]+" Nov)" if t.get("closed") else ""}</li>' for t in m.get('threads',[]))
    ow=''.join(f'<li>“{e(o["text"])}”</li>' for o in m.get('own',[]))
    return f'<details class="mem"><summary>What Clive remembers after 14 days (the memory bank)</summary><div class="mgrid"><div><h5>People</h5><ul>{pe}</ul></div><div><h5>Themes</h5><ul>{th}</ul></div><div><h5>Open threads</h5><ul>{tr}</ul></div><div><h5>In their own words</h5><ul>{ow}</ul></div></div></details>'
cb, ca = cost(B), cost(A)
blurbs={'sam':'Going through a breakup with Jess. Sister Mia. Says no one knows how bad it is, plans to call Mia, mentions counselling twice.','dan':'Work stress with manager Priya, partner Kate, dad Pete. A pull toward teaching. Day 11 has a borderline "what\'s the point" line (should not trigger crisis).','lena':'Light and creative: pottery, a market-stall idea, friend Ana. Tests whether Clive stays light and doesn\'t over-read.'}
tabs=''.join(f'<button class="tab{" on" if i==0 else ""}" data-p="{pid}">{e(B[pid]["name"])}</button>' for i,pid in enumerate(B))
panes=''
for i,pid in enumerate(B):
    rows=''
    for x,y in zip(B[pid]['days'], A[pid]['days']):
        d=int(x['day'][-2:])
        rows+=f'''<article class="day"><div class="entry"><span class="dn">Day {d} · {d} Nov</span><h4>{e(x["question"])}</h4><p>{e(x["text"])}</p></div>
        <div class="cols"><div class="col"><h6>Current version</h6>{refl(x)}</div><div class="col"><h6>With memory bank</h6>{refl(y)}</div></div></article>'''
    panes+=f'<section class="pane{" on" if i==0 else ""}" id="p-{pid}"><p class="blurb">{e(blurbs.get(pid,""))}</p>{mem(A[pid]["days"][-1].get("memory"))}{rows}</section>'
page=f'''<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mr Journal test bench</title>
<style>
:root{{--ink:#16191c;--ink2:#4a4f55;--ink3:#80868c;--paper:#f6f6f2;--sheet:#fff;--rule:#e3e3dc}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--paper);color:var(--ink);font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}
.wrap{{max-width:1180px;margin:0 auto;padding:40px 24px 80px}}
h1{{font:500 40px/1.1 Georgia,"Times New Roman",serif;margin:0 0 8px}} .lede{{color:var(--ink2);max-width:760px;margin:0 0 24px}}
.stats{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:0 0 28px}}.stat{{background:var(--sheet);border:1px solid var(--rule);border-radius:14px;padding:14px 16px}}
.stat b{{display:block;font:500 24px Georgia,serif}}.stat span{{font-size:12.5px;color:var(--ink3)}}
.tabs{{display:flex;gap:8px;position:sticky;top:0;background:var(--paper);padding:12px 0;z-index:2;border-bottom:1px solid var(--rule)}}
.tab{{border:1px solid var(--rule);background:var(--sheet);border-radius:999px;padding:8px 18px;font:600 14px inherit;cursor:pointer}}.tab.on{{background:var(--ink);color:#fff;border-color:var(--ink)}}
.pane{{display:none}}.pane.on{{display:block}}.blurb{{color:var(--ink2);margin:18px 0}}
.day{{background:var(--sheet);border:1px solid var(--rule);border-radius:18px;padding:20px;margin:0 0 16px}}
.entry{{border-bottom:1px solid var(--rule);padding-bottom:14px;margin-bottom:14px}}.dn{{font:600 11px/1 sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--ink3)}}
.entry h4{{font:500 18px Georgia,serif;margin:6px 0 4px}}.entry p{{margin:0;color:var(--ink2);font-family:Georgia,serif}}
.cols{{display:grid;grid-template-columns:1fr 1fr;gap:18px}}h6{{margin:0 0 8px;font:700 11px sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--ink3)}}
.sec{{margin:0 0 10px}}.sec h5{{margin:0 0 3px;font:600 10.5px sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--ink3)}}.sec p,.sec li{{font-family:Georgia,serif;margin:0}}
.sec ul,.sec ol{{margin:0;padding-left:18px}}.q li{{font-weight:600}}.nudge{{border-left:3px solid var(--ink);padding-left:10px}}.crisis{{border:1px solid #b00;padding:8px;border-radius:8px}}
.meta{{font-size:11.5px;color:var(--ink3);margin:6px 0 0}}.fail{{color:#b00}}
.mem{{background:var(--sheet);border:1px solid var(--rule);border-radius:14px;padding:12px 16px;margin:0 0 16px}}.mem summary{{cursor:pointer;font-weight:600}}
.mgrid{{display:grid;grid-template-columns:repeat(2,1fr);gap:16px;margin-top:12px}}.mgrid h5{{margin:0 0 4px;font:600 11px sans-serif;text-transform:uppercase;letter-spacing:.08em;color:var(--ink3)}}.mgrid ul{{margin:0;padding-left:18px}}.done{{color:var(--ink3);text-decoration:line-through}}
@media(max-width:760px){{.cols,.mgrid,.stats{{grid-template-columns:1fr}}}}
</style></head><body><div class="wrap">
<h1>Mr Journal test bench</h1>
<p class="lede">Three made-up people, 14 days each, run through the real Mr Journal (Claude Sonnet 5.5) on 24 Nov 2026. Each day shows the entry, then the reflection from the <b>current version</b> (recent entries, shortened) next to the <b>memory bank version</b> (people, themes and threads remembered, recent entries in full, exact counts).</p>
<div class="stats"><div class="stat"><b>${cb[3]:.3f}</b><span>avg per reflection, current ({cb[1]:,.0f} in / {cb[2]:,.0f} out tokens)</span></div>
<div class="stat"><b>${ca[3]:.3f}</b><span>avg per reflection, memory bank ({ca[1]:,.0f} in / {ca[2]:,.0f} out)</span></div>
<div class="stat"><b>${ca[3]*14:.2f}</b><span>14 days of daily reflections, memory bank</span></div>
<div class="stat"><b>{sum(1 for p in A.values() for x in p["days"] if x.get("reflection"))}/{sum(len(p["days"]) for p in A.values())}</b><span>reflections completed, memory bank</span></div></div>
<div class="tabs">{tabs}</div>{panes}
</div><script>document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>{{document.querySelectorAll('.tab,.pane').forEach(x=>x.classList.remove('on'));b.classList.add('on');document.getElementById('p-'+b.dataset.p).classList.add('on');scrollTo({{top:0}})}});</script></body></html>'''
open('/home/claude/bench/report.html','w').write(page); print('ok', cb, ca)
