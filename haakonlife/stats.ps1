# The `haakonlife` command: play time and leaderboard stats from Haakon Life's live database.
# A PowerShell port of Linux-Setup's haakonlife/stats.mjs, so it needs nothing but PowerShell 7.
# It only reads, and sends nothing. The list of boards comes from js/game.js in the game's repo, so
# a new game's board turns up here on its own. Set HAAKONLIFE_REPO if the repo isn't at
# ~\GitHub\HaakonLife.
#
# Local times come from Windows' own time zone data (TimeZoneInfo), which Windows Update keeps
# current, so they agree with the taskbar clock. (The Node version has to ask `date` for this,
# because Node's built-in copy of the tz database can lag the system's.)

$ErrorActionPreference = 'Stop'

$DB = 'https://haakonlife-d4ef2-default-rtdb.firebaseio.com'
$REPO = if ($env:HAAKONLIFE_REPO) { $env:HAAKONLIFE_REPO } else { Join-Path $HOME 'GitHub\HaakonLife' }
$inv = [Globalization.CultureInfo]::InvariantCulture
$tty = -not [Console]::IsOutputRedirected
$width = try { [Console]::WindowWidth } catch { 0 }
$COLS = [Math]::Max(60, $(if ($width -gt 0) { $width } else { 100 }))
$ESC = [char]27

function bold($s) { if ($tty) { "$ESC[1m$s$ESC[0m" } else { $s } }
function dim($s) { if ($tty) { "$ESC[2m$s$ESC[0m" } else { $s } }
$script:first = $true
function heading($title, $note) {
  $line = $(if ($script:first) { '' } else { "`n" }) + (bold $title) + $(if ($note) { '  ' + (dim $note) } else { '' })
  $script:first = $false
  Write-Output $line
}
# Names come from the database, which anybody can write to, so keep them to plain text.
function plain($s) {
  $t = $(if ($null -eq $s) { '?' } else { [string]$s }) -replace '[\x00-\x1f\x7f-\x9f]', ''
  if ($t.Length -gt 16) { $t.Substring(0, 16) } else { $t }
}
function ordinal([long]$n) {
  $s = 'th', 'st', 'nd', 'rd'
  $v = $n % 100
  $i = ($v - 20) % 10
  $suffix = if ($i -ge 1 -and $i -le 3) { $s[$i] } elseif ($v -ge 1 -and $v -le 3) { $s[$v] } else { $s[0] }
  "$n$suffix"
}
function hours($s) { '{0}h {1:00}m' -f [Math]::Floor($s / 3600), ([Math]::Floor($s / 60) % 60) }
function ago($t) {
  $s = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $t) / 1000
  if ($s -lt 60) { 'just now' }
  elseif ($s -lt 3600) { "$([Math]::Floor($s / 60))m ago" }
  elseif ($s -lt 86400) { "$([Math]::Floor($s / 3600))h ago" }
  else { "$([Math]::Floor($s / 86400))d ago" }
}
$dtf = (Get-Culture).DateTimeFormat
function localTime($t) {
  $d = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$t).LocalDateTime
  $d.ToString($dtf.ShortDatePattern) + ', ' + $d.ToString($dtf.LongTimePattern)
}
function isNum($v) { $v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal] -or $v -is [bigint] }
function num($v) { if ($v -is [double]) { $v.ToString('R', $inv) } else { [string]$v } }
# A list of words wrapped to the terminal, with the lines after the first indented.
function wrap($words, $indent) {
  $lines = [Collections.Generic.List[string]]::new()
  $cur = ''
  foreach ($w in $words) {
    if ($cur -and $indent + $cur.Length + 2 + $w.Length -gt $COLS) { $lines.Add($cur + ','); $cur = $w }
    elseif ($cur) { $cur = $cur + ', ' + $w }
    else { $cur = $w }
  }
  if ($cur) { $lines.Add($cur) }
  $lines -join ("`n" + (' ' * $indent))
}

# The database's entries as (key, value) pairs. Firebase sends a list instead of an object when
# every key is a number, so take either.
function entries($d) {
  if ($d -is [Collections.IDictionary]) { foreach ($k in $d.Keys) { , @($k, $d[$k]) } }
  elseif ($d -is [array]) { for ($i = 0; $i -lt $d.Count; $i++) { if ($null -ne $d[$i]) { , @([string]$i, $d[$i]) } } }
}

