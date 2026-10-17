# Apollo-Hack

Apollo is an educational paper-investing game with stocks, ETFs, commodity and real-estate fund exposures, crypto, a synthetic long option, demo stablecoins, a fictional direct bond, and a fictional portfolio-copy strategy. All execution uses simulated cash and labeled demo prices. Research provenance, dates, missing evidence and historical sponsor receipts remain separate.

The native app opens the game by default. Tap a card for research, swipe left to pass, up to watch, or right to review an explicitly confirmed paper order. Choose a risk profile before trading; previews show portfolio-risk and sentiment coverage estimates. Saved demo portfolios survive reopening. Provider diagnostics remain available only in development. TestFlight uses the guarded staging configuration. On first release launch, a validated one-time local carryover preserves the existing portfolio, saved profile, completed onboarding and discovery preferences; the original development bytes remain saved. Conflicting or unreadable accounts stop safely rather than being overwritten.

The optional Mac-local backend starts with `python3 -m backend.server --port 8767`. Simulator launch argument `--apollo-backend-url=http://127.0.0.1:8767` opts into its persistent paper account and reviewed research. A physical phone cannot reach the Mac through loopback. Backend failure never substitutes a demo account. `data/` is ignored and startup does not reset saved state.

PRISM/Nicrron action defaults are paused/disabled with zero model allowance. Current WINA research and the historical assigned PRISM corpus have different hashes; mismatches are rejected. Explicit cached search is local evidence only. Never enable paid requests or telemetry without fresh owner authority.

Current integration status, ownership, exact imports and remaining acceptance checks are in [the shared ledger](docs/lanes/INTEGRATION.md). The current nine-type Simulator acceptance passed. The core Beta gate and final P0/P1 review are recorded in the shared ledger; full hackathon acceptance and TestFlight availability are separate.

## Original four-provider diagnostic (explicit new run only)

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
simulator. The game opens by default. Development diagnostics display the captured provider run bundled at build time; those historical results do not certify the current game. Provider credentials are not bundled. Release builds explicitly select staging; production is disabled.

Physical-device operations must use the existing shared device lease wrapper;
do not run raw physical-device xcodebuild or disrupt another device owner.
TestFlight requires a Developer Program team, distribution signing and an App
Store Connect app record. Nothing here uploads a build or creates certificates.

## Verification

There is no hosted CI pipeline. The current task's actual-base core Beta checks are recorded in `docs/lanes/core-beta-gate-and-final-review.json`: backend101, Discord44, environment guards48, carryover repair21, native populated Release carryover/reopen and original-development preservation. Earlier nine-type, comparison, charts, onboarding and paused-provider evidence is reused only within its recorded boundary. Obsolete UI fixtures and the owner-mutating one-share driver are excluded from automatic test runs. Full feature acceptance, signing, Apple processing, installation and owner acceptance remain separate.

## Internal TestFlight release

Owner authorized one Apollo-Hack distribution certificate and app registration on 2026-10-17. Existing certificates are preserved. The signing key remains in the protected local App Store Connect signing directory, outside this repository.

`tools/testflight.sh archive` requires clean committed source, records its SHA, regenerates the Xcode project and builds a Release archive using the exact Apollo-Hack manual distribution profile. `tools/testflight.sh export` exports an internal-TestFlight-only IPA from that archive. Artifacts and receipts remain ignored under `results/testflight/`.

Before upload: verify the App Store Connect app record matches `com.zaccromero.ApolloHack`, confirm the build number is unused, validate the exported IPA, and record one upload attempt before starting transfer. After an uncertain transfer, read App Store Connect before retrying. Verify processing and internal tester availability separately from upload acceptance. App creation uses Apple’s website; no public App Store release or external tester invitations are authorized.
