# Apollo testing environment contracts

These nonsecret templates are **preparation only**. The app and server do not load them. `runtime_wired:false` is deliberate. `validate.py` proves contract consistency, not native isolation, a build, a release gate or TestFlight readiness.

| Environment | Prepared behavior | Current readiness |
|---|---|---|
| dev | Preserve the existing labeled fixture account. Optional loopback backend remains an explicit Integration-owned launch choice. | Existing fixture runtime; new contract not wired. |
| staging | Isolated synthetic fixture account, existing Apollo bundle/team, internal TestFlight preparation only. | Disabled until native selection and isolation are verified. No staging backend or authenticated test accounts exist. |
| prod | Disabled; no endpoint, data, signing or delivery. | Intentionally unconfigured and unshipped. No production deadline assigned. |

Run the contract-only check with `python3 config/environments/validate.py`. It reads files and makes no network/signing/build changes.

`data/dev/apollo-paper.sqlite` and `data/staging/apollo-paper.sqlite` are proposed future isolated local databases, not existing stores or migration instructions. The current server default is `data/apollo-paper.sqlite`; do not copy, rename or reset it. The current Integration-focused backend is reported on loopback port 8769, with 8767 an older snapshot; never choose a backend by port alone. No server is started by these files.

Synthetic `test_identity` names are fixture labels, not accounts or authentication. Do not expose the present unauthenticated local backend to a network. A future hosted staging service requires a separately authorized endpoint, transport/authentication boundary and synthetic data isolation; none is provisioned here. For the current demo, standalone staging fixtures avoid that dependency once Integration wires them.

Reuse `com.zaccromero.ApolloHack` and team `6GB3JDVN8D`; no new bundle, certificate, profile, key or account is requested. Same-bundle dev/TestFlight builds replace each other rather than coexist. Separate storage namespaces must cover both paper-game state and onboarding/settings, and preserve existing development data. Distinct coinstalled apps would require a separate owner decision and matching App ID/profile/record; that is not needed for this preparation.

`observed-metadata.json` is a timestamped local observation, not a renewable signing receipt. It contains certificate/profile/public artifact metadata only. It does not contain private keys, raw profiles, credentials, device UDIDs or personal profiles. The old IPA is provider-viewer-only and must not be mistaken for the current game.

`artifact.template.json` lists the evidence Integration must collect for a real staging candidate. Null means unknown, not passed. Environment/configuration hash, exact source/file manifest, bundle, team, version/build and artifact hash must travel together. Build 1 was observed locally; its availability in App Store Connect was not queried. Upload, Apple processing, internal install and owner acceptance are separate states.

See `integration-request.md` for the exact shared-source work owned by Integration. Importing this folder does not perform that work or authorize any upload, invite, production promotion, new signing asset or paid call.
