param(
    [string[]]$ScanPath = @('src', 'public', 'docs', 'scripts', 'README.md', 'AGENTS.md')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRootPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$textExtensions = @('.astro', '.css', '.html', '.js', '.json', '.md', '.mdx', '.mjs', '.svg', '.ts', '.txt', '.yaml', '.yml')

$scanRules = @(
    [pscustomobject]@{
        Name = 'Private Windows user path'
        Pattern = '(?i)C:\\Users\\[^\\\s]+'
    },
    [pscustomobject]@{
        Name = 'Private macOS user path'
        Pattern = '/Users/[^/\s]+'
    },
    [pscustomobject]@{
        Name = 'Email address'
        Pattern = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    },
    [pscustomobject]@{
        Name = 'Private key block'
        Pattern = '-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----'
    },
    [pscustomobject]@{
        Name = 'Likely credential assignment'
        Pattern = '(?i)(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]\s*\S{8,}'
    },
    [pscustomobject]@{
        Name = 'Private IPv4 address'
        Pattern = '(?<!\d)(?:10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.(?:\d{1,3}\.)\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.(?:\d{1,3}\.)\d{1,3})(?!\d)'
    },
    [pscustomobject]@{
        Name = 'Local or internal URL'
        Pattern = '(?i)https?://(?:localhost|127\.0\.0\.1|[^/\s]+\.(?:local|internal))(?:[:/\s]|$)'
    },
    [pscustomobject]@{
        Name = 'Conversation identifier'
        Pattern = '(?i)conversation[_ -]?id\s*[:=]\s*[A-Za-z0-9_-]+'
    }
)

$publicFiles = foreach ($relativePath in $ScanPath) {
    $candidatePath = Join-Path $repoRootPath $relativePath
    if (-not (Test-Path -LiteralPath $candidatePath)) {
        Write-Warning "Scan target does not exist: $relativePath"
        continue
    }

    $candidateItem = Get-Item -LiteralPath $candidatePath
    if ($candidateItem.PSIsContainer) {
        Get-ChildItem -LiteralPath $candidateItem.FullName -Recurse -File |
            Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() }
    }
    elseif ($textExtensions -contains $candidateItem.Extension.ToLowerInvariant()) {
        $candidateItem
    }
}

$publicFiles = @($publicFiles | Sort-Object -Property FullName -Unique)
if ($publicFiles.Count -eq 0) {
    Write-Error 'No public text files were found to scan.'
    exit 1
}

$findings = foreach ($rule in $scanRules) {
    Select-String -LiteralPath $publicFiles.FullName -Pattern $rule.Pattern -AllMatches | ForEach-Object {
        [pscustomobject]@{
            Rule = $rule.Name
            File = [System.IO.Path]::GetRelativePath($repoRootPath, $_.Path)
            Line = $_.LineNumber
            Text = $_.Line.Trim()
        }
    }
}

$findings = @($findings)
if ($findings.Count -gt 0) {
    Write-Warning 'Potential public-content findings require human classification.'
    $findings | Sort-Object File, Line, Rule | Format-Table -AutoSize
    Write-Host 'Classify every finding as REMOVE, GENERALIZE, ASK USER, or SAFE before publication.'
    exit 1
}

Write-Host "PASS: scanned $($publicFiles.Count) public text files; no configured private/workplace patterns were found."
exit 0
