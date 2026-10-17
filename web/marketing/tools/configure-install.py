#!/usr/bin/env python3
"""Run only AFTER a human verifies Apollo GAME installation from the exact link."""
import argparse, datetime, json, pathlib, re, subprocess, tempfile, urllib.parse
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--url',required=True)
p.add_argument('--build',required=True)
p.add_argument('--verified-at',required=True,help='ISO timestamp with timezone of real iPhone install check')
p.add_argument('--confirm-game-build',action='store_true',required=True,help='Attest exact link installs current Apollo game, not old provider viewer')
a=p.parse_args()
u=urllib.parse.urlsplit(a.url)
assert u.scheme=='https' and u.hostname in ('testflight.apple.com','apps.apple.com') and not u.username and not u.password and not u.port and not u.query and not u.fragment, 'Only direct Apple HTTPS links are supported'
assert (u.hostname=='testflight.apple.com' and re.fullmatch(r'/join/[A-Za-z0-9]{8}',u.path)) or (u.hostname=='apps.apple.com' and re.search(r'/id\d+/?$',u.path)), 'Unsupported Apple install URL'
t=datetime.datetime.fromisoformat(a.verified_at.replace('Z','+00:00'))
assert t.tzinfo and t<=datetime.datetime.now(datetime.timezone.utc), 'Verification must be a real timestamp with timezone, not future'
assert a.build.strip(), 'Build must identify the actual Apollo game'
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='apollo-swift-cache-') as cache:
    subprocess.run(['swift','-module-cache-path',cache,str(root/'tools/qr.swift'),a.url,str(root/'assets/install-qr.png')],check=True)
config=dict(status='verified',url=a.url,product='Apollo',build=a.build,verifiedAt=a.verified_at,gameBuildVerified=True,qr='assets/install-qr.png',qrPayload=a.url)
(root/'install.json').write_text(json.dumps(config,indent=2)+'\n')
print('Configured exact URL + locally decoded QR. This script does not verify Apple availability; human install check is required.')
