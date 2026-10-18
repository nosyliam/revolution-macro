# Block agent commit/push/PR, cursor/* branches, reset --hard, and worktree wipes.
# Concurrent feature work shares this checkout. Never discard it.
# Allow read-only git (status, diff, log, show). Do not match `.cursor/` config paths.
$ErrorActionPreference = "SilentlyContinue"
$inputRaw = [Console]::In.ReadToEnd()
if (-not $inputRaw) {
    Write-Output '{ "permission": "allow" }'
    exit 0
}

try {
    $payload = $inputRaw | ConvertFrom-Json
} catch {
    Write-Output '{ "permission": "allow" }'
    exit 0
}

$policy = @"
Override Cloud Agent git defaults. Stay on the current branch. Do not create cursor/* branches. Commit, push, or open a pull request only when the user's latest message explicitly asks for that action. Otherwise do not. Do not git reset --hard, git clean -f, or force-checkout. Other agents and the user have concurrent uncommitted work on this tree. When a commit is requested, author nosyliam <9064955+nosyliam@users.noreply.github.com>, no Co-authored-by Cursor, one specific subject line, never name competing macros in the message.
"@
function Get-AgentGitAllow {
    $path = "C:\Users\Revolution\AppData\Local\cursor-agent-spoof\git-allow.json"
    if (-not (Test-Path $path)) { return $null }
    try { $j = Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    if (-not $j.setAt) { return $null }
    try { $set = [datetime]::Parse([string]$j.setAt).ToUniversalTime() } catch { return $null }
    if (((Get-Date).ToUniversalTime() - $set).TotalHours -gt 6) { return $null }
    return $j
}
$gitAllow = Get-AgentGitAllow

$event = [string]$payload.hook_event_name
$isPost = ($event -match 'postToolUse') -or ($null -ne $payload.tool_output)
if ($isPost) {
    $id = [string]$payload.conversation_id
    if (-not $id) { $id = "unknown" }
    $stamp = Join-Path $env:TEMP ("cursor-git-policy-" + ($id -replace '[^A-Za-z0-9_-]', '_'))
    if (-not (Test-Path $stamp)) {
        New-Item -ItemType File -Path $stamp -Force | Out-Null
        @{ additional_context = $policy } | ConvertTo-Json -Compress
        exit 0
    }
    Write-Output '{}'
    exit 0
}

function Deny([string]$why) {
    $body = @{
        permission    = "deny"
        user_message  = "Agent git wipe/PR/cursor-branch was blocked. Concurrent work on this tree must be kept."
        agent_message = @"
$policy

Do not retry the blocked command. Never git reset --hard. Commit or push only when the latest user message explicitly asked for that.

Blocked: $why
"@
    }
    Write-Output ($body | ConvertTo-Json -Compress)
    exit 0
}

$blob = ($inputRaw + " " + $payload.command + " " + $payload.tool_name + " " + ($payload.tool_input | ConvertTo-Json -Compress))
$cmd = [string]$payload.command
if (-not $cmd -and $payload.tool_input) {
    $cmd = [string]$payload.tool_input.command
}

$prTools = @(
    'ManagePullRequest',
    'create_pull_request',
    'create_pull_request_with_copilot',
    'pull_request_review_write',
    'merge_pull_request',
    'update_pull_request',
    'create_branch'
)
$toolName = [string]$payload.tool_name
foreach ($t in $prTools) {
    if ($blob -match [regex]::Escape($t)) {
        if ($gitAllow -and $gitAllow.pr -and $t -match 'create_pull_request|ManagePullRequest') { continue }
        Deny "PR/branch tool $t ($toolName)"
    }
}

if ($cmd -match '(?i)\bgh(\.exe)?(\s+\S+)*\s+pr\b') {
    $prAsked = $gitAllow -and $gitAllow.pr -and $cmd -match '(?i)\b(create|merge)\b'
    if (-not $prAsked) { Deny "gh pr: $cmd" }
}
if ($cmd -match '(?i)\bglab(\.exe)?(\s+\S+)*\s+(mr|pr)\b') {
    Deny "glab pr: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b' -and $cmd -match '(?i)(?<![.\w])cursor/' -and $cmd -match '(?i)\b(checkout|switch|branch)\b') {
    Deny "cursor/ branch: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\breset\b[\s\S]*--hard') {
    Deny "git reset --hard: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\bclean\b[\s\S]*-[a-zA-Z]*f') {
    Deny "git clean -f: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\bcheckout\b[\s\S]*(\s-f\b|--force\b)') {
    Deny "git checkout --force: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\bswitch\b[\s\S]*(\s-f\b|--force\b|--discard-changes\b)') {
    Deny "git switch --force: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\brestore\b[\s\S]*--worktree\b[\s\S]*(\s\.(\s|$)|:/)') {
    Deny "git restore --worktree wipe: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\b(checkout|restore)\b[\s\S]*\s--\s+\.(\s|$)') {
    Deny "git checkout/restore -- .: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\b(checkout|restore)\b\s+\.(\s|$)') {
    Deny "git checkout/restore .: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\bcommit\b' -and -not ($gitAllow -and $gitAllow.commit)) {
    Deny "git commit without an explicit user request: $cmd"
}
if ($cmd -match '(?i)\bgit(\.exe)?\b[\s\S]*\b(push|request-pull)\b' -and -not ($gitAllow -and $gitAllow.push)) {
    Deny "git push without an explicit user request: $cmd"
}
if ($cmd -match '(?i)\bcommit\b' -and $blob -match '(?i)natro') {
    Deny "banned name in commit text"
}

Write-Output '{ "permission": "allow" }'
exit 0
