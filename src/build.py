#!/usr/bin/env python3
import re, json, glob, html, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------- inline ----------
def inline(s):
    codes = []
    def keep(m):
        codes.append(m.group(1)); return '\x00%d\x00' % (len(codes) - 1)
    s = re.sub(r'`([^`]+)`', keep, s)
    s = html.escape(s, quote=False)
    s = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)', lambda m: '<a href="%s"%s>%s</a>' % (
        m.group(2), '' if m.group(2).startswith('#') else ' target="_blank" rel="noopener"', m.group(1)), s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', s)
    s = re.sub(r'(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])', r'<i>\1</i>', s)
    s = re.sub(r'\x00(\d+)\x00', lambda m: '<code>%s</code>' % html.escape(codes[int(m.group(1))], quote=False), s)
    return s

def pre(code, cls=''):
    lines = code.rstrip('\n').split('\n')
    out = []
    for ln in lines:
        e = html.escape(ln, quote=False)
        if ln.startswith('$ '):
            e = '<span class="ps">$ </span>' + e[2:]
        elif ln.startswith('#'):
            e = '<span class="cm">' + e + '</span>'
        out.append(e)
    return '<pre%s><code>%s</code></pre>' % (' class="%s"' % cls if cls else '', '\n'.join(out))

# ---------- blocks ----------
def blocks(text):
    lines = text.split('\n')
    out = []; i = 0; para = []
    def flush():
        nonlocal para
        if para:
            out.append('<p>%s</p>' % inline(' '.join(para))); para = []
    while i < len(lines):
        ln = lines[i]
        if ln.startswith('```'):
            flush()
            cls = ln[3:].strip(); buf = []; i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                buf.append(lines[i]); i += 1
            out.append(pre('\n'.join(buf), cls)); i += 1; continue
        if ln.startswith('::: '):
            flush()
            parts = ln[4:].split(' ', 1); typ = parts[0]; title = parts[1] if len(parts) > 1 else ''
            buf = []; i += 1
            while i < len(lines) and lines[i].strip() != ':::':
                buf.append(lines[i]); i += 1
            i += 1
            out.append('<div class="callout %s"><b>%s</b>%s</div>' % (typ, inline(title), blocks('\n'.join(buf))))
            continue
        if ln.startswith('### '):
            flush(); out.append('<h3>%s</h3>' % inline(ln[4:])); i += 1; continue
        if ln.startswith('## '):
            flush(); out.append('<h2>%s</h2>' % inline(ln[3:])); i += 1; continue
        if ln.startswith('|'):
            flush(); rows = []
            while i < len(lines) and lines[i].startswith('|'):
                rows.append(lines[i]); i += 1
            rows = [r for r in rows if not re.match(r'^\|[\s:|-]+\|?$', r)]
            def cells(r):
                r = r.strip().replace('\\|', '\x01')
                if r.endswith('|'): r = r[:-1]
                return [c.strip().replace('\x01', '|') for c in r[1:].split('|')]
            hd = cells(rows[0])
            for rr in rows[1:]:
                assert len(cells(rr)) == len(hd), 'table column mismatch: %s' % rr[:80]
            t = '<div class="tw"><table><tr>%s</tr>' % ''.join('<th>%s</th>' % inline(c) for c in hd)
            for r in rows[1:]:
                t += '<tr>%s</tr>' % ''.join('<td>%s</td>' % inline(c) for c in cells(r))
            out.append(t + '</table></div>'); continue
        if re.match(r'^- ', ln):
            flush(); items = []
            while i < len(lines) and re.match(r'^- ', lines[i]):
                items.append(lines[i][2:]); i += 1
            out.append('<ul>%s</ul>' % ''.join('<li>%s</li>' % inline(x) for x in items)); continue
        if re.match(r'^\d+\. ', ln):
            flush(); items = []
            while i < len(lines) and re.match(r'^\d+\. ', lines[i]):
                items.append(re.sub(r'^\d+\. ', '', lines[i])); i += 1
            out.append('<ol>%s</ol>' % ''.join('<li>%s</li>' % inline(x) for x in items)); continue
        if ln.startswith('>> '):
            flush(); out.append('<p class="lead">%s</p>' % inline(ln[3:])); i += 1; continue
        if ln.strip() == '':
            flush(); i += 1; continue
        para.append(ln.strip()); i += 1
    flush()
    return '\n'.join(out)

