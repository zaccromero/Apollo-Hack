import asyncio
import contextlib
import io
import json
import os
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

import bot

APP = 1561042929265418392
GUILD = 1561049999999999999  # Synthetic offline ID, never a runtime destination.


class ApolloTests(unittest.TestCase):
    def setUp(self):
        self.config = bot.Config(APP, GUILD)

    def test_offline_default_reads_no_credentials_or_network(self):
        with patch.object(bot.Config, 'from_environment', side_effect=AssertionError('credentials read')):
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(bot.main([]), 0)
            self.assertFalse(json.loads(out.getvalue())['connected'])

    def test_token_never_printed_on_failure(self):
        secret = 'synthetic-sensitive-value'
        env = {'APOLLO_DISCORD_APPLICATION_ID': str(APP), 'APOLLO_DISCORD_GUILD_ID': str(GUILD),
               'APOLLO_DISCORD_BOT_TOKEN': secret}
        with patch.dict(os.environ, env, clear=True), patch.object(bot, 'create_client', side_effect=RuntimeError(secret)):
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(bot.main(['--connect']), 1)
            self.assertNotIn(secret, out.getvalue())

    def test_install_url_requests_zero_permissions(self):
        from urllib.parse import parse_qs, urlsplit
        query = parse_qs(urlsplit(bot.installation_url(APP)).query)
        self.assertEqual(query['permissions'], ['0'])
        self.assertEqual(query['scope'], ['bot applications.commands'])
        self.assertEqual(query['client_id'], [str(APP)])

    def test_links_reject_credentials_and_local_addresses(self):
        for value in ['http://apollo.example', 'https://u:p@apollo.example', 'https://127.0.0.1',
                      'https://192.168.1.1', 'https://localhost', 'https://apollo.local',
                      'https://apollo.example/?token=x']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                bot.public_url(value)
        self.assertEqual(bot.public_url('https://apollo.example/game'), 'https://apollo.example/game')

    def test_identity_inputs_fail_closed(self):
        for value in ['', '123', 'a'*18, '9'*20, '\u0661'*18]:
            with self.assertRaises(ValueError):
                bot.snowflake(value)
        with patch.dict(os.environ, {}, clear=True), self.assertRaises(ValueError):
            bot.Config.from_environment()

    def test_all_content_is_paper_only_and_status_does_not_claim_backend(self):
        for name in ['help', 'status', 'links']:
            self.assertIn(bot.PAPER_NOTICE, bot.command_text(name, self.config))
        self.assertIn('not monitored', bot.command_text('status', self.config))
        self.assertIn('not configured', bot.command_text('links', self.config))


class DiscordAdapterTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client = bot.create_client(bot.Config(APP, GUILD))

    async def asyncTearDown(self):
        await self.client.close()

    async def test_zero_intents_guild_commands_and_private_responses(self):
        import discord
        self.assertEqual(self.client.intents.value, 0)
        self.assertFalse(self.client.allowed_mentions.everyone)
        self.assertEqual(self.client.tree.get_commands(), [])
        group = self.client.tree.get_commands(guild=discord.Object(GUILD))[0]
        self.assertEqual({x.name for x in group.commands}, {'help', 'status', 'links', 'research', 'job', 'jobs', 'claim'})
        for command in [c for c in group.commands if c.name in {'help','status','links'}]:
            response = SimpleNamespace(send_message=AsyncMock())
            await command.callback(SimpleNamespace(guild_id=GUILD, response=response))
            args, kwargs = response.send_message.call_args
            self.assertIn(bot.PAPER_NOTICE, args[0])
            self.assertTrue(kwargs['ephemeral'])
            self.assertFalse(kwargs['allowed_mentions'].everyone)

    async def test_different_guild_does_not_get_apollo_content(self):
        import discord
        group = self.client.tree.get_commands(guild=discord.Object(GUILD))[0]
        for command in [c for c in group.commands if c.name in {'help','status','links','research'}]:
            response = SimpleNamespace(send_message=AsyncMock())
            await command.callback(SimpleNamespace(guild_id=GUILD+1, response=response), **({'question': 'AAPL'} if command.name == 'research' else {}))
            self.assertEqual(response.send_message.call_args.args[0], 'Apollo is not configured for this server.')

    async def test_research_defers_and_responds_privately(self):
        import discord
        group = self.client.tree.get_commands(guild=discord.Object(GUILD))[0]
        command = next(c for c in group.commands if c.name == 'research')
        interaction = SimpleNamespace(guild_id=GUILD, response=SimpleNamespace(defer=AsyncMock()),
                                      followup=SimpleNamespace(send=AsyncMock()))
        with patch('research.research_payload', return_value={'content':'Dated snapshot', 'embeds':[]}):
            await command.callback(interaction, 'What changed AAPL this week?')
        interaction.response.defer.assert_awaited_once_with(ephemeral=True, thinking=True)
        self.assertTrue(interaction.followup.send.call_args.kwargs['ephemeral'])

    async def test_actual_research_callback_retains_private_three_track_payload(self):
        import discord
        group = self.client.tree.get_commands(guild=discord.Object(GUILD))[0]
        command = next(c for c in group.commands if c.name == 'research')
        interaction = SimpleNamespace(guild_id=GUILD, response=SimpleNamespace(defer=AsyncMock()),
                                      followup=SimpleNamespace(send=AsyncMock()))
        with patch('socket.socket', side_effect=AssertionError('Network forbidden')):
            await command.callback(interaction, 'What changed AAPL this week?')
        kwargs = interaction.followup.send.call_args.kwargs
        self.assertTrue(kwargs['ephemeral'])
        self.assertEqual([e.title for e in kwargs['embeds'][1:]],
                         ['Leadership', 'Promises vs results', 'Public sentiment'])
        self.assertIn('reviewed/observed as of', str([e.to_dict() for e in kwargs['embeds']]))

    async def test_no_automatic_sync_and_application_identity_guard(self):
        self.client.application_info = AsyncMock(return_value=SimpleNamespace(id=APP))
        self.client.tree.sync = AsyncMock()
        await self.client.setup_hook()
        self.client.tree.sync.assert_not_awaited()
        self.client.application_info = AsyncMock(return_value=SimpleNamespace(id=APP+1))
        with self.assertRaises(RuntimeError):
            await self.client.setup_hook()
        self.client.tree.sync.assert_not_awaited()


if __name__ == '__main__':
    unittest.main()
