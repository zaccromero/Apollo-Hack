const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const context=vm.createContext({document:{getElementById:()=>null}});vm.runInContext(fs.readFileSync(path.join(__dirname,'../hero.js'),'utf8'),context);
for(const [dx,dy,cancelled,expected] of [[54,0,false,null],[0,-54,false,null],[55,0,false,'review'],[-55,0,false,'pass'],[0,55,false,'edit'],[0,-55,false,'watch'],[70,20,false,'review'],[-70,20,false,'pass'],[20,70,false,'edit'],[20,-70,false,'watch'],[100,100,true,null],[NaN,100,false,null],[0,0,false,null]])assert.equal(context.apolloGesture(dx,dy,cancelled),expected);
console.log('13 gesture direction/threshold/cancel assertions PASS; browser integration is separate.');