# Every read starts at once, as the Node version's Promise.all does, then each is waited on.
$http = [Net.Http.HttpClient]::new()
$http.Timeout = [TimeSpan]::FromSeconds(15)
function startGet($path) { @{ path = $path; task = $http.GetAsync("$DB/$path.json") } }
function finishGet($req) {
  try { $r = $req.task.GetAwaiter().GetResult() }
  catch { throw "$($req.path) ($($_.Exception.InnerException.Message ?? $_.Exception.Message))" }
  if (-not $r.IsSuccessStatusCode) { throw "$($req.path) ($([int]$r.StatusCode))" }
  $json = $r.Content.ReadAsStringAsync().GetAwaiter().GetResult()
  $v = ConvertFrom-Json $json -AsHashtable -NoEnumerate
  if ($v -is [Collections.IDictionary] -or $v -is [array]) { , $v } else { @{} }
}
# keys as the database has them: "Sam" and "sam" are different rows, as they are in a JS Map
function newMap { [Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal) }

# BOARDS in js/game.js, one @{ key; title; unit; low; net; unlisted } each
function readBoards {
  $src = [IO.File]::ReadAllText((Join-Path $REPO 'js\game.js'))
  $start = $src.IndexOf('const BOARDS = {')
  if ($start -lt 0) { throw 'no BOARDS in js/game.js' }
  $end = $src.IndexOf("`n  };", $start)
  $block = if ($end -lt 0) { $src.Substring($start) } else { $src.Substring($start, $end - $start) }
  foreach ($m in [regex]::Matches($block, "(\w+): \{ title: '((?:[^'\\]|\\.)*)'([^}]*)\}")) {
    $rest = $m.Groups[3].Value
    $unit = [regex]::Match($rest, "unit: ('(?:[^'\\]|\\.)*'|\w+)")
    [pscustomobject]@{
      key      = $m.Groups[1].Value
      title    = $m.Groups[2].Value -replace "\\'", "'"
      unit     = if ($unit.Success) { $unit.Groups[1].Value } else { $null }
      low      = $rest -match '\blow: true'
      net      = $rest -match '\bnet: true'
      unlisted = $rest -match '\bunlisted: true'
    }
  }
}

# how many cards there are to win: WINNABLE in js/game.js, which is what the board counts. That leaves
# out the starters (S), the ones only other cards bring in (T) and the versions of your own legendary
# (own), so it is smaller than the whole list. js/cardlist.js has one card to a line.
function cardTotal {
  try {
    $n = 0
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $REPO 'js\cardlist.js'))) {
      $r = [regex]::Match($line, "^\s*\{\s*id:.*\brarity: '(\w)'")
      if ($r.Success -and $r.Groups[1].Value -notin 'T', 'S' -and $line -notmatch '\bown: true') { $n++ }
    }
    $n
  } catch { 0 }
}

# the same units the game shows (tenths, racetime, times and goals in js/game.js)
function show($b, $score) {
  $n = if ($b.low) { -$score } else { $score } # lowest-wins boards are kept as negative numbers
  if ($b.unit -and $b.unit[0] -eq "'") { return (num $n) + ($b.unit.Substring(1, $b.unit.Length - 2) -replace "\\'", "'") }
  switch ($b.unit) {
    'tenths' { return ($n / 10).ToString('F1', $inv) + 's' }
    'racetime' { return "$([Math]::Floor($n / 600)):" + (($n % 600) / 10).ToString('F1', $inv).PadLeft(4, '0') }
    'times' { return "$(num $n) $(if ($n -eq 1) { 'time' } else { 'times' })" }
    'goals' { return "$(num $n) $(if ($n -eq 1) { 'goal' } else { 'goals' })" }
  }
  num $n
}
# best first, and the earlier of two equal scores, as the Hall of Fame does (byScore)
function byScore($rows) { @($rows | Sort-Object -Stable @{ e = { $_.score }; Descending = $true }, @{ e = { $_.t } }) }

