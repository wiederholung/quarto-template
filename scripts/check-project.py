"""Check the local snapshot and the two examples' rendered outputs.

Python standard library checks DOCX/HTML and hashes. Install pypdf to include
PDF content, links and embedded-font checks. Run after `quarto render --to all`.
"""
from pathlib import Path
from zipfile import ZipFile
from html.parser import HTMLParser
from urllib.parse import unquote
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
W='http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
NS={'w':W,'r':R,'a':'http://schemas.openxmlformats.org/drawingml/2006/main',
    'asvg':'http://schemas.microsoft.com/office/drawing/2016/SVG/main'}
ORCID='https://orcid.org/0000-0002-1825-0097'
checks=[]

def require(condition,message):
    if not condition: raise AssertionError(message)

def snapshot_path(name):
    path=ROOT/name
    # Local `quarto use template <path>` installs without an owner namespace.
    if not path.exists() and name.startswith('_extensions/wiederholung/'):
        path=ROOT/name.replace('_extensions/wiederholung/','_extensions/',1)
    return path

manifest=json.loads((ROOT/'styles/manifest.json').read_text(encoding='utf-8'))
for name,digest in manifest['sha256'].items():
    path=snapshot_path(name)
    require(path.is_file(),f'Missing snapshot input: {name}')
    require(hashlib.sha256(path.read_bytes()).hexdigest()==digest,f'Changed snapshot input: {name}')
checks.append(f"Snapshot: {len(manifest['sha256'])} SHA-256 checks passed")

class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids=set(); self.hrefs=[]; self.images=[]; self.sections=[]; self.unresolved=[]
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if attrs.get('id'): self.ids.add(attrs['id'])
        if tag=='a': self.hrefs.append(attrs.get('href',''))
        if tag=='img': self.images.append(attrs.get('src',''))
        if tag=='section': self.sections.append(attrs)
        if 'quarto-unresolved-ref' in attrs.get('class',''): self.unresolved.append(attrs)

