"""Shared explicit thesis action; no startup, automatic, or paid calls by default."""
import json
import os
from datetime import datetime, timezone
from dataclasses import replace
from time import monotonic
from uuid import UUID
from urllib.parse import urlsplit
from backend.providers.prism.api import PrismAPI
from backend.providers.prism.service import PrismConfig, PrismService
from backend.providers.nicrron import NicrronAdapter, NicrronConfig, request_from_prism

def nicrron_key_from_env(env):
    direct=env.get('NICRRON_API_KEY') or env.get('MONEY_TALKS_2_NICRRON_API_KEY')
    if direct:
        return direct
    # Existing event loader names MODEL_API_KEY; accept it only for its exact Nicrron destination.
    if env.get('MODEL_BASE_URL','').rstrip('/') == 'https://api.nicrron.ai/v1':
        return env.get('MODEL_API_KEY','')
    return ''

class ProviderGateway:
    def __init__(self, prism=None, nicrron=None):
        self.prism = prism or PrismService(replace(PrismConfig.from_env(),network_enabled=False,telemetry_enabled=False))
        self.prism_api = PrismAPI(self.prism)
        self.nicrron = nicrron or NicrronAdapter(NicrronConfig(api_key=nicrron_key_from_env(os.environ),enabled=False,credit_paused=True,request_allowance=0))
        self.last_receipt = None

    def handle(self, method, path, body=None):
        route = urlsplit(path).path.rstrip('/')
        if route.startswith('/providers/prism/'):
            return self.prism_api.handle(method,path,body)
        if method == 'GET' and route == '/providers/nicrron/status':
            return 200,self.nicrron.health()
        if method != 'POST' or route != '/providers/challenge':
            return 404,{'error':'route_not_found'}
        retrieval = full = evaluation = payload = None
        query = None
        request_time = datetime.now(timezone.utc).isoformat()
        self.last_receipt = None  # Never expose an earlier request's prepared receipt after a paused/failed action.
        body = body if isinstance(body,dict) else {}
        context = body.get('context',{})
        result = {'schema_version':1,'request_id':body.get('request_id'),'asset_id':body.get('asset_id'),
            'status':'unavailable','reason':'invalid_request',
            'notice':'Explicit historical assigned WINA notes only. This is separate from current Apollo research. Paid calls remain paused; no risk or order authority.',
            'context':{'mode':'assigned_historical','corpus_hash':self.prism.corpus['corpus_hash'],'cutoff':self.prism.corpus['cutoff'],'label':'Frozen historical assigned WINA notes'},
            'providers':{'prism':{'status':'not_run','live_verified':False,'trace_id':None},
                'nicrron':{'status':'not_run','proof_kind':'not_run','requested_model':self.nicrron.config.model,'actual_model':None,'network_attempted':False},
                'telemetry':{'status':'not_sent','trace_id':None,'trajectory_id':None}},
            'answer':None,'sources':[],'generated_analysis':True,'semantic_grounding_verified':False,'sponsor_acceptance':False}
        def finish(code,status,reason):
            result.update(status=status,reason=reason)
            source_ids=[s['id'] for s in retrieval.get('sources',[])] if retrieval else []
            result['process_steps']=[
                {'id':'context','title':'Question & source version','status':'mismatch' if status=='corpus_mismatch' else 'recorded' if query else 'unavailable','detail':result['notice'],'input_summary':query,'output_summary':result['context']['corpus_hash'],'source_ids':[],'timestamp':request_time},
                {'id':'prism','title':'PRISM passages','status':retrieval['status'] if retrieval else 'not_run','detail':'Actual retrieved source notes only; no cached fallback for this action.','source_ids':source_ids,'timestamp':retrieval.get('ended_at') if retrieval else None,'duration_milliseconds':retrieval.get('duration_ms') if retrieval else None},
                {'id':'nicrron','title':'Nicrron thesis challenge','status':full['status'] if full else 'not_run','detail':full.get('proof_kind','unverified') if full else 'No model call made.','source_ids':source_ids if full else [],'timestamp':full.get('provider_ended_at') if full else None},
                {'id':'checks','title':'Apollo source/response checks','status':evaluation['status'] if evaluation else 'not_run','detail':'Offline exact source/quote/identity contract checks; interpretations remain unverified.' if evaluation else 'No generated answer to check.','source_ids':source_ids if evaluation else []},
                {'id':'trace','title':'PRISM trace status','status':'prepared_not_sent' if payload else 'not_sent','detail':'Local payload prepared; no telemetry sent.' if payload else 'No telemetry or published trace receipt.','source_ids':[]}]
            result['saved_evidence_notice']='Saved sponsor evidence is historical and separate from this request and current Apollo research. It does not establish current-game sponsor acceptance.'
            return code,result
        try:
            UUID(body['request_id'])
            thesis=body['thesis']
            if set(thesis) != {'reason','risk','invalidation'} or any(not isinstance(v,str) or not v.strip() or len(v)>800 for v in thesis.values()): raise ValueError()
            query=json.dumps(thesis,sort_keys=True,separators=(',',':'),ensure_ascii=False)
            if len(query)>2400 or not isinstance(context,dict) or context.get('mode')!='assigned_historical': raise ValueError()
        except (KeyError,ValueError,TypeError,AttributeError):
            return finish(400,'unavailable','invalid_request')
        if body.get('asset_id') != self.prism.corpus['asset_id']:
            return finish(422,'unavailable','unsupported_asset')
        if context.get('corpus_hash') != self.prism.corpus['corpus_hash']:
            return finish(409,'corpus_mismatch','Current research corpus differs from historical assigned PRISM corpus; no substitution performed.')
        ph=self.prism.status();nh=self.nicrron.health()
        result['providers']['prism']['status']=ph['retrieval_state']
        result['providers']['nicrron']['status']=nh['status']
        if ph['retrieval_state'] != 'enabled_unverified' or nh['status'] != 'ready':
            return finish(503,'paused','Providers paused or disabled. No retrieval, model call or telemetry sent.')
        started=monotonic()
        retrieval=self.prism.retrieve(body['asset_id'],query,session_id=body['request_id'])
        result['providers']['prism'].update(status=retrieval['status'],live_verified=retrieval.get('live_verified',False),trace_id=retrieval.get('trace_id'))
        if retrieval['status'] != 'retrieved':
            return finish(502,'unavailable','Assigned source retrieval did not complete; no fallback used.')
        try:
            request=request_from_prism(retrieval,thesis=query,frozen_manifest=self.prism.corpus,
                tracks_by_source={k:tuple(v) for k,v in self.prism.classifications['tracks_by_source'].items()},date_kinds=self.prism.classifications['date_kinds'])
            full=self.nicrron.analyze(request)
            result['providers']['nicrron'].update({k:full.get(k) for k in ('status','proof_kind','requested_model','actual_model','network_attempted')})
            if full['status'] != 'completed':
                return finish(502,'unavailable','Provider analysis did not complete; no fallback used.')
            evaluation=self.prism.evaluate_response(full,retrieval,question=query)
            if evaluation.get('status') != 'PASS':
                return finish(502,'unavailable','Generated analysis failed source validation; no answer substituted.')
            payload=self.prism.trace_payload(retrieval,question=query,answer=full,model=full['actual_model'],latency_ms=(monotonic()-started)*1000,evaluation=evaluation)
            self.last_receipt={'retrieval':retrieval,'result':full,'evaluation':evaluation,'trace_payload':payload,'telemetry_sent':False}
            result.update(answer=full['answer'],sources=full.get('sources',[]))
            return finish(200,'success','Generated analysis from the explicitly selected historical notes; telemetry not sent.')
        except (ValueError,TypeError,KeyError):
            return finish(502,'unavailable','Source or result validation failed; no answer substituted.')
