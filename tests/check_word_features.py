"""Quarto integration cases for Word headings, callouts and page layout.

Run with Python 3; Quarto must be on PATH. No Word/Python packages needed.
The temporary project is deliberately outside the source tree.
"""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import os
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as E

ROOT=Path(__file__).resolve().parents[1]
W='http://schemas.openxmlformats.org/wordprocessingml/2006/main'
NS={'w':W}

def run(args,root,env=None):
    p=subprocess.run(args,cwd=root,capture_output=True,text=True,encoding='utf8',env=env)
    if p.returncode: raise AssertionError(p.stdout+'\n'+p.stderr)

with tempfile.TemporaryDirectory(prefix='quarto-word-中文 features-') as temp:
    root=Path(temp)
    # Exercise a copied template with its bundled XML dependency, without imports
    # from the checkout or globally installed XML libraries.
    for name in ['scripts','styles','_extensions']:
        shutil.copytree(ROOT/name,root/name)
    shutil.copyfile(ROOT/'_quarto.yml',root/'_quarto.yml')
    assert 'post-render:' not in (root/'_quarto.yml').read_text(encoding='utf8')
    for mode in ['quarto-numbered','numbered','unnumbered','no-headings']:
        native=mode!='quarto-numbered'
        env={**os.environ,'QUARTO_DOCX_NATIVE_NUMBERING':'1' if native else '0'}
        source='''---
title: Word integration check
lang: en
number-sections: NUMBERED
format:
  docx:
    reference-doc: styles/docx/reference-en.docx
---
'''.replace('NUMBERED','false' if mode=='unnumbered' else 'true')
        if mode!='no-headings':
            source+='''
# First {#sec-first}

## Nested {#sec-nested}

### Deep {#sec-deep}

1. An ordinary list item.
2. Another ordinary list item.

# Excluded {.unnumbered}

# Second {#sec-second}

[A custom heading link](#sec-first).
'''
            if mode in ['numbered','quarto-numbered']:source+='\nSee [@sec-first; @sec-nested; @sec-deep; @sec-second].\n'
        for kind in ['note','tip','warning','caution','important']:
            for appearance in ['simple','default']:
                source+=f'\n::: {{.callout-{kind} appearance="{appearance}"}}\n## A {kind}\n\nA long paragraph with enough text to wrap inside the callout, while retaining normal indentation and a fixed table grid.\n:::\n'
        source+='\n::: {.callout-note appearance="simple"}\n## Rich content\n\nA [linked phrase](https://quarto.org) with **bold text** and $x=1$.\n\n1. First callout item.\n2. Second callout item.\n\n```python\nx = 1\n```\n:::\n'
        source+='\n::: {.callout-note icon=false}\nA note without an icon.\n:::\n'
        # Chinese filenames exercise Windows paths in both render modes.
        (root/'标题验证.qmd').write_text(source,encoding='utf8')
        run(['quarto','render','标题验证.qmd','--to','docx','--quiet'],root,env)
        file=root/'output/标题验证.docx'
        if native:
            # Native numbering is an archived opt-in; no project hook runs it.
            run(['quarto','run','scripts/finalize-docx.lua'],root,
                {**env,'QUARTO_PROJECT_OUTPUT_FILES':str(file)})
        with ZipFile(file) as z:
            assert z.testzip() is None
            doc=E.fromstring(z.read('word/document.xml'))
            if not native:assert b'qt-docx-finalize' not in z.read('word/document.xml')
            texts=[''.join(p.itertext()) for p in doc.findall('.//w:p',NS)]
            assert not any('qt-' in x for x in texts)
            fields=[e.text for e in doc.findall('.//w:instrText',NS)]
            if mode=='numbered':
                assert len(fields)==4 and all(r'\w' in x and r'\h' in x for x in fields)
            else:assert not fields
            if mode!='no-headings':
                for title in ['First','Nested','Deep','Excluded','Second']:
                    para=next(p for p in doc.findall('.//w:p',NS) if ''.join(p.itertext()).endswith(title))
                    number=para.find('w:pPr/w:numPr/w:numId',NS)
                    if not native:
                        assert number is None
                        if title=='First':assert ''.join(para.itertext()).startswith('1. ')
                        continue
                    assert number is not None
                    assert (number.get(f'{{{W}}}val')!='0')==(mode=='numbered' and title!='Excluded')
                assert any('A custom heading link' in ''.join(h.itertext()) for h in doc.findall('.//w:hyperlink',NS))
                if not native:
                    assert doc.find('.//w:hyperlink[@w:anchor="sec-nested"]',NS) is not None
                    assert b'QuartoNativeHeadings' not in z.read('word/numbering.xml')
            tables=doc.findall('.//w:tbl',NS)
            assert len(tables)==12
            assert 'First callout item.' in ''.join(doc.itertext())
            assert 'https://quarto.org' in z.read('word/_rels/document.xml.rels').decode('utf8')
            for table in tables:
                width=int(table.find('w:tblPr/w:tblW',NS).get(f'{{{W}}}w'))
                cols=table.findall('w:tblGrid/w:gridCol',NS)
                assert sum(int(c.get(f'{{{W}}}w')) for c in cols)==width
                for row in table.findall('w:tr',NS):
                    assert sum(int(c.find('w:tcPr/w:tcW',NS).get(f'{{{W}}}w')) for c in row.findall('w:tc',NS))==width
                assert all(len(p.findall('w:pPr',NS))==1 for p in table.findall('.//w:p',NS))
        before=hashlib.sha256(file.read_bytes()).digest()
        run(['quarto','run','scripts/finalize-docx.lua'],root,
            {**env,'QUARTO_PROJECT_OUTPUT_FILES':str(file)})
        assert hashlib.sha256(file.read_bytes()).digest()==before,'post-render is not idempotent'
        print(f'{mode}: numbering, section references, rich content, 12 callouts and idempotence passed')

    # A regular sample has authors, short tables and full-width artwork. Cover
    # the cases where title-block placement and float ownership previously broke.
    shutil.copyfile(ROOT/'figures/workflow.png',root/'workflow.png')
    rows='\n'.join(f'| S-{i:03} | {i} |' for i in range(1,79))
    source='''---
lang: en
abstract: |
  First paragraph.

  Second paragraph with *emphasis* and a [link](https://quarto.org).
keywords: [Alpha, Beta]
format:
  docx:
    reference-doc: styles/docx/reference-en.docx
---

![Narrow figure caption.](workflow.png){#fig-narrow width=45%}

::: {.figure-note}
An outside note.
:::

:::: {#tbl-data}
| Sample | Value |
|:-------|------:|
ROWS

::: {.table-note}
Final table note.
:::

Sample values.
::::
'''.replace('ROWS',rows)
    (root/'layout.qmd').write_text(source,encoding='utf8')
    run(['quarto','render','layout.qmd','--to','docx','--quiet'],root)
    with ZipFile(root/'output/layout.docx') as z:
        doc=E.fromstring(z.read('word/document.xml'))
        body=doc.find('w:body',NS)
        def paragraph_with(role):
            return next(p for p in body.findall('w:p',NS) if p.find(f'w:pPr/w:pStyle[@w:val="{role}"]',NS) is not None)
        assert ''.join(paragraph_with('Abstract').itertext())=='Abstract First paragraph.'
        second=paragraph_with('AbstractContinuation')
        assert second.find('w:hyperlink',NS) is not None and second.find('.//w:i',NS) is not None
        assert ''.join(paragraph_with('Keywords').itertext())=='Keywords Alpha; Beta'
        figure,data=body.findall('w:tbl',NS)
        assert figure.find('w:tblPr/w:tblW',NS).get(f'{{{W}}}w')=='2250'
        assert figure.find('.//w:pStyle[@w:val="FigureNote"]',NS) is not None
        assert len(data.findall('w:tr',NS))==79 and data.find('w:tr/w:trPr/w:tblHeader',NS) is not None
        assert data.findall('w:tr',NS)[-1].find('.//w:pStyle[@w:val="TableTextKeep"]',NS) is not None
        assert ''.join(paragraph_with('TableNote').itertext())=='Final table note.'
    print('Layout: authorless rich abstract, keywords, narrow figure, note and pageable data table passed')

    # Check both the Word grid and its pictures. A correct caption or grid on
    # its own does not prevent Word from clipping an oversized inline image.
    group_cases = [
        ('wide', 'layout="[[65,35]]"', 2, [[.65, .35]]),
        ('reverse', 'layout="[[35,65]]"', 2, [[.35, .65]]),
        ('mixed', 'layout="[[1,1],[1]]"', 3, [[.5, .5], [1]]),
        ('thirds', 'layout-ncol=3', 3, [[1/3]*3]),
        ('plain', 'layout="[[65,35]]"', 2, [[.65, .35]]),
    ]
    groups = []
    for name, layout, count, _ in group_cases:
        panels = []
        for i in range(count):
            attr = '' if name == 'plain' else f'{{#fig-{name}-{i+1}}}'
            panels.append(f'![Panel {i+1}](workflow.png){attr}')
        groups.append(f'::: {{#fig-{name} {layout}}}\n' + '\n\n'.join(panels) + '\n\nGroup caption.\n:::\n')
    front = '---\nformat:\n  docx:\n    reference-doc: styles/docx/reference-en.docx\n---\n'
    (root/'panels.qmd').write_text(front + '\n'.join(groups), encoding='utf8')
    run(['quarto','render','panels.qmd','--to','docx','--quiet'],root)
    with ZipFile(root/'output/panels.docx') as archive:
        doc = E.fromstring(archive.read('word/document.xml'))
        tables = doc.findall('w:body/w:tbl', NS)
        expected_rows = [row for _, _, _, rows in group_cases for row in rows]
        assert len(tables) == len(expected_rows)
        extent = './/{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}extent'
        section = doc.find('w:body/w:sectPr', NS)
        page = section.find('w:pgSz', NS)
        margins = section.find('w:pgMar', NS)
        width = (int(page.get(f'{{{W}}}w')) - sum(int(margins.get(f'{{{W}}}{side}')) for side in ('left','right'))) / 20
        for table, fractions in zip(tables, expected_rows):
            cols = [int(c.get(f'{{{W}}}w')) for c in table.findall('w:tblGrid/w:gridCol',NS)]
            cells = table.findall('w:tr/w:tc',NS)
            assert len(cols) == len(cells) == len(fractions)
            for col, cell, fraction in zip(cols, cells, fractions):
                assert abs(col / sum(cols) - fraction) < .001
                picture, = cell.findall(extent)
                points = int(picture.get('cx')) / 12700
                assert .94 * width * fraction < points <= width * fraction
                assert cell.find('.//w:pStyle[@w:val="PanelFigure"]',NS) is not None
    print('Panels: both width ratios, mixed rows, thirds and unlabelled images passed')
