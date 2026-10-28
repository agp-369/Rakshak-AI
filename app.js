/* Rakshak AI - Live Interactive Demo (static web) */
const I18N = {
  en: {
    home: 'Home', map: 'Map', beacon: 'Beacon', alerts: 'Alerts', more: 'More',
    alertTitle: 'IMD Red Alert', alertBody: 'Heavy rainfall warning for Dehradun district. Avoid riverbanks. Move to higher ground.',
    situation: 'Situation Brief', quick: 'Quick Actions', qBeacon:'Beacon', qMap:'Map', qFamily:'Family', qEmergency:'Emergency #',
    mapGoTo: 'Go-To Bearing', mapGoToBody: 'Tap "Set Target" then click on map. Arrow shows bearing & distance.',
    beaconTitle: 'Composed SMS', emergencyTitle:'Emergency Helplines', emergencySub:'Tap any number to open dialer directly',
    whereTitle:'Where Am I', packsTitle:'AI Pack Manager', familyTitle:'Family Board',
    surveyTitle:'Damage Survey', guidesTitle:'First 10 Minutes',
    safe:'SAFE', needHelp:'NEED HELP', evacuate:'EVACUATE',
  },
  hi: {
    home: 'होम', map: 'मैप', beacon: 'बीकन', alerts: 'अलर्ट', more: 'मोर',
    alertTitle: 'आईएमडी रेड अलर्ट', alertBody: 'देहरादून जिले में भारी बारिश की चेतावनी। नदी किनारे से बचें। ऊंचे स्थान पर जाएं।',
    situation: 'स्थिति सारांश', quick: 'त्वरित कार्रवाई', qBeacon:'बीकन', qMap:'मैप', qFamily:'परिवार', qEmergency:'आपातकालीन #',
    mapGoTo: 'जाओ-बेयरिंग', mapGoToBody: ' "Set Target" दबाएं फिर मैप पर क्लिक करें। तीर दिशा और दूरी दिखाएगा।',
    beaconTitle: 'तैयार SMS', emergencyTitle:'आपातकालीन हेल्पलाइन', emergencySub:'डायलर खोलने के लिए किसी भी नंबर पर टैप करें',
    whereTitle:'मैं कहाँ हूँ', packsTitle:'AI पैक मैनेजर', familyTitle:'परिवार बोर्ड',
    surveyTitle:'क्षति सर्वेक्षण', guidesTitle:'पहले 10 मिनट',
    safe:'सुरक्षित', needHelp:'मदद चाहिए', evacuate:'खाली करें',
  }
};

let lang = 'en';
let hindi = () => lang === 'hi';
function t(key){ return (I18N[lang] && I18N[lang][key]) || I18N.en[key] || key; }

function toast(msg){
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.classList.add('show');
  clearTimeout(window._toastTimer);
  window._toastTimer = setTimeout(()=>el.classList.remove('show'), 2200);
}

function showTab(name){
  document.querySelectorAll('.tab').forEach(s=>s.classList.remove('active'));
  document.getElementById('tab-'+name).classList.add('active');
  document.querySelectorAll('.navbtn').forEach(b=>b.classList.toggle('active', b.dataset.tab===name));
  if(name==='map') drawMap();
  if(name==='alerts') renderAlerts();
  if(name==='more' && !window._panel) openPanel('family');
}

// Language toggle
document.getElementById('langToggle').addEventListener('click', ()=>{
  lang = lang==='en' ? 'hi' : 'en';
  document.getElementById('langToggle').textContent = lang==='en' ? 'HI / EN' : 'EN / HI';
  applyI18n();
});
function applyI18n(){
  document.getElementById('alertTitle').textContent = t('alertTitle');
  document.getElementById('alertBody').textContent = t('alertBody');
  document.getElementById('homeSituationTitle').textContent = t('situation');
  document.getElementById('homeQuickTitle').textContent = t('quick');
  document.getElementById('qBeacon').textContent = t('qBeacon');
  document.getElementById('qMap').textContent = t('qMap');
  document.getElementById('qFamily').textContent = t('qFamily');
  document.getElementById('qEmergency').textContent = t('qEmergency');
  document.getElementById('mapGoToTitle').textContent = t('mapGoTo');
  document.getElementById('mapGoToBody').textContent = t('mapGoToBody');
  document.getElementById('nHome').textContent = t('home');
  document.getElementById('nMap').textContent = t('map');
  document.getElementById('nBeacon').textContent = t('beacon');
  document.getElementById('nAlerts').textContent = t('alerts');
  document.getElementById('nMore').textContent = t('more');
  if(window._currentPanel) openPanel(window._currentPanel, true);
  renderAlerts();
}