# A board's rows. Live Hold'em keeps what each name won and lost as two boards, and the
# game shows the difference, so this does too.
function rowsFrom($d) {
  foreach ($e in entries $d) {
    $r = $e[1]
    if ($r -is [Collections.IDictionary] -and (isNum $r['score']) -and (isNum $r['t'])) {
      [pscustomobject]@{ id = $e[0]; name = plain $r['name']; score = $r['score']; t = $r['t'] }
    }
  }
}
function startBoard($b) {
  if ($b.net) { startGet "scores/$($b.key)won"; startGet "scores/$($b.key)lost" } else { startGet "scores/$($b.key)" }
}
function finishBoard($b, $reqs) {
  if (-not $b.net) { return , @(rowsFrom (finishGet $reqs[0])) }
  $won = rowsFrom (finishGet $reqs[0])
  $lost = rowsFrom (finishGet $reqs[1])
  $by = newMap
  foreach ($pair in @(@(1, $won), @(-1, $lost))) {
    foreach ($r in $pair[1]) {
      $o = $by[$r.id]
      if (-not $o) { $o = [pscustomobject]@{ id = $r.id; name = $r.name; score = 0; t = 0 }; $by[$r.id] = $o }
      $o.score += $pair[0] * $r.score
      if ($r.t -gt $o.t) { $o.t = $r.t } # (not [Math]::Max, which picks Int32 from the 0 and overflows)
    }
  }
  , @($by.Values)
}

