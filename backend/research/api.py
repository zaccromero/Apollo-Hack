"""Importable JSON adapter; the integration lane alone binds the HTTP server."""
from urllib.parse import urlsplit,parse_qs,unquote
from .service import ResearchService

class ResearchAPI:
 def __init__(self,service=None):self.service=service or ResearchService()
 def handle(self,method,path,body=None):
  try:
   url=urlsplit(path);query=parse_qs(url.query);parts=[unquote(p) for p in url.path.strip('/').split('/')];method=method.upper()
   if method=='GET' and parts==['research','catalog']:return 200,self.service.catalog(query.get('kind',[None])[0],query.get('q',[''])[0])
   if method=='GET' and len(parts)==3 and parts[:2]==['research','assets']:return 200,self.service.details(parts[2])
   if method=='GET' and len(parts)==4 and parts[:2]==['research','assets'] and parts[3]=='analysis':return 200,self.service.analysis(parts[2],query.get('thesis',[''])[0])
   if method=='POST' and parts==['research','analysis']:
    if not isinstance(body,dict):raise ValueError('JSON object required')
    if set(body)-{'asset_id','thesis'}:raise ValueError('Unknown analysis fields')
    return 200,self.service.analysis(body.get('asset_id'),body.get('thesis',''))
   return 404,{'error':'Research route not found'}
  except KeyError:return 404,{'error':'Unknown asset_id'}
  except (ValueError,TypeError):return 400,{'error':'Invalid research request'}
