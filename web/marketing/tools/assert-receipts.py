import json,re,sys,pathlib
root=pathlib.Path(__file__).resolve().parent/'evidence'
def read(name):
    t=json.loads((root/name).read_text())
    def unpack(r):
        return json.loads(re.search(r'```json\n(.*?)\n```',r['content'][0]['text'],re.S).group(1))
    return [unpack(r['result']) for r in t] if isinstance(t,list) else unpack(t)
e=read('browser-examples.tool.json'); g=read('guards.tool.json'); m=read('responsive.tool.json'); k=read('keyboard.tool.json'); r=read('reload.tool.json')
f=read('final.tool.json')
checks=[]
def check(name,condition):
    if not condition: raise AssertionError(name)
    checks.append(name)
check('Three distinct substantive learning examples',len(e['examples'])==3 and len({x['kind'] for x in e['examples']})==3 and all(len(x['answer'])>80 for x in e['examples']))
check('Each example selects, opens and closes',all(x['selected']=='true' and x['expanded']=='true' and not x['answerHidden'] and x['closedAgain'] for x in e['examples']))
check('Option contract cost and premium risk', '$500' in e['examples'][2]['answer'] and 'entire premium can be lost' in e['examples'][2]['answer'])
expected_hidden=False if '--negative-control' in sys.argv else True
check('Unavailable distribution has no install target or QR',e['install']['hidden']==expected_hidden and e['install']['qrHidden'] and e['install']['href'] is None and e['install']['status']=='TestFlight access coming soon')
check('All incomplete or unsafe install configs rejected',all(v is False for n,v in g['tests'].items() if n!='validAttestedFixture'))
check('Attested fixture accepted by validator only',g['tests']['validAttestedFixture'] is True)
check('Four measured responsive widths with visible sections and no overflow',len(m)==4 and {x['client'] for x in m}=={320,390,768,1440} and all(x['client']==x['width']==x['scrollWidth'] and not x['overflow'] and x['navVisible'] and all(y['visible'] for y in x['sections']) for x in m))
check('Keyboard activates learning answer and displays focus',k['focused']=='reveal' and k['kind']=='OPTIONS' and k['expanded']=='true' and not k['answerHidden'] and k['outline']=='solid')
check('Direct hash entry reload resets ephemeral example and preserves unavailable access',r['url'].endswith('#preview') and r['kind']=='STOCKS' and r['answerHidden'] and r['installHidden'] and r['qrHidden'])
check('All visible images loaded',all(x['loaded'] for x in e['images']))
check('Final source navigation and unavailable access',all(a['visible'] for a in f['anchors']) and all(s['visible'] for s in f['sections']) and f['distribution']['hidden'] and f['distribution']['qrHidden'])
check('Reduced-motion equivalent disables smooth scrolling',f['motion']['reducedEquivalent']=='auto')
check('QR request is destination-specific to prevent stale cached QR',f['qrCacheKeySource'])
print(json.dumps({'result':'PASS','checks':checks,'proof':'Assertions over saved actual browser tool returns; not owner acceptance'},indent=2))
