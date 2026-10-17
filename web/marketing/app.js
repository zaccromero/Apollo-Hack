"use strict";
(() => {
 const initialCash=10000;
 const money=n=>new Intl.NumberFormat("en-US",{style:"currency",currency:"USD",maximumFractionDigits:2}).format(n);
 const panel=document.getElementById("demo-panel");
 const sessions=Object.fromEntries(Object.entries(APOLLO_EXAMPLES).map(([key,e])=>[key,{draft:String(e.quantity),committed:null,decision:null,errorShown:false}]));
 let topic="stock",stage=0;
 const item=()=>APOLLO_EXAMPLES[topic], session=()=>sessions[topic];
 const unit=n=>n===1?item().unit.slice(0,-1):item().unit;
 function setTopic(key){
  if(!Object.hasOwn(APOLLO_EXAMPLES,key))return;
  topic=key;stage=0;
  const e=item();
  for(const [id,value] of Object.entries({"asset-symbol":e.symbol,"asset-kind":e.kind,"asset-name":e.name,"asset-description":e.description,"quote-label":e.quoteLabel,"asset-question":e.question,"asset-price":money(e.price)}))document.getElementById(id).textContent=value;
  document.querySelectorAll("[data-topic]").forEach(b=>b.setAttribute("aria-pressed",String(b.dataset.topic===topic)));
  render();
 }
 function selectStage(value,focus=false){
  if(!Number.isInteger(value)||value<0||value>2)return;
  stage=value;render();
  if(focus)document.getElementById("panel-title").focus({preventScroll:true});
 }
 function render(){
  const e=item(),s=session(),committed=s.committed;
  document.querySelectorAll("[data-step]").forEach(b=>b.setAttribute("aria-pressed",String(Number(b.dataset.step)===stage)));
  if(stage===0){
   panel.innerHTML='<p class="panel-kicker">Discover / '+e.kind+'</p><h3 class="panel-title" id="panel-title" tabindex="-1"><span class="desktop-title">'+e.discoverTitle+'</span><span class="mobile-question">'+e.question+'</span></h3><div class="idea-card"><p class="eyebrow">Fictional idea card</p><h4>'+e.name+'</h4><p>'+e.discover+'</p><div class="card-choices" role="group" aria-label="Choose what to do with this idea"><button type="button" data-decision="pass" aria-pressed="'+(s.decision==='pass')+'">Pass</button><button type="button" data-decision="watch" aria-pressed="'+(s.decision==='watch')+'">Watch</button><button type="button" data-decision="investigate">Investigate →</button></div></div><div class="decision-result" role="status" '+(!s.decision?'hidden':'')+'>'+(s.decision==='pass'?'Passed for now. No paper position was created. You can still examine the evidence.':s.decision==='watch'?'Kept in this website session for a closer look. Watching does not buy anything.':'')+'</div><div class="panel-actions"><button type="button" class="button primary" data-next="1">Understand the idea <span aria-hidden="true">→</span></button></div>';
  }else if(stage===1){
   panel.innerHTML='<p class="panel-kicker">Understand / '+e.kind+'</p><h3 class="panel-title" id="panel-title" tabindex="-1">'+e.understandTitle+'</h3><p class="evidence-identity">'+e.name+' · fictional teaching example</p><ul class="evidence-list">'+e.points.map(p=>'<li>'+p+'</li>').join('')+'</ul><p class="evidence-note">'+e.limit+'</p><div class="flow-bridge"><span aria-hidden="true">↓</span><p>Turn that question into a deliberate choice. Review the cost before putting paper money behind this idea.</p></div><div class="panel-actions"><button type="button" class="button primary" data-next="2">Review paper practice <span aria-hidden="true">→</span></button><button type="button" class="text-button" data-next="0">Back to the idea</button></div>';
  }else if(committed){
   panel.innerHTML='<p class="panel-kicker">Practice / website simulation</p><h3 class="panel-title" id="panel-title" tabindex="-1">A paper position. A reason to reflect.</h3><p class="panel-copy">You confirmed '+committed.quantity+' '+unit(committed.quantity)+' of '+e.name.toLowerCase()+' in this website example. No app account was changed.</p><div class="receipt"><p class="receipt-heading"><span aria-hidden="true">✓</span> Website practice receipt</p><h4>'+e.name+'</h4><p class="receipt-detail">'+committed.quantity+' '+unit(committed.quantity)+' · '+money(e.price)+(e.multiplier===100?' × 100 per contract':' per share')+'</p><div class="receipt-line"><span>Paper cash remaining</span><strong data-value="cash">'+money(initialCash-committed.cost)+'</strong></div><div class="receipt-line"><span>Illustrative position cost</span><strong data-value="holdings">'+money(committed.cost)+'</strong></div><div class="receipt-line"><span>Total at example prices</span><strong data-value="equity">'+money(initialCash)+'</strong></div></div><p class="risk-note">No gain or loss is assumed here. If the price or premium changes, the position value changes too. What would make you revisit your thinking?</p><div class="panel-actions"><button type="button" class="button primary" data-reset>Start this example again <span aria-hidden="true">↺</span></button></div>';
  }else{
   panel.innerHTML='<p class="panel-kicker">Practice / explicit preview</p><h3 class="panel-title" id="panel-title" tabindex="-1">Review before you confirm.</h3><p class="panel-copy">Choose a quantity. Nothing changes until you confirm this website-only example.</p><div class="quantity-field"><label for="quantity">Number of '+e.unit+'</label><input id="quantity" type="number" inputmode="numeric" min="1" step="1" aria-describedby="quantity-help practice-error"></div><p id="quantity-help" class="evidence-note">'+(e.multiplier===100?'Each contract: $5 quoted premium × 100 units.':'Illustrative price: '+money(e.price)+' per share.')+'</p><div class="math-line"><span>Starting paper cash</span><strong>'+money(initialCash)+'</strong></div><div class="math-line total"><span>Position cost</span><strong id="preview-cost">—</strong></div><div class="math-line"><span>Cash after confirmation</span><strong id="preview-cash">—</strong></div><p class="risk-note">'+e.risk+'</p><p id="practice-error" class="error" role="alert" hidden></p><div class="confirmation-group"><div class="confirm-summary"><p class="eyebrow">Confirm website practice for</p><h4 id="confirm-asset">'+e.name+'</h4><p id="confirm-detail"></p><div><span>Position cost</span><strong id="confirm-cost">—</strong></div></div><div class="panel-actions"><button type="button" id="demo-confirm" class="button primary">Confirm website practice <span aria-hidden="true">✓</span></button><button type="button" class="text-button" data-next="1">Keep exploring</button></div></div>';
   document.getElementById("quantity").value=s.draft;
   updatePreview(s.errorShown);
  }
 }
 function readQuantity(){
  const raw=session().draft.trim(),n=Number(raw);
  if(raw===""||!Number.isFinite(n)||!Number.isSafeInteger(n)||n<1)return {error:"Enter a whole number of at least 1."};
  const cost=n*item().price*item().multiplier;
  if(cost>initialCash)return {error:"That costs more than the $10,000 paper balance. Try a smaller quantity."};
  return {quantity:n,cost};
 }
 function updatePreview(showError){
  const result=readQuantity(),e=item();
  document.getElementById("preview-cost").textContent=result.error?"—":money(result.cost);
  document.getElementById("preview-cash").textContent=result.error?"—":money(initialCash-result.cost);
  document.getElementById("confirm-cost").textContent=result.error?"—":money(result.cost);
  document.getElementById("confirm-detail").textContent=result.error?'Enter a valid quantity above before confirming.':result.quantity+' '+unit(result.quantity)+' × '+money(e.price)+(e.multiplier===100?' × 100 units':' per share');
  const error=document.getElementById("practice-error");
  error.hidden=!(showError&&result.error);
  error.textContent=showError&&result.error?result.error:"";
  document.getElementById("quantity").setAttribute("aria-invalid",String(Boolean(showError&&result.error)));
  return result;
 }
 panel.addEventListener("input",event=>{if(event.target.id==="quantity"){session().draft=event.target.value;updatePreview(session().errorShown);}});
 panel.addEventListener("click",event=>{
  const button=event.target.closest("button");if(!button)return;
  if(button.hasAttribute("data-next"))selectStage(Number(button.dataset.next),true);
  else if(button.hasAttribute("data-decision")){
   if(button.dataset.decision==='investigate')selectStage(1,true);
   else {session().decision=button.dataset.decision;render();panel.querySelector('[data-decision="'+session().decision+'"]').focus({preventScroll:true});}
  }else if(button.hasAttribute("data-reset")){Object.assign(session(),{draft:String(item().quantity),committed:null,decision:null,errorShown:false});selectStage(0,true);}
  else if(button.id==="demo-confirm"&&!session().committed&&stage===2){
   session().errorShown=true;const result=updatePreview(true);
   if(result.error){document.getElementById("quantity").focus({preventScroll:true});return;}
   session().committed={quantity:result.quantity,cost:result.cost};render();document.getElementById("panel-title").focus({preventScroll:true});
  }
 });
 document.querySelectorAll("[data-topic]").forEach(b=>b.addEventListener("click",()=>setTopic(b.dataset.topic)));
 document.querySelectorAll("[data-step]").forEach(b=>b.addEventListener("click",()=>selectStage(Number(b.dataset.step))));
 document.querySelectorAll('[data-open-topic]').forEach(a=>a.addEventListener('click',()=>{setTopic(a.dataset.openTopic);selectStage(Number(a.dataset.openStage));}));
 setTopic("stock");
})();
