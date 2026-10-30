<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>AWS SAP-C02 study notes · Trác Việt</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Roboto:ital,wght@0,400;0,500;0,700;1,400&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
:root{
  --blue:#0972d3; --blue-d:#075aa6; --navbg:#232f3e;
  --bg:#ffffff; --side:#fafbfc; --ink:#202124; --muted:#5f6368; --line:#e1e4e8;
  --link:#0972d3; --code:#f3f5f8; --codeink:#1f2933;
  --note:#e8f0fe; --note-b:#326ce5; --tip:#e6f4ea; --tip-b:#1e8e3e; --warn:#fff4e5; --warn-b:#e37400;
  --font:"Roboto",system-ui,-apple-system,"Segoe UI",Arial,sans-serif;
  --mono:"Roboto Mono",ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
  box-sizing:border-box;
  padding-top:env(safe-area-inset-top,0px); padding-bottom:env(safe-area-inset-bottom,0px);
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --navbg:#161e2a; --bg:#0f141b; --side:#0f141b; --ink:#e4e8ee; --muted:#9aa5b1; --line:#252f3c;
    --link:#8ab0ff; --code:#171f2a; --codeink:#dbe4ee;
    --note:#14233f; --note-b:#5b8cf0; --tip:#10261a; --tip-b:#3fb860; --warn:#2b200f; --warn-b:#f0a03c; color-scheme:dark;
  }
}
:root[data-theme="dark"]{
  --navbg:#161e2a; --bg:#0f141b; --side:#0f141b; --ink:#e4e8ee; --muted:#9aa5b1; --line:#252f3c;
  --link:#8ab0ff; --code:#171f2a; --codeink:#dbe4ee;
  --note:#14233f; --note-b:#5b8cf0; --tip:#10261a; --tip-b:#3fb860; --warn:#2b200f; --warn-b:#f0a03c; color-scheme:dark;
}
html{height:100%;scroll-padding-top:calc(env(safe-area-inset-top,0px) + 72px)}
*{box-sizing:border-box}
body{margin:0;min-height:100%;background:var(--bg);color:var(--ink);font-family:var(--font);font-size:16px;line-height:1.65}
body::before{content:"";position:fixed;inset:0 0 auto;height:env(safe-area-inset-top,0px);background:var(--navbg);z-index:40}
a{color:var(--link)}
:focus-visible{outline:2px solid var(--blue);outline-offset:2px;border-radius:3px}

/* navbar */
.nav{position:sticky;top:env(safe-area-inset-top,0px);z-index:30;height:56px;background:var(--navbg);color:#fff;
  display:flex;align-items:center;gap:18px;padding:0 20px}
