"""Strict domain types for the local, simulated-only Apollo portfolio."""
from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from enum import Enum


class PaperError(ValueError):
    def __init__(self, code, message, status=400):
        self.code, self.status = code, status
        super().__init__(message)


class AssetKind(str, Enum):
    STOCK = 'stock'
    ETF = 'etf'
    CRYPTO = 'crypto'
    COMMODITY_EXPOSURE = 'commodity_exposure'
    REAL_ESTATE_EXPOSURE = 'real_estate_exposure'
    OPTION = 'option'
    STABLECOIN = 'stablecoin'
    BOND = 'bond'


def number(value, name='value', positive=False):
    if isinstance(value, bool) or len(str(value)) > 100:
        raise PaperError('invalid_number', f'{name} must be a finite decimal')
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        raise PaperError('invalid_number', f'{name} must be a finite decimal')
    if not result.is_finite() or abs(result) > Decimal('1000000000000') or result.as_tuple().exponent < -18:
        raise PaperError('invalid_number', f'{name} is out of range')
    if positive and result <= 0:
        raise PaperError('invalid_number', f'{name} must be positive')
    return result


def decimal_text(value):
    return format(value, 'f')


def utcnow():
    return datetime.now(timezone.utc)


def timestamp(value, name='timestamp'):
    try:
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if parsed.tzinfo is None:
            raise ValueError()
        return parsed.astimezone(timezone.utc)
    except (ValueError, TypeError, AttributeError):
        raise PaperError('invalid_timestamp', f'{name} needs an ISO-8601 timezone')


@dataclass(frozen=True)
class Provenance:
    label: str
    as_of: str
    source_url: str
    is_demo: bool

    def __post_init__(self):
        if not self.label.strip() or not self.source_url.startswith(('https://', 'http://')):
            raise PaperError('invalid_provenance', 'A label and source URL are required')
        if type(self.is_demo) is not bool:
            raise PaperError('invalid_provenance', 'is_demo must be boolean')
        timestamp(self.as_of)


@dataclass(frozen=True)
class OptionContract:
    underlying_asset_id: str
    right: str
    strike: Decimal
    expires_at: str
    multiplier: int = 100

    def __post_init__(self):
        object.__setattr__(self, 'strike', number(self.strike, 'strike', positive=True))
        if not self.underlying_asset_id or self.right not in ('call', 'put'):
            raise PaperError('invalid_option', 'An option needs underlying identity and call/put right')
        if type(self.multiplier) is not int or self.multiplier <= 0 or self.multiplier > 10000:
            raise PaperError('invalid_option', 'Contract multiplier must be a positive integer')
        timestamp(self.expires_at, 'expires_at')


@dataclass(frozen=True)
class StablecoinTerms:
    peg_currency: str = 'USD'
    target_peg: Decimal = Decimal('1.00')
    redemption_guaranteed: bool = False

    def __post_init__(self):
        object.__setattr__(self, 'target_peg', number(self.target_peg, 'target_peg', positive=True))
        if self.peg_currency != 'USD' or self.redemption_guaranteed is not False:
            raise PaperError('invalid_stablecoin', 'USD peg is a target, never a guaranteed redemption or cash balance')


@dataclass(frozen=True)
class BondContract:
    face_value: Decimal
    annual_coupon_rate: Decimal
    matures_at: str
    coupon_frequency: int = 2
    price_convention: str = 'clean_per_100_face'

    def __post_init__(self):
        object.__setattr__(self, 'face_value', number(self.face_value, 'face_value', positive=True))
        rate = number(self.annual_coupon_rate, 'annual_coupon_rate')
        object.__setattr__(self, 'annual_coupon_rate', rate)
        if rate < 0 or rate > 1 or type(self.coupon_frequency) is not int or self.coupon_frequency not in (1, 2, 4, 12):
            raise PaperError('invalid_bond', 'Bond coupon rate is a fraction 0–1 with explicit payment frequency')
        if self.price_convention != 'clean_per_100_face':
            raise PaperError('invalid_bond', 'This demo requires an explicit clean quote per 100 face')
        timestamp(self.matures_at, 'matures_at')


