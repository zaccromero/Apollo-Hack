import Foundation
@main struct EnvironmentPolicyChecks {
    static func main() throws {
        var checks=[String]()
        func check(_ value:Bool,_ name:String){precondition(value,name);checks.append(name)}
        func config(_ env:String?=nil,_ debug:Bool=true,_ args:[String]=[])throws->ApolloRuntimeConfiguration {
            try ApolloRuntimeConfiguration.resolve(declaredEnvironment:env,isDebugBuild:debug,arguments:args)
        }
        func reject(_ name:String,_ env:String?,_ debug:Bool,_ args:[String]=[]) {
            do {_=try config(env,debug,args);fatalError("accepted: "+name)}catch {checks.append(name)}
        }
        let dev=try config()
        check(dev.environment == .dev && dev.paperStorageKey == "apollo.game.demo.v1" && dev.stateNamespace == "apollo.demo" && dev.backendURL == nil,"legacy debug DEV identity preserved")
        let explicit=try config("dev",true,["--provider-diagnostics","--apollo-owner-comparison"])
        check(explicit.diagnosticsEnabled && explicit.initialComparison,"DEV diagnostic/comparison behavior preserved")
        for url in ["http://127.0.0.1:8769","http://localhost:8767/","http://[::1]:8769","https://localhost:8769"] {
            let connected=try config("dev",true,["--apollo-backend-url="+url])
            check(connected.backendURL != nil && connected.stateNamespace == "apollo.connected","allowed loopback "+url)
        }
        let test=try config("dev",true,["--apollo-test-storage=namespace-123"])
        check(test.paperStorageKey == "apollo.game.test.namespace-123" && test.stateNamespace == "--apollo-test-storage=namespace-123","legacy test paper/raw state namespace preserved")
        let connectedTest=try config("dev",true,["--apollo-test-storage=ns","--apollo-backend-url=http://127.0.0.1:8769"])
        check(connectedTest.backendURL != nil && connectedTest.stateNamespace == "--apollo-test-storage=ns","connected test namespace preserved")
        let stage=try config("staging",false)
        check(stage.environment == .staging && stage.paperStorageKey == "apollo.stage.fixture.v1" && stage.stateNamespace == "apollo.stage.fixture.v1" && stage.backendURL == nil && !stage.initialComparison && !stage.diagnosticsEnabled,"explicit Release staging isolated fixtures only")
        let debugStage=try config("staging",true)
        check(debugStage.paperStorageKey == stage.paperStorageKey,"explicit debug staging uses same isolated policy")
        reject("Release missing environment rejected",nil,false)
        reject("Release DEV rejected","dev",false)
        reject("production Debug rejected","prod",true)
        reject("production Release rejected","prod",false)
        reject("production with diagnostic bypass rejected","prod",false,["--provider-diagnostics"])
        reject("unknown environment rejected","preview",true)
        reject("blank declared environment rejected","",true)
        reject("case-mismatched environment rejected","STAGING",false)
        for args in [["--apollo-backend-url=http://127.0.0.1:8769"],["--apollo-test-storage=apollo.game.demo.v1"],["--provider-diagnostics"],["--apollo-owner-comparison"],["--apollo-environment=dev"],["--apollo-env=dev"],["--environment=dev"],["--apollo-test-storage"],["--provider-diagnostics=1"]] {
            reject("stage override rejected "+args.joined(separator:" "),"staging",false,args)
        }
        reject("Debug environment CLI override rejected","dev",true,["--apollo-env=prod"])
        for url in ["https://production.invalid:8769","http://127.0.0.1.attacker.invalid:8769","http://127.0.0.1:8768","http://127.0.0.1","file://127.0.0.1:8769","http://fake:fake@127.0.0.1:8769","http://127.0.0.1:8769/api","http://127.0.0.1:8769?env=prod","http://127.0.0.1:8769#prod","http://127.0.0.1:8769/%2e%2e","http://192.168.1.1:8769","http://localhost.:8769"] {
            reject("unsafe DEV URL rejected "+url,"dev",true,["--apollo-backend-url="+url])
        }
        reject("duplicate backend rejected","dev",true,["--apollo-backend-url=http://localhost:8769","--apollo-backend-url=http://localhost:8767"])
        reject("duplicate test storage rejected","dev",true,["--apollo-test-storage=a","--apollo-test-storage=b"])
        reject("malformed backend flag rejected","dev",true,["--apollo-backend-url"])
        reject("malformed storage flag rejected","dev",true,["--apollo-test-storage"])
        reject("empty test identifier rejected","dev",true,["--apollo-test-storage="])
        reject("path test identifier rejected","dev",true,["--apollo-test-storage=../../owner"])
        reject("oversized test identifier rejected","dev",true,["--apollo-test-storage="+String(repeating:"a",count:101)])
        check(Set([dev.paperStorageKey,stage.paperStorageKey]).count == 2 && Set([dev.stateNamespace,stage.stateNamespace]).count == 2,"DEV/STAGING paper+UI namespaces distinct")
        let result:[String:Any]=["result":"PASS","check_count":checks.count,"checks":checks,"scope":"Pure Foundation runtime policy; app-root/project/native wiring NOT_RUN","production":"always rejected"]
        print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
    }
}
