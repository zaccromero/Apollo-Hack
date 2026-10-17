"""Apollo's isolated read-only Discord companion. Default execution is offline."""
from __future__ import annotations
import argparse
import asyncio
from dataclasses import dataclass
import ipaddress
import json
import os
from urllib.parse import urlencode, urlsplit

APOLLO_APPLICATION_ID = 1561042929265418392
REPOSITORY_URL = 'https://github.com/zaccromero/Apollo-Hack'
PAPER_NOTICE = 'Educational paper simulation only. No real trades or investment advice.'


def snowflake(value: str) -> int:
    if not value.isascii() or not value.isdecimal() or not 16 <= len(value) <= 20:
        raise ValueError('Use a Discord numeric ID with 16-20 digits.')
    result = int(value)
    if not 0 < result < 2**64:
        raise ValueError('Discord ID out of range.')
    return result


def public_url(value: str) -> str:
    if not value:
        return ''
    parsed = urlsplit(value)
    host = parsed.hostname or ''
    if (parsed.scheme != 'https' or not host or parsed.username or parsed.password
            or parsed.query or parsed.fragment or parsed.port not in (None, 443)
            or '.' not in host or host.endswith(('.local', '.localhost', '.internal'))):
        raise ValueError('Use a public HTTPS game URL without credentials or query data.')
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        address = None
    if address is not None and not address.is_global:
        raise ValueError('Game link cannot use a private address.')
    return value


@dataclass(frozen=True)
class Config:
    application_id: int
    guild_id: int
    game_url: str = ''
    forum_id: int = 0
    jobs_db: str = ''
    admission_config: str = ''

    @classmethod
    def from_environment(cls):
        return cls(snowflake(os.environ.get('APOLLO_DISCORD_APPLICATION_ID', '')),
                   snowflake(os.environ.get('APOLLO_DISCORD_GUILD_ID', '')),
                   public_url(os.environ.get('APOLLO_GAME_URL', '')),
                   snowflake(os.environ['APOLLO_RESEARCH_FORUM_ID']) if os.environ.get('APOLLO_RESEARCH_FORUM_ID') else 0,
                   os.environ.get('APOLLO_RESEARCH_JOB_DB', ''),
                   os.environ.get('APOLLO_ADMISSION_CONFIG', ''))


def installation_url(application_id: int) -> str:
    snowflake(str(application_id))
    return 'https://discord.com/oauth2/authorize?' + urlencode({
        'client_id': str(application_id), 'scope': 'bot applications.commands',
        'permissions': '0', 'integration_type': '0'})


def command_text(name: str, config: Config) -> str:
    if name == 'help':
        body = ('Apollo helps you learn with asset cards, research and confirmed PAPER orders.\n'
                'Use /apollo status, /apollo links or private /apollo research. The owner can publish /apollo job and view /apollo jobs. Discord cannot place or confirm orders.\n'
                'In the game: left = pass, up = watchlist, right = interest/preview; '
                'review portfolio effects before explicitly confirming.')
    elif name == 'status':
        body = ('Apollo Discord companion: responding to this command.\n'
                'Game/backend health: not monitored by this bot.\n'
                'Market data freshness and paper balances: not read here. '
                "Check the game's source labels and portfolio.")
    elif name == 'links':
        game = f'Open Apollo: {config.game_url}' if config.game_url else 'Public game link: not configured.'
        body = f'{game}\nApollo project: {REPOSITORY_URL}'
    else:
        raise ValueError('Unknown Apollo command.')
    return f'{body}\n\n{PAPER_NOTICE}'


