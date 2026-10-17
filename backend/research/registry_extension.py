"""Opt-in evidence metadata over Paper's sole canonical instrument registry."""
import copy

def expansion_assets():
 from backend.paper.fixtures import get_instrument_specs
 specs=get_instrument_specs()
 if specs.get('schema_version')!=2:raise ValueError('Unsupported instrument registry')
 out={}
 for row in specs['assets']:
  kind=row['kind']
  if kind not in ('stablecoin','bond'):continue
  asset={k:copy.deepcopy(row[k]) for k in ('asset_id','symbol','name','kind','currency','quantity_unit','quantity_step','multiplier','stablecoin','bond','bond_clean_price_per_100','bond_accrued_interest_per_bond')}
  asset.update(demo_price=row['price'],demo_asset=True,instrument_type='peg_token_demo' if kind=='stablecoin' else 'direct_bond_demo',registry_provenance=copy.deepcopy(row['provenance']))
  if kind=='stablecoin':
   asset.update(description='DEMO token exposure targeting a USD peg. Not cash, a verified live price, or a guaranteed redemption.',risk_tags=['depeg','issuer','reserve','custody','redemption_not_guaranteed'])
  else:
   asset.update(description='Fictional direct bond. Terms and clean-price convention are demo specifications, not a verified issuer offer. Coupon payments and settlement are not simulated promises.',risk_tags=['credit_default','interest_rate','liquidity','maturity','demo_terms_only'])
  if asset['asset_id'] in out:raise ValueError('Duplicate registry identity')
  out[asset['asset_id']]=asset
 if {a['kind'] for a in out.values()}!={'stablecoin','bond'}:raise ValueError('Registry expansion incomplete')
 return out
