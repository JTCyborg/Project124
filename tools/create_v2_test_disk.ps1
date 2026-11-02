[CmdletBinding()]
param(
    [string]$SourceImage = 'disk_A.trd',
    [string]$OutputImage = 'disk_A_v2.trd'
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceImage -PathType Leaf)) {
    throw "Source TR-DOS image not found: $SourceImage"
}
[byte[]]$Image = [IO.File]::ReadAllBytes($SourceImage)
if ($Image.Length -ne 655360) {
    throw "Unexpected TR-DOS image size: $($Image.Length), expected 655360"
}

$DirectoryOffset = 0
$EntrySize = 16
$EntryCount = 128
$V1Name = 'neoprog'
$V2Name = 'neopv2'
$V1Entry = -1
$V2Entry = -1

for ($Index = 0; $Index -lt $EntryCount; $Index++) {
    $Offset = $DirectoryOffset + ($Index * $EntrySize)
    $Name = [Text.Encoding]::ASCII.GetString($Image, $Offset, 8)
    $Type = [char]$Image[$Offset + 8]
    if ($Type -ne 'C') { continue }
    if ($Name.TrimEnd() -ceq $V1Name) {
        if ($V1Entry -ge 0) { throw 'Duplicate neoprog.C directory entries in source image' }
        $V1Entry = $Offset
    }
    if ($Name.TrimEnd() -ceq $V2Name) {
        if ($V2Entry -ge 0) { throw 'Duplicate neopv2.C directory entries in source image' }
        $V2Entry = $Offset
    }
}
if ($V1Entry -lt 0) { throw 'V1 neoprog.C entry not found in source TR-DOS image' }
if ($V2Entry -lt 0) { throw 'V2 neopv2.C entry not found in source TR-DOS image' }

# The test copy retains the V1 package under neoprog1.C and exposes the
# staged V2 package under the original host filename neoprog.C.
[byte[]]$Copy = $Image.Clone()
[byte[]]$OldName = [Text.Encoding]::ASCII.GetBytes('neoprog1')
[byte[]]$ActiveName = [Text.Encoding]::ASCII.GetBytes('neoprog ')
[Array]::Copy($OldName, 0, $Copy, $V1Entry, 8)
[Array]::Copy($ActiveName, 0, $Copy, $V2Entry, 8)

$OutputDirectory = Split-Path -Parent $OutputImage
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory) -and -not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
[IO.File]::WriteAllBytes($OutputImage, $Copy)

# Re-read the directory entries from the actual output, not the in-memory source.
[byte[]]$Check = [IO.File]::ReadAllBytes($OutputImage)
$ActiveCount = 0
$OldCount = 0
for ($Index = 0; $Index -lt $EntryCount; $Index++) {
    $Offset = $DirectoryOffset + ($Index * $EntrySize)
    if ([char]$Check[$Offset + 8] -ne 'C') { continue }
    $Name = [Text.Encoding]::ASCII.GetString($Check, $Offset, 8)
    if ($Name -ceq 'neoprog ') { $ActiveCount++ }
    if ($Name -ceq 'neoprog1') { $OldCount++ }
}
if ($ActiveCount -ne 1 -or $OldCount -ne 1) {
    Remove-Item -LiteralPath $OutputImage -Force
    throw "V2 disk directory post-check failed: active=$ActiveCount old=$OldCount"
}
Write-Host "[V2-DISK] PASS: $OutputImage; neoprog.C points to staged V2 package; V1 retained as neoprog1.C"
