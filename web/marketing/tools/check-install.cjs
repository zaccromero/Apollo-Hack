const fs=require("node:fs"),vm=require("node:vm"),assert=require("node:assert/strict"),path=require("node:path");
const root=path.resolve(__dirname,"..");
const code=fs.readFileSync(path.join(root,"install.js"),"utf8");
const ctx=vm.createContext({Date,URL,Number,fetch:async()=>({ok:false}),document:{}});
vm.runInContext(code,ctx);
const base={status:"verified",product:"Apollo",gameBuildVerified:true,build:"OFFLINE FIXTURE",verifiedAt:new Date(Date.now()-1000).toISOString(),url:"https://testflight.apple.com/join/TESTONLY",qr:"assets/install-qr.png",qrPayload:"https://testflight.apple.com/join/TESTONLY"};
function valid(c){ctx.config=c;return vm.runInContext("validInstall(config)",ctx);}
assert.equal(valid(base),true);
for(const c of [
 {...base,status:"unavailable"},{...base,gameBuildVerified:false},{...base,product:"Other"},
 {...base,build:""},{...base,verifiedAt:"invalid"},
 {...base,verifiedAt:new Date(Date.now()+86400000).toISOString()},
 {...base,url:"https://evil.test/join/TESTONLY"},
 {...base,url:"http://testflight.apple.com/join/TESTONLY"},
 {...base,url:base.url+"?x=1"},{...base,qrPayload:"different"},{...base,qr:"wrong.png"},
 {...base,url:"https://testflight.apple.com.evil.test/join/TESTONLY"},
 {...base,url:"https://user:pass@testflight.apple.com/join/TESTONLY"}
])assert.equal(valid(c),false);
assert.equal(JSON.parse(fs.readFileSync(path.join(root,"install.json"),"utf8")).status,"unavailable");
console.log("14 install-guard fixtures passed; no network requests or config mutation.");