try {
  $boards = @()
  try { $boards = @(readBoards | Where-Object { -not $_.unlisted }) } # the Christmas Cup isn't in the Hall of Fame
  catch { [Console]::Error.WriteLine("Couldn't read the boards from $REPO\js\game.js: $($_.Exception.InnerException.Message ?? $_.Exception.Message)") }
  $ptReq = startGet 'playtime/live'
  $boardReqs = @(foreach ($b in $boards) { , @(startBoard $b) })

  # ---------- play time ----------
  heading 'PLAY TIME'
  $pt = $null; $ptError = $null
  try { $pt = finishGet $ptReq } catch { $ptError = $_.Exception.Message }
  if ($ptError) { Write-Output "  Couldn't read it: $ptError" }
  else {
    $people = @(foreach ($e in entries $pt) {
        $p = $e[1]
        if ($p -is [Collections.IDictionary] -and (isNum $p['s']) -and (isNum $p['t'])) { [pscustomobject]@{ name = $p['name']; s = $p['s']; t = $p['t'] } }
      }) | Sort-Object -Stable @{ e = { $_.s }; Descending = $true }
    $people = @($people)
    $sum = ($people | Measure-Object -Property s -Sum).Sum ?? 0
    $total = if ($sum) { $sum } else { 1 }
    foreach ($p in $people) {
      $pct = "$([Math]::Round(100 * $p.s / $total, [MidpointRounding]::AwayFromZero))%"
      Write-Output ('  ' + (plain $p.name).PadRight(14) + ' ' + (hours $p.s).PadLeft(8) + ' ' + $pct.PadLeft(4) + '  last ' + (localTime $p.t))
    }
    Write-Output ('  ' + 'TOTAL'.PadRight(14) + ' ' + (hours $sum).PadLeft(8) + '       (' + $people.Count + ' names)')

    # ---------- who's been on ----------
    # A browser sends its play time every minute while somebody's playing, so a send in the
    # last 3 minutes means they're on now.
    heading "WHO'S BEEN ON"
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $midnight = ([DateTimeOffset][DateTime]::Today).ToUnixTimeMilliseconds()
    $since = { param($t0) @($people | Where-Object { $_.t -ge $t0 } | Sort-Object -Stable @{ e = { $_.t }; Descending = $true }) }
    $names = { param($list) if ($list.Count) { wrap @($list | ForEach-Object { plain $_.name }) 20 } else { dim 'nobody' } }
    $onNow = & $since ($now - 3 * 60000)
    $today = & $since $midnight
    $week = & $since ($now - 7 * 86400000)
    Write-Output ('  ' + 'Right now'.PadRight(13) + "$($onNow.Count)".PadLeft(3) + '  ' + (& $names $onNow))
    Write-Output ('  ' + 'Today'.PadRight(13) + "$($today.Count)".PadLeft(3) + '  ' + (& $names $today))
    Write-Output ('  ' + 'Last 7 days'.PadRight(13) + "$($week.Count)".PadLeft(3) + '  ' + (dim "of $($people.Count) names"))
  }

  $read = @(for ($i = 0; $i -lt $boards.Count; $i++) {
      $rows = try { finishBoard $boards[$i] $boardReqs[$i] } catch { $null }
      [pscustomobject]@{ b = $boards[$i]; rows = $rows }
    })
  $failed = @($read | Where-Object { $null -eq $_.rows })
  $boardsRead = @($read | Where-Object { $null -ne $_.rows })

  if ($boards.Count) {
    # ---------- crowns ----------
    $crowns = newMap
    $empty = 0
    foreach ($x in $boardsRead) {
      if (-not $x.rows.Count) { $empty++; continue }
      $top = (byScore $x.rows)[0]
      $c = $crowns[$top.id]
      if (-not $c) { $c = [pscustomobject]@{ name = $top.name; titles = [Collections.Generic.List[string]]::new() }; $crowns[$top.id] = $c }
      $c.titles.Add($x.b.title)
    }
    heading 'HALL OF FAME CROWNS' '#1 on each board'
    foreach ($c in (@($crowns.Values) | Sort-Object -Stable @{ e = { $_.titles.Count }; Descending = $true })) {
      Write-Output ('  ' + $c.name.PadRight(13) + "$($c.titles.Count)".PadLeft(3))
    }
    if ($empty) { Write-Output ('  ' + (dim "$empty boards with no scores yet")) }

    # ---------- most played ----------
    heading 'MOST-PLAYED GAMES' 'names with a score'
    $played = $boardsRead | Where-Object { $_.rows.Count } | Sort-Object -Stable @{ e = { $_.rows.Count }; Descending = $true } | Select-Object -First 10
    foreach ($x in $played) { Write-Output ('  ' + $x.b.title.PadRight(24) + "$($x.rows.Count)".PadLeft(3)) }

    # ---------- latest ----------
    # A row's time is when it last went up, so this is new bests (and every win, on the boards that count them).
    # The place is where that row stands on its board now, ranked as the Hall of Fame ranks it.
    heading 'LATEST SCORES' 'new bests, and every win on the boards that count them'
    $all = foreach ($x in $boardsRead) {
      $sorted = byScore $x.rows
      for ($i = 0; $i -lt $sorted.Count; $i++) {
        $r = $sorted[$i]
        [pscustomobject]@{ name = $r.name; score = $r.score; t = $r.t; b = $x.b; place = $i + 1; of = $sorted.Count }
      }
    }
    $latest = @($all | Sort-Object -Stable @{ e = { $_.t }; Descending = $true } | Select-Object -First 10 |
        ForEach-Object { $_ | Add-Member -NotePropertyName shown -NotePropertyValue (show $_.b $_.score) -PassThru })
    $scoreW = [int](@(0) + @($latest | ForEach-Object { $_.shown.Length }) | Measure-Object -Maximum).Maximum + 3
    foreach ($r in $latest) {
      Write-Output ('  ' + (ago $r.t).PadRight(10) + $r.name.PadRight(13) + $r.b.title.PadRight(24) + $r.shown.PadRight($scoreW) + (ordinal $r.place).PadLeft(4) + ' ' + (dim "of $($r.of)"))
    }

    # ---------- Morale Madness ----------
    $top10 = { param($key)
      $x = $boardsRead | Where-Object { $_.b.key -eq $key } | Select-Object -First 1
      if ($x) { @(byScore $x.rows | Select-Object -First 10) } else { @() }
    }
    $cards = @(& $top10 'cards'); $wins = @(& $top10 'cardwins'); $of = cardTotal
    heading 'MORALE MADNESS'
    Write-Output ('  ' + ('Most cards' + $(if ($of) { " (of $of)" } else { '' })).PadRight(26) + 'Most wins')
    $cell = { param($r, $i) if ($r) { "$($i + 1)".PadLeft(2) + ' ' + $r.name.PadRight(13) + (num $r.score).PadLeft(4) } else { '' } }
    for ($i = 0; $i -lt [Math]::Max($cards.Count, $wins.Count); $i++) {
      Write-Output (('  ' + (& $cell $cards[$i] $i).PadRight(26) + (& $cell $wins[$i] $i)).TrimEnd())
    }

    if ($failed.Count) { Write-Output ("`n" + (dim "Couldn't read $($failed.Count) boards: $(($failed | ForEach-Object { $_.b.key }) -join ', ')")) }
  }
} finally {
  $http.Dispose()
}