// ---------- MAP ----------
const canvas = document.getElementById('mapCanvas');
const ctx = canvas.getContext('2d');
let gps = {lat:30.3255, lon:78.0413, acc:5};
let trail = [];
let backtracking = false;
let hazards = [];
let target = null;
let mapScale = 1;

function latLonToPx(lat,lon){
  // simple equirectangular around center
  const centerLat = gps.lat, centerLon = gps.lon;
  const mPerDegLat = 111320;
  const mPerDegLon = 111320 * Math.cos(centerLat*Math.PI/180);
  const x = (lon - centerLon) * mPerDegLon;
  const y = (centerLat - lat) * mPerDegLat;
  const scale = 4; // px per meter
  return {x: canvas.width/2 + x*scale, y: canvas.height/2 + y*scale};
}
function drawMap(){
  const w = canvas.width, h = canvas.height;
  ctx.clearRect(0,0,w,h);
  // grid
  ctx.strokeStyle = 'rgba(255,255,255,0.05)';
  ctx.lineWidth = 1;
  for(let x=0;x<w;x+=40){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
  for(let y=0;y<h;y+=40){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
  // trail
  if(trail.length>1){
    ctx.strokeStyle = '#4dd4c6';
    ctx.lineWidth = 3;
    ctx.beginPath();
    trail.forEach((p,i)=>{
      const q = latLonToPx(p.lat,p.lon);
      if(i===0) ctx.moveTo(q.x,q.y); else ctx.lineTo(q.x,q.y);
    });
    ctx.stroke();
  }
  // hazards
  hazards.forEach(hz=>{
    const q = latLonToPx(hz.lat,hz.lon);
    ctx.fillStyle = '#e53935';
    ctx.beginPath(); ctx.arc(q.x,q.y,8,0,Math.PI*2); ctx.fill();
    ctx.fillStyle='#fff'; ctx.font='10px sans-serif'; ctx.fillText('⚠', q.x-4, q.y+3);
  });
  // target
  if(target){
    const q = latLonToPx(target.lat,target.lon);
    ctx.strokeStyle='#ff8c1a'; ctx.lineWidth=2;
    ctx.beginPath(); ctx.arc(q.x,q.y,12,0,Math.PI*2); ctx.stroke();
    ctx.fillStyle='#ff8c1a'; ctx.beginPath(); ctx.arc(q.x,q.y,4,0,Math.PI*2); ctx.fill();
  }
  // gps accuracy ring
  const g = latLonToPx(gps.lat,gps.lon);
  ctx.strokeStyle='rgba(255,140,26,0.4)';
  ctx.lineWidth=2;
  ctx.beginPath(); ctx.arc(g.x,g.y, gps.acc*4,0,Math.PI*2); ctx.stroke();
  ctx.fillStyle='#ff8c1a';
  ctx.beginPath(); ctx.arc(g.x,g.y,6,0,Math.PI*2); ctx.fill();
  ctx.fillStyle='#fff'; ctx.font='bold 12px sans-serif'; ctx.fillText('📍', g.x-6, g.y-10);
  // bearing arrow to target
  if(target){
    const dx = g.x, dy = g.y;
    const tx = latLonToPx(target.lat,target.lon).x;
    const ty = latLonToPx(target.lat,target.lon).y;
    const ang = Math.atan2(ty-dy, tx-dx);
    const distPx = Math.hypot(tx-dx, ty-dy);
    const distM = distPx/4;
    // arrow
    ctx.strokeStyle='#ffb347'; ctx.lineWidth=3;
    ctx.beginPath(); ctx.moveTo(dx,dy); ctx.lineTo(tx,ty); ctx.stroke();
    // arrowhead
    ctx.fillStyle='#ffb347';
    ctx.beginPath();
    ctx.moveTo(tx,ty);
    ctx.lineTo(tx-12*Math.cos(ang-0.4), ty-12*Math.sin(ang-0.4));
    ctx.lineTo(tx-12*Math.cos(ang+0.4), ty-12*Math.sin(ang+0.4));
    ctx.closePath(); ctx.fill();
    const bearingDeg = (ang*180/Math.PI+90+360)%360;
    document.getElementById('goToInfo').textContent = `Bearing ${bearingDeg.toFixed(0)}° · Distance ${distM.toFixed(0)} m`;
  }
}
canvas.addEventListener('click', (e)=>{
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width/rect.width;
  const scaleY = canvas.height/rect.height;
  const cx = (e.clientX-rect.left)*scaleX;
  const cy = (e.clientY-rect.top)*scaleY;
  // convert px to lat/lon
  const centerLat = gps.lat, centerLon = gps.lon;
  const mPerDegLat = 111320, mPerDegLon = 111320*Math.cos(centerLat*Math.PI/180);
  const scale = 4;
  const lon = centerLon + (cx - canvas.width/2)/(scale*mPerDegLon);
  const lat = centerLat - (cy - canvas.height/2)/(scale*mPerDegLat);
  if(window._settingTarget){
    target = {lat,lon};
    window._settingTarget = false;
    toast('Target set');
  } else if(window._droppingHazard){
    hazards.push({lat,lon});
    window._droppingHazard = false;
    toast('Hazard pinned');
  }
  drawMap();
});
function dropHazard(){ window._droppingHazard=true; window._settingTarget=false; toast('Click on map to drop hazard'); }
function setTarget(){ window._settingTarget=true; window._droppingHazard=false; toast('Click on map to set target'); }
function toggleBacktrack(){ backtracking=!backtracking; if(backtracking){ trail=[]; toast('Backtrack recording...'); recordTrail(); } else { toast('Backtrack stopped'); } }
function recordTrail(){ if(!backtracking) return; trail.push({lat:gps.lat,lon:gps.lon}); if(trail.length>200) trail.shift(); drawMap(); setTimeout(recordTrail, 1500); }
function clearTrail(){ trail=[]; hazards=[]; target=null; drawMap(); toast('Cleared'); }

// live GPS
document.getElementById('liveLocBtn').addEventListener('click', ()=>{
  if(!navigator.geolocation){ toast('Geolocation not supported'); return; }
  navigator.geolocation.getCurrentPosition(pos=>{
    gps.lat = pos.coords.latitude;
    gps.lon = pos.coords.longitude;
    gps.acc = pos.coords.accuracy;
    document.getElementById('hudCoord').textContent = gps.lat.toFixed(4)+', '+gps.lon.toFixed(4);
    document.getElementById('hudAcc').textContent = '±'+gps.acc.toFixed(0)+' m';
    drawMap();
    toast('Live location updated');
  }, err=>toast('GPS error: '+err.message), {enableHighAccuracy:true, timeout:8000});
});

// ---------- BEACON ----------
function composeBeacon(type){
  const labels = {safe:'SAFE', needHelp:'NEED HELP', evacuate:'EVACUATE'};
  const hiLabels = {safe:'सुरक्षित', needHelp:'मदद चाहिए', evacuate:'खाली करें'};
  const label = hindi() ? hiLabels[type] : labels[type];
  const loc = `~${(Math.random()*0.8+0.2).toFixed(1)} km NE of Clock Tower, Paltan Bazaar, Dehradun, Uttarakhand (${gps.lat.toFixed(5)}, ${gps.lon.toFixed(5)})`;
  const msg = `[RAKSHAK] ${label} — ${loc} — ${new Date().toLocaleString()} — Acc ±${gps.acc.toFixed(0)}m`;
  document.getElementById('beaconMsg').textContent = msg;
  toast(label+' beacon composed');
}
function copyBeacon(){
  const text = document.getElementById('beaconMsg').textContent;
  navigator.clipboard.writeText(text).then(()=>toast('Copied')).catch(()=>toast('Copy failed'));
}

// ---------- ALERTS ----------
const ALERTS = [
  {sev:'red', titleEn:'IMD Red Alert: Heavy Rainfall', titleHi:'आईएमडी रेड अलर्ट: भारी बारिश',
   actionsEn:['Avoid riverbanks and low-lying areas','Move to higher ground / relief camp','Keep emergency kit ready','Do not cross flooded roads'],
   actionsHi:['नदी किनारे और निचले इलाकों से बचें','ऊंचे स्थान / राहत शिविर में जाएं','आपातकालीन किट तैयार रखें','बाढ़ वाली सड़कें पार न करें']},
  {sev:'orange', titleEn:'CWC Flood Warning: River Level Rising', titleHi:'सीडब्ल्यूसी बाढ़ चेतावनी: नदी स्तर बढ़ रहा',
   actionsEn:['Monitor official updates','Evacuate if instructed','Secure documents & medicines'],
   actionsHi:['आधिकारिक अपडेट देखें','निर्देश मिलने पर खाली करें','दस्तावेज़ और दवाएं सुरक्षित रखें']},
];
function renderAlerts(){
  const list = document.getElementById('alertsList');
  list.innerHTML = '';
  ALERTS.forEach(a=>{
    const title = hindi()?a.titleHi:a.titleEn;
    const actions = hindi()?a.actionsHi:a.actionsEn;
    const item = document.createElement('div');
    item.className='alert-item';
    item.innerHTML = `<span class="sev ${a.sev}">${a.sev.toUpperCase()}</span><h4>${title}</h4><ul>${actions.map(x=>'<li>'+x+'</li>').join('')}</ul>`;
    list.appendChild(item);
  });
}

// ---------- MORE PANELS ----------
const EMERGENCY = [
  {name:'Emergency', nameHi:'आपातकाल', phone:'112', desc:'National Emergency', descHi:'राष्ट्रीय आपातकाल', icon:'🚨'},
  {name:'Ambulance', nameHi:'एम्बुलेंस', phone:'108', desc:'Medical Emergency', descHi:'चिकित्सा आपातकाल', icon:'🚑'},
  {name:'Fire', nameHi:'अग्निशमन', phone:'101', desc:'Fire Brigade', descHi:'अग्निशमन विभाग', icon:'🚒'},
  {name:'Police', nameHi:'पुलिस', phone:'100', desc:'Police', descHi:'पुलिस', icon:'👮'},
  {name:'Disaster Mgmt', nameHi:'आपदा प्रबंधन', phone:'1078', desc:'NDMA Helpline', descHi:'एनडीएमए हेल्पलाइन', icon:'🌪️'},
  {name:'Women Helpline', nameHi:'महिला हेल्पलाइन', phone:'1091', desc:'Women Safety', descHi:'महिला सुरक्षा', icon:'👩'},
];
let familyMembers = [
  {name:'Asha Devi', phone:'+91 98765 43210', status:'safe'},
  {name:'Ramesh Gupta', phone:'+91 91234 56789', status:'needHelp'},
  {name:'Sita', phone:'+91 99887 76655', status:'moving'},
  {name:'Mohan', phone:'+91 90000 11111', status:'unknown'},
];
const AI_TIERS = [
  {id:'tiny', name:'Tiny (270M)', size:304, ram:'2-3 GB', loaded:false},
  {id:'small', name:'Small (1B)', size:584, ram:'3-4 GB', loaded:false},
  {id:'full', name:'Full (E2B)', size:2560, ram:'6 GB+', loaded:false},
];
let activeTier = null;
const GUIDES = [
  {en:'Check yourself and others for injuries. Do not move seriously injured people.', hi:'खुद और दूसरों को चोट के लिए जांचें। गंभीर रूप से घायल लोगों को न हिलाएं।'},
  {en:'If indoors, take cover under sturdy furniture. Stay away from windows.', hi:'अंदर हों तो मजबूत फर्नीचर के नीचे छिपें। खिड़कियों से दूर रहें।'},
  {en:'If outdoors, move to open area away from buildings, trees, power lines.', hi:'बाहर हों तो इमारतों, पेड़ों, बिजली लाइनों से दूर खुले स्थान पर जाएं।'},
  {en:'Turn off gas, electricity, water if safe to do so.', hi:'सुरक्षित हो तो गैस, बिजली, पानी बंद करें।'},
  {en:'Use stairs, not elevators.', hi:'लिफ्ट नहीं, सीढ़ियां इस्तेमाल करें।'},
  {en:'Listen to radio/official alerts. Do not spread rumors.', hi:'रेडियो/आधिकारिक अलर्ट सुनें। अफवाह न फैलाएं।'},
];

function openPanel(name, rerenderOnly){
  window._currentPanel = name;
  window._panel = true;
  const panel = document.getElementById('panel');
  const hi = hindi();
  if(name==='family'){
    panel.innerHTML = `<h4>${t('familyTitle')}</h4>` +
      familyMembers.map(m=>`<div class="contact-row"><div class="avatar">${m.name[0]}</div><div class="info"><div class="name">${m.name}</div><div class="phone">${m.phone}</div></div><span class="pill ${m.status==='safe'?'green':m.status==='needHelp'?'saffron':'grey'}">${m.status}</span></div>`).join('') +
      `<div class="btn-row"><button class="btn primary" onclick="importContactsDemo()">📥 Import from Contacts</button><button class="btn ghost" onclick="addFamilyDemo()">+ Add</button></div>`;
  } else if(name==='whereami'){
    const desc = `~1.2 km North-East of Clock Tower (Ghanta Ghar), Paltan Bazaar / Rajpur Road, Dehradun, Uttarakhand (30.32550° N, 78.04130° E ±5m)`;
    const radio = `MAYDAY/ALERT: My location is ~1.2 km North-East of Clock Tower, locality Paltan Bazaar, Dehradun, Uttarakhand. Coordinates: 30.32550 North, 78.04130 East (accuracy ±5 meters).`;
    panel.innerHTML = `<h4>${t('whereTitle')}</h4>
      <div class="survey-result">${desc}</div>
      <div style="margin-top:8px;font-size:11px;color:var(--grey)">${hi?'रेडियो स्क्रिप्ट:':'Radio Script:'}</div>
      <div class="survey-result">${radio}</div>
      <div class="btn-row">
        <button class="btn primary" onclick="copyText('${radio.replace(/'/g,"\\'")}')">Copy Script</button>
        <button class="btn ghost" onclick="speakText('${radio.replace(/'/g,"\\'")}')">🔊 Read Aloud</button>
      </div>`;
  } else if(name==='packs'){
    panel.innerHTML = `<h4>${t('packsTitle')}</h4>` +
      AI_TIERS.map(tier=>`<div class="ai-tier">
        <span class="status ${tier.loaded?'loaded':'unloaded'}">${tier.loaded?'LOADED':'UNLOADED'}</span>
        <div class="name">${tier.name}</div>
        <div class="meta">${tier.size} MB · ${tier.ram} RAM · ${tier.loaded?'On-device reasoning active':'0 MB RAM (rule mode)'}</div>
        <div class="btn-row">
          ${tier.loaded?`<button class="btn ghost" onclick="unloadTier('${tier.id}')">Unload</button>`:`<button class="btn primary" onclick="loadTier('${tier.id}')">Load</button>`}
          <button class="btn ghost" onclick="importTierDemo('${tier.id}')">📥 Import from Downloads</button>
          <button class="btn ghost" onclick="downloadTierDemo('${tier.id}')">⬇ Download</button>
        </div>
      </div>`).join('') +
      `<p style="color:var(--grey);font-size:11px;margin-top:8px">Storage scan: found ${AI_TIERS.length} candidate tier(s). Import copies .litertlm from /sdcard/Download into app storage.</p>`;
  } else if(name==='emergency'){
    panel.innerHTML = `<h4>${t('emergencyTitle')}</h4><p style="color:var(--grey);font-size:11px;margin-bottom:8px">${t('emergencySub')}</p>
      <div class="emergency-list">
        ${EMERGENCY.map(e=>`<div class="emergency-card">
          <div><div class="name">${e.icon} ${hi?e.nameHi:e.name}</div><div class="desc">${hi?e.descHi:e.desc}</div></div>
          <div style="display:flex;align-items:center;gap:8px"><span class="num">${e.phone}</span>
          <button onclick="dialNumber('${e.phone}')">Call</button></div>
        </div>`).join('')}
      </div>`;
  } else if(name==='survey'){
    panel.innerHTML = `<h4>${t('surveyTitle')}</h4>
      <div class="form-grid">
        <div><label>Structure type</label><select id="sType"><option>House</option><option>Shop</option><option>School</option><option>Bridge</option></select></div>
        <div><label>Damage severity</label><select id="sSev"><option>Minor</option><option>Partial</option><option>Severe</option><option>Destroyed</option></select></div>
        <div><label>Flood water mark (m)</label><input id="sWater" type="number" step="0.1" value="0.5"></div>
        <div><label>Habitable?</label><select id="sHab"><option>Yes</option><option>No</option></select></div>
      </div>
      <div class="btn-row">
        <button class="btn primary" onclick="submitSurvey()">Save & Export CSV</button>
      </div>
      <div id="surveyOut" class="survey-result" style="display:none"></div>`;
  } else if(name==='guides'){
    panel.innerHTML = `<h4>${t('guidesTitle')}</h4>` + GUIDES.map(g=>`<div style="padding:8px 0;border-bottom:1px solid var(--surface-light);font-size:13px;color:var(--white)">• ${hi?g.hi:g.en}</div>`).join('');
  }
}
function importContactsDemo(){
  const newOnes = [{name:'Priya Sharma',phone:'+91 98123 45678'},{name:'Vikram Singh',phone:'+91 97000 12345'}];
  newOnes.forEach(n=>familyMembers.push({name:n.name,phone:n.phone,status:'unknown'}));
  openPanel('family'); toast('Imported 2 contacts (demo)');
}
function addFamilyDemo(){ const name=prompt('Name'); if(!name) return; const phone=prompt('Phone'); if(!phone) return; familyMembers.push({name,phone,status:'unknown'}); openPanel('family'); toast('Added'); }
function loadTier(id){
  const tier = AI_TIERS.find(t=>t.id===id);
  // unload others
  AI_TIERS.forEach(t=>t.loaded=false);
  tier.loaded=true; activeTier=tier.id;
  openPanel('packs'); toast(tier.name+' loaded (demo)');
}
function unloadTier(id){
  const tier = AI_TIERS.find(t=>t.id===id);
  tier.loaded=false; activeTier=null;
  openPanel('packs'); toast('AI unloaded — 0 MB RAM (demo)');
}
function importTierDemo(id){ toast('Imported from /sdcard/Download (demo)'); }
function downloadTierDemo(id){ toast('Download started (demo)'); }
function dialNumber(phone){
  const clean = phone.replace(/[^\d+]/g,'');
  window.location.href = 'tel:'+clean;
  toast('Opening dialer: '+clean);
}
function copyText(text){ navigator.clipboard.writeText(text).then(()=>toast('Copied')).catch(()=>toast('Copy failed')); }
function speakText(text){
  if(!('speechSynthesis' in window)){ toast('TTS not supported'); return; }
  const u = new SpeechSynthesisUtterance(text);
  u.lang = hindi() ? 'hi-IN' : 'en-US';
  speechSynthesis.cancel(); speechSynthesis.speak(u);
  toast('Speaking...');
}
function submitSurvey(){
  const type=document.getElementById('sType').value;
  const sev=document.getElementById('sSev').value;
  const water=document.getElementById('sWater').value;
  const hab=document.getElementById('sHab').value;
  const csv = `type,severity,waterMarkMeters,habitable,timestamp\n${type},${sev},${water},${hab},${new Date().toISOString()}`;
  const out=document.getElementById('surveyOut');
  out.style.display='block';
  out.textContent = csv;
  toast('Survey saved (demo)');
}

// HUD init
document.getElementById('hudCoord').textContent = gps.lat.toFixed(4)+', '+gps.lon.toFixed(4);
applyI18n();
showTab('home');
drawMap();
// record trail automatically for demo
setInterval(()=>{ if(backtracking){ trail.push({lat:gps.lat+(Math.random()-0.5)*0.0005, lon:gps.lon+(Math.random()-0.5)*0.0005}); if(trail.length>100) trail.shift(); drawMap(); } }, 2000);
