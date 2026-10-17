# Apollo-Hack

A small, real four-provider round trip with a native iOS results viewer.

## Run the live test

```sh
/Users/zaccromero/code/hackathon/daytona-hackathon/tools/foundation/.venv/bin/python tools/e2e.py
open results/index.html
```

The runner uses the ignored `.mcp.json` and the existing Doppler `hackathon/dev`
connections. It currently depends on the shared Daytona hackathon provider helpers
and foundation tracing runtime; override their root with `APOLLO_PROVIDER_HOME`.
No keys are stored in this repository or in the iOS app.

1. Anchor opens `example.com` with recording disabled and reads its title and URL.
2. A private, network-blocked Daytona sandbox validates that payload and computes
   its SHA-256. The Mac independently downloads and checks the result.
3. SurrealDB stores the exact result in the authorized `hacksprint` scope; a fresh
   connection recalls the run-specific record with Apollo-only labels.
4. Arize records the root and three provider spans using the existing ingestion
   credential. Its separate read-only MCP independently verifies all four spans.

Temporary sandbox/browser resources are cleaned up; hard lifetimes bound leaks.
The test exits nonzero unless all four checks and both cleanups pass. It writes
`results/latest.json`, `results/index.html` and `ios/ApolloHack/run.json`.
Only synthetic public-page data is stored remotely. Each run retains a labeled
memory record and trace. Arize readback polls at most three times. A pending trace
is a failed overall test, never a manufactured pass. Hosted evaluation is not run.

## iOS app and XCUITest

```sh
cd ios
xcodegen generate
```

Open `ApolloHack.xcodeproj`, choose the `ApolloHack` scheme, then build/test on a
simulator. The app displays the captured run bundled at build time, with a full
evidence screen. Rerun the Mac test and rebuild to update it. It deliberately has
no provider credentials and does not trigger cloud jobs from the phone.

Physical-device operations must use the existing shared device lease wrapper;
do not run raw physical-device xcodebuild or disrupt another device owner.
TestFlight requires a Developer Program team, distribution signing and an App
Store Connect app record. Nothing here uploads a build or creates certificates.

## Verification

This new repository has no established full CI/release gate. The meaningful
checks are the live provider journey above and the `ApolloHackUITests` native
journey (provider results → evidence). Their results are reported separately from
physical-device verification, distribution, and owner visual acceptance.

## Internal TestFlight release

Owner authorized one Apollo-Hack distribution certificate and app registration on 2026-10-17. Existing certificates are preserved. The signing key remains in the protected local App Store Connect signing directory, outside this repository.

`tools/testflight.sh archive` requires clean committed source, records its SHA, regenerates the Xcode project and builds a Release archive using the exact Apollo-Hack manual distribution profile. `tools/testflight.sh export` exports an internal-TestFlight-only IPA from that archive. Artifacts and receipts remain ignored under `results/testflight/`.

Before upload: verify the App Store Connect app record matches `com.zaccromero.ApolloHack`, confirm the build number is unused, validate the exported IPA, and record one upload attempt before starting transfer. After an uncertain transfer, read App Store Connect before retrying. Verify processing and internal tester availability separately from upload acceptance. App creation uses Apple’s website; no public App Store release or external tester invitations are authorized.
