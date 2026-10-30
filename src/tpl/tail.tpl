

    <footer>
      <p style="margin:0 0 8px"><a href="https://tracviethustcs.github.io/">← Về trang chủ Trác Việt</a></p>
      <p style="margin:0 0 8px"><b style="color:var(--ink)">Soạn bởi Trác Việt</b> (<a href="https://github.com/TracVietHustCS" target="_blank" rel="noopener">@TracVietHustCS</a>)</p>
      Ghi chú tự soạn để ôn thi, <b>không phải tài liệu chính thức của AWS</b> và không bảo đảm đậu. Đề thi, trọng số, giới hạn và tên dịch vụ thay đổi theo thời gian, luôn đối chiếu với exam guide hiện hành và tài liệu AWS. AWS và các tên dịch vụ là nhãn hiệu của Amazon.com, Inc.
    </footer>
  </main>

  <nav id="toc" aria-label="Trong trang này"></nav>
</div>

<script>
const $=(s,r=document)=>r.querySelector(s), $$=(s,r=document)=>[...r.querySelectorAll(s)];
const pages=$$('.page');
const index=pages.map(p=>p.textContent.toLowerCase());
let read={};
try{read=JSON.parse(localStorage.getItem('sap-read')||'{}')}catch(e){}
const saveRead=()=>{try{localStorage.setItem('sap-read',JSON.stringify(read))}catch(e){}};

/* sidebar */
const groups=[];
pages.forEach(p=>{
  let g=groups.find(x=>x.name===p.dataset.group);
  if(!g){g={name:p.dataset.group,items:[]};groups.push(g)}
  g.items.push(p);
});
let current='overview';
function buildNav(){
  $('#side-links').innerHTML=groups.map(g=>`<div class="grp"><h3>${g.name}</h3>${g.items.map(p=>
    `<a href="#${p.dataset.id}" data-id="${p.dataset.id}" class="${read[p.dataset.id]?'read':''}">${p.dataset.title}</a>`).join('')}</div>`).join('');
  const n=Object.values(read).filter(Boolean).length;
  $('#progtxt').textContent=`Đã đọc ${n}/${pages.length} trang`;
  $('#progbar').style.width=(n/pages.length*100)+'%';
  $$('#side-links a').forEach(a=>a.classList.toggle('on',a.dataset.id===current));
  applyFilter();
}

/* pages */
function show(id){
  const page=pages.find(p=>p.dataset.id===id)||pages[0];
  current=page.dataset.id;
  pages.forEach(p=>p.hidden=(p!==page));
  if(!$('.crumb',page)){
    const c=document.createElement('div');c.className='crumb';
    c.textContent=page.dataset.group+'  ›  '+page.dataset.title;
    page.prepend(c);
  }
  $$('pre',page).forEach(pre=>{
    if($('.copy',pre))return;
    const b=document.createElement('button');b.className='copy';b.type='button';b.textContent='Sao chép';
    b.addEventListener('click',()=>copyCode(pre,b));
    pre.appendChild(b);
  });
  $$('.mark,.pn',page).forEach(e=>e.remove());
  const m=document.createElement('div');m.className='mark';
  m.innerHTML=`<button type="button" aria-pressed="${!!read[current]}">${read[current]?'Đã đọc ✓':'Đánh dấu đã đọc'}</button>`;
  m.firstChild.addEventListener('click',e=>{
    read[current]=!read[current];saveRead();
    e.currentTarget.setAttribute('aria-pressed',!!read[current]);
    e.currentTarget.textContent=read[current]?'Đã đọc ✓':'Đánh dấu đã đọc';
    buildNav();
  });
  page.appendChild(m);
  const i=pages.indexOf(page),prev=pages[i-1],next=pages[i+1];
  const pn=document.createElement('div');pn.className='pn';
  pn.innerHTML=(prev?`<a href="#${prev.dataset.id}"><small>Trước</small>${prev.dataset.title}</a>`:'<span></span>')+
               (next?`<a href="#${next.dataset.id}"><small>Tiếp theo</small>${next.dataset.title}</a>`:'');
  page.appendChild(pn);

  document.title=page.dataset.title+' · AWS SAP-C02 notes';
  buildNav();initQuiz(page);buildToc(page);
  window.scrollTo(0,0);
  closeSide();
}
function copyCode(pre,btn){
  const text=$('code',pre).innerText;
  const done=()=>{btn.textContent='Đã chép';setTimeout(()=>btn.textContent='Sao chép',1400)};
  const fallback=()=>{
    try{const r=document.createRange();r.selectNodeContents($('code',pre));
      const s=getSelection();s.removeAllRanges();s.addRange(r);document.execCommand('copy');s.removeAllRanges();done();}
    catch(e){btn.textContent='Không chép được'}
  };
  try{navigator.clipboard.writeText(text).then(done,fallback)}catch(e){fallback()}
}