def create_client(config: Config, *, sync_commands: bool = False):
    if config.application_id != APOLLO_APPLICATION_ID:
        raise ValueError('This companion is bound to the dedicated Apollo application.')
    import discord
    from discord import app_commands
    guild = discord.Object(id=config.guild_id)

    class ApolloClient(discord.Client):
        def __init__(self):
            intents=discord.Intents.none()
            super().__init__(intents=intents, application_id=config.application_id,
                             allowed_mentions=discord.AllowedMentions.none(), max_messages=None)
            self.tree = app_commands.CommandTree(self)
            self.forum_runner = None
            self.forum_task = None
            self.forum_owner_id = None
            self.admission_agent = None
            self.admission_task = None
            self.dm_busy = set()
            self.dm_last = {}

        async def setup_hook(self):
            info = await self.application_info()
            if info.id != config.application_id:
                raise RuntimeError('Apollo application identity mismatch.')
            if config.forum_id and config.jobs_db:
                try:
                    from forum_jobs import JobStore, ForumTransport, ForumRunner
                    forum = await self.fetch_channel(config.forum_id)
                    if not isinstance(forum, discord.ForumChannel) or forum.guild.id != config.guild_id:
                        raise ValueError('Wrong forum destination')
                    owner_guild = await self.fetch_guild(config.guild_id)
                    self.forum_owner_id = owner_guild.owner_id
                    self.forum_runner = ForumRunner(JobStore(config.jobs_db), ForumTransport(self, forum))
                    self.forum_task = asyncio.create_task(self.forum_runner.work(self.wait_until_ready))
                    print(json.dumps({'event':'apollo_forum_configured','forum_id':config.forum_id,'modes':['fresh_public_source_read','cached_reviewed_or_demo']}),flush=True)
                except Exception as exc:
                    print(json.dumps({'event':'apollo_forum_unavailable','error_type':type(exc).__name__}),flush=True)
            if config.admission_config:
                try:
                    from admissions import AdmissionStore,AdmissionAgent
                    from mail_bridge import config as admission_configuration
                    ac=admission_configuration(config.admission_config)
                    self.admission_agent=AdmissionAgent(AdmissionStore(ac['database']),self,ac['install_receipt'],guild_id=ac['guild_id'],category_id=ac['category_id'])
                    self.admission_agent.store.recover()
                    print(json.dumps({'event':'apollo_admission_configured','email_transport':'connected_gmail_agent_outbox','guild_id':config.guild_id}),flush=True)
                except Exception as exc:
                    print(json.dumps({'event':'apollo_admission_unavailable','error_type':type(exc).__name__}),flush=True)
            if sync_commands:
                await self.tree.sync(guild=guild)

        async def close(self):
            if self.admission_task:
                self.admission_task.cancel()
                try:await self.admission_task
                except asyncio.CancelledError:pass
            if self.forum_task:
                self.forum_task.cancel()
                try:
                    await self.forum_task
                except asyncio.CancelledError:
                    pass
            await super().close()

        async def on_ready(self):
            print(json.dumps({'event': 'apollo_gateway_ready', 'application_id': config.application_id,
                              'allowed_guild_id': config.guild_id, 'intents': self.intents.value}))

    client = ApolloClient()
    group = app_commands.Group(name='apollo', description='Apollo educational paper-game companion')

    async def respond(interaction, name):
        text = (command_text(name, config) if interaction.guild_id == config.guild_id
                else 'Apollo is not configured for this server.')
        await interaction.response.send_message(text, ephemeral=True,
                                                allowed_mentions=discord.AllowedMentions.none())

    @group.command(name='help', description="Learn Apollo's paper-only controls")
    async def help_command(interaction: discord.Interaction):
        await respond(interaction, 'help')

    @group.command(name='status', description="Show this companion's actual scope and status")
    async def status_command(interaction: discord.Interaction):
        await respond(interaction, 'status')

    @group.command(name='links', description='Open the Apollo game or project')
    async def links_command(interaction: discord.Interaction):
        await respond(interaction, 'links')

    @group.command(name='research', description='Review dated stock evidence in three separate tracks')
    @app_commands.describe(question='Natural question, e.g. What changed AAPL this week?',
                           asset='Optional explicit asset ID, e.g. AAPL or WINA',
                           source_url='Optional pasted HTTPS URL; context only, never fetched')
    async def research_command(interaction: discord.Interaction, question: str,
                               asset: str = '', source_url: str = ''):
        if interaction.guild_id != config.guild_id:
            await respond(interaction, 'help')
            return
        await interaction.response.defer(ephemeral=True, thinking=True)
        try:
            from research import research_payload
            payload = await asyncio.to_thread(research_payload, question, asset, source_url)
            embeds = [discord.Embed.from_dict(item) for item in payload['embeds']]
            await interaction.followup.send(payload['content'], embeds=embeds, ephemeral=True,
                                            allowed_mentions=discord.AllowedMentions.none())
        except ValueError:
            await interaction.followup.send('Include one supported Apollo asset (e.g. AAPL/Apple or WINA/Winmark), '
                                            'a question up to 1000 characters, and optionally an HTTPS source URL. '
                                            'Pasted links are context only; this bot does not fetch them.',
                                            ephemeral=True, allowed_mentions=discord.AllowedMentions.none())
        except Exception:
            await interaction.followup.send('Local research is unavailable. No current research or sentiment '
                                            'was retrieved, and no model/provider call was made.',
                                            ephemeral=True, allowed_mentions=discord.AllowedMentions.none())

    @group.command(name='job', description='Publish an owner-requested research job to the public market forum')
    @app_commands.describe(asset='Fresh: AAPL, SPY or BTC-USD. Reviewed: any supported exact asset ID',
                           fresh='Default true: fetch fixed public sources now. False: reviewed local evidence')
    async def job_command(interaction: discord.Interaction, asset: str, fresh: bool = True):
        if interaction.guild_id != config.guild_id or interaction.user.id != client.forum_owner_id:
            await interaction.response.send_message('Only the Apollo server owner can start a public research job.',
                ephemeral=True, allowed_mentions=discord.AllowedMentions.none())
            return
        if not client.forum_runner:
            await interaction.response.send_message('Public research jobs are unavailable; private /apollo research remains available.',
                ephemeral=True, allowed_mentions=discord.AllowedMentions.none())
            return
        await interaction.response.defer(ephemeral=True, thinking=True)
        try:
            job, created = await client.forum_runner.submit(str(interaction.id), asset, fresh=fresh)
            await interaction.followup.send(f"{'Queued' if created else 'Existing'} public job `{job['id']}` for {job['asset_id']}. "
                f"Watch https://discord.com/channels/{config.guild_id}/{config.forum_id}. "
                + ('Fresh public source reads; source dates and gaps stay explicit. No model or paid calls.' if fresh else
                 'This checks reviewed local evidence; no fresh web search or paid calls.'),
                ephemeral=True, allowed_mentions=discord.AllowedMentions.none())
        except ValueError:
            await interaction.followup.send('Fresh reads support AAPL, SPY or BTC-USD; fresh:false checks other reviewed assets. '
                'The bounded queue may also be full.', ephemeral=True, allowed_mentions=discord.AllowedMentions.none())
        except Exception:
            await interaction.followup.send('The job could not be queued. No automatic public retry was made.',
                ephemeral=True, allowed_mentions=discord.AllowedMentions.none())

    @group.command(name='claim', description='Link your emailed Apollo acceptance code to your own Discord account')
    @app_commands.describe(code='Private code from your Apollo access email; never post it as a normal message')
    async def claim_command(interaction: discord.Interaction, code: str):
        if interaction.guild_id!=config.guild_id or not client.admission_agent:
            await interaction.response.send_message('Apollo email claims are unavailable in this server.',ephemeral=True,allowed_mentions=discord.AllowedMentions.none());return
        await interaction.response.defer(ephemeral=True,thinking=True)
        try:
            result=await client.admission_agent.claim(code,str(interaction.user.id))
            link=result.get('private_channel_url')
            text='Your email code is linked to this Discord account.'
            if link:text+=' Your private channel inside Apollo: '+link
            text+=' The final access email waits for a verified Apollo TestFlight link. Check your inbox when available.'
            await interaction.followup.send(text,ephemeral=True,allowed_mentions=discord.AllowedMentions.none())
        except ValueError:
            await interaction.followup.send('This code is invalid, expired or linked to another account. Never share your code.',ephemeral=True,allowed_mentions=discord.AllowedMentions.none())
        except Exception:
            await interaction.followup.send('Your request needs reconciliation before another private message attempt. No public account details were posted.',ephemeral=True,allowed_mentions=discord.AllowedMentions.none())

    @group.command(name='jobs', description='Show recent public research job progress and result links')
    async def jobs_command(interaction: discord.Interaction):
        if interaction.guild_id != config.guild_id:
            await respond(interaction, 'help')
            return
        if not client.forum_runner:
            text = 'Public research jobs are unavailable; private /apollo research remains available.'
        else:
            from forum_jobs import STAGES
            jobs = client.forum_runner.store.recent()
            text = '\n'.join(f"{j['asset_id']} · {STAGES[j['stage']]} · "
                + (f"https://discord.com/channels/{config.guild_id}/{j['thread_id']}" if j['thread_id'] else f"job `{j['id']}`") for j in jobs) or 'No public research jobs yet.'
        await interaction.response.send_message(text[:1900], ephemeral=True, allowed_mentions=discord.AllowedMentions.none())

    client.tree.add_command(group, guild=guild)
    return client


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--connect', action='store_true', help='Connect after owner selects/installs a server')
    parser.add_argument('--sync-commands', action='store_true', help='Publish commands to the selected server')
    parser.add_argument('--install-url', metavar='APPLICATION_ID', help='Print install URL; no installation')
    args = parser.parse_args(argv)
    try:
        if args.install_url:
            print(installation_url(snowflake(args.install_url)))
            return 0
        if args.sync_commands and not args.connect:
            raise ValueError('Registration requires --connect and an owner-selected server.')
        if not args.connect:
            print(json.dumps({'mode': 'offline', 'connected': False, 'commands': ['help', 'status', 'links', 'research', 'job', 'jobs', 'claim'],
                              'paper_only': True, 'intents': 0, 'secret_read': False}))
            return 0
        config = Config.from_environment()
        token = os.environ.get('APOLLO_DISCORD_BOT_TOKEN', '')
        if not token:
            raise ValueError('Inject the dedicated Apollo token through the approved secret store.')
        create_client(config, sync_commands=args.sync_commands).run(token, log_handler=None)
        return 0
    except (Exception, KeyboardInterrupt) as exc:
        # No SDK exception bodies, request headers or credential values in receipts.
        print(json.dumps({'status': 'stopped', 'error_type': type(exc).__name__,
                          'action': 'Check Apollo IDs, approved secret injection, installation and connectivity.'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
