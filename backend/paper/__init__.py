"""Apollo persistent simulated investing. No broker, paid API or server side effects."""
from .models import Allocation, AssetKind, BondContract, CopyStrategy, Instrument, OptionContract, PaperError, Provenance, StablecoinTerms
from .service import PaperService
from .api import PaperAPI
from .research_bridge import sync_research_catalog
from .fixtures import get_instrument_specs

__all__ = ['Allocation', 'AssetKind', 'BondContract', 'CopyStrategy', 'Instrument', 'OptionContract', 'PaperError', 'Provenance', 'StablecoinTerms', 'PaperService', 'PaperAPI', 'sync_research_catalog', 'get_instrument_specs']
