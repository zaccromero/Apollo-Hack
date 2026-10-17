# Apollo marketing page

Self-contained static site. Host this directory as a static root, or mount it at a directory URL ending in `/`. Entry: `index.html`. No build, npm install, account, tracking or remote asset dependencies. Local preview: `python3 -m http.server 4177 --bind 127.0.0.1` from this directory.

## Distribution is pending

`install.json` deliberately ships with `status: unavailable`, no URL and no QR. Do not substitute the old provider-viewer IPA or invent a public invitation. The local website example is educational; it is not a browser version of the native game.

The integration/release owner must first open the exact current Apollo GAME Apple install link on a real iPhone and verify build identity and access. Only then run `python3 tools/configure-install.py --url ACTUAL_VERIFIED_APPLE_URL --build ACTUAL_GAME_BUILD --verified-at ISO_TIMESTAMP_WITH_TIMEZONE --confirm-game-build` on macOS. The helper uses built-in Swift/CoreImage/Vision, generates `assets/install-qr.png`, decodes its pixels back to the exact URL, then writes the matching configuration. No package install or paid service. The helper does not inspect Apple availability or grant distribution permission; the human install check is required. Keep its console readback as evidence.

Supported direct URLs: Apple TestFlight `/join/` invitations and App Store product links. No redirect shorteners, queries, custom schemes or non-Apple hosts. The page rejects incomplete config, wrong product/build attestation, future/invalid dates, payload mismatch and missing QR image. If config or image fails to load, access remains honestly unavailable. QR requests include the destination as a cache key. The visible button and QR come from the same configuration.

To disable access again, restore the supplied unavailable install.json. No browser storage is used.

## Brand and icons

`brand/GUIDE.md`, `brand/tokens.json`, `brand/app-icon.svg`, and opaque 1024/180 PNG exports are proposed brand assets. Integrator owns any iOS asset-catalog change; none has been made here. `assets/apollo-demo.jpg` is the coordinator-approved actual simulator screenshot, visibly labeled as demo.

## Verification boundaries

`python3 tools/assert-receipts.py` checks saved actual browser observations. `--negative-control` intentionally fails to demonstrate rejection of a false expectation. These are recorded receipts, not a new live test or owner acceptance. The focused gate covered examples/disclosures, keyboard, direct hash reload, honest unavailable access, validation guards, four responsive widths, every section and reduced-motion CSS equivalent. Local QR pixels were generated/decoded only with a TESTONLY fixture outside this distributable site; no real install link was available to test.

Native desktop fullscreen acceptance remains BLOCKED by the shared Chrome preflight; emulated/responsive captures are diagnostic. OS reduced-motion preference, physical iPhone website check, hosted URL, actual install journey and owner visual acceptance are NOT_RUN/OPEN. Existing game/release tests are integration-owned and were not rerun by marketing. The repo has no established web full CI gate.


Current owner-selected branding: Ascending A, blue on light. See brand/GUIDE.md andbrand/tokens.json; historicalsun/limeassetsarepreservedbutunusedbycurrentpage. Targeted branding verifier: python3 tools/verify-branding.py; its savedbrowserreceiptsdescribe the refreshedcandidate, not ageneralCIgate or nativeappacceptance.
