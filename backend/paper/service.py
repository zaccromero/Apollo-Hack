"""Transactional, long-only PAPER engine. Decimal strings cross the API boundary."""
from contextlib import contextmanager
from dataclasses import asdict
from datetime import timedelta
from decimal import Decimal, ROUND_DOWN, ROUND_HALF_UP
import hashlib
import json
from pathlib import Path
import sqlite3

from .models import (Allocation, AssetKind, BondContract, CopyStrategy, Instrument, OptionContract, StablecoinTerms,
                     PaperError, Provenance, decimal_text, number, timestamp, utcnow)

from .portfolio import TOLERANCES, default_assessment, projection, validate_assessment

CENT = Decimal('0.01')


def money(value):
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def encode(value):
    return json.dumps(value, default=lambda x: decimal_text(x) if isinstance(x, Decimal) else x.value,
                      sort_keys=True, separators=(',', ':'))


def instrument_json(asset):
    result = asdict(asset)
    result.update(multiplier=asset.multiplier, quantity_unit=asset.unit, tradable=True)
    return json.loads(encode(result))


def strategy_json(strategy):
    result = json.loads(encode(asdict(strategy)))
    result.update(kind='copy_strategy', tradable=False, cash_weight=decimal_text(
        Decimal(1) - sum((a.weight for a in strategy.allocations), Decimal(0))))
    return result


def read_instrument(value):
    item = json.loads(value)
    for key in ('multiplier', 'quantity_unit', 'tradable', 'assessment'):
        item.pop(key, None)
    item['provenance'] = Provenance(**item['provenance'])
    if item['option']:
        item['option'] = OptionContract(**item['option'])
    if item.get('bond'):
        item['bond'] = BondContract(**item['bond'])
    if item.get('stablecoin'):
        item['stablecoin'] = StablecoinTerms(**item['stablecoin'])
    return Instrument(**item)


