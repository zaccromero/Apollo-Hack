from pathlib import Path
import json,sys,hashlib
root=Path(__file__).resolve().parents[1];e=json.loads((root/'tools/evidence/site/evidence.json').read_text());checks=[]
negative='--negative-control' in sys.argv
def check(name,value):checks.append({'name':name,'pass':bool(value)})
check('Twenty actual route/viewport receipts',len(e['routes'])==20)
for row in e['routes']:
 r=row['result'];check(f"{row['width']} {row['page']}: layout, links, semantic headings and IDs",r['width']==row['width']==r['client']==r['scroll'] and r['h1']==1 and not r['duplicateIDs'] and not r['brokenAnchors'] and all(x['status']==200 for x in r['localLinks']))
 check(f"{row['width']} {row['page']}: primary navigation target sizes",all(x['height']>=44 for x in r['nav']))
 if row['page']=='access.html':check(f"{row['width']}: public install and QR stay unavailable",r['installHidden'] and r['qrHidden'])
 if row['page']=='demo.html':check(f"{row['width']}: both demo choices present",r['videoChoices']==2)
rows=e['practice320']['rows']
for t,price,mult,default in [('stock',100,1,'10'),('etf',50,1,'10'),('option',5,100,'1')]:
 d={x['action']:x for x in rows if x['topic']==t};c=3*price*mult;money=lambda n:f'${n:,.2f}'
 check(t+': pass and watch never execute',not d['pass']['receipt'] and not d['watch']['receipt'] and d['pass']['stage']=='0' and d['watch']['stage']=='0')
 check(t+': default quantity',d['default']['quantity']==default)
 for action in ['edit3','roundtrip3','topicreturn3']:
  expected='$301.00' if negative and t=='stock' and action=='edit3' else money(c)
  check(t+': '+action+' keeps edited quantity and exact cost/cash',d[action]['quantity']=='3' and d[action]['cost']==expected and d[action]['cash']==money(10000-c) and not d[action]['receipt'])
 invalid=[x for k,x in d.items() if k.startswith('invalid')]
 check(t+': all invalid quantities remain rejected across navigation',len(invalid)==12 and all(x['errorVisible'] and not x['receipt'] and x['confirm'] for x in invalid))
 check(t+': explicit confirm and duplicate guard',all(d[a]['receipt'] and d[a]['receiptCash']==money(10000-c) and d[a]['holdings']==money(c) and d[a]['equity']=='$10,000.00' and not d[a]['confirm'] for a in ['confirm3','revisit']))
 check(t+': restart default and exact-budget boundary',d['reset']['quantity']==default and not d['reset']['receipt'] and d['exactbalance']['receiptCash']=='$0.00' and d['exactbalance']['holdings']=='$10,000.00')
check('Browser Back restores draft and context',e['practiceBack']['q']=='3' and e['practiceBack']['stage']=='2' and e['practiceBack']['cost']=='$300.00' and not e['practiceBack']['receipt'])
check('Reload clears lesson according to disclosure',e['practiceReload']['stageOnReload']=='0' and e['practiceReload']['q']=='10' and e['practiceReload']['cost']=='$1,000.00' and not e['practiceReload']['receipt'])
h=e['hero320']['rows'];d={x['action']:x for x in h}
check('Concept label and no mobile overflow in all earlier hero financial branches',all('SIMULATED' in x['concept'] and x['width']==x['scroll']==320 for x in h))
for mode in ['review','agent','manual']:
 check(mode+': preview never fills and invalid input blocks confirmation',not d[mode+':preview']['receipt'] and all(not x['receipt'] and not x['errorHidden'] for x in h if x['action'].startswith(mode+':invalid')))
 check(mode+': confirmed gain/loss/flat exact illustrative marks',d[mode+':confirmed']['receipt'] and d[mode+':up']['holding']=='$272.80' and d[mode+':down']['holding']=='$223.20' and d[mode+':flat']['holding']=='$248.00')
