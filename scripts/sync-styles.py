"""Snapshot reviewed local forks. Run explicitly, never during document rendering."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument("--word-repo",type=Path,default=ROOT.parent/"pandoc_docx_template")
parser.add_argument("--authors-repo",type=Path,default=ROOT.parent/"authors-block")
args=parser.parse_args()
for lang in ("zh","en"):
    dest=ROOT/f"styles/docx/reference-{lang}.docx"
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(args.word_repo/f"templates/quarto/reference-{lang}.docx",dest)
extension=ROOT/"_extensions/wiederholung/authors-block"
shutil.copytree(args.authors_repo/"_extensions/authors-block",extension,dirs_exist_ok=True)
shutil.copyfile(extension/"assets/orcid.pdf",ROOT/"styles/latex/orcid.pdf")

def commit(path):
    return subprocess.check_output(["git","-C",str(path),"rev-parse","HEAD"],text=True).strip()
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
paths=sorted(list((ROOT/"styles").rglob("*"))+list(extension.rglob("*")))
hashes={p.relative_to(ROOT).as_posix():sha(p) for p in paths if p.is_file() and p.name!="manifest.json"}
manifest={
    "snapshot_version":"0.1.0-dev",
    "status":"local working-tree snapshot; unpublished",
    "word":{
        "repository":"https://github.com/wiederholung/pandoc_docx_template",
        "base_commit":commit(args.word_repo),
        "builder":"scripts/build_quarto_references.py",
        "builder_sha256":sha(args.word_repo/"scripts/build_quarto_references.py"),
        "upstream_source":json.loads((args.word_repo/"templates/quarto/manifest.json").read_text(encoding="utf-8"))},
    "authors_block":{"repository":"https://github.com/wiederholung/authors-block",
                     "base_commit":commit(args.authors_repo),"version":"0.3.0-dev"},
    "csl":{"repository":"https://github.com/citation-style-language/styles",
           "commit":"1ccf4696be22ea0b55f83cc9163bde3061fddb0a","path":"ieee.csl"},
    "verified_environment":{"quarto":"1.11.9","pandoc":"3.10","pdf_engine":"XeLaTeX / MiKTeX",
                            "word_fonts":["Times New Roman","SimSun","SimHei","Consolas"]},
    "sha256":hashes}
(ROOT/"styles/manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(f"Snapshotted {len(hashes)} style/extension files. No remote updates performed.")