.brand{display:flex;align-items:center;gap:10px;color:#fff;text-decoration:none;font-weight:500;font-size:18px;white-space:nowrap}
.brand svg{width:34px;height:34px;flex:none}
.nav .links{display:flex;gap:18px;font-size:14px}
.nav .links a{color:#fff;text-decoration:none;opacity:.9}
.nav .links a:hover{opacity:1;text-decoration:underline}
.nav .sp{flex:1}
.search{position:relative;width:260px;max-width:40vw}
.search input{width:100%;height:34px;border:0;border-radius:4px;padding:0 12px;font:inherit;font-size:14px;
  background:rgba(255,255,255,.18);color:#fff}
.search input::placeholder{color:rgba(255,255,255,.8)}
.search input:focus{background:#fff;color:#202124;outline:2px solid #fff}
.search input:focus::placeholder{color:#6b7280}
.ibtn{background:transparent;border:1px solid rgba(255,255,255,.45);color:#fff;border-radius:4px;height:32px;padding:0 10px;
  font:inherit;font-size:13px;cursor:pointer}
.ibtn:hover{background:rgba(255,255,255,.14)}
#burger{display:none;font-size:18px;padding:0 10px}

/* layout */
.shell{display:grid;grid-template-columns:290px minmax(0,1fr) 240px;max-width:1500px;margin:0 auto}
aside#side{position:sticky;top:calc(56px + env(safe-area-inset-top,0px));align-self:start;
  height:calc(100vh - 56px - env(safe-area-inset-top,0px));overflow-y:auto;background:var(--side);
  border-right:1px solid var(--line);padding:16px 12px 40px}
.prog{font-size:13px;color:var(--muted);margin:0 8px 12px}
.prog i{display:block;height:4px;background:var(--line);border-radius:2px;margin-top:6px;overflow:hidden}
.prog i b{display:block;height:100%;background:var(--blue);width:0}
.grp h3{font-size:12px;font-weight:700;color:var(--muted);margin:16px 8px 4px;letter-spacing:.02em}
#side a{display:flex;align-items:center;gap:8px;padding:6px 10px;border-radius:4px;color:var(--ink);text-decoration:none;font-size:14px;line-height:1.35}
#side a:hover{background:var(--code)}
#side a.on{color:var(--blue);background:var(--note);font-weight:500}
#side a.read::after{content:"✓";margin-left:auto;color:var(--tip-b);font-size:12px}
.none{display:none;margin:16px 8px;font-size:14px;color:var(--muted)}
#side a.by{margin:24px 4px 0;padding:10px 12px;border:1px solid var(--line);border-radius:8px;gap:10px;color:var(--ink)}
#side a.by:hover{border-color:var(--blue);background:transparent}
#side a.by span{display:flex;flex-direction:column;line-height:1.25}
#side a.by small{color:var(--muted);font-size:12px}

main{padding:28px 44px 80px;min-width:0}
.crumb{font-size:13px;color:var(--muted);margin-bottom:6px}
.page h1{font-size:34px;font-weight:500;line-height:1.2;margin:0 0 14px}
.lead{font-size:18px;color:var(--muted);margin:0 0 8px;max-width:70ch}
.page h2{font-size:24px;font-weight:500;margin:40px 0 10px;padding-bottom:6px;border-bottom:1px solid var(--line)}
.page h3{font-size:18px;font-weight:500;margin:26px 0 6px}
.page p,.page li{max-width:76ch}
.page ul,.page ol{padding-left:24px}
.page li{margin:3px 0}
code{font-family:var(--mono);font-size:.86em;background:var(--code);color:var(--codeink);padding:2px 5px;border-radius:3px}
pre{position:relative;background:var(--code);border:1px solid var(--line);border-radius:6px;padding:14px 16px;overflow-x:auto;margin:14px 0;line-height:1.5}
pre code{background:none;padding:0;font-size:13px;white-space:pre}
.copy{position:absolute;top:6px;right:6px;font:inherit;font-size:12px;background:var(--bg);color:var(--muted);border:1px solid var(--line);
  border-radius:4px;padding:2px 8px;cursor:pointer}
.copy:hover{color:var(--ink)}
.tw{overflow-x:auto;margin:14px 0}
table{border-collapse:collapse;width:100%;font-size:14.5px;min-width:520px}
th,td{border:1px solid var(--line);padding:8px 12px;text-align:left;vertical-align:top}
th{background:var(--code);font-weight:500}
.callout{border-left:4px solid var(--note-b);background:var(--note);padding:10px 16px;margin:18px 0;border-radius:0 6px 6px 0;max-width:76ch}
.callout p{margin:4px 0}
.callout>b:first-child{display:block;margin-bottom:2px}
.callout.tip{background:var(--tip);border-color:var(--tip-b)}
.callout.warn{background:var(--warn);border-color:var(--warn-b)}
.dg{width:100%;height:auto;margin:16px 0;border:1px solid var(--line);border-radius:6px;background:var(--bg)}
.dg .box{fill:var(--bg);stroke:var(--blue);stroke-width:1.5}
.dg .zone{fill:var(--code);stroke:var(--line);stroke-width:1.5}
.dg .pod{fill:var(--note);stroke:var(--note-b);stroke-width:1}
.dg text{fill:var(--ink);font-family:var(--font);font-size:13px}
.dg .zt{font-weight:700;font-size:13px}
.dg .ln{stroke:var(--blue);stroke-width:1.5;fill:none}
.dg .dash{stroke-dasharray:5 4}

.mark{display:flex;align-items:center;gap:10px;margin:40px 0 0;padding-top:20px;border-top:1px solid var(--line)}
.mark button{font:inherit;font-size:14px;border:1px solid var(--blue);color:var(--blue);background:transparent;border-radius:4px;padding:6px 14px;cursor:pointer}
.mark button[aria-pressed="true"]{background:var(--blue);color:#fff}
.pn{display:flex;justify-content:space-between;gap:12px;margin-top:20px}
.pn a{display:block;border:1px solid var(--line);border-radius:6px;padding:10px 16px;text-decoration:none;color:var(--ink);max-width:48%}
.pn a:hover{border-color:var(--blue)}
.pn small{display:block;color:var(--muted);font-size:12px}
.pn a:last-child{text-align:right;margin-left:auto}

nav#toc{position:sticky;top:calc(56px + env(safe-area-inset-top,0px));align-self:start;
  max-height:calc(100vh - 56px - env(safe-area-inset-top,0px));overflow-y:auto;padding:28px 16px 40px 0;font-size:13.5px}
#toc h4{margin:0 0 8px;font-size:12px;color:var(--muted);font-weight:700}
#toc a{display:block;padding:3px 0 3px 12px;border-left:2px solid var(--line);color:var(--muted);text-decoration:none;line-height:1.4}
#toc a.l3{padding-left:26px}
#toc a:hover{color:var(--ink)}
#toc a.on{color:var(--blue);border-left-color:var(--blue);font-weight:500}
footer{border-top:1px solid var(--line);margin-top:48px;padding-top:16px;font-size:13px;color:var(--muted)}
#scrim{display:none}

@media (max-width:1100px){.shell{grid-template-columns:270px minmax(0,1fr)}nav#toc{display:none}}
@media (max-width:820px){
  .shell{grid-template-columns:1fr}
  .nav .links{display:none}
  #burger{display:inline-block}
  .brand span{font-size:16px}
  aside#side{position:fixed;left:0;bottom:0;top:calc(56px + env(safe-area-inset-top,0px));height:auto;width:300px;max-width:86vw;z-index:25;
    transform:translateX(-102%);transition:transform .2s}
  aside#side.open{transform:none}
  #scrim.open{display:block;position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:20}
  main{padding:20px 16px 64px}
  .page h1{font-size:28px}
  .search{width:auto;flex:1;max-width:none}
  .sp{display:none}
}
@media (prefers-reduced-motion:reduce){aside#side{transition:none}}

.nav{border-bottom:3px solid #ff9900}
.mk{background:#ff9900;color:#232f3e;font-weight:700;font-size:13px;padding:4px 8px;border-radius:4px;letter-spacing:.02em}
.brand{gap:10px}
/* quiz */
.qsum{display:flex;flex-wrap:wrap;align-items:center;gap:10px 16px;margin:16px 0 8px;padding:12px 16px;border:1px solid var(--line);border-radius:8px;background:var(--code)}
.qsum b{font-weight:500}.qsum button{font:inherit;font-size:13px;padding:4px 12px;border:1px solid var(--line);border-radius:4px;background:var(--bg);color:var(--ink);cursor:pointer;margin-left:auto}
.qs{border:1px solid var(--line);border-radius:8px;padding:18px 20px;margin:16px 0;background:var(--bg)}
.qs.right{border-color:var(--tip-b)}.qs.wrong{border-color:#d13212}
.qn{margin:0 0 6px;font-size:13px;color:var(--muted);font-weight:500}
.qt{margin:0 0 12px;max-width:80ch}
.qo{list-style:none;margin:0 0 10px;padding:0}
.qo li{margin:6px 0;max-width:80ch}
.qo label{display:flex;gap:10px;align-items:flex-start;padding:8px 12px;border:1px solid var(--line);border-radius:6px;cursor:pointer}
.qo label:hover{border-color:var(--blue)}
.qo input{margin-top:5px;accent-color:var(--blue)}
.qo li.ok label{border-color:var(--tip-b);background:var(--tip)}
.qo li.bad label{border-color:#d13212;background:rgba(209,50,18,.1)}
.qo li.miss label{border-color:var(--tip-b);border-style:dashed}
.qh{margin:0 0 10px;font-size:13px;color:var(--muted)}
.qb{font:inherit;font-size:14px;padding:7px 18px;border:0;border-radius:4px;background:var(--blue);color:#fff;cursor:pointer}
.qb:disabled{opacity:.5;cursor:default}
.qe{margin-top:14px;padding:12px 16px;border-left:4px solid var(--note-b);background:var(--note);border-radius:0 6px 6px 0;max-width:80ch}
.qe b.v{display:block;margin-bottom:4px}
</style>
</head>
<body>

<header class="nav">
  <button class="ibtn" id="burger" aria-label="Mở mục lục">☰</button>
  <a class="brand" href="#overview" aria-label="AWS SAP-C02 study notes"><span class="mk">AWS</span><span>SAP-C02 <span style="font-weight:400;opacity:.85">study notes</span></span></a>
  <nav class="links" aria-label="Liên kết nhanh">
    <a href="https://tracviethustcs.github.io/">← Trác Việt</a>
    <a href="#d1-accounts">Domain 1</a>
    <a href="#d2-compute">Domain 2</a>
    <a href="#d3-ops">Domain 3</a>
    <a href="#d4-migration">Domain 4</a>
    <a href="#quiz-d1">Luyện đề</a>
  </nav>
  <span class="sp"></span>
  <div class="search"><input id="q" type="search" placeholder="Tìm trong ghi chú  ( / )" aria-label="Tìm trong ghi chú"></div>
  <button class="ibtn" id="theme" aria-label="Đổi giao diện sáng/tối">Sáng/Tối</button>
</header>
<div id="scrim"></div>

<div class="shell">
  <aside id="side" aria-label="Mục lục">
    <a href="https://tracviethustcs.github.io/" style="margin:0 0 10px;font-weight:500;color:var(--blue)">← Tất cả tài liệu</a>
    <div class="prog"><span id="progtxt"></span><i><b id="progbar"></b></i></div>
    <div id="side-links"></div>
    <p class="none" id="none">Không có trang nào khớp từ khóa.</p>
    <a class="by" href="https://github.com/TracVietHustCS" target="_blank" rel="noopener">
      <svg viewBox="0 0 16 16" width="20" height="20" aria-hidden="true"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.5 7.5 0 0 1 4 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
      <span><b>TracViet</b><small>@TracVietHustCS</small></span>
    </a>
  </aside>

  <main id="main">

<!-- ============ OVERVIEW ============ -->
