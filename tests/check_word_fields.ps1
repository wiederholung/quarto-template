# Requires desktop Microsoft Word. Edits are made in memory and discarded.
$ErrorActionPreference='Stop'
if($env:QUARTO_DOCX_NATIVE_NUMBERING -ne '1'){
 Write-Output 'SKIP: native Word numbering is disabled; default numbering is managed by Quarto.'
 exit 0
}
$root=Split-Path $PSScriptRoot -Parent
$beforeProcesses=@(Get-Process WINWORD -ErrorAction SilentlyContinue | ForEach-Object {$_.Id})
$w=New-Object -ComObject Word.Application
$newProcesses=@(Get-Process WINWORD -ErrorAction SilentlyContinue | Where-Object {$_.Id -notin $beforeProcesses})
$private=($newProcesses.Count -eq 1)
if($private){$w.Visible=$false;$w.DisplayAlerts=0}
$qaDir=Join-Path $root '.qa/word-fields'
New-Item -ItemType Directory -Path $qaDir -Force | Out-Null
try {
 foreach($lang in @('zh','en')){
 # Always edit a separate copy, even if Word reuses an existing application.
 [string]$copy=Join-Path $qaDir ("$lang-"+[guid]::NewGuid().ToString('N')+'.docx')
 Copy-Item -LiteralPath "$root\output\template-$lang.docx" -Destination $copy
 $d=$w.Documents.Open($copy,$false,$true,$false)
 try{
  $d.Fields.Update() | Out-Null
  $before=@($d.Fields | Where-Object { $_.Type -eq 3 } | ForEach-Object { $_.Result.Text })
  Write-Output "$lang before: $($before -join ', ')"
  if(($before -join ',') -ne '1.1,4'){throw 'Initial REF results incorrect'}
  $r=$d.Range(0,0);$r.InsertBefore("Inserted validation section`r")
  $d.Paragraphs.Item(1).Range.Style=-2
  $d.Fields.Update() | Out-Null
  $after=@($d.Fields | Where-Object { $_.Type -eq 3 } | ForEach-Object { $_.Result.Text })
  Write-Output "$lang inserted: $($after -join ', ')"
  if(($after -join ',') -ne '2.1,5'){throw 'REF did not follow native heading numbering'}
  $d.Paragraphs.Item(1).Range.Delete() | Out-Null
  $d.Fields.Update() | Out-Null
  $restored=@($d.Fields | Where-Object { $_.Type -eq 3 } | ForEach-Object { $_.Result.Text })
  Write-Output "$lang deleted: $($restored -join ', ')"
  if(($restored -join ',') -ne '1.1,4'){throw 'REF did not restore after deletion'}
 }finally{$d.Close(0);Remove-Item -LiteralPath $copy}
 }
}finally{if($private){$w.Quit()}}


