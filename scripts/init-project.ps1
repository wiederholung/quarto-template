# Quarto template initialization omits dotfiles and README.md.
# Supply project housekeeping without replacing existing user files.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$files = @{
    '.gitattributes' = @'
styles/** -text whitespace=cr-at-eol
_extensions/** -text whitespace=cr-at-eol
*.docx binary
*.png binary
*.pdf binary
'@
    '.gitignore' = @'
/output/
/.quarto/
/.qa/
*.tex
*.log
*.aux
*.out
*.toc
*.synctex.gz
!styles/latex/*.tex
'@
    '.quartoignore' = @'
output/
.qa/
*.tex
*.pdf
*.docx
*.html
*.aux
*.out
*.toc
*.synctex.gz
*.log
'@
}
foreach ($entry in $files.GetEnumerator()) {
    $target = Join-Path $projectRoot $entry.Key
    if (-not (Test-Path -LiteralPath $target)) {
        [IO.File]::WriteAllText($target, $entry.Value + "`n", [Text.UTF8Encoding]::new($false))
        Write-Output "Created $($entry.Key)"
    }
}
Write-Output 'Ready. Choose template-zh.qmd or template-en.qmd and replace the example metadata.'
