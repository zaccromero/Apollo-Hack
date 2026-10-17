# Apollo Discord lane

Receiving owner chat: `01a14a8a-92a9-7f33-a659-1b1039830e1e`.
Coordinator: `01a14a6f-1bfb-7000-99cb-16b6c9c876d9`.
Exclusive source: `integrations/discord/**` and this file. Integration owns the central
ledger, shared server, device, release and final combined game gate. Research owns
`backend/research/**`; its pure formatter is consumed read-only. Personal Zeus/Plutus
apps, tokens, channels and source are preserved.

Work-ready cutoff: October 17, 2026 **16:00 America/New_York**. Protected rehearsal and
recording: **16:00–16:30**; judging16:30. Intake11:46EDT; first checkpoint by12:06.
Discord dependencies do not hold the phone/full-game priority.

## Outcome, authority and actual receipts

Human requested Apollo's own app/bot. Direct replies in this chat approved Developer
Terms/Policy creation, a custom Apollo server and its Community Guidelines, exact
zero-permission bot installation, and coordinator messages. Separate direct human
Research-chat turn `01a14a92-f524-7e32-a02f-db76ff182135` authorized Research/Discord
coordination and source-linked summaries without spending credits.

- PASS: distinct Apollo app `1561042929265418392`, verified General Information page.
- PASS: its bot exists; Presence, Server Members, Message Content privileged intents OFF.
- PASS: dedicated Apollo server `1561044080698331337`, general `1561044081335992362`;
  owner Zacc verified in actual server UI.
- PASS: exact `bot applications.commands`, permissions0 installation. OAuth Success
  says Apollo authorized/added to Apollo; server member list shows Apollo App and Zacc.
- No manual user-account message, public invite, other bot credential or paid call used.
- NOT_RUN: Gateway connection and real slash-command delivery. Dedicated Apollo token
  generation/storage remains owner-only input. The earlier Zeus setup reused an existing
  Doppler token; it did not create an Apollo token.

## Implementation and acceptance

`bot.py` defaults to an offline readiness report and never reads credentials in that mode.
Explicit connect requires dedicated Apollo application identity, selected guild, and token
injected from the approved secret store. Zero Gateway intents, no message listeners,
private responses, mentions disabled. Registration is explicit and guild-scoped; it
replaces only this application's command tree. Startup posts nothing.

Commands: `/apollo help`, `/apollo status`, `/apollo links`, `/apollo research`.
Help teaches paper controls; status describes only companion scope; links labels missing
public game URL. Discord cannot place or confirm paper or real-money orders.

Research accepts a natural-language question, optional asset ID and optional HTTPS URL.
It resolves one supported asset locally, reads `ResearchService.details/analysis` and
calls the Research owner's pure `format_brief`. No shared HTTP/auth/server restart is
needed. Output: overview with caution/counterevidence, then exactly Leadership / Promises
vs results / Public sentiment, source URLs/dates and snapshot limitations. Unknown or
ambiguous assets fail explicitly. Pasted URLs are context, **NOT FETCHED or reviewed**.
A question such as 'What changed AAPL this week?' does not establish current-week
coverage; completeness/latest updates remain unverified. No sentiment percentage or
public consensus is invented. No personal notebook or thesis is read/saved.

Offline checks cover default-no-network/no-secret behavior, token nonlogging, identity
binding, wrong-guild rejection, private/deferred responses, source separation, ambiguous
questions, actual local AAPL/WINA output, explicit asset and known-URL resolution, and
unfetched pasted URLs. Research formatter hash/release remains producer-owned; import
only its explicit ready release. Record actual test results in the scoped import receipt.
Stable focused local gate: **17 tests PASS**, dependency consistency PASS, offline readiness PASS at12:00EDT. Includes actual local research-to-command callback payload with network forbidden; Discord delivery remains NOT_RUN. Research formatter dependency SHA256 `55acb17b10b890c7189308b926e833feecb53d55a7cc5e495daac393aca08588` matched producer release.

The repository has no pre-existing full CI/release gate for this new companion. Its
focused local gate does not establish actual game/integrated-gate/device acceptance.

## Remaining required work and exact resume

Owner must generate the dedicated token through Apollo's Bot page and store it in
Doppler `hackathon/dev` as `APOLLO_DISCORD_BOT_TOKEN`; no chat/plaintext/repo token.
After that: inject only that key; set application1561042929265418392 and
server1561044080698331337; run dedicated foreground bot with explicit first registration;
verify authenticated app identity and Gateway ready, then have owner invoke
`/apollo research question:What changed AAPL this week?`. Capture its actual private
three-track reply and clickable dated links without a manual owner-account message.
Until then live delivery is BLOCKED by credential input, not by game integration.

