from pathlib import Path
import json,re,sys,hashlib
root=Path(__file__).resolve().parents[1]
e=root/'tools/evidence/blue-refresh'
def unpack(r):return json.loads(re.search(r'```json\n(.*?)\n```',r['content'][0]['text'],re.S).group(1))
rows=[unpack(x['result']) for x in json.loads((e/'responsive.tool.json').read_text())]
k=unpack(json.loads((e/'keyboard.tool.json').read_text()));r=unpack(json.loads((e/'reload.tool.json').read_text()))
checks=[]
def check(n,v):
 if not v:raise AssertionError(n)
 checks.append(n)
check('Four measured widths, no horizontal overflow',len(rows)==4 and {x['width'] for x in rows}=={320,390,768,1440} and all(x['width']==x['client']==x['scrollWidth'] for x in rows))
check('Every section inspected and navigation visible',all(x['navVisible'] and all(s['visible'] for s in x['sections']) for x in rows))
check('Ascending A logos loaded in header and footer',all(len(x['logos'])==2 and all(i['src']=='brand/ascending-blue/logo-light.svg' and i['loaded'] for i in x['logos']) for x in rows))
expectedAccent='#c4ed59' if '--negative-control' in sys.argv else '#3268DF'
check('Owner blue-on-light palette rendered',all(x['colors']['background']=='rgb(244, 247, 255)' and x['colors']['text']=='rgb(11, 20, 40)' and x['colors']['accent']==expectedAccent and x['colors']['primaryText']=='rgb(255, 255, 255)' for x in rows))
check('Three distinct learning examples open/select/close',all(len(x['examples'])==3 and all(y['selected']=='true' and y['visible'] and y['closed'] and len(y['answer'])>80 for y in x['examples']) for x in rows))
check('All visible images load',all(x['imagesLoaded'] for x in rows))
check('Unavailable installation remains truthful',all(x['install']['hidden'] and x['install']['qrHidden'] and x['install']['status']=='TestFlight access coming soon' for x in rows))
check('Keyboard activation and focus visible',k['focused']=='reveal' and k['outline']=='solid' and k['kind']=='OPTIONS' and k['visible'] and k['expanded']=='true')
check('Direct reload and both primary anchors work',r['url'].endswith('#preview') and r['kind']=='STOCKS' and r['closed'] and r['#preview']['visible'] and r['#access']['visible'])
base=Path('/Users/zaccromero/code/hackathon/Apollo-Hack/web/marketing')
check('Behavior and install bytes unchanged on actual base',all((base/f).read_bytes()==(root/f).read_bytes() for f in ['app.js','install.json']))
print(json.dumps({'status':'PASS','checks':checks,'scope':'Targeted owner-authorized branding delta; originalfullreview not restarted'},indent=2))