def quiz(body):
    qs = []; cur = None
    for ln in body.split('\n'):
        if ln.startswith('Q: '):
            cur = {'q': ln[3:], 'o': [], 'a': [], 'e': ''}; qs.append(cur)
        elif ln.startswith('+ ') or ln.startswith('- '):
            if ln[0] == '+': cur['a'].append(len(cur['o']))
            cur['o'].append(ln[2:])
        elif ln.startswith('E: '):
            cur['e'] = ln[3:]
    import random
    for q in qs:
        r = random.Random(q['q'])
        order = list(range(len(q['o']))); r.shuffle(order)
        q['o'] = [q['o'][i] for i in order]
        q['a'] = sorted(order.index(a) for a in q['a'])
    for q in qs:
        assert q['a'], q['q']
        assert 3 <= len(q['o']) <= 6, q['q']
    js = json.dumps(qs, ensure_ascii=False).replace('</', '<\\/')
    return '<div class="quiz"></div>\n<script type="application/json" class="qj">%s</script>' % js


# ---------- site assembly (config in site.json) ----------
CFG = json.load(open(os.path.join(HERE, 'site.json'), encoding='utf-8'))
OUT = os.environ.get('SITE_OUT') or os.path.normpath(os.path.join(HERE, CFG.get('out', '../index.html')))

def load_pages():
    pages = []
    for f in sorted(glob.glob(os.path.join(HERE, 'content', '*.md'))):
        txt = open(f, encoding='utf-8').read()
        for chunk in re.split(r'^=== ', txt, flags=re.M)[1:]:
            head_, _, body = chunk.partition('\n')
            pid, grp, title = [x.strip() for x in head_.split('|', 2)]
            if re.search(r'^@quiz\s*$', body, flags=re.M):
                parts = re.split(r'^@quiz\s*$', body, maxsplit=1, flags=re.M)
                body_h = blocks(parts[0]) + '\n' + quiz(parts[1])
            else:
                body_h = blocks(body)
            pages.append((pid, grp, title, body_h))
    return pages

def article(p):
    pid, grp, title, body = p
    return '<article class="page" data-id="%s" data-group="%s" data-title="%s" hidden>\n<h1>%s</h1>\n%s\n</article>' % (
        pid, html.escape(grp), html.escape(title), html.escape(title), body)

tpl = os.path.join(HERE, 'tpl')
head = open(os.path.join(tpl, 'head.tpl'), encoding='utf-8').read()
tail = open(os.path.join(tpl, 'tail.tpl'), encoding='utf-8').read()
C = CFG['colors']

head = head.replace('AWS SAP-C02 study notes · Trác Việt', html.escape(CFG['html_title'], quote=False))
head = re.sub(r'family=Roboto:[^"]*"', 'family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&family=IBM+Plex+Mono:wght@400;500&display=swap"', head, count=1)
head = head.replace('--font:"Roboto",', '--font:"IBM Plex Sans",').replace('--mono:"Roboto Mono",', '--mono:"IBM Plex Mono",')
head = head.replace('.nav{border-bottom:3px solid #ff9900}', '.nav{border-bottom:3px solid %s}' % C['mark'])
head = head.replace('.mk{background:#ff9900;color:#232f3e;', '.mk{background:%s;color:%s;font-family:var(--mono);' % (C['mark'], C['mark_ink']))

links = ''.join('\n    <a href="%s">%s</a>' % (h, l) for l, h in CFG['nav'])
nav = """<header class="nav">
  <button class="ibtn" id="burger" aria-label="Mở mục lục">☰</button>
  <a class="brand" href="#overview" aria-label="%s"><span class="mk">%s</span><span>%s <span style="font-weight:400;opacity:.85">%s</span></span></a>
  <nav class="links" aria-label="Liên kết nhanh">
    <a href="%s">← Trác Việt</a>%s
  </nav>
  <span class="sp"></span>
  <div class="search"><input id="q" type="search" placeholder="Tìm trong ghi chú  ( / )" aria-label="Tìm trong ghi chú"></div>
  <button class="ibtn" id="theme" aria-label="Đổi giao diện sáng/tối">Sáng/Tối</button>
</header>""" % (html.escape(CFG['brand_aria'], quote=True), html.escape(CFG['mk']), html.escape(CFG['brand_text'][0]), html.escape(CFG['brand_text'][1]), CFG['home_url'], links)
i = head.find('<header class="nav">'); j = head.find('</header>') + 9
head = head[:i] + nav + head[j:]

