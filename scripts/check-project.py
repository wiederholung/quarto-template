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
AUTHORS = {
    'zh': ['Josiah Carberry', '示例作者', 'Catherine Alexandra Montgomery', '陈明'],
    'en': ['Josiah Carberry', 'Alex Example', 'Sam Lee', 'Robin Example'],
}
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
        core=ET.fromstring(z.read('docProps/core.xml'))
        creator=core.findtext('{http://purl.org/dc/elements/1.1/}creator')
        require(creator=='; '.join(AUTHORS[lang]), f'{lang} DOCX Author property: {creator!r}')
        rels={r.get('Id'):r.get('Target') for r in ET.fromstring(z.read('word/_rels/document.xml.rels'))}
        footer_ref=doc.find('w:body/w:sectPr/w:footerReference[@w:type="default"]',NS)
        require(footer_ref is not None,f'{lang} DOCX default footer missing')
        footer=ET.fromstring(z.read('word/'+rels[footer_ref.get(f'{{{R}}}id')]))
        footer_paras=footer.findall('.//w:p',NS)
        footer_fields=[(f.text or '').split() for f in footer.findall('.//w:instrText',NS)]
        require(len(footer_paras)==1 and footer_paras[0] in list(footer)
                and len(footer_fields)==1 and footer_fields[0][:1]==['PAGE']
                and footer.find('.//w:br',NS) is None,
                f'{lang} DOCX footer must have a single paragraph containing the PAGE field')
        ids=[s.get(f'{{{W}}}styleId') for s in styles.findall('w:style',NS)]
        require(len(ids)==len(set(ids)),f'{lang} DOCX duplicate style IDs')
        require(not styles.findall('.//w:autoRedefine',NS),f'{lang} DOCX styles auto-update')
        default_char=styles.find('w:style[@w:type="character"][@w:default="1"]',NS)
        require(default_char is not None, f'{lang} DOCX default character style missing')
        for name in ('Hyperlink','FollowedHyperlink'):
            style=styles.find(f'w:style/w:name[@w:val="{name}"]/..',NS)
            require(style is not None and style.get(f'{{{W}}}type')=='character',
                    f'{lang} DOCX {name} character style missing')
            parent=style.find('w:basedOn',NS)
            require(parent is not None and parent.get(f'{{{W}}}val')==default_char.get(f'{{{W}}}styleId'),
                    f'{lang} DOCX {name} must inherit the default character style')
            props=style.find('w:rPr',NS)
            require(props is not None and props.find('w:color[@w:val="000000"]',NS) is not None
                    and props.find('w:u[@w:val="none"]',NS) is not None,
                    f'{lang} DOCX {name} must use black text without an underline')
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
        ref_num=heading[0].find('w:pPr/w:numPr/w:numId',NS)
        require(ref_num is None or ref_num.get(f'{{{W}}}val')=='0',
                f'{lang} DOCX references must remain unnumbered')
        numbering=ET.fromstring(z.read('word/numbering.xml'))
        require(numbering.find('.//w:name[@w:val="QuartoNativeHeadings"]',NS) is None,
                f'{lang} DOCX native heading numbering should be disabled')
        fields=[e.text or '' for e in doc.findall('.//w:instrText',NS)]
        require(not any(' REF "sec-' in f for f in fields),
                f'{lang} DOCX native section fields should be disabled')
        for target in ['sec-headings','sec-math']:
            require(doc.find(f'.//w:hyperlink[@w:anchor="{target}"]',NS) is not None,
                    f'{lang} DOCX Quarto section link missing: {target}')
        abstract=[p for p in doc.findall('.//w:p',NS)
                  if p.find('w:pPr/w:pStyle[@w:val="Abstract"]',NS) is not None]
        require(len(abstract)==1 and ''.join(abstract[0].itertext()).startswith('摘要　' if lang=='zh' else 'Abstract '),
                f'{lang} DOCX abstract label must run into its first paragraph')
        keywords=[p for p in doc.findall('w:body/w:p',NS)
                  if p.find('w:pPr/w:pStyle[@w:val="Keywords"]',NS) is not None]
        require(len(keywords)==1 and ''.join(keywords[0].itertext()).startswith('关键词　' if lang=='zh' else 'Keywords '),
                f'{lang} DOCX keyword label and terms must share a paragraph')
        for role,p in [('Abstract',abstract[0]),('Keywords',keywords[0])]:
            require(p.find(f'w:r/w:rPr/w:rStyle[@w:val="{role}Label"]',NS) is not None,
                    f'{lang} DOCX {role} label must inherit its character style')
        body_paras=doc.findall('w:body/w:p',NS)
        date_id=next(s.get(f'{{{W}}}styleId') for s in styles.findall('w:style',NS)
                     if s.find('w:name[@w:val="Date"]',NS) is not None)
        date=next(p for p in body_paras if p.find(f'w:pPr/w:pStyle[@w:val="{date_id}"]',NS) is not None)
        positions=[body_paras.index(p) for p in (author,contacts[0],date,abstract[0],keywords[0])]
        require(positions==sorted(positions),f'{lang} DOCX title-block order')
        for table in doc.findall('.//w:tbl',NS):
            if table.find('w:tblPr/w:tblBorders/w:left[@w:color="0758E5"]',NS) is None: continue
            grid=table.findall('w:tblGrid/w:gridCol',NS)
            require(len(grid)==2 and table.find('w:tblPr/w:tblLayout[@w:type="fixed"]',NS) is not None,
                    f'{lang} DOCX callout grid must match its two cells')
            require(table.find('.//w:pStyle[@w:val="CalloutBody"]',NS) is not None,
                    f'{lang} DOCX callout must use dedicated paragraph styles')
            require(all(len(p.findall('w:pPr',NS))==1 for p in table.findall('.//w:p',NS)),
                    f'{lang} DOCX callout has conflicting duplicate paragraph properties')
        require(len(panels)==2 and all(p.find('.//w:drawing',NS) is not None and p.find('.//w:br',NS) is not None for p in panels),
                f'{lang} DOCX panels must retain image and caption together')
        pair_rows=[row for row in doc.findall('.//w:tr',NS) if len(row.findall('w:tc',NS))==2 and
                   all(c.find('.//w:drawing',NS) is not None for c in row.findall('w:tc',NS))]
        require(bool(pair_rows),f'{lang} DOCX panels are not side by side')
        tables=doc.findall('w:body/w:tbl',NS)
        data=[t for t in tables if t.find('w:tblPr/w:tblStyle[@w:val="Table"]',NS) is not None]
        require(len(data)==1 and data[0].find('w:tr/w:trPr/w:tblHeader',NS) is not None,
                f'{lang} DOCX data table needs a top-level repeating header')
        for cell in data[0].findall('w:tr/w:tc',NS):
            require(any(e.get(f'{{{W}}}val') in ('TableText','TableTextKeep') for e in cell.findall('.//w:pStyle',NS)),
                    f'{lang} DOCX data-table typography missing')
        equations=[t for t in tables if t.find('w:tblPr/w:tblStyle[@w:val="EquationLayout"]',NS) is not None]
        require(len(equations)==2,f'{lang} DOCX missing numbered equations')
        for number,table in enumerate(equations,1):
            cells=table.findall('w:tr/w:tc',NS)
            require(len(cells)==3 and cells[1].find('.//{http://schemas.openxmlformats.org/officeDocument/2006/math}oMath') is not None
                    and ''.join(cells[2].itertext())==f'({number})',f'{lang} DOCX equation or tag placement')
        for key,alignment in [('ImageCaption','center'),('TableCaption','center'),('PanelFigure','center'),
                              ('FigureNote','left'),('TableNote','left'),('EquationNumber','right')]:
            require(styles.find(f'w:style[@w:styleId="{key}"]/w:pPr/w:jc[@w:val="{alignment}"]',NS) is not None,
                    f'{lang} DOCX {key} style alignment')
        code_style=styles.find('w:style[@w:styleId="SourceCode"]/w:pPr',NS)
        require(code_style is not None and code_style.find('w:shd[@w:fill="F1F3F5"]',NS) is not None,
                f'{lang} DOCX code paragraph shading')
        for side in ('left','right'):
            require(code_style.find(f'w:pBdr/w:{side}[@w:color="F1F3F5"]',NS) is not None,
                    f'{lang} DOCX code paragraph {side} border color')
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
        # Class-owned title with the authors-block LaTeX backend.
        first_page=''.join(reader.pages[0].extract_text().split())
        for name in AUTHORS[lang]:
            require(''.join(name.split()) in first_page,f'{lang} PDF author missing: {name}')
        require(any('orcid.org/0000-0002-1825-0097' in uri for uri in uris),f'{lang} PDF ORCID link missing')
        require('mailto:example@example.org' in uris and 'mailto:second@example.org' in uris,f'{lang} PDF correspondence missing')
        for annotation in reader.pages[0].get('/Annots',[]):
            action=annotation.get_object().get('/A',{})
            if action.get('/S')=='/GoTo':
                require(str(action['/D']) in reader.named_destinations,f'{lang} PDF author target missing')
        require(any('10.1093/comjnl/27.2.97' in uri for uri in uris),f'{lang} PDF bibliography DOI link missing')
        require(fonts and all(fonts.values()),f'{lang} PDF has unembedded fonts: {fonts}')
        checks.append(f'{lang} PDF: {len(reader.pages)} A4 pages; native author names, text, references and {len(fonts)} embedded fonts passed')

print('\n'.join(checks))