check('Agent fee and funding differ from holding P&L', '$2 conversion' in d['agent:confirmed']['summary'] and '$0.00' in d['agent:confirmed']['summary'])
check('Manual existing record never becomes a broker fill','Manual / unverified' in d['record:confirmed']['summary'] and 'Unknown' in d['record:confirmed']['summary'] and not d['record:invaliddate']['receipt'])
check('Cancel no-fill and pass/watch no-fill',all(not d[a]['receipt'] for a in ['pass','watch','cancel:no-fill']))
for w,s in e['stories'].items():
 check(w+': normal causal transition has intermediate and settled state',float(s['frames'][0]['opacity'])==0 and 0<float(s['frames'][1]['opacity'])<1 and float(s['frames'][2]['opacity'])>.99)
 check(w+': interrupted state settles, reduced motion immediate, inactive layers inert',s['interrupted']['active']=='flow-3' and float(s['interrupted']['opacity'])>.99 and s['reduced']['transition']=='0s' and s['reduced']['opacity']=='1' and s['inertInactive'])
 check(w+': alternate basket changes linked context and correct numbers',s['basket']['cost']=='$150.00' and s['basket']['cash']=='$9,850.00' and 'topic=etf' in s['basket']['href'])
for row in e['fixedStoryLayouts']:check(str(row['width'])+': all four repaired panels fully fit',all(not x['clipped'] for x in row['result']['rows']) and row['result']['root']==row['result']['scroll'])
for key,reduced in [('guideNormal',False),('guideReduced',True)]:
 g=e[key];s=g['samples'];motions=[x for x in s if x['phase']=='motion'];outcomes=[x for x in s if x['phase']=='outcome'];
 check(key+': full repeatable four-direction cycle finishes with no purchase',g['finalPhase']=='complete' and all(not x['receipt'] for x in s) and {x['direction'] for x in motions}=={'left','right','up','down'} and not g['permanentStripVisible'])
 check(key+': down edits quantity and consequence without filling',any(x.get('quantity')=='2' and x.get('cost')=='$100.00' and x.get('cash')=='$9,900.00' for x in outcomes))
 check(key+': motion preference equivalent',g['reduced']==str(reduced).lower() and (all(x['transform'] in ['none','matrix(1, 0, 0, 1, 0, 0)'] for x in motions) if reduced else any(x['transform'] not in ['none','matrix(1, 0, 0, 1, 0, 0)'] for x in motions)))
check('Four sampled direction states with bounded readable cues; no screenshot-time claim',len(e['gestureFrames'])==4 and all(x['phase']=='motion' and 0<=x['cueRect']['left']<x['cueRect']['right']<=x['width'] for x in e['gestureFrames']))
check('Actual pointer drag and actual keyboard no-fill path',e['pointer']['passed'] and not e['pointer']['receipt'] and e['keyboard']['pass'] and not e['keyboard']['receipt'])
v=e['video390']['videos'];check('Both unchanged local videos decode, play and seek',len(v)==2 and all(x['played'] and not x['error'] and all(abs(y['target']-y['actual'])<.1 and y['ready']>=2 and not y['error'] for y in x['samples']) for x in v))
check('Video format identities',[(x['width'],x['height']) for x in v]==[(1920,1080),(886,1920)])
baseline=json.loads((root/'tools/evidence/site/baseline.json').read_text())
for name in ['brand/ascending-blue/logo-light.svg','brand/ascending-blue/mark-light.svg','assets/apollo-discover-blue.png','assets/apollo-comparison-blue.png','install.js','install.json','demo-data.js']:
 check('Unchanged accepted source: '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==baseline[name])
check('No account/order/provider calls in hero','fetch(' not in (root/'hero.js').read_text() and 'localStorage' not in (root/'hero.js').read_text())
check('No-JS explanation retains four readable articles','story-enhanced' not in (root/'how-it-works.html').read_text() and (root/'how-it-works.html').read_text().count('class="story-state"')==4)
result={'status':'PASS' if all(x['pass'] for x in checks) else 'FAIL','count':len(checks),'checks':checks,'negativeControl':negative,'scope':'Focused marketing site + actual browser receipts. No native/full-repository CI, physical phone or public-host certification.'}
if not negative:(root.parent/'APOLLO-FULL-SITE-CHECKS.json').write_text(json.dumps(result,indent=2))
print(json.dumps({'status':result['status'],'count':len(checks),'failures':[x['name'] for x in checks if not x['pass']]}))
sys.exit(0 if result['status']=='PASS' else 1)