@dataclass(frozen=True)
class Instrument:
    asset_id: str
    symbol: str
    name: str
    kind: AssetKind
    price: Decimal
    provenance: Provenance
    currency: str = 'USD'
    venue: str = 'DEMO'
    option: OptionContract | None = None
    quantity_step: Decimal = Decimal('0.00000001')
    stablecoin: StablecoinTerms | None = None
    bond: BondContract | None = None
    bond_clean_price_per_100: Decimal | None = None
    bond_accrued_interest_per_bond: Decimal = Decimal(0)

    def __post_init__(self):
        try:
            object.__setattr__(self, 'kind', AssetKind(self.kind))
        except ValueError:
            raise PaperError('invalid_asset_kind', 'People and strategies are not tradable instruments')
        object.__setattr__(self, 'price', number(self.price, 'price', positive=True))
        object.__setattr__(self, 'quantity_step', number(self.quantity_step, 'quantity_step', positive=True))
        if not self.asset_id or not self.symbol or not self.name or not self.venue or self.currency != 'USD':
            raise PaperError('invalid_asset', 'Exact asset identity, venue and USD pricing are required')
        if (self.kind == AssetKind.OPTION) != (self.option is not None):
            raise PaperError('invalid_option', 'Only options carry contract terms')
        if (self.kind == AssetKind.STABLECOIN) != (self.stablecoin is not None):
            raise PaperError('invalid_stablecoin', 'Only stablecoins carry peg terms; they are not cash')
        if (self.kind == AssetKind.BOND) != (self.bond is not None):
            raise PaperError('invalid_bond', 'A direct bond requires face, coupon, maturity and price convention')
        accrued = number(self.bond_accrued_interest_per_bond, 'bond_accrued_interest_per_bond')
        object.__setattr__(self, 'bond_accrued_interest_per_bond', accrued)
        if accrued < 0:
            raise PaperError('invalid_bond', 'Accrued interest cannot be negative in this demo')
        if self.bond:
            clean = number(self.bond_clean_price_per_100, 'bond_clean_price_per_100', positive=True)
            object.__setattr__(self, 'bond_clean_price_per_100', clean)
            expected = (self.bond.face_value * clean / 100 + accrued).quantize(Decimal('.01'), rounding=ROUND_HALF_UP)
            if self.price != expected:
                raise PaperError('invalid_bond_price', 'USD price per bond must equal face × clean quote / 100 + accrued interest')
        elif self.bond_clean_price_per_100 is not None or accrued != 0:
            raise PaperError('invalid_bond', 'Only a bond carries clean quote and accrued interest')
        if self.kind in (AssetKind.OPTION, AssetKind.BOND):
            object.__setattr__(self, 'quantity_step', Decimal(1))

    @property
    def multiplier(self):
        return self.option.multiplier if self.option else 1

    @property
    def unit(self):
        return 'contracts' if self.option else 'bonds' if self.bond else 'tokens' if self.stablecoin else ('units' if self.kind == AssetKind.CRYPTO else 'shares')

    def validate_quantity(self, quantity, now):
        quantity = number(quantity, 'quantity', positive=True)
        if quantity % self.quantity_step:
            raise PaperError('invalid_quantity', f'Quantity must use steps of {self.quantity_step} {self.unit}')
        if self.option and timestamp(self.option.expires_at) <= now:
            raise PaperError('expired_option', 'Expired options cannot be traded; settlement is not simulated')
        if self.bond and timestamp(self.bond.matures_at) <= now:
            raise PaperError('matured_bond', 'Matured bond settlement is not simulated; no new trade is permitted')
        return quantity


@dataclass(frozen=True)
class Allocation:
    asset_id: str
    weight: Decimal

    def __post_init__(self):
        object.__setattr__(self, 'weight', number(self.weight, 'weight', positive=True))
        if not self.asset_id or self.weight > 1:
            raise PaperError('invalid_allocation', 'Allocation needs exact asset identity and weight <= 1')


@dataclass(frozen=True)
class CopyStrategy:
    strategy_id: str
    name: str
    person_name: str
    allocations: tuple[Allocation, ...]
    provenance: Provenance

    def __post_init__(self):
        if not self.strategy_id or not self.name or not self.person_name or not self.allocations:
            raise PaperError('invalid_strategy', 'A copy strategy needs identity, attribution and allocations')
        ids = [item.asset_id for item in self.allocations]
        if len(ids) != len(set(ids)) or sum((a.weight for a in self.allocations), Decimal(0)) > 1:
            raise PaperError('invalid_allocation', 'Allocations must be unique and sum to at most 1; remainder stays cash')