override = """
/* ===== site theme ===== */
:root{--blue:%(acc)s;--blue-d:%(acc_d)s;--onacc:#fff;--navbg:%(navbg)s;--bg:#fcfcfd;--side:#f5f6f8;--ink:#1d2229;--muted:#5b6571;--line:#dfe2e7;
  --link:%(acc)s;--code:#eef0f3;--codeink:#1d2229;--note:#edf1f6;--note-b:#51647b;--tip:#e7f4ea;--tip-b:#1f8a3b;--warn:#fff1e0;--warn-b:#c25b00}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){--blue:%(acc_dk)s;--blue-d:%(acc_dk)s;--onacc:%(onacc_dk)s;--navbg:%(navbg_dk)s;--bg:#11151a;--side:#11151a;--ink:#e3e7ec;--muted:#98a3b0;--line:#252c35;
    --link:%(acc_dk)s;--code:#1a2027;--codeink:#dde4ec;--note:#18212c;--note-b:#7f95b0;--tip:#102419;--tip-b:#46b866;--warn:#2a1d0c;--warn-b:#f0a03c}
}
:root[data-theme="dark"]{--blue:%(acc_dk)s;--blue-d:%(acc_dk)s;--onacc:%(onacc_dk)s;--navbg:%(navbg_dk)s;--bg:#11151a;--side:#11151a;--ink:#e3e7ec;--muted:#98a3b0;--line:#252c35;
  --link:%(acc_dk)s;--code:#1a2027;--codeink:#dde4ec;--note:#18212c;--note-b:#7f95b0;--tip:#102419;--tip-b:#46b866;--warn:#2a1d0c;--warn-b:#f0a03c}
:root[data-theme="light"]{--blue:%(acc)s;--onacc:#fff}
body{font-size:16px}
.page h1{font-weight:600;letter-spacing:-.01em}
.page h2{font-weight:600}
.mark button[aria-pressed="true"],.qb{color:var(--onacc)}
#side a.on{color:var(--link)}
pre{background:#12171d;border-color:#28313c;color:#d6dde5}
pre code{color:#d6dde5;font-size:13px}
pre .ps{color:%(ps)s;user-select:none}
pre .cm{color:#7f8c99}
pre.ascii{line-height:1.25}
pre.ascii code{font-size:12.5px}
.copy{background:#1b222a;color:#9fb0c1;border-color:#2c3744}
.copy:hover{color:#fff}
.callout.lab{background:var(--code);border-color:var(--blue)}
.callout.lab>b:first-child::before{content:"Lab · ";color:var(--blue)}
.callout.lab pre{margin:10px 0}
.qs.wrong{border-color:#c0392b}
.page code{overflow-wrap:anywhere}
.page pre code{overflow-wrap:normal}
@media (max-width:560px){
  .nav{gap:10px;padding:0 12px}
  .brand>span:last-child{display:none}
  .search input{min-width:0}
  #theme{padding:0 8px;font-size:12px}
}
""" % dict(acc=C['acc'], acc_d=C['acc_d'], acc_dk=C['acc_dk'], onacc_dk=C['onacc_dk'], navbg=C['navbg'], navbg_dk=C['navbg_dk'], ps=C['mark'])
head = head.replace('</style>', override + '</style>', 1)

P = CFG['storage']
tail = tail.replace('sap-read', P + '-read').replace('sap-theme', P + '-theme').replace('sap-quiz-', P + '-quiz-')
tail = tail.replace("document.title=page.dataset.title+' · AWS SAP-C02 notes';", "document.title=page.dataset.title+' · %s';" % CFG['doc_suffix'])
tail = tail.replace("if($('.copy',pre))return;", "if($('.copy',pre)||pre.classList.contains('ascii'))return;")
k = tail.find('<footer>'); l = tail.find('</footer>') + 9
foot = """<footer>
      <p style="margin:0 0 8px"><a href="%s">← Về trang chủ Trác Việt</a></p>
      <p style="margin:0 0 8px"><b style="color:var(--ink)">Soạn bởi Trác Việt</b> (<a href="https://github.com/TracVietHustCS" target="_blank" rel="noopener">@TracVietHustCS</a>)</p>
      %s
    </footer>""" % (CFG['home_url'], CFG['footer'])
tail = tail[:k] + foot + tail[l:]

if __name__ == '__main__':
    pages = load_pages()
    ids = [p[0] for p in pages]
    assert len(ids) == len(set(ids)), 'duplicate ids'
    doc = head + '\n'.join(article(p) for p in pages) + tail
    open(OUT, 'w', encoding='utf-8').write(doc)
    print('pages:', len(pages), 'chars:', len(doc), '->', OUT)
