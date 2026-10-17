"use strict";
// Distribution is fail-closed: a configured URL alone cannot enable installation.
function validInstall(config){
  if(!config||config.status!=="verified"||config.product!=="Apollo"||config.gameBuildVerified!==true||typeof config.build!=="string"||!config.build.trim()||!config.verifiedAt||!Number.isFinite(Date.parse(config.verifiedAt))||Date.parse(config.verifiedAt)>Date.now()||config.qr!=="assets/install-qr.png"||config.qrPayload!==config.url)return false;
  try{const url=new URL(config.url);return url.protocol==="https:"&&!url.username&&!url.password&&!url.port&&!url.search&&!url.hash&&((url.hostname==="testflight.apple.com"&&/^\/join\/[A-Za-z0-9]{8}$/.test(url.pathname))||(url.hostname==="apps.apple.com"&&/\/id\d+\/?$/.test(url.pathname)));}catch{return false;}
}
async function loadInstall(){
  try{
    const response=await fetch("install.json",{cache:"no-store"});if(!response.ok)return;
    const config=await response.json();if(!validInstall(config))return;
    const qr=document.getElementById("install-qr");
    await new Promise((resolve,reject)=>{qr.onload=resolve;qr.onerror=reject;qr.src=config.qr+"?destination="+encodeURIComponent(config.url);});
    const faq=document.getElementById("availability-answer");if(faq)faq.textContent="A verified install link is available in the iPhone availability section. Open it on your iPhone, or scan the matching QR code.";
    document.getElementById("access-status").textContent="Apollo is ready to explore";
    document.getElementById("access-detail").textContent="Open the verified Apollo game link on your iPhone, or scan the QR code. Both lead to the same destination.";
    const link=document.getElementById("install-link");link.href=config.url;link.textContent=config.url.includes("testflight.apple.com")?"Open Apollo in TestFlight ↗":"View Apollo on the App Store ↗";link.hidden=false;
    document.getElementById("qr-region").hidden=false;
    const steps=document.getElementById("install-steps");steps.textContent=config.url.includes("testflight.apple.com")?"Open the link on your iPhone, follow Apple’s TestFlight instructions, then install the Apollo game build named on the invitation.":"Open the App Store link on your iPhone and follow Apple’s installation instructions.";steps.hidden=false;
    document.getElementById("build-label").textContent=`Apollo game · ${config.build} · link checked ${new Date(config.verifiedAt).toLocaleDateString("en-US",{month:"short",day:"numeric",year:"numeric",timeZone:"America/New_York"})}`;
  }catch{/* Preserve the honest unavailable state after config, network or QR failures. */}
}
loadInstall();
