[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$PackagePath)
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "V2 package invalid: $Message" }
function Read-U16([byte[]]$Data, [int]$Offset) {
    if ($Offset -lt 0 -or ($Offset + 1) -ge $Data.Length) { Fail "WORD read outside package at offset $Offset" }
    return [int]$Data[$Offset] + ([int]$Data[$Offset + 1] * 256)
}
if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) { Fail "file not found: $PackagePath" }
[byte[]]$Package = [IO.File]::ReadAllBytes($PackagePath)
if ($Package.Length -gt 0xFF00) { Fail "outer package exceeds #FF00 bytes ($($Package.Length))" }
if ($Package.Length -lt 2) { Fail 'missing outer stage-0-length prefix' }
$Stage0Length = Read-U16 $Package 0
if ($Stage0Length -lt 1 -or $Stage0Length -gt 254) { Fail "stage-0 length outside 1..254: $Stage0Length" }
$Stage1MarkerOffset = 2 + $Stage0Length
if (($Stage1MarkerOffset + 6) -gt $Package.Length) { Fail 'truncated before stage-1 marker/length' }
$Stage1Marker = [Text.Encoding]::ASCII.GetString($Package, $Stage1MarkerOffset, 4)
if ($Stage1Marker -cne 'V2S1') { Fail "missing V2S1 stage marker: '$Stage1Marker'" }
$Stage1LengthOffset = $Stage1MarkerOffset + 4
$Stage1Length = Read-U16 $Package $Stage1LengthOffset
if ($Stage1Length -lt 1 -or $Stage1Length -gt 0x0800) { Fail "stage-1 length outside 1..#0800: $Stage1Length" }
$PayloadStart = $Stage1LengthOffset + 2 + $Stage1Length
if (($PayloadStart + 8) -gt $Package.Length) { Fail 'truncated before v2 base header' }
$Magic = [Text.Encoding]::ASCII.GetString($Package, $PayloadStart, 4)
if ($Magic -cne 'P124') { Fail "bad magic '$Magic'" }
if ($Package[$PayloadStart + 4] -ne 2) { Fail "unsupported version $($Package[$PayloadStart + 4])" }
$Count = [int]$Package[$PayloadStart + 5]
if ($Count -lt 1 -or $Count -gt 3) { Fail "segment count outside 1..3: $Count" }
$TotalLength = Read-U16 $Package ($PayloadStart + 6)
if ($TotalLength -lt 1 -or $TotalLength -gt 0xC000) { Fail "total payload outside 1..#C000: $TotalLength" }
$HeaderLength = 8 + (6 * $Count)
$DataStart = $PayloadStart + $HeaderLength
if ($DataStart -gt $Package.Length) { Fail 'truncated descriptor table' }
$SeenPages = @{}
$Sum = 0
$Descriptors = @()
for ($i = 0; $i -lt $Count; $i++) {
    $At = $PayloadStart + 8 + (6 * $i)
    $Page = [int]$Package[$At]
    $Offset = Read-U16 $Package ($At + 1)
    $Length = Read-U16 $Package ($At + 3)
    $Flags = [int]$Package[$At + 5]
    if ($Page -notin @(0, 68, 69)) { Fail "unsupported physical page $Page" }
    if ($SeenPages.ContainsKey([string]$Page)) { Fail "duplicate physical page $Page" }
    $SeenPages[[string]$Page] = $true
    if ($Offset -ne 0) { Fail "canonical profile requires offset 0; page $Page has $Offset" }
    if ($Length -lt 1 -or $Length -gt 0x4000) { Fail "segment length outside 1..#4000 on page $Page length $Length" }
    if (($Flags -band 0xFE) -ne 0) { Fail "unknown flags on page $Page" }
    if ($i -eq 0) {
        if ($Page -ne 0) { Fail 'first descriptor must target resident page 0' }
        if (($Flags -band 1) -eq 0) { Fail 'resident descriptor must be executable' }
    } elseif ($Page -eq 0) { Fail 'resident page may appear only as descriptor 0' }
    $Sum += $Length
    $Descriptors += [pscustomobject]@{ Page = $Page; Offset = $Offset; Length = $Length; Flags = $Flags }
}
if ($Sum -ne $TotalLength) { Fail "descriptor sum $Sum differs from header total $TotalLength" }
$ExpectedLength = $DataStart + $TotalLength
if ($Package.Length -lt $ExpectedLength) { Fail "truncated segment data: got $($Package.Length), expected $ExpectedLength" }
if ($Package.Length -gt $ExpectedLength) { Fail "trailing bytes after payload: got $($Package.Length), expected $ExpectedLength" }
Write-Host ("[V2-VERIFY] PASS: stage0={0}; stage1={1}; segments={2}; firmware={3}; package={4}" -f $Stage0Length, $Stage1Length, $Count, $TotalLength, $Package.Length)
foreach ($Descriptor in $Descriptors) {
    Write-Host ("[V2-VERIFY] PAGE={0} OFFSET=#{1:X4} LENGTH=#{2:X4} FLAGS=#{3:X2}" -f $Descriptor.Page, $Descriptor.Offset, $Descriptor.Length, $Descriptor.Flags)
}