Autonomous fresh web research and pasted-article retrieval are not implemented by the
cached research adapter. They remain UNVERIFIED/unsupported; do not describe this
component as a live research agent. Any later live retrieval must be owned by Research,
source-scoped and separately verified under the existing no-credit restriction.

Failure/recovery: stop only this dedicated foreground process; no persistent service is
installed. No application deletion, other-server cleanup or token rotation is authorized.
Bounded source inspection and affected checks only; no additional agent or broad review.
Central full-game review budget remains with Integration. Disposition ACTIVE_KEEP;
full Discord outcome stays open until actual command delivery or owner accepts offline.

## Superseding live checkpoint — 12:09 EDT

The earlier credential blocker is RESOLVED. Human personally reset the replacement,
then authorized secure saving. Direct browser UI transfer saved the dedicated value to
Doppler hackathon/dev/APOLLO_DISCORD_BOT_TOKEN; scoped availability TRUE12:08:27EDT.
No value was put in chat, source, scratch files, logs or command arguments.

ONE explicitly authorized Apple brief was delivered by the authenticated Apollo bot:
https://discord.com/channels/1561044080698331337/1561044081335992362/1561048502845317247
Application and destination identities were checked before sending. Existing-message
GET readback verified exact text, all four embeds, three tracks, dated URLs, opposing
evidence and no mentions. Discord-added default inline=false metadata was normalized
in the verification only; no second message was sent. No paid/model/provider calls.

Distinct app/bot, dedicated server, minimal installation, prepared companion and one
actual authenticated operation are VERIFIED. Gateway and ongoing slash-command
operation remain NOT_RUN. Cached briefs do not establish fresh autonomous web research.
No background bot service or restart policy was installed. Existing proof and source
receipts: Apollo Discord chat outputs/apollo-apple-discord-live.json and
apollo-apple-discord-actual-message.json. Resume ongoing operation only with reconciled
runtime ownership; never resend the already delivered Apple test as a new test.

## Ongoing runtime — 12:14 EDT

Direct human authorized keeping Apollo running for stock questions in Discord, with
three tracks, clickable sources, no paid credits and no delay to16:00 app delivery.
Registered the existing four guild slash commands and independently fetched their
definitions: help/status/links/research PASS. Started dedicated user LaunchAgent
`com.apollo-hack.discord`; observed state running, PID69219, runs1, never exited,
and actual Gateway-ready event for Apollo app1561042929265418392 /
server1561044080698331337 / intents0. Configuration contains only nonsecret IDs and
scoped Doppler injection. Auto-restart on failure and user login startup are installed.

Service configuration: `/Users/zaccromero/Library/LaunchAgents/com.apollo-hack.discord.plist`.
Runtime logs/config: this chat workspace `work/apollo-discord-runtime/`; no token files.
Stop only this service with `launchctl bootout gui/501/com.apollo-hack.discord`.
Source/requirements match the17-PASS release; no new code or full gate/review rerun.

Use `/apollo research question:What changed AAPL this week?` in Apollo. Replies are
private and use locally reviewed, dated evidence. They do not establish fresh current
web research or answer every arbitrary financial question. Ongoing actual slash-command
response awaits an owner-invoked command; no manual user-account test was sent.
Gateway readiness, slash registration, local callback checks and earlier actual REST
brief delivery are separate proofs. Evidence: chat outputs/apollo-discord-running.json
and apollo-discord-command-registration.json. No shared app/device/server mutation.

## Actual ongoing slash-command acceptance — 12:16 EDT

Direct human requested one stock-question test through Apollo Discord. Sent ONE real
`/apollo research` question: 'For WINA, what supports caution and what pushes back?
Keep the three tracks separate with dated sources.' Actual request1561050196819836928
produced private follow-up1561050200456560691 from Apollo in its general channel.
Discord UI DOM confirmed exact three tracks, caution/counterevidence, snapshot limits,
9clickable links to3distinct sources, publication dates and the one-article sentiment
sample limitation. No AAPL evidence mixed into WINA. No paid/model/provider calls.

PASS_ONE_LIVE_SLASH_QUESTION closes the earlier pending live-response check.
Exact actual text and links: this chat outputs/apollo-wina-live-slash-reply.txt/.json;
acceptance outputs/apollo-wina-live-slash-acceptance.json. This is an ephemeral private
reply; no durable public message URL is fabricated. Service remains running; no source
code or app/device/shared-server change, no extra suite or review.16:00 app priority
and16:00–16:30 recording/rehearsal remain independent.

## Research forum extension — authorized12:23 EDT

Full outcome: build a native market research forum with visible real progress,
coordinate existing Research, retain three tracks/clickable sources, spend no paid
credits, and preserve16:00 app priority/16:00–16:30 rehearsal. First observable
checkpoint12:43EDT. Native forum1561052340360978523 created through owner UI; tags
Stocks/ETFs/Commodities/Crypto/Real estate/Options/Strategies/Stablecoins/Bonds.