for lang in ('zh','en'):
    reference='参考文献' if lang=='zh' else 'References'
    file=ROOT/f'output/template-{lang}.html'
    page=Page(); page.feed(file.read_text(encoding='utf-8'))
    require(not page.unresolved,f'{lang} HTML has unresolved references')
    missing=[h for h in page.hrefs if h.startswith('#') and len(h)>1 and unquote(h[1:]) not in page.ids]
    require(not missing,f'{lang} HTML missing anchors: {missing}')
    require(ORCID in page.hrefs,f'{lang} HTML missing ORCID link')
    require(any(h.get('id')==reference.lower() and 'unnumbered' in h.get('class','') for h in page.sections),
            f'{lang} HTML references heading must be unnumbered')
    for src in page.images:
        if not src.startswith(('data:','https:','http:')):
            require((file.parent/unquote(src)).is_file(),f'{lang} HTML missing image: {src}')
    checks.append(f'{lang} HTML: image files, anchors, ORCID and unnumbered references passed')

    with ZipFile(ROOT/f'output/template-{lang}.docx') as z:
        require(z.testzip() is None,f'{lang} DOCX damaged ZIP')
        doc=ET.fromstring(z.read('word/document.xml'))
        styles=ET.fromstring(z.read('word/styles.xml'))
        rels={r.get('Id'):r.get('Target') for r in ET.fromstring(z.read('word/_rels/document.xml.rels'))}
        ids=[s.get(f'{{{W}}}styleId') for s in styles.findall('w:style',NS)]
        require(len(ids)==len(set(ids)),f'{lang} DOCX duplicate style IDs')
        require(not styles.findall('.//w:autoRedefine',NS),f'{lang} DOCX styles auto-update')
        links=[h for h in doc.findall('.//w:hyperlink',NS) if rels.get(h.get(f'{{{R}}}id'))==ORCID]
        require(any(h.find('.//w:drawing',NS) is not None for h in links),f'{lang} DOCX missing linked ORCID image')
        svg=links[0].find('.//asvg:svgBlip',NS)
        require(svg is not None,f'{lang} DOCX must embed the vector ORCID icon')
        require(z.read('word/'+rels[svg.get(f'{{{R}}}embed')])==snapshot_path('_extensions/wiederholung/authors-block/assets/orcid.svg').read_bytes(),
                f'{lang} DOCX ORCID differs from the bundled SVG')
        require(links[0].find('.//w:vertAlign',NS) is None,f'{lang} DOCX ORCID must not be superscript')
        author=next(p for p in doc.findall('.//w:p',NS) if p.find('.//asvg:svgBlip',NS) is not None)
        children=list(author)
        icon_at=next(i for i,e in enumerate(children) if e.find('.//asvg:svgBlip',NS) is not None)
        marks_at=next(i for i,e in enumerate(children) if e.find('.//w:position',NS) is not None)
        require(icon_at < marks_at,f'{lang} DOCX ORCID must precede the superscript marks')
        envelopes=[d for d in author.findall('.//w:drawing',NS)
                   if d.find('.//asvg:svgBlip',NS) is not None and
                   z.read('word/'+rels[d.find('.//asvg:svgBlip',NS).get(f'{{{R}}}embed')])==
                   snapshot_path('_extensions/wiederholung/authors-block/assets/envelope.svg').read_bytes()]
        require(len(envelopes)==2,f'{lang} DOCX must demonstrate two corresponding authors')
        envelope_at=next(i for i,e in enumerate(children) if e.find('.//w:drawing',NS) in envelopes)
        require(''.join(''.join(e.itertext()) for e in children[marks_at:envelope_at]
                       if e.find('.//w:position',NS) is not None)=='1,2,†',
                f'{lang} DOCX must demonstrate multiple affiliations and equal contribution')
        require('*' not in ''.join(author.itertext()),f'{lang} DOCX correspondence still uses an asterisk')
        contacts=[p for p in doc.findall('.//w:p',NS) if 'example@example.org' in ''.join(p.itertext())]
        require(len(contacts)==1 and 'Josiah' not in ''.join(contacts[0].itertext()),
                f'{lang} DOCX contact line must contain emails without repeated names')
        require('example@example.org; second@example.org' in ''.join(contacts[0].itertext()),
                f'{lang} DOCX must demonstrate merged, ordered contact emails')
        require(all('mailto:'+email in rels.values() for email in ('example@example.org','second@example.org')),
                f'{lang} DOCX contact emails must retain links')
        bookmarks={b.get(f'{{{W}}}name') for b in doc.findall('.//w:bookmarkStart',NS)}
        anchors=[h.get(f'{{{W}}}anchor') for h in doc.findall('.//w:hyperlink',NS) if h.get(f'{{{W}}}anchor')]
        require(all(a in bookmarks for a in anchors),f'{lang} DOCX broken internal link')
        mark_links=[h for h in author.findall('.//w:hyperlink',NS)
                    if h.get(f'{{{W}}}anchor','').startswith('authors_block_')]
        require([''.join(h.itertext()) for h in mark_links]==['1','2','†','1','†','2','2'],
                f'{lang} DOCX each author mark needs its own internal link')
        require(len(set(h.get(f'{{{W}}}anchor') for h in mark_links))==3,
                f'{lang} DOCX author marks must share the three detail targets')
        heading=[]; panels=[]
        for p in doc.findall('.//w:p',NS):
            text=''.join(p.itertext())
            ps=p.find('w:pPr/w:pStyle',NS)
            if text==reference: heading.append(p)
            if ps is not None and ps.get(f'{{{W}}}val')=='PanelFigure': panels.append(p)
        require(len(heading)==1,f'{lang} DOCX reference heading missing/duplicated')
        require(heading[0].find('w:pPr/w:numPr',NS) is None,f'{lang} DOCX references heading numbered')
        require(len(panels)==2 and all(p.find('.//w:drawing',NS) is not None and p.find('.//w:br',NS) is not None for p in panels),
                f'{lang} DOCX panels must retain image and caption together')
        pair_rows=[row for row in doc.findall('.//w:tr',NS) if len(row.findall('w:tc',NS))==2 and
                   all(c.find('.//w:drawing',NS) is not None for c in row.findall('w:tc',NS))]
        require(bool(pair_rows),f'{lang} DOCX panels are not side by side')
        require(doc.find('.//w:pPr/w:pStyle[@w:val="TableText"]',NS) is not None,f'{lang} DOCX data-table typography missing')
        require('literate programming' in ''.join(doc.itertext()).lower(),
                f'{lang} DOCX bibliography not rendered')
    checks.append(f'{lang} DOCX: ZIP, styles, links, baseline SVG before superscripts, panels and references passed')

try:
    from pypdf import PdfReader
except ImportError:
    checks.append('PDF checks skipped: install pypdf to enable them')
else:
    for lang in ('zh','en'):
        reader=PdfReader(ROOT/f'output/template-{lang}.pdf')
        text='\n'.join(p.extract_text() for p in reader.pages)
        require('literateprogramming' in ''.join(text.lower().split()),f'{lang} PDF bibliography missing')
        require('??' not in text,f'{lang} PDF has unresolved TeX references')
        uris=[]; fonts={}
        for page in reader.pages:
            require(abs(float(page.mediabox.width)-595.28)<1 and abs(float(page.mediabox.height)-841.89)<1,
                    f'{lang} PDF is not A4')
            for item in page.get('/Annots',[]):
                action=item.get_object().get('/A',{})
                if '/URI' in action: uris.append(action['/URI'])
            for item in page['/Resources'].get('/Font',{}).values():
                font=item.get_object()
                for descendant in font.get('/DescendantFonts',[font]):
                    child=descendant.get_object(); name=child.get('/BaseFont','unnamed')
                    descriptor=child.get('/FontDescriptor')
                    embedded=descriptor is not None and any(k in descriptor.get_object() for k in ('/FontFile','/FontFile2','/FontFile3'))
                    fonts[name]=embedded or child.get('/Subtype')=='/Type3'
        require(ORCID in uris,f'{lang} PDF missing ORCID link')
        # These examples have no figures on page 1; the ORCID must be vector-only.
        require(not reader.pages[0].images,f'{lang} PDF title page has a raster ORCID icon')
        require(fonts and all(fonts.values()),f'{lang} PDF has unembedded fonts: {fonts}')
        checks.append(f'{lang} PDF: {len(reader.pages)} A4 pages; text, references, vector ORCID and {len(fonts)} embedded fonts passed')

print('\n'.join(checks))
