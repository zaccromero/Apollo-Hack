"""Validate nonsecret preparation contracts only. No runtime, network, or signing effects."""
from __future__ import annotations
import argparse
import json
from pathlib import Path, PurePosixPath

TOP = {'schema_version','environment','contract_only','runtime_wired','bundle_id','team_id','runtime','data','safety','delivery'}
SAFETY = {'real_money_trades','paid_provider_calls','provider_network','telemetry','automatic_upload','external_testers','public_release','new_signing_assets'}

def validate(value, expected):
    errors=[]
    def require(condition, message):
        if not condition: errors.append(message)
    def exact_keys(obj, keys, name):
        require(isinstance(obj,dict) and set(obj)==keys, name+': unexpected or missing fields')
        return obj if isinstance(obj,dict) else {}
    value=exact_keys(value,TOP,'contract')
    require(type(value.get('schema_version')) is int and value['schema_version']==1,'unsupported schema')
    require(value.get('environment')==expected and expected in {'dev','staging','prod'},'environment/file mismatch')
    require(value.get('contract_only') is True and value.get('runtime_wired') is False,'templates must not claim runtime wiring')
    require(value.get('bundle_id')=='com.zaccromero.ApolloHack' and value.get('team_id')=='6GB3JDVN8D','Apollo identity mismatch')
    runtime=exact_keys(value.get('runtime'),{'enabled','mode','backend_url','endpoint_allowlist'},'runtime')
    data=exact_keys(value.get('data'),{'storage_namespace','backend_database','test_identity','identity_is_authenticated','private_profile_import'},'data')
    safety=exact_keys(value.get('safety'),SAFETY,'safety')
    delivery=exact_keys(value.get('delivery'),{'channel','signing','testflight_internal_only','upload_authorized_by_template'},'delivery')
    require(all(safety.get(k) is False for k in SAFETY),'all network/spending/release authority must remain off')
    require(data.get('identity_is_authenticated') is False and data.get('private_profile_import') is False,'synthetic fixture identity only; no private profile import')
    require(delivery.get('upload_authorized_by_template') is False,'a template cannot authorize upload')
    # No hosted service or arbitrary endpoint exists in this preparation packet.
    require(runtime.get('backend_url') is None and runtime.get('endpoint_allowlist')==[],'backend is unconfigured; endpoint activation requires Integration')
    if expected=='prod':
        require(runtime.get('enabled') is False and runtime.get('mode')=='disabled','production must stay inert')
        require(all(data.get(k) is None for k in ['storage_namespace','backend_database','test_identity']),'production data must stay unconfigured')
        require(delivery.get('channel')=='none' and delivery.get('signing')=='none' and delivery.get('testflight_internal_only') is False,'production delivery must stay disabled')
    else:
        require(runtime.get('mode')=='fixture','testing starts with labeled fixtures')
        require(runtime.get('enabled') is (expected=='dev'),'staging must remain disabled pending native wiring')
        namespace=data.get('storage_namespace')
        require(isinstance(namespace,str) and namespace.startswith('apollo.') and (expected!='staging' or namespace.startswith('apollo.stage.')),'invalid fixture namespace')
        path=data.get('backend_database')
        require(isinstance(path,str) and path.startswith('data/'+expected+'/') and not PurePosixPath(path).is_absolute() and '..' not in PurePosixPath(path).parts,'database must stay inside its environment data directory')
        require(isinstance(data.get('test_identity'),str) and bool(data['test_identity']),'synthetic tester identity required')
        if expected=='staging':
            require(delivery.get('channel')=='internal_testflight_preparation' and delivery.get('signing')=='existing_apollo_distribution' and delivery.get('testflight_internal_only') is True,'staging must reuse Apollo signing and remain internal-only')
        else:
            require(delivery.get('channel')=='local_only' and delivery.get('signing')=='existing_development' and delivery.get('testflight_internal_only') is False,'dev is local development only')
    return errors

def validate_directory(root):
    errors=[]; profiles={}
    for env in ('dev','staging','prod'):
        try:
            profiles[env]=json.loads((root/(env+'.json')).read_text())
            errors.extend(env+': '+e for e in validate(profiles[env],env))
        except (OSError,ValueError,TypeError) as exc:
            errors.append(env+': unreadable contract ('+type(exc).__name__+')')
    if len(profiles)==3:
        for key in ('storage_namespace','backend_database','test_identity'):
            values=[d.get('data',{}).get(key) for d in profiles.values() if isinstance(d,dict) and isinstance(d.get('data'),dict)]
            values=[v for v in values if v is not None]
            if len(values)!=len(set(map(str,values))):errors.append(key+': environment data collision')
    return errors

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parent)
    errors=validate_directory(parser.parse_args().root)
    print(json.dumps({'check':'ENVIRONMENT_CONTRACT_ONLY','result':'FAIL' if errors else 'PASS','runtime_wiring':'NOT_RUN','errors':errors}))
    raise SystemExit(bool(errors))
