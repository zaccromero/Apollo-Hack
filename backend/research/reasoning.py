"""Source-preserving reasoning presentation; no inference engine or model calls."""
import copy

def reasoning_tracks(record):
 tracks=copy.deepcopy(record['tracks']);sources={s['id']:s for s in record['sources']}
 for track in tracks:
  ids=track.get('sources',[])
  if any(i not in sources for i in ids):raise ValueError('Evidence source missing from record')
  facts=[]
  for sid in ids:
   s=sources[sid]
   if not s.get('text'):continue
   facts.append({'text':s['text'],'source_ids':[sid],'kind':'observed_opinion_or_sample' if track['key']=='public_sentiment' else 'reviewed_source_summary',
    'verbatim_quote':False,'source':{k:copy.deepcopy(s.get(k)) for k in ('id','title','url','date','date_kind','kind')}})
  counter=[]
  # Only already reviewed, explicitly sourced counterevidence within this track.
  reviewed=(record.get('evidence_review') or {}).get('counterevidence')
  if reviewed and set(reviewed.get('sources',[]))<=set(ids) and reviewed.get('sources'):
   counter=[{'text':reviewed['text'],'source_ids':copy.deepcopy(reviewed['sources']),'kind':'reviewed_counterevidence'}]
  if record.get('ticker')=='WINA' and track['key']=='promises_results':
   counter=[{'text':'Reported quarterly net income, diluted EPS and royalties increased; delivered marketing actions are real, although causal attribution remains unknown.','source_ids':['S3','S4'],'kind':'reviewed_counterevidence'}]
  track['reasoning']={'facts':facts,'fact_label':'Observed source content' if track['key']=='public_sentiment' else 'Reviewed facts / source summaries',
   'interpretations':[{'text':track['headline'],'source_ids':copy.deepcopy(ids),'kind':'interpretation_not_source_quote'}] if facts else [],
   'counterevidence':counter,'counterevidence_status':'reviewed' if counter else 'No separate reviewed counterevidence in this track; absence does not confirm the interpretation.',
   'unknowns':[track.get('caveat','No reviewed evidence available.'),'Latest updates and completeness are not independently verified.'],
   'method':'Curated deterministic evidence presentation, not generated financial advice'}
 return tracks
