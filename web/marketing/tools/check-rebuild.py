#!/usr/bin/env python3
"""Focused static/browser gate for the rebuilt marketing page; not owner acceptance."""
from pathlib import Path
from html.parser import HTMLParser
import json,re,sys,subprocess
root=Path(__file__).resolve().parents[1]
evidence=root/'tools/evidence/rebuild'
def raw(name):
 obj=json.loads((evidence/(name+'.tool.json')).read_text())
 def decode(x):
  text=next(v['text'] for v in x['content'] if v['type']=='text')
  fence=chr(96)*3
  match=re.search(fence+r'json\n(.*?)\n'+fence,text,re.S)
  if not match: raise ValueError('No browser JSON in '+name)
  return json.loads(match.group(1))
 return [decode(x)for x in obj] if isinstance(obj,list) else decode(obj)
checks=[]
def check(name,condition):
 checks.append({'name':name,'status':'PASS' if condition else 'FAIL'})
 if not condition: raise AssertionError(name)
try:
 rows=raw('journey')['observations']
 expectation={'stock':('$1,000.00','$9,000.00'),'etf':('$500.00','$9,500.00'),'option':('$500.00','$9,500.00')}
 if '--negative-control' in sys.argv: expectation['stock']=('$1,000.00','$9,999.00')
 for topic,(cost,cash)in expectation.items():
  def row(action):return next(x for x in rows if x.get('topic')==topic and x['action']==action)
  pre=row('preview'); done=row('confirm')
  check(topic+' explicit preview protects balance',not pre['receiptPresent'] and pre['cost']==cost and pre['cash']==cash)
  check(topic+' confirmed arithmetic',done['holdings']==cost and done['cash']==cash and done['equity']=='$10,000.00')
  check(topic+' website scope and duplicate protection','No app account was changed.' in done['scope'] and not done['confirmStillPresent'] and not row('revisit confirmed')['confirmStillPresent'] and row('revisit confirmed')['cash']==cash)
  check(topic+' distinct reasoning and reset',len(row('understand')['points'])==3 and row('reset')['selectedStage']=='0' and not row('reset')['receiptPresent'])
 invalid=raw('invalid')['observations']
 check('invalid quantities reject actual confirmation',all(not x['receiptPresent'] and not x['errorHidden'] and x['invalid']=='true' for x in invalid if x['action']=='reject invalid quantity'))
 recovery=invalid[-1]
 check('valid recovery after invalid attempt',recovery['cash']=='$9,800.00' and recovery['holdings']=='$200.00' and recovery['equity']=='$10,000.00')
 edge=raw('boundaries')['observations']
 check('all exact-budget boundaries preserve equity',all(x['cash']=='$0.00' and x['holdings']=='$10,000.00' and x['equity']=='$10,000.00'for x in edge if x['action']=='exact balance'))
 check('all topics reject over-budget confirmation',all(not x['receiptPresent'] and 'smaller quantity' in x['error'] for x in edge if x['action']=='over maximum'))
 check('cancel preview does not create receipt',edge[-1]['stage']=='1' and not edge[-1]['receiptPresent'])
 reload=raw('reload')
 check('direct hash reload resets website exercise honestly',reload['topic']=='stock' and reload['stage']=='0' and not reload['receiptPresent'] and reload['installHidden'] and reload['qrHidden'])
 anchors=raw('anchors')
 check('all offered anchor destinations exist and Back works',anchors['hash']=='#try-it' and all(x['exists'] for x in anchors['links']))
 check('selected brand and visible images',anchors['images'] and anchors['canvas']=='rgb(244, 247, 255)' and anchors['accent']=='rgb(50, 104, 223)' and anchors['logo']=='brand/ascending-blue/logo-light.svg')
 sizes=raw('responsive')
 check('all nine states at four widths fit and keep actions',len(sizes)==4 and all(x['navigation_visible'] and len(x['rows'])==9 and all(not z['horizontalOverflow'] and z['essentialAction'] for z in x['rows'])for x in sizes))
 key=raw('keyboard-topic'); stage=raw('keyboard-stage'); confirm=raw('keyboard-confirm')
 check('trusted keyboard topic and advance',key['selected']=='etf' and key['outline']=='solid' and stage['selectedStage']=='1' and stage['focusedId']=='panel-title')
 check('trusted keyboard confirmation and focus return',confirm['cash']=='$9,800.00' and confirm['holdings']=='$200.00' and confirm['focused']=='panel-title')
 mobile=raw('mobile-content')
 check('all FAQ answers and seven asset types',len([x for x in mobile['observations']if 'faq' in x])==4 and len(mobile['assetRows'])==7)
 check('truthful unavailable acquisition',mobile['install']['linkHidden'] and mobile['install']['qrHidden'] and mobile['install']['status']=='Beta access coming soon')
 class HTML(HTMLParser):
  def __init__(self):super().__init__();self.ids=[];self.refs=[]
  def handle_starttag(self,tag,attrs):
   a=dict(attrs)
   if 'id'in a:self.ids.append(a['id'])
   for k in ['src','href']:
    if k in a:self.refs.append((k,a[k]))
 h=HTML();h.feed((root/'index.html').read_text())
 check('HTML IDs unique',len(h.ids)==len(set(h.ids)))
 check('static asset and anchor integrity',all((ref[1:] in h.ids if ref.startswith('#') else (root/ref).is_file())for _,ref in h.refs))
 node='/Users/zaccromero/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node'
 for name in ['app.js','demo-data.js','install.js']:
  subprocess.run([node,'--check',str(root/name)],check=True,capture_output=True)
 check('JavaScript syntax',True)
 subprocess.run([node,str(root/'tools/check-install.cjs')],check=True,capture_output=True)
 check('verified install contract guard fixtures',True)
 print(json.dumps({'status':'PASS','assertions':len(checks),'checks':checks},indent=2))
except Exception as error:
 print(json.dumps({'status':'FAIL','error':str(error),'checks':checks},indent=2));sys.exit(1)
