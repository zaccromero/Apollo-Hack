# Apollo Discord companion

Read-only slash commands: `/apollo help`, `/apollo status`, `/apollo links`.
Every reply is ephemeral, mentions are disabled, Gateway intents are zero, and commands
are scoped to the explicitly configured Apollo server. No message listeners, financial
execution, paper orders, shared server edits, provider calls or paid model calls.
The companion does not claim to monitor game/backend/market health.

## Offline check

Use Python 3.10 or later and an isolated virtual environment. Install requirements.txt.
Run `python -m unittest discover -s integrations/discord -p 'test_*.py' -v` from repo root.
`python integrations/discord/bot.py` is offline by default and reads no credentials.

## Runtime prerequisites and custody

Apollo application: `1561042929265418392`.
Apollo dedicated server: `1561044080698331337`.
General channel: `1561044081335992362`.
Owner generates the dedicated token on Apollo's Bot page and stores it as
`APOLLO_DISCORD_BOT_TOKEN` in existing Doppler project `hackathon`, config `dev`.
Never paste it in chat, source, receipts or shell arguments. Never use Zeus/Plutus tokens.
Keep Presence, Server Members and Message Content privileged intents OFF.
No interactions endpoint, public tunnel or extra hosting service is needed.

Set nonsecret environment variables:

```
APOLLO_DISCORD_APPLICATION_ID=1561042929265418392
APOLLO_DISCORD_GUILD_ID=1561044080698331337
```

Optional `APOLLO_GAME_URL` is a public HTTPS game link without query credentials.
Without it, links explicitly reports no configured game link and offers the project URL.
A repository URL does not prove the game is publicly deployed.

## Installation and operation

Review the exact zero-permission installation URL in `application.json`.
Only install into the owner-selected Apollo server. No administrator, message history,
message content, member/presence or channel-management access is requested. Existing
server defaults can still grant basic member visibility; this bot requests no event intents.

After owner-selected installation and secure token injection, run with `--connect`.
Add `--sync-commands` on the first authorized run to publish only Apollo's guild-scoped
command tree. This replaces THIS application's guild command set; do not use it if a
future Apollo owner adds commands without reconciling that set. Reconnect without this
flag afterwards. Run under `doppler run --project hackathon --config dev
--only-secrets APOLLO_DISCORD_BOT_TOKEN --no-fallback --no-liveness-ping --attempts 1 --`
followed by the virtual environment Python and bot path. Export the two nonsecret IDs
in the same process environment; never put the token on the command line.

The bot verifies the authenticated application ID before syncing or connecting to the
Gateway. Startup makes no channel posts. Real proof requires the Gateway-ready receipt
AND an owner-invoked slash command with its actual private response. A dry run or mocked
interaction does not establish a live bot. No manual messages through the owner's user
account are part of this lane.

To stop, interrupt only this dedicated foreground bot process. No service manager or
startup persistence is installed. Removing the app from Apollo is an owner action;
never delete the application or another server's bot as cleanup.

Official references inspected 2026-10-17:
- https://docs.discord.com/developers/quick-start/getting-started
- https://discordpy.readthedocs.io/en/stable/interactions/api.html
- https://pypi.org/project/discord.py/

## Source-linked research

`/apollo research question:"What changed AAPL this week?"` resolves AAPL/Apple,
WINA/Winmark or another catalog asset. Optional `asset` selects an exact Apollo asset
ID; `source_url` adds HTTPS context. It uses the producer-owned pure formatter in
`backend/research/discord_brief.py`, with no HTTP transport, port ownership, new key,
network retrieval or model invocation. Run it inside the Apollo source tree so that
sibling package imports resolve. The adapter never writes research data or personal
theses. Fresh web retrieval and unknown pasted articles remain unsupported and are
labelled NOT FETCHED. An arbitrary question is context, not proof it was answered.


## Market research forum and progress jobs

Native forum: `1561052340360978523` in Apollo. Nine market tags classify jobs.
`/apollo job asset:AAPL` explicitly requests PUBLIC reviewed-evidence work; creation
is limited to the actual Apollo server owner. `/apollo jobs` privately lists recent
public progress/results. Existing `/apollo research` questions remain private and
are never copied into forum jobs. Public jobs use a fixed asset-only question template.

Configure nonsecret `APOLLO_RESEARCH_FORUM_ID` and `APOLLO_RESEARCH_JOB_DB` in the
dedicated service. DB path stays in this lane's runtime workspace, outside the source
repository. Durable request IDs prevent duplicate queue entries. At most10 jobs may
be pending; a single async worker runs lightweight local evidence operations.
Interrupted or uncertain jobs become blocked rather than being requeued by the worker.
The Discord SDK retains its documented transport/rate-limit behavior.