/* on this page */
let tocItems=[];
function buildToc(page){
  const hs=$$('h2,h3',page);
  tocItems=hs.map((h,i)=>{h.id=`${current}-h${i}`;return {h,a:null}});
  $('#toc').innerHTML='<h4>Trong trang này</h4>'+hs.map((h,i)=>`<a href="#" class="${h.tagName==='H3'?'l3':''}" data-i="${i}">${h.textContent}</a>`).join('');
  $$('#toc a').forEach(a=>{
    tocItems[+a.dataset.i].a=a;
    a.addEventListener('click',e=>{e.preventDefault();tocItems[+a.dataset.i].h.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'})});
  });
  spy();
}
function spy(){
  if(!tocItems.length)return;
  let cur=0;
  tocItems.forEach((t,i)=>{if(t.h.getBoundingClientRect().top<110)cur=i});
  tocItems.forEach((t,i)=>t.a&&t.a.classList.toggle('on',i===cur));
}
addEventListener('scroll',spy,{passive:true});

/* search */
function applyFilter(){
  const q=$('#q').value.trim().toLowerCase();
  let any=false;
  $$('.grp').forEach(g=>{
    let vis=false;
    $$('a',g).forEach(a=>{
      const i=pages.findIndex(p=>p.dataset.id===a.dataset.id);
      const hit=!q||index[i].includes(q)||a.textContent.toLowerCase().includes(q);
      a.style.display=hit?'':'none'; if(hit)vis=true;
    });
    g.style.display=vis?'':'none'; if(vis)any=true;
  });
  $('#none').style.display=any?'none':'block';
}
$('#q').addEventListener('input',()=>{ if(innerWidth<=820)openSide(); applyFilter(); });
$('#q').addEventListener('keydown',e=>{
  if(e.key==='Enter'){const a=$$('#side-links a').find(x=>x.style.display!=='none');if(a){location.hash=a.dataset.id;}}
});
addEventListener('keydown',e=>{
  if(e.key==='/'&&!/input|textarea/i.test(document.activeElement.tagName)){e.preventDefault();$('#q').focus()}
});

/* mobile sidebar */
function openSide(){$('#side').classList.add('open');$('#scrim').classList.add('open')}
function closeSide(){$('#side').classList.remove('open');$('#scrim').classList.remove('open')}
$('#burger').addEventListener('click',()=>$('#side').classList.contains('open')?closeSide():openSide());
$('#scrim').addEventListener('click',closeSide);

/* theme */
const root=document.documentElement;
try{const t=localStorage.getItem('sap-theme');if(t)root.dataset.theme=t}catch(e){}
$('#theme').addEventListener('click',()=>{
  const dark=root.dataset.theme?root.dataset.theme==='dark':matchMedia('(prefers-color-scheme:dark)').matches;
  root.dataset.theme=dark?'light':'dark';
  try{localStorage.setItem('sap-theme',root.dataset.theme)}catch(e){}
});


/* ===== quiz engine ===== */
const qesc=s=>String(s).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c])).replace(/`([^`]+)`/g,'<code>$1</code>');
function initQuiz(page){
  const box=$('.quiz',page); if(!box||box.dataset.ready) return;
  box.dataset.ready='1';
  const data=JSON.parse($('script.qj',page).textContent);
  const key='sap-quiz-'+page.dataset.id;
  let st={}; try{st=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}
  const sum=document.createElement('div'); sum.className='qsum';
  box.appendChild(sum);
  const list=document.createElement('div'); box.appendChild(list);
  const upd=()=>{
    const done=Object.keys(st).length, ok=Object.values(st).filter(Boolean).length;
    sum.innerHTML=`<span>Đã làm <b>${done}/${data.length}</b></span><span>Đúng <b>${ok}</b></span><span>${done?Math.round(ok/done*100)+'%':''}</span><button type="button">Làm lại</button>`;
    $('button',sum).onclick=()=>{st={};try{localStorage.removeItem(key)}catch(e){};box.dataset.ready='';box.innerHTML='';initQuiz(page)};
  };
  data.forEach((d,i)=>{
    const multi=d.a.length>1;
    const q=document.createElement('div'); q.className='qs';
    q.innerHTML=`<p class="qn">Câu ${i+1}</p><p class="qt">${qesc(d.q)}</p><ul class="qo">`+
      d.o.map((t,j)=>`<li><label><input type="${multi?'checkbox':'radio'}" name="q${i}" value="${j}"><span>${qesc(t)}</span></label></li>`).join('')+
      `</ul>${multi?`<p class="qh">Chọn ${d.a.length} đáp án</p>`:''}<button class="qb" type="button">Kiểm tra</button><div class="qe" hidden></div>`;
    list.appendChild(q);
    const btn=$('.qb',q), ex=$('.qe',q);
    const finish=(picked,ok)=>{
      q.classList.add(ok?'right':'wrong');
      $$('li',q).forEach((li,j)=>{
        const inp=$('input',li); inp.disabled=true;
        if(d.a.includes(j)) li.classList.add(picked.includes(j)?'ok':'miss');
        else if(picked.includes(j)) li.classList.add('bad');
      });
      ex.hidden=false; btn.disabled=true;
      ex.innerHTML=`<b class="v">${ok?'Đúng.':'Chưa đúng.'} Đáp án: ${d.a.map(j=>String.fromCharCode(65+j)).join(', ')}</b>${qesc(d.e)}`;
    };
    if(i in st){ // restore state
      $$('input',q).forEach((inp,j)=>{ if(d.a.includes(j)&&st[i]) inp.checked=true; });
      finish(st[i]?d.a:[],st[i]);
    }
    btn.onclick=()=>{
      const picked=$$('input:checked',q).map(x=>+x.value);
      if(!picked.length){ex.hidden=false;ex.textContent='Hãy chọn đáp án trước.';return}
      const ok=picked.length===d.a.length&&d.a.every(x=>picked.includes(x));
      st[i]=ok; try{localStorage.setItem(key,JSON.stringify(st))}catch(e){}
      finish(picked,ok); upd();
    };
  });
  upd();
}

/* routing: only a plain #page-id is used in the hash */
addEventListener('hashchange',()=>show(location.hash.slice(1)));
show(location.hash.slice(1));
</script>
</body>
</html>