class PaperService:
    """One local portfolio per database; caller supplies account/auth isolation.

    No network calls, background jobs or ports. Construct with a dedicated file,
    never an existing research database. Transactions serialize concurrent confirms.
    """
    def __init__(self, db_path, initial_cash='10000.00', *, seed_demo=True, clock=utcnow):
        self.db_path = str(db_path)
        if self.db_path == ':memory:':
            raise PaperError('persistent_database_required', 'Use a dedicated SQLite file for persistence')
        self.clock = clock
        initial_cash = money(number(initial_cash, 'initial_cash', positive=True))
        if initial_cash <= 0:
            raise PaperError('invalid_cash', 'Initial cash must be at least one cent')
        with self._transaction() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS paper_profile (
                    id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_assessments (
                    asset_id TEXT PRIMARY KEY, payload TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_account (
                    id INTEGER PRIMARY KEY CHECK(id=1), cash TEXT NOT NULL,
                    initial_cash TEXT NOT NULL, epoch INTEGER NOT NULL DEFAULT 1);
                CREATE TABLE IF NOT EXISTS paper_assets (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_strategies (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_orders (
                    id TEXT PRIMARY KEY, request_id TEXT UNIQUE NOT NULL,
                    request_hash TEXT NOT NULL, epoch INTEGER NOT NULL, status TEXT NOT NULL,
                    payload TEXT NOT NULL, receipt TEXT);
                CREATE TABLE IF NOT EXISTS paper_positions (
                    asset_id TEXT PRIMARY KEY, quantity TEXT NOT NULL, cost_basis TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_decisions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, epoch INTEGER NOT NULL,
                    target_id TEXT NOT NULL, action TEXT NOT NULL, thesis TEXT NOT NULL, created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_watchlist (
                    target_id TEXT PRIMARY KEY, created_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_transactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, epoch INTEGER NOT NULL,
                    order_id TEXT UNIQUE NOT NULL, payload TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS paper_resets (
                    token TEXT PRIMARY KEY, epoch INTEGER NOT NULL, expires_at TEXT NOT NULL, receipt TEXT);
            ''')
            db.execute('INSERT OR IGNORE INTO paper_account VALUES (1,?,?,1)',
                       (decimal_text(initial_cash), decimal_text(initial_cash)))
        if seed_demo:
            from .fixtures import demo_catalog
            assets, strategies = demo_catalog()
            self.register_catalog(assets, strategies, replace_quotes=False)

    @contextmanager
    def _transaction(self):
        db = sqlite3.connect(self.db_path, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    def _now(self):
        now = self.clock()
        if now.tzinfo is None:
            raise PaperError('invalid_clock', 'Clock must include timezone')
        return now

    @staticmethod
    def _account(db):
        return db.execute('SELECT * FROM paper_account WHERE id=1').fetchone()

    @staticmethod
    def _asset(db, asset_id):
        if not isinstance(asset_id, str) or not asset_id:
            raise PaperError('invalid_asset_id', 'asset_id must be a nonempty string')
        row = db.execute('SELECT payload FROM paper_assets WHERE id=?', (asset_id,)).fetchone()
        if not row:
            raise PaperError('unknown_asset', 'Use an exact catalog asset_id; people/strategies cannot be ordered', 404)
        return read_instrument(row['payload'])

    @staticmethod
    def _strategy(db, strategy_id):
        if not isinstance(strategy_id, str) or not strategy_id:
            raise PaperError('invalid_strategy_id', 'strategy_id must be a nonempty string')
        row = db.execute('SELECT payload FROM paper_strategies WHERE id=?', (strategy_id,)).fetchone()
        if not row:
            raise PaperError('unknown_strategy', 'Copy strategy not found', 404)
        return json.loads(row['payload'])

    def register_catalog(self, assets, strategies=(), *, replace_quotes=True):
        """Trusted integration seam, never exposed by PaperAPI. Identity cannot be repurposed."""
        assets, strategies = tuple(assets), tuple(strategies)
        with self._transaction() as db:
            for asset in assets:
                if not isinstance(asset, Instrument):
                    raise PaperError('invalid_asset', 'Catalog accepts Instrument objects only')
                if db.execute('SELECT 1 FROM paper_strategies WHERE id=?', (asset.asset_id,)).fetchone():
                    raise PaperError('identity_conflict', 'An instrument must not reuse a strategy identity')
                existing = db.execute('SELECT payload FROM paper_assets WHERE id=?', (asset.asset_id,)).fetchone()
                if existing:
                    old = read_instrument(existing['payload'])
                    identity = lambda a: (a.symbol, a.kind, a.currency, a.venue, a.option, a.bond, a.stablecoin, a.quantity_step)
                    if identity(old) != identity(asset):
                        raise PaperError('asset_identity_conflict', 'An asset_id cannot change identity or contract terms')
                    if not replace_quotes:
                        continue
                db.execute('INSERT OR REPLACE INTO paper_assets VALUES (?,?)', (asset.asset_id, encode(instrument_json(asset))))
            for asset in assets:
                if asset.option:
                    underlying = self._asset(db, asset.option.underlying_asset_id)
                    if underlying.option:
                        raise PaperError('invalid_option', 'An option cannot underlie another option')
            for strategy in strategies:
                if not isinstance(strategy, CopyStrategy):
                    raise PaperError('invalid_strategy', 'Catalog accepts CopyStrategy objects only')
                for allocation in strategy.allocations:
                    self._asset(db, allocation.asset_id)
                if db.execute('SELECT 1 FROM paper_assets WHERE id=?', (strategy.strategy_id,)).fetchone():
                    raise PaperError('identity_conflict', 'A person/strategy must have separate identity')
                if not replace_quotes and db.execute('SELECT 1 FROM paper_strategies WHERE id=?', (strategy.strategy_id,)).fetchone():
                    continue
                db.execute('INSERT OR REPLACE INTO paper_strategies VALUES (?,?)', (strategy.strategy_id, encode(strategy_json(strategy))))

    @staticmethod
    def _profile(db):
        row = db.execute('SELECT payload FROM paper_profile WHERE id=1').fetchone()
        return json.loads(row[0]) if row else None

    def profile(self):
        with self._transaction() as db:
            return {'profile': self._profile(db), 'required_before_accepting': True,
                    'choices': [{'tolerance': name, 'asset_risk_ceiling': ceiling} for name, ceiling in TOLERANCES.items()],
                    'model': 'DEMO educational 1–5 rubric, not a measured loss probability', 'mode': 'paper'}

    def set_profile(self, tolerance, *, confirmed=False):
        if confirmed is not True:
            raise PaperError('confirmation_required', 'Explicitly confirm your paper-game risk tolerance')
        if not isinstance(tolerance, str) or tolerance not in TOLERANCES:
            raise PaperError('invalid_tolerance', 'Choose conservative, balanced or adventurous')
        profile = {'tolerance': tolerance, 'asset_risk_ceiling': TOLERANCES[tolerance],
                   'chosen_at': self._now().isoformat(), 'model': 'DEMO educational risk rubric'}
        with self._transaction() as db:
            db.execute('INSERT OR REPLACE INTO paper_profile VALUES (1,?)', (encode(profile),))
        return {'profile': profile, 'mode': 'paper'}

    @staticmethod
    def _assessment(db, asset_id):
        row = db.execute('SELECT payload FROM paper_assessments WHERE asset_id=?', (asset_id,)).fetchone()
        return json.loads(row[0]) if row else default_assessment(asset_id)

    def register_assessments(self, assessments):
        """Trusted integration only: user/client requests cannot manufacture sentiment or risk ratings."""
        with self._transaction() as db:
            for item in assessments:
                assessment = validate_assessment(item)
                self._asset(db, assessment['asset_id'])
                db.execute('INSERT OR REPLACE INTO paper_assessments VALUES (?,?)',
                           (assessment['asset_id'], encode(assessment)))

    def _risk_check(self, db, lines, *, preview=False, mixed_exception_acknowledged=False, profile_override=None):
        buys = [line for line in lines if line['side'] == 'buy']
        profile = profile_override if profile_override is not None else self._profile(db)
        if not buys:
            return {'status': 'reduces_exposure', 'requires_mixed_exception': False, 'profile': profile, 'assets': []}
        if profile is None:
            raise PaperError('risk_profile_required', 'Choose and confirm your risk tolerance before accepting an investment', 409)
        ceiling = TOLERANCES[profile['tolerance']]
        checks, exception_ids = [], []
        for line in buys:
            assessment = self._assessment(db, line['asset_id'])
            level = assessment['risk_level']
            if level is None:
                raise PaperError('risk_assessment_unknown', 'Risk assessment is missing; watchlist this asset until reviewed', 409)
            outside = level > ceiling
            mixed = assessment['sentiment_status'] == 'mixed' and assessment['sentiment'] is not None
            if outside and not mixed:
                raise PaperError('risk_tolerance_exceeded', 'Asset exceeds your tolerance without a known mixed-sentiment paper exception; use the watchlist', 409)
            if outside:
                exception_ids.append(line['asset_id'])
            checks.append({'asset_id': line['asset_id'], 'assessment': assessment, 'outside_tolerance': outside})
        if exception_ids and not preview and mixed_exception_acknowledged is not True:
            raise PaperError('mixed_exception_required', 'Explicitly acknowledge this above-tolerance PAPER-only exception. Mixed sentiment does not reduce risk.', 409)
        return {'status': 'mixed_exception' if exception_ids else 'within_tolerance', 'profile': profile,
                'requires_mixed_exception': bool(exception_ids), 'exception_asset_ids': exception_ids, 'assets': checks,
                'notice': 'Mixed sentiment is uncertainty, not safety or a 50% chance of profit. Exception applies only to this paper order.'}

    def compare(self, asset_id, quantity, *, strategy_id='DEMO_PATIENT_BUILDER', strategy_budget=None):
        from .comparison import compare_portfolios
        return compare_portfolios(self, asset_id, quantity, strategy_id=strategy_id, strategy_budget=strategy_budget)

    def portfolio(self):
        return self.state()['portfolio_summary']

    def catalog(self):
        with self._transaction() as db:
            return {'mode': 'paper', 'assets': [{**json.loads(r[0]), 'assessment': self._assessment(db, json.loads(r[0])['asset_id'])} for r in db.execute('SELECT payload FROM paper_assets ORDER BY id')],
                    'strategies': [json.loads(r[0]) for r in db.execute('SELECT payload FROM paper_strategies ORDER BY id')]}

    @staticmethod
    def _thesis(value):
        if value is None:
            value = {}
        if isinstance(value, str):
            value = {'reason': value}
        if not isinstance(value, dict) or set(value) - {'reason', 'risk', 'invalidation'}:
            raise PaperError('invalid_thesis', 'Thesis fields are reason, risk and invalidation')
        if any(not isinstance(v, str) or len(v) > 4000 for v in value.values()):
            raise PaperError('invalid_thesis', 'Thesis fields must be text of at most 4000 characters')
        return {key: value.get(key, '').strip() for key in ('reason', 'risk', 'invalidation')}

    @staticmethod
    def _feedback(thesis):
        missing = [key for key, value in thesis.items() if not value]
        return {'reasoning_complete': not missing, 'missing_fields': missing,
                'message': 'Your thesis records a reason, risk and invalidation trigger.' if not missing else
                           'Before deciding, record your reason, downside risk and what would change your mind.',
                'disclaimer': 'Educational simulation. Returns and investment timing are not guaranteed.'}

    def _line(self, asset, quantity, side, now):
        quantity = asset.validate_quantity(quantity, now)
        raw_total = asset.price * quantity * asset.multiplier
        if raw_total > Decimal('1000000000000'):
            raise PaperError('order_too_large', 'Paper order exceeds supported size')
        total = money(raw_total)
        if total <= 0:
            raise PaperError('order_too_small', 'Paper order must be worth at least one cent')
        return {'asset_id': asset.asset_id, 'symbol': asset.symbol, 'kind': asset.kind.value,
                'side': side, 'quantity': decimal_text(quantity), 'quantity_unit': asset.unit,
                'price': decimal_text(asset.price), 'multiplier': asset.multiplier,
                'total': decimal_text(total), 'currency': 'USD', 'provenance': asdict(asset.provenance),
                'option': json.loads(encode(asdict(asset.option))) if asset.option else None,
                'bond': json.loads(encode(asdict(asset.bond))) if asset.bond else None,
                'bond_clean_price_per_100': decimal_text(asset.bond_clean_price_per_100) if asset.bond else None,
                'bond_accrued_interest_per_bond': decimal_text(asset.bond_accrued_interest_per_bond) if asset.bond else None,
                'stablecoin': json.loads(encode(asdict(asset.stablecoin))) if asset.stablecoin else None}

    @staticmethod
    def _retry_preview(db, request_id, request):
        if not isinstance(request_id, str) or not request_id.strip() or len(request_id) > 200:
            raise PaperError('request_id_required', 'Provide a stable client_request_id for retry safety')
        digest = hashlib.sha256(encode(request).encode()).hexdigest()
        existing = db.execute('SELECT * FROM paper_orders WHERE request_id=?', (request_id,)).fetchone()
        if existing:
            if existing['request_hash'] != digest:
                raise PaperError('idempotency_conflict', 'client_request_id was used for a different request', 409)
            return {**json.loads(existing['payload']), 'status': existing['status']}
        return None

    def _save_preview(self, db, request_id, request, lines, thesis, strategy=None, budget=None):
        existing = self._retry_preview(db, request_id, request)
        if existing is not None:
            return existing
        digest = hashlib.sha256(encode(request).encode()).hexdigest()
        from uuid import uuid4
        account = self._account(db)
        cost = sum((number(line['total']) * (1 if line['side'] == 'buy' else -1) for line in lines), Decimal(0))
        self._check_resources(db, lines, cost, number(account['cash']))
        risk_check = self._risk_check(db, lines, preview=True)
        now = self._now()
        warnings = ['PAPER simulation only; preview prices are snapshots, with no fees or slippage.',
                    'Quotes retain their dated provenance and may be stale; no live execution is represented.']
        if any(line['kind'] == 'option' for line in lines):
            warnings.append('Long option premiums can lose 100%. No exercise, assignment or settlement is simulated.')
        if any(line['kind'] == 'bond' for line in lines):
            warnings.append('Direct bond units: USD per bond includes the stated clean quote and accrued interest. Coupon cash flows and maturity settlement are not simulated.')
        if any(line['kind'] == 'stablecoin' for line in lines):
            warnings.append('Stablecoin is a token exposure, not cash. Its peg and redemption are not guaranteed; depeg losses are possible.')
        payload = {'order_id': str(uuid4()), 'mode': 'paper', 'status': 'pending', 'epoch': account['epoch'],
                   'created_at': now.isoformat(), 'expires_at': (now + timedelta(minutes=5)).isoformat(),
                   'lines': lines, 'cash_change': decimal_text(-cost), 'total': decimal_text(abs(cost)),
                   'cash_after': decimal_text(number(account['cash']) - cost), 'requires_confirmation': True,
                   'thesis': thesis, 'learning': self._feedback(thesis), 'warnings': warnings, 'risk_check': risk_check,
                   'portfolio_before': self._portfolio_snapshot(db, account, now),
                   'portfolio_after': self._portfolio_snapshot(db, account, now, projected_lines=lines, cash_change=-cost),
                   'portfolio_projection_is_estimate': True,
                   'projection_notice': 'Hypothetical impact at current dated marks. No holdings or cash change until confirmation; current state is rechecked then.'}
        if strategy is not None:
            payload.update(strategy=strategy, budget=decimal_text(budget),
                           uninvested_budget=decimal_text(budget - cost))
        db.execute('INSERT INTO paper_orders VALUES (?,?,?,?,?,?,NULL)',
                   (payload['order_id'], request_id, digest, account['epoch'], 'pending', encode(payload)))
        return payload

    def preview_order(self, asset_id, quantity, *, client_request_id, side='buy', thesis=None):
        if side not in ('buy', 'sell'):
            raise PaperError('invalid_side', 'Only long-only buy/sell orders are supported')
        thesis = self._thesis(thesis)
        with self._transaction() as db:
            quantity = number(quantity, 'quantity', positive=True)
            request = {'asset_id': asset_id, 'quantity': decimal_text(quantity), 'side': side, 'thesis': thesis}
            existing = self._retry_preview(db, client_request_id, request)
            if existing is not None:
                return existing
            asset = self._asset(db, asset_id)
            line = self._line(asset, quantity, side, self._now())
            return self._save_preview(db, client_request_id, request, [line], thesis)

    def _copy_lines(self, db, strategy, budget):
        lines = []
        for allocation in strategy['allocations']:
            asset = self._asset(db, allocation['asset_id'])
            allocation_cash = (budget * number(allocation['weight'])).quantize(CENT, rounding=ROUND_DOWN)
            steps = (allocation_cash / (asset.price * asset.multiplier * asset.quantity_step)).to_integral_value(rounding=ROUND_DOWN)
            if steps > 0:
                lines.append(self._line(asset, steps * asset.quantity_step, 'buy', self._now()))
        if not lines:
            raise PaperError('budget_too_small', 'Budget cannot buy any allocation unit')
        return lines

    def preview_copy(self, strategy_id, budget, *, client_request_id, thesis=None):
        budget = money(number(budget, 'budget', positive=True))
        thesis = self._thesis(thesis)
        with self._transaction() as db:
            request = {'strategy_id': strategy_id, 'budget': decimal_text(budget), 'thesis': thesis}
            existing = self._retry_preview(db, client_request_id, request)
            if existing is not None:
                return existing
            strategy = self._strategy(db, strategy_id)
            account = self._account(db)
            if budget > number(account['cash']):
                raise PaperError('insufficient_funds', 'Copy budget exceeds virtual cash', 409)
            lines = self._copy_lines(db, strategy, budget)
            request = {'strategy_id': strategy_id, 'budget': decimal_text(budget), 'thesis': thesis}
            return self._save_preview(db, client_request_id, request, lines, thesis, strategy, budget)

    @staticmethod
    def _check_resources(db, lines, cost, cash):
        if cost > cash:
            raise PaperError('insufficient_funds', 'Not enough virtual cash; pending previews do not reserve cash', 409)
        for line in lines:
            if line['side'] == 'sell':
                position = db.execute('SELECT quantity FROM paper_positions WHERE asset_id=?', (line['asset_id'],)).fetchone()
                if not position or number(position['quantity']) < number(line['quantity']):
                    raise PaperError('insufficient_position', 'Short selling is not supported', 409)

    def confirm_order(self, order_id, *, confirmed=False, mixed_exception_acknowledged=False):
        if confirmed is not True:
            raise PaperError('confirmation_required', 'Explicit confirmed: true is required')
        with self._transaction() as db:
            row = db.execute('SELECT * FROM paper_orders WHERE id=?', (order_id,)).fetchone()
            if not row:
                raise PaperError('unknown_order', 'Order not found', 404)
            if row['status'] == 'confirmed':
                return json.loads(row['receipt'])
            if row['status'] != 'pending':
                raise PaperError('order_not_pending', 'Order is cancelled or invalidated', 409)
            order = json.loads(row['payload'])
            now, account = self._now(), self._account(db)
            if account['epoch'] != row['epoch']:
                raise PaperError('stale_order', 'Account has been reset since this preview', 409)
            if timestamp(order['expires_at']) <= now:
                raise PaperError('expired_preview', 'Preview expired; create a new preview', 409)
            cost = -number(order['cash_change'])
            self._check_resources(db, order['lines'], cost, number(account['cash']))
            risk_check = self._risk_check(db, order['lines'], mixed_exception_acknowledged=mixed_exception_acknowledged)
            before = self._portfolio_snapshot(db, account, now)
            for line in order['lines']:
                asset = self._asset(db, line['asset_id'])
                quantity = asset.validate_quantity(line['quantity'], now)
                old = db.execute('SELECT * FROM paper_positions WHERE asset_id=?', (asset.asset_id,)).fetchone()
                old_quantity = number(old['quantity']) if old else Decimal(0)
                old_basis = number(old['cost_basis']) if old else Decimal(0)
                if line['side'] == 'buy':
                    new_quantity, basis = old_quantity + quantity, old_basis + number(line['total'])
                else:
                    new_quantity = old_quantity - quantity
                    basis = money(old_basis * new_quantity / old_quantity)
                if new_quantity == 0:
                    db.execute('DELETE FROM paper_positions WHERE asset_id=?', (asset.asset_id,))
                else:
                    db.execute('INSERT OR REPLACE INTO paper_positions VALUES (?,?,?)',
                               (asset.asset_id, decimal_text(new_quantity), decimal_text(basis)))
            cash_after = money(number(account['cash']) - cost)
            db.execute('UPDATE paper_account SET cash=? WHERE id=1', (decimal_text(cash_after),))
            receipt = {**order, 'status': 'confirmed', 'requires_confirmation': False,
                       'confirmed_at': now.isoformat(), 'cash_after': decimal_text(cash_after),
                       'risk_check': risk_check, 'mixed_exception_acknowledged': bool(risk_check['requires_mixed_exception']),
                       'portfolio_before': before, 'portfolio_after': self._portfolio_snapshot(db, self._account(db), now),
                       'portfolio_projection_is_estimate': False,
                       'projection_notice': 'Actual portfolio change recorded at confirmation, valued with dated catalog marks; not a live quote.'}
            db.execute('UPDATE paper_orders SET status=?,receipt=? WHERE id=?', ('confirmed', encode(receipt), order_id))
            db.execute('INSERT INTO paper_transactions(epoch,order_id,payload) VALUES (?,?,?)',
                       (account['epoch'], order_id, encode(receipt)))
            for line in order['lines']:
                db.execute('INSERT INTO paper_decisions(epoch,target_id,action,thesis,created_at) VALUES (?,?,?,?,?)',
                           (account['epoch'], line['asset_id'], 'paper_' + line['side'], encode(order['thesis']), now.isoformat()))
            return receipt

    def cancel_order(self, order_id):
        with self._transaction() as db:
            row = db.execute('SELECT status FROM paper_orders WHERE id=?', (order_id,)).fetchone()
            if not row:
                raise PaperError('unknown_order', 'Order not found', 404)
            if row['status'] == 'confirmed':
                raise PaperError('already_confirmed', 'An executed paper order cannot be cancelled', 409)
            db.execute('UPDATE paper_orders SET status=? WHERE id=?', ('cancelled', order_id))
            return {'order_id': order_id, 'status': 'cancelled', 'mode': 'paper'}

    def record_decision(self, target_id, action, *, thesis=None):
        if action not in ('pass', 'watchlist', 'interest', 'remove_watchlist', 'save_thesis'):
            raise PaperError('invalid_action', 'Unsupported decision')
        thesis = self._thesis(thesis)
        if not isinstance(target_id, str) or not target_id:
            raise PaperError('invalid_target_id', 'target_id must be a nonempty string')
        with self._transaction() as db:
            if not db.execute('SELECT 1 FROM paper_assets WHERE id=? UNION SELECT 1 FROM paper_strategies WHERE id=?', (target_id, target_id)).fetchone():
                raise PaperError('unknown_target', 'Use an exact asset_id or strategy_id', 404)
            now, account = self._now().isoformat(), self._account(db)
            db.execute('INSERT INTO paper_decisions(epoch,target_id,action,thesis,created_at) VALUES (?,?,?,?,?)',
                       (account['epoch'], target_id, action, encode(thesis), now))
            if action == 'watchlist':
                db.execute('INSERT OR IGNORE INTO paper_watchlist VALUES (?,?)', (target_id, now))
            elif action == 'remove_watchlist':
                db.execute('DELETE FROM paper_watchlist WHERE target_id=?', (target_id,))
            return {'target_id': target_id, 'action': action, 'thesis': thesis, 'learning': self._feedback(thesis), 'mode': 'paper'}

    def _portfolio_snapshot(self, db, account, now, *, projected_lines=(), cash_change=Decimal(0), profile_override=None):
        # Projection changes only in-memory quantities. Both projected and actual
        # summaries share the same mark, multiplier, rounding and coverage math.
        quantities = {row['asset_id']: number(row['quantity']) for row in
                      db.execute('SELECT asset_id,quantity FROM paper_positions ORDER BY asset_id').fetchall()}
        for line in projected_lines:
            asset_id, quantity = line['asset_id'], number(line['quantity'])
            quantities[asset_id] = quantities.get(asset_id, Decimal(0)) + (quantity if line['side'] == 'buy' else -quantity)
            if quantities[asset_id] < 0:
                raise PaperError('insufficient_position', 'Projection would create an unsupported short position', 409)
        positions, assessments = [], {}
        for asset_id, quantity in sorted(quantities.items()):
            if quantity == 0:
                continue
            asset = self._asset(db, asset_id)
            value = money(quantity * asset.price * asset.multiplier)
            positions.append({'asset_id': asset.asset_id, 'asset': instrument_json(asset), 'market_value': decimal_text(value)})
            assessments[asset.asset_id] = self._assessment(db, asset.asset_id)
        cash = money(number(account['cash']) + cash_change)
        profile = profile_override if profile_override is not None else self._profile(db)
        return projection(positions, cash, profile, assessments)

    def state(self):
        with self._transaction() as db:
            now, account = self._now(), self._account(db)
            positions, total = [], Decimal(0)
            for row in db.execute('SELECT * FROM paper_positions ORDER BY asset_id').fetchall():
                asset = self._asset(db, row['asset_id'])
                value = money(number(row['quantity']) * asset.price * asset.multiplier)
                total += value
                expired = bool(asset.option and timestamp(asset.option.expires_at) <= now)
                matured = bool(asset.bond and timestamp(asset.bond.matures_at) <= now)
                positions.append({'asset_id': asset.asset_id, 'asset': instrument_json(asset), 'quantity': row['quantity'],
                                  'quantity_unit': asset.unit, 'cost_basis': row['cost_basis'], 'market_value': decimal_text(value),
                                  'unrealized_pnl': decimal_text(value - number(row['cost_basis'])),
                                  'valuation': {'price': decimal_text(asset.price), 'provenance': asdict(asset.provenance),
                                                'status': 'expired_unsettled_snapshot' if expired else 'matured_unsettled_snapshot' if matured else 'snapshot',
                                                'is_live': False}})
            decisions = [dict(r) for r in db.execute('SELECT target_id,action,thesis,created_at FROM paper_decisions WHERE epoch=? ORDER BY id DESC', (account['epoch'],))]
            for decision in decisions:
                decision['thesis'] = json.loads(decision['thesis'])
            watchlist = [dict(r) for r in db.execute('SELECT * FROM paper_watchlist ORDER BY created_at,target_id')]
            transactions = [json.loads(r[0]) for r in db.execute('SELECT payload FROM paper_transactions WHERE epoch=? ORDER BY id DESC', (account['epoch'],))]
            pending = [json.loads(r[0]) for r in db.execute('SELECT payload FROM paper_orders WHERE epoch=? AND status=?', (account['epoch'], 'pending')) if timestamp(json.loads(r[0])['expires_at']) > now]
            return {'mode': 'paper', 'currency': 'USD', 'epoch': account['epoch'], 'cash': account['cash'],
                    'initial_cash': account['initial_cash'], 'positions_value': decimal_text(total),
                    'equity': decimal_text(number(account['cash']) + total), 'positions': positions,
                    'watchlist': watchlist, 'decisions': decisions, 'transactions': transactions, 'pending_orders': pending,
                    'risk_profile': self._profile(db), 'portfolio_summary': self._portfolio_snapshot(db, account, now),
                    'valuation_notice': 'Dated snapshot valuation, not a live quote. Expired options/matured bonds remain explicitly unsettled; no coupon cash flows, settlement or performance claim.'}

    def preview_reset(self):
        from uuid import uuid4
        with self._transaction() as db:
            account, now = self._account(db), self._now()
            token, expires = str(uuid4()), (now + timedelta(minutes=5)).isoformat()
            db.execute('INSERT INTO paper_resets VALUES (?,?,?,NULL)', (token, account['epoch'], expires))
            return {'reset_token': token, 'expires_at': expires, 'requires_confirmation': True,
                    'confirmation_phrase': 'RESET PAPER PORTFOLIO', 'mode': 'paper',
                    'message': 'Clears current paper positions, watchlist and decisions; restores initial virtual cash. Prior transaction audit rows remain archived.'}

    def confirm_reset(self, reset_token, *, confirmed=False, confirmation_phrase=''):
        if confirmed is not True or confirmation_phrase != 'RESET PAPER PORTFOLIO':
            raise PaperError('confirmation_required', 'Reset requires confirmed:true and the exact displayed phrase')
        with self._transaction() as db:
            row = db.execute('SELECT * FROM paper_resets WHERE token=?', (reset_token,)).fetchone()
            if not row:
                raise PaperError('unknown_reset', 'Reset preview not found', 404)
            if row['receipt']:
                return json.loads(row['receipt'])
            account = self._account(db)
            if row['epoch'] != account['epoch'] or timestamp(row['expires_at']) <= self._now():
                raise PaperError('stale_reset', 'Reset preview is stale or expired', 409)
            db.execute('DELETE FROM paper_positions')
            db.execute('DELETE FROM paper_watchlist')
            db.execute('UPDATE paper_orders SET status=? WHERE status=?', ('invalidated_by_reset', 'pending'))
            db.execute('UPDATE paper_account SET cash=initial_cash,epoch=epoch+1 WHERE id=1')
            receipt = {'mode': 'paper', 'status': 'reset', 'epoch': account['epoch'] + 1, 'cash': account['initial_cash']}
            db.execute('UPDATE paper_resets SET receipt=? WHERE token=?', (encode(receipt), reset_token))
            return receipt