Actual milestones: queued, thread creation, record loaded, references checked, reviewed
analysis prepared, three tracks formatted, result posted, published only after result
and progress-message read-back. Time display is America/New_York. No artificial stage
delays, no claim that research is still running after it finishes. Starter posts show
source counts, cutoff, quote status/staleness, missing tracks and result link.

Research producer contract is unchanged: exact asset lookup, details, analysis, pure
format_brief. Default7asset types; stablecoin/bond expansion is explicit per exact ID.
AAPL has reviewed company evidence, SPY issuer-only evidence, BTC and the fictional
option lack reviewed tracks. Jobs label this; they do not fabricate coverage, current
web research, separate autonomous agents, financial advice or any model/provider use.

No Manage Channels/Administrator/privileged event intents are requested. Forum setup
uses the authorized owner UI; the bot publishes as an ordinary member using existing
forum permissions. The bot does not create channels, change roles or manage members.


## Fresh public source jobs

`/apollo job asset:AAPL` (or `SPY`, `BTC-USD`) defaults to a fresh HTTP read of a
small fixed public-source list. `/apollo job asset:WINA fresh:false` retains reviewed
local evidence mode. Exact asset IDs only; only the server owner can publish.
The worker updates the existing market forum with actual fetch/check events, then
publishes separate Leadership, Promises vs results and Public sentiment embeds.
A freshly fetched page can be an old publication. This is bounded source reading,
not broad search, current quotes, complete market coverage, or representative
sentiment. Unknown evidence remains explicit. No model or paid provider calls.
Research owns outbound source/security/date handling in backend/research/fresh_content.py
using the frozen fresh.py transport constants. Fresh jobs include short attributed
official-source content excerpts; they do not establish independent corroboration
or a comprehensive investment analysis. Partial failures and unknown sentiment stay explicit.
The Discord consumer validates identity/provenance/receipt and independently reads
back the final Discord message. All-failure, interrupted and uncertain jobs block;
they are not silently retried. Existing cached posts and job history are preserved.
Private `/apollo research` still uses reviewed evidence and never publishes a question.


## Consented waitlist and private access

`admissions.WaitlistAPI(store)` is an additive producer for Integration to expose as
POST `/waitlist`, body exactly `{email, consent:true}`. Both a new valid request and
a duplicate return the same generic202. No account/status/list route or claim code
is exposed to the browser. Integration must enforce same-origin/rate/body/HTTPS
before public traffic; a loopback demonstration is not public production authority.
Store location is private `APOLLO_ADMISSION_CONFIG` JSON -> `database` (file0600),
shared by the server adapter and Discord process. Do not create separate DB copies.

The owner selected connected Gmail through this agent and approved a five-minute
outbox agent. `mail_bridge.py` is a LOCAL trusted helper, never an HTTP route. Its
config requires `delivery_mode: guild_channel` and the private category ID. `prepare`
reserves one email before returning private MIME data. Send exactly once, read back
Gmail's actual Sent message, then `ack` its actual provider ID. Unknown outcomes block;
never retry them automatically. Never publish emails, claim codes or private content.

The first email includes a verified Apollo invite and one-time 24-hour email code.
`/apollo claim code:...` binds only the actual invoking account inside Apollo. After
membership is checked, it creates a private TEXT CHANNEL inside category Apollo
Personal (1561070673047068754), with explicit access for that user and Apollo and a
View Channel denial for everyone. Server administrators retain Discord's normal
access. No email/name appears in the title. Creation applies all overwrites atomically;
independent permission and welcome-message readback are required. Repeated claims
reuse the same channel. Uncertain creation/message outcomes require reconciliation.
Historical DM records are preserved, but no DM listener or sending path is enabled.

The only additional grant proposed is category-scoped Manage Channels for Apollo,
alongside View/Send/Read History/Embed Links. No Administrator/Manage Roles or global
role grant. The permission grant and effective channel creation are separate live
checks. Use `/apollo research question:...` inside the private channel for Leadership,
Promises vs results and Public sentiment with clickable sources and labeled gaps.
Gateway intents remain zero, including Message Content, Members and DM messages.

Final Gmail welcome waits for BOTH a verified server channel and Integration's real
current Apollo TestFlight receipt. `verified_install` accepts only a verified Apollo
game receipt and exact HTTPS TestFlight join URL. Never put a TESTONLY fixture into
real configuration. Gmail Sent readback proves sending, not recipient opening.
All paid model/provider calls are off. Public HTTPS intake and install readiness are
Integration-owned dependencies; source/tests alone do not prove the complete journey.