Research producer explicitly released existing pure details/analysis/format_brief
contract for real local stages, with cached_reviewed_or_demo/paid_calls0 metadata.
No new Research mutation, callback, model/provider or fresh-web agent was requested.
Actual required fresh autonomous agent research remains distinct from this reviewed
evidence worker; do not imply that cache-processing jobs scanned a market.

Design check scope: public publishing, ownership, source binding and restart behavior.
OBSERVED: private command tested, token custody established, forum/channel actual,
producer API source read. INFERRED failure paths addressed before implementation:
private question leakage (asset-only public command; private command unchanged),
unrelated users publishing (server-owner gate), mismatched evidence (exact asset/
corpus/track-source binding and date/URL checks), duplicate remote publication after
restart (durable request IDs, blocked interrupted/uncertain work; no worker requeue),
false Published state (result plus progress read-back). No added agent or broad review.
UNVERIFIED until live proof: forum member publishing permissions, actual progress
updates/tag application, restart/runtime import and four-market final results.

Implementation stays only integrations/discord/** and this record. Durable job DB
and service config are lane runtime dependencies; no shared app/backend/device edits.
Acceptance: owner queues four exact IDs across stock/ETF/crypto/options, actual forum
threads show honest event history and source coverage, final three-track payloads
match read-back, invalid/nonowner/uncertain/restart cases pass offline, private
research still works, actual service returns Gateway ready with no paid calls.

## Research forum live result — 2026-10-17T12:39:33.072904-04:00 / 2026-10-17T16:39:33.072904+00:00 UTC

Owner chat01a14a8a-92a9-7f33-a659-1b1039830e1e; exclusive
integrations/discord/** + docs/lanes/discord.md. Documented cooperative assignment;
formal managed Kanban claim remains NOT ESTABLISHED. Integration alone publishes
central ledger/index. No ownership or permission was inferred from chat silence.

PASS: native market-research forum1561052340360978523, nine market tags and saved
guidelines; six commands registered and independently fetched. Actual imported source
gate29PASS, zero resource warnings. Own source hashes:
- integrations/discord/bot.py: caca2cc0bdfa9ddfbf69536ccd6cfb26c4c2e0116eaa4dbfd758df3f8c3d2f29
- integrations/discord/forum_jobs.py: ab143d65a1e9a342ff2d5cfd999edd65d62aa3226c9a0615889432119a8c08a5
- integrations/discord/test_bot.py: 4f5bff4c4670f931f04d6ffeaa3ec927584c3d37414397b119a4e7fc7d455324
- integrations/discord/test_forum_jobs.py: 1fd623758f93e9f48793a083f04a599bd23b42940f4756375ff109fe63dd6ccf
- integrations/discord/README.md: ff7f8846ef0702b73bfff7114c5a928c02385d35c849229fe98c11b9fab08782

PASS: actual four owner-UI jobs across stocks(AAPL), ETFs(SPY), crypto(BTC-USD),
options(AAPL_20261120_C350_DEMO). Actual starter/status and final message reads verified
application identity, forum parent, market tag, event timeline, exact three tracks,
source links/date labels and no mentions. Source records7/1/0/0 respectively; missing
tracks explicitly visible. Published means the local job/result was delivered; it does
not certify fresh web research, market coverage or a trading conclusion.

Live forum: https://discord.com/channels/1561044080698331337/1561052340360978523
Actual progress-list command response1561055605525971046 privately lists all four
Published threads. Evidence: this chat outputs/apollo-research-forum-live.json; actual
base gate outputs/apollo-discord-forum-05-actual-base-tests.txt; immutable import
manifest outputs/apollo-discord-forum-05.json.

RUNNING: dedicated service com.apollo-hack.discord PID6406, Gateway ready/intents0,
forum configured. Durable job DB under lane runtime workspace, max10pending, single
lightweight worker, owner-only public job submission, no private question forwarding.
Token still injected only through Doppler. No added server grants, privileged intents,
paid/model/provider calls, new agents, shared backend/device work or app delay.

Review: scoped design/final source checks only, no extra broad review or reviewer;
P0/P1 identified=0 for this component. P2 follow-up: stronger remote idempotency beyond
Discord SDK transport behavior; worker-level interrupted/uncertain jobs already block.
No review budget for the main game was consumed or reset.

Remaining required work: owner acceptance of this forum/progress feature. Fresh
autonomous retrieval/research agents remain NOT_RUN and are Research-owned; this
component processes reviewed records/fixtures honestly. Parent waitlist/dedup/admission,
personal-channel welcome and usable current-game TestFlight link remain OPEN outside
this selected first step. Marketing/admission and Integration must establish those
contracts before delivery. No missing parent capability is silently removed.

Next action: owner inspect forum or run /apollo job asset:WINA and /apollo jobs;
Research may add its future fresh-evidence contract without displacing app work. First
observable deadline12:43EDT met at12:34:55 with first published job; all four done12:35.
Work-ready16:00 America/New_York; rehearsal/recording16:00–16:30; judging16:30 preserved.
Global app combined gate, final review, phone journeys and TestFlight acceptance remain
Integration-owned and UNVERIFIED by this Discord component. Disposition ACTIVE_KEEP.


## Fresh-source forum extension — 2026-10-17 12:47 EDT / 16:47 UTC

Direct human request adds actual fresh source retrieval across markets with real
forum progress; three tracks, clickable dated sources, zero paid credits and16:00
app priority remain required. Existing cached posts remain historical. Research
reconciled ownership and accepts backend/research/fresh.py; Discord consumer only
integrations/discord/** plus this record. No new executor/device/server work.

Contract: on-demand exact AAPL/SPY/BTC-USD reads of allowlisted public primary
sources; fresh HTTP retrieval is distinct from newly published/current-complete
research, live quotes, model reasoning or representative public sentiment. Real
fetch-start/completed/check events bridge producer to forum; unknown tracks and
failure details are explicit. Existing /apollo job defaults fresh, optional
fresh:false retains reviewed mode. Public command remains owner-only and asset-only;
private questions stay private. Persistent mode and interaction ID preserve history.
No automatic schedule or recurring source calls.

Acceptance: source producer owns fixed-URL/redirect/TLS/SSRF/byte/time guards and
retrieval receipts. Consumer validates asset/corpus/track/source binding and receipts,
rejects paid/missing/zero-success fresh claims, and publishes only after source job
completion plus exact Discord result/status readback. Three actual owner UI jobs
must show stock/ETF/crypto fresh events, clickable source links and explicit limits.
All-failure stays Blocked; interrupted/uncertain jobs never silently retry. Scope
rollback: restore own version and restart own service; preserve DB/history and all
shared app work. Source import uses exact expected hashes.

Focused engineering-understanding check (one round, new producer/consumer boundary):
OBSERVED old formatter hardcodes cache and old progress deduplicates source stages.
INFERRED P1 false-fresh claim if reused unchanged: require separate fresh formatter
and receipt validation; INFERRED P1 publish despite all fetch failures: require
successful receipts before Published. INFERRED P1 SSRF from user URLs: exactIDs only,
producer static allowlist, no pastedURL forwarding. INFERRED privacy failure: public
jobs carry only asset/mode; no question or account context. UNVERIFIED actual source
availability and live Discord until bounded proof. No new broad review/reviewer.
Next observable contract13:00EDT; end-to-end fresh forum target13:15 if producer
available;16:00 work-ready +16:00–16:30 recording preserved. Broader research agents,
remaining markets, waitlist/admission/personal channel/TestFlight remain required
parent scope, not silently claimed complete by this bounded fresh capability.


## Fresh HTTP forum proof — 2026-10-17T16:55:34.128721+00:00 / 12:55 EDT

PASS bounded3actualfresh HTTP source jobs initiated via signed-in owner slash UI,
then independently retrieved via bot API: AAPLthread1561059585585053857 (2feedrecords,
1HTTPread), SPY1561059646221983814 (1/1), BTC1561059683853410455 (1/1). Sourceproducer
SHA78e49965fbbd338f14648e8ce4f3e62984d0d74f84a1749173d48202e1d25ada exactreleased.
Each timeline has actual fetchstarted/completed/sourcechecked times and the exact
three tracks with dated clickable source links. Receipt source binding validates
fetch_url/checkedHTTP200/hash/asset/corpus/time/no historicalblend/paidcalls0.
All-failure, unbound or paid receipts BLOCKED. Existing reviewedposts preserved.

Own imported gate32PASS (outputs/apollo-discord-fresh-07-actual-base-tests.txt),
commandoption fresh registered+fetched, sixcommands unchanged. Dedicated service
Gatewayready/intents0 PID47533 runs2; previousexit255 from intentional ownrestart,
not evidence of spontaneous crash. No otherprocess/source/device/build touched.
Forum guidelines saved/readback hideunsavedchanges; updatestruthfullydistinguish
fresh metadata from broaderresearch. Actualbusiness-stateproof DOM/API; native
fullscreen/screenshot certification NOT_RUN. Receipt outputs/apollo-fresh-research-forum-live.json.

OPEN REQUIRED full sourcecontentresearch: V1 metadata-only is dependencyready,
not full requested agentresearch. Research explicitly accepted bounded sourcecontent
checks target13:10EDT; no broadsearch/measuredsentiment fabricated. Discord owns
progresswordingfix SourceRecords vs HTTPReads and exactduplicatecollapse for next
checkpoint; no new broadreview. Sourcecountlabels observed V1AAPL2records are1HTTP,
not2HTTP. Parentremainingfreshothermarkets/admission/dedup/personalchannel/TestFlight
remain open by namedResearch/Marketing/Integrationowners. Nextactualproof13:15EDT,
16:00workready/16:00–16:30rehearsal preserved, appfullgate Integrationonly.


12:59EDT consumer delta: source records and successful HTTP reads now separate;
exact repeated stage/note collapses without suppressing separate source activity.
New callback timeout cancels its pending progress operation before Blocked handling;
focused stalled-progress check proves no result published. Focused16testsPASS staged;
actual-base check and existing3postprogresscorrection pending import. No sourcefetch
or newjob needed for this correction. V2contentproducer stillResearch-owned/open.


## Fresh source CONTENT contract release — 2026-10-17 13:06 EDT / 17:06 UTC

Research newmodulebackend/research/fresh_content.py SHA
ad5978cbc201063e74309aac49f8ca4307ca62c83c6cfabdbaf75962a9bc0a17 released,
V1dependency78e49965... preserved. Actualproducer3livecontentchecks and failure/
partial/malformed-feed/date/binding/20words/Discordsize checks PASS by producer,
read source/release here. Consumer switches both imports to new module, requires
version2/fetched_content plus bound observations/checkedHTTP receipts. Partial
failures show SOURCE_FAILED/no_excerpt SOURCE_GAP, only bound successes publish;
metadata-only cannot masquerade as source-content success. Unknown sentiment,
independent corroboration and directional verdict remain explicit. Actualsource
contentquotes are issuer/projectstatements, not independently established outcomes.

Consumer prior actual16testsPASS + 17newstablefocusedstagedPASS; previous absolute
unittest module-path invocation error retained in workspace and corrected by proper
module invocation (test infrastructure invocation, not productfailure). Last3existing
V1statusposts corrected+independentreadbackPASS, sourceitems vs HTTPreads separate;
no jobs/fetches repeated. Evidence outputs/apollo-fresh-progress-08.json.

Required acceptance remaining: import exactcurrentownedhashes, actual-base ownsuite,
restart only Apollo service, run3actualownerUI contentjobs, independentfinalmessage/
track/date/sourcehash/statusreadback, scopedfinaladversarialP0/P1check once. Noextra
broadreview/mainappgate, no paidcalls/newagents/device/sharedbackend changes. Target
13:15EDT;16:00workready and16:00–16:30recording buffer remain protected.


## Fresh CONTENT forum acceptance — 2026-10-17T17:10:01.863440+00:00 / 13:09 EDT

Completed bounded requested capability: actual free official-source CONTENT reads
across stocks(AAPL), ETFs(SPY), crypto(BTC-USD), real forum progress and three tracks
with clickable dated sources. Actual ownerUIjobIDs1561063118719811705,
1561063123992055809,1561063131269300397; threads1561063120619831437,
1561063188454187152,1561063232360284361. AAPL2attributedobservations/3HTTPreads;
SPY1/1; BTC1/1. IndependentAPIreads validate actualauthor/forum/tags/finalpayload,
threecanonicaltracks, sourceHTTP/hash/datebinding, version2/contentstatus, no mentions
and no paidcalls. VisibleAAPLreply confirms2actualclickablelinks, untruncated short
attributedsourceexcerpts, and no-sample Publicsentimentunknown. Jobs completed13:08,
first13:10producerand13:15consumerproofdeadlines met early.

Evidence this chat outputs/apollo-fresh-content-forum-live.json (all actualmessages,
receipts, progress), outputs/apollo-discord-fresh-09-actual-base-tests.txt34PASS zero
resourcewarnings, outputs/apollo-discord-fresh-running.json runningPID79216
Gatewayready/intents0/runs4. Last exit255 reflects intentionalownreloads,
no spontaneouscrash claimed. All10historicaljobs preserved. No privatequestions,
notes/account data, extraapppermissions, newagents/reviewers, paid/model calls,
sharedserver/native/build/Simulator/device mutation.

Final scoped adversarial review ONCE: inspected current consumer/producer path,
owner-only publicsubmission, exactasset/URLbounds, TLSdefault/no proxy/redirect,
HTMLasdata/escapedsourcecontent, paid/version/time/corpus/HTTP/hash/sourcebinding,
partialfailurevisibility, cancelledstalledprogress, terminalrestart/readback ordering.
P0=0/P1=0; STOP review, READY FOR OWNER REVIEW for this bounded component. No new
broadmainappreview/gate consumed. P2followups remain: resolver/DNS pinning + strict
preemptivejobdeadline (currently socket5s/45s betweenreads/4attempts), SDKremote
idempotency beyond worker block, clearermetadata/contentposttitles. They do not
reopen review. This is attributedofficialobservations, not independentcorroboration,
comprehensivemarketanalysis/livequotes or representativepublicsentiment; unknowns
explicit. Nativefullscreen/screenshotacceptance NOT_RUN; proof is businessDOM/API.

Owner/path binding unchanged exclusiveintegrations/discord/** + thisrecord;
Researchownsbackend/research/**; formalmanagedclaim NOT ESTABLISHED. Exacthashes:
- integrations/discord/bot.py: 9bc646b60f092ac4f85ffe8caec7911dcf3dffc73bdfef2bfe804ad7243b7538
- integrations/discord/forum_jobs.py: 95204173e85e88b61cec4b102a7cc6a155d92f75ffe7cae7b1938a806e33b560
- integrations/discord/test_forum_jobs.py: 9154e30e9ac97505753b54d1176aa89db75d193013e0a3c7a36d6a7aa81fa4d9
- backend/research/fresh.py: 78e49965fbbd338f14648e8ce4f3e62984d0d74f84a1749173d48202e1d25ada
- backend/research/fresh_content.py: ad5978cbc201063e74309aac49f8ca4307ca62c83c6cfabdbaf75962a9bc0a17
- backend/research/discord_brief.py: 55acb17b10b890c7189308b926e833feecb53d55a7cc5e495daac393aca08588


Remaining fullparent capabilities: owner acceptance of freshforum; broader markets/
independentcounterevidence/sentimentsampling remain Research coverage gaps. Waitlist
acceptance+dedup/admission/personalApollochannelwelcome/currentTestFlightlink remain
Marketing/Integration-owned OPEN, outside this selected researchforum extension.
Appcombinedgate/nativejourneys/release/TestFlight acceptance UNVERIFIED here and
Integration-only. No missingparentcapability silentlyremoved. Coordinatorsentexact
currentresult for canonicalledger; Integrationaloneowns sharedledger/index.
Nextaction owner /apollo job asset:AAPL,SPY,BTC-USD or /apollo jobs; no auto recurring
fetchschedule introduced. Postproofhandoff13:10EDT, work-ready16:00America/New_York,
recording/rehearsal16:00–16:30, judging16:30 remain protected. ACTIVE_KEEP ownservice.


## Waitlist admission + private email delivery — 2026-10-17 13:16 EDT /17:16 UTC

Directhumanadds dedup→accept→privateApolloDiscordchannel+TestFlightlink; explicitly
chooses EMAILviaexistingFREEsender. OwnerDiscordchat unchanged; exclusiveowned
integrations/discord/** +thisrecord. Marketingownsform/web; Integrationownsserver/
publichosting/currentinstallreceipt. Newboundary, previousresearchreviewclosed.

Contract: exactnormalizedemail dedup; first validconsentedrequestacceptedpending
emailclaim. Generic202/no token/accountdisclosure for duplicate/new submissions.
Emailone-timeexpiringclaimcode storedhashed only; actualguildslashinteraction binds
DiscordID, unique1Discordaccount peradmission. PrivateBOTDMtype1 (user+Apollo) avoids
newguildpermissiongrants. Finalemailcontains privateDMchannel+verifiedcurrentGAME
TestFlightlink only afteractualDMreadback and validinstallreceipt. Unconfiguredsender,
missinginstalllink, blockedDM or uncertainremote outcome stayexplicitpending/blocked;
never fakeSent, never automatical uncertainresend. Existingverifieduserrawprivate
questions, email, claimcodes stayoutofpublicforum/logs/evidence artifacts.

Firstinspect: noexistingwaitlistAPI/form found inMarketingactualsource; install.json
statusunavailable/urlnull. Existingfreeemailprovider UNKNOWN pendingowners; user
confirmedEMAILrequired, website-onlynotacceptedfallback. Mainapp/phoneleftuntouched.
Acceptance: sameemailcases duplicateoneadmission/oneemail; realemailcodeclaimbound
Discordinteraction; sameDiscordnewemailconflictdenied; tokenexpiry/replay/concurrency
checks; privateDMrecipientidentity+actualwelcome readback; finalemailprovidermessage
receipt withbothverifiedlinks; actualMarketingform→API→deliveryjourney. No paidcall.

Engineeringunderstandingcheck onefocusedround: inferredP1emailenumeration/exposing
claimtokens viaGET/API duplicate responses→genericresponse/no browserclaimtokens;
inferredP1wrongrecipient/privatechannelleak→emailpossessioncode+actualDiscordbinding;
inferredP1duplicateemails onrestart→durableoutboxSENDINGbeforeexternalcall, uncertain
blocked; inferredP1fakeinstallavailability→validatedIntegrationreceiptgate. Unknown
currentfreeemailtransport/publicendpoint/runtimeowner—onlyblockedactionsheld.
Rollback ownnewmodule/configoff; preserveprivateDB/outbox receipts; no mainapprebuild.
Nextschema13:25EDT, boundedproof13:45ifdependenciesready;16:00workready/16–16:30buffer.


13:26EDT checkpoint: userexplicitlyselected ConnectedGmailthroughthisagent after
emaildeliveryselection. GmailprofilecapabilityPASS; no OAuth/credentialexport, no
SMTPcredentialsinapprovedhackathon/dev(name-onlychecked), no neednewemailaccount.
ActualApolloinvitecreated+readbackviaexistingbotpermissions/no addedgrants. Private
DMroute selected; onlyDIRECT_MESSAGES nonprivilegedintent whenadmissionconfigenabled,
no guildmessages/privilegedintents. Claim+privateplaceholderDMworkswithoutTestFlight;
finalWelcomeemailremainsqueueduntilrealverifiedbuild/link. UnitfakeDMcorrectrecipient,
readback/replay/mismatchedrecipient+claimcommandidentity/privateackchecksadded.
Stablecandidate46ownchecksPASS; sourceimport/actualbasegate/realGmail+claim stillpending.
Marketingacceptedexactformcontractbutowns5otherdirecthumanfixesfirst. Integration
sharedserver/publicHTTPS/rate/OriginhookNOTACKNOWLEDGED; no competingserver/publicroute
claimed. CoordinatorconfirmedAppleappbuilds/groupsEMPTY13:19; preservefakeURLguard.
Gmailoutboxagent5minutequietprocessingwilluseactualMIMEpayload+Sentreadback, reserved
unknownsblocked; no emailaccepted/deliveredclaimfromcodeexistence. Next13:45boundedproof.


## Destination correction — 2026-10-17 13:52 EDT / 17:52 UTC

Direct human explicitly selected PRIVATE CHANNEL IN APOLLO DISCORD SERVER; prior DM
plan is superseded. Own service admission config removed immediately; forum worker
continues, no new DMs. Historical DB/claim/Gmail/DM receipts preserved. Connected Gmail
self-test CLAIM actually Sent/readback; final WELCOME remains QUEUED, not sent.
Human explicitly approved five-minute Gmail agent after initial automatic approval
review rejected recurring execution without direct authorization. Automation NOT yet
created; correct guild-channel-only helper must be imported before enabling it.

New scope: additive guild_channel/guild_message DB migration; guild membership and
actual slash invoker binding; atomic channel+exact three overwrites, independent ACL
and message readback. Everyone denied View, only bound user and Apollo granted normal
text access; Discord administrators can access. Category-only bot Manage Channels
proposed, no Admin/Manage Roles/global grant. CREATING_CHANNEL reservation prevents
concurrent/uncertain duplicate creation or welcome. No DM listeners or DM sends;
all Gateway intents zero. Existing claims and historical DM metadata retained.

Verified actual private category Apollo Personal 1561070673047068754: type4; everyone
allow0/deny1049600, Apollo member allow1049600/deny0. Bot can view, has no category
Manage Channels grant yet. New permission change still requires action-time browser
confirmation. Category-scoped permission sufficiency is unproven until actual create;
a403 does not authorize broadening the grant. No TestFlight receipt available: actual
web/marketing/install.json remains unavailable/urlnull. Integration alone owns HTTPS
waitlist hook/origin/rate/body controls and install release. Marketing additive disabled
form staged separately, no actual public intake proof here. App/device/build untouched.

Owner remains Apollo Discord chat 01a14a8a-92a9-7f33-a659-1b1039830e1e; exclusive
integrations/discord/** + this doc. Waitlist initial scope checks ongoing; previous
research review CLOSED P0/P1=0; no broad review restart/new agents/paid providers.
Full outcome OPEN pending real server-channel claim, correct scheduled Gmail helper,
Integration public HTTPS endpoint and current TestFlight, then real form→email journey.
Next checkpoint13:55EDT; work-ready16:00America/New_York Oct17, recording/rehearsal
16:00–16:30 and judging16:30 preserved. Missing dependencies do not move the cutoff.


## Private server channel live proof — 2026-10-17 13:57:16 EDT / 17:57:16 UTC

Correction: the preceding destination entry13:52 label and dispatched13:56 label were
preparation labels ahead of actual clock; actual check at17:51:07UTC was13:51:07EDT.
This entry and checkedAt receipts use the actual clock. No deadline moved.

Human explicitly approved category-only Manage Channels at action time. Actual
category Apollo member overwrite changed1049600→1049616 (onlybit16 added); everyone
allow0/deny1049600 unchanged. No global role/Admin/ManagePermissions grant. Actual
create succeeded under this scope. Gatewayrunning PID84042/intents0; forumconfigured
and admissionconfigured, no DM listener. Private configmode guild_channel/category
1561070673047068754; privateSQLite backup before additive migration, legacy claim and
DMmetadata independently equalbackup. Same actual verified Gmail code bound same
Discordaccount1385362917582700716→guildtextchannel1561074823696883713, welcome
1561074827396259912. RawAPI confirms type0/guild/category, exactEveryoneDENYVIEW and
onlyApollo+accepteduser textallow84992. Actualwelcome author/content/nomentions
readbackPASS. Serveradmins retainaccess. Second non-adminaccountvisibility NOT_RUN.

Actual userguild /apollo research question:What should I research about AAPL? replied
ephemerally INSIDE thischannel, all3tracks Leadership/Promises vs results/Public
sentiment and5unique clickable sourceURLs present. Reviewedcachedmode clearly
labeled; freshpublicforum unaffected. Proof outputs/apollo-admission-private-server-
proof.json and apollo-private-channel-stock-reply.json. Contextscreens exported in
canonicalDesktopVisualReviewspacket; NATIVEFULLSCREEN/visualacceptance NOT_RUN.

Actualbase44DiscordchecksPASS outputs/apollo-admission-13-actual-base-tests.txt;
exact6-fileimport manifestoutputs/apollo-admission-13-guild.json verified6/6 before
this documentation-only append. Sharedappfullgate remains Integration-owned, not
rerunhere. One final scoped adversarial review inspected email-possession/actual
invoker/uniqueDiscordbinding, atomicprivateACL/membercheck, reservations/concurrent
claim and uncertainremote outcomes, localtrustedGmailbridge/Sentack, installreceipt
guard/nullableunavailability, source/serviceidentity and disabledDMpath. P0=0/P1=0,
STOPthisreview; boundedcomponent READYFOROWNERREVIEW, fullparentstillOPEN. P2/P3
followups: non-adminsecond-account UIproof, clearerreconciliationcopy, unusedbotDM
bookkeepingcleanup. No optionalrepairs/reopenedresearchreview/newagents/paidcalls.

Human explicitlyapproved5-minuteconnectedGmailagent after originalautomaticreview
rejectedmissingrecurringauthorization; retrywithcorrectguilddestination SUCCEEDED
automationapollo-waitlist-email-delivery ACTIVE FREQMINUTELYINTERVAL5 inthischat.
Actualtomlreadbacktargetchat/cadence/statusPASS; futurewake NOT_RUN_YET. FreshGmail
profile privatelymatchesapprovedsender. Actualcorrecthelperprepare returns
WAITING_VERIFIED_TESTFLIGHT, no send attempted; CLAIMSENTreadbackpreserved, final
WELCOMEQUEUED. Agent max4sends/wake, exactpayload+actualSentreadbackbeforeack,
uncertainsendsBLOCKED/noretry, quietunchanged, no rawemail/code/privatecontentlogs.
Localcomputer+desktopappmustremainrunning; this is not hostedalways-on emailservice.

Fullremainingrequiredscope: IntegrationactualpublicHTTPS/origin/rate/bodyPOST
/waitlist hook stillnotacknowledged; Marketingdisabledformstaged (itsDELTA.json),
actualpublicform→APIjourneyNOT_RUN. IntegrationrealcurrentApolloTestFlightreceipt
unavailable/null; finalWELCOMEemailwithbothlinkscorrectlyheld. Appnativecombined
gate/release/TestFlight acceptance UNVERIFIEDhere, Integrationalone. Nextcheckpoint
14:05EDT, work-readyOct17 16:00America/New_York, recording16–16:30/judging16:30
protected. Sourceownershipunchanged; onlyownedDiscordfiles+thisrecordmodified.

Current source hashes:
- integrations/discord/admissions.py: 0c70a6c276ec02eb6aadac79c020aec1dd89e3170770539f6908301c9aec84fc
- integrations/discord/mail_bridge.py: 5c029ffd3a766c0114940c64eb95abaa9289249437921f8496dc538a2a711254
- integrations/discord/bot.py: d11a57a9b7e1d9728c28c864f35909c0b06a7fdbbe7158da7173b35095706d77
- integrations/discord/test_admissions.py: a6fa8dc5d3d961cc89e5e90dd09aafb2b6800cb29f78df356d863b5d4a0426fc

Integration direct ACK received13:58EDT: privateguild/ACL/44checks acknowledged;
publicHTTPSintake remainsOPEN, no verifieddeployment/publichostingauthority.
Integration prioritizes actualTestFlight before16:00 and nativecarryover release
requirement; publicendpoint checkpoint15:10 afterfirstupload is a TARGET, not promise.
This dependency timing does not remove required fullwaitlistjourney from parent.
