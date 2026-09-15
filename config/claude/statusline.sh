#!/usr/bin/env bash
# Claude Code status line.
# Reads the harness JSON payload on stdin; prints two colored lines:
#
#   <dir>                                  <branch+state> <diff> <version> <pr>
#   <model>                                          [ctx] · [5h] · [7d]
#
# Each line is justified: the left group is fixed, the right group is flush to
# the terminal's right edge, so a long branch name grows leftward into the gap
# instead of shoving the rest of the line around. When the window is too narrow
# to hold everything, segments are dropped by priority — nothing ever wraps.
#
# Payload schema: `claude` binary, "How to use the statusLine command".
# Icons are plain Unicode, deliberately NOT emoji: emoji-presentation glyphs
# render double-width, which would silently break the column math below.
#
# Knobs: CLAUDE_STATUSLINE_{BARS,BAR_WIDTH,BRANCH_MAX,MARGIN}

# ── payload ──────────────────────────────────────────────────────────────────
# One jq pass for every field — this runs on a timer, so don't fork per lookup.
# Delimiter is US (0x1f), not tab: bash collapses runs of IFS *whitespace*, which
# would silently shift every field after an absent one. For the same reason the
# reset timestamps are turned into "seconds from now" here rather than with
# `// empty`, which would drop the element and shift every field after it.
IFS=$'\x1f' read -r cur_dir proj_dir wt name effort thinking fast \
                    pr pr_state used_ctx used_5h in_5h used_7d in_7d < <(
  jq -r '[ (.cwd // .workspace.current_dir), .workspace.project_dir, .worktree.name,
           .model.display_name, .effort.level, .thinking.enabled, .fast_mode,
           .pr.number, .pr.review_state,
           .context_window.used_percentage,
           .rate_limits.five_hour.used_percentage,
           (if .rate_limits.five_hour.resets_at
              then (.rate_limits.five_hour.resets_at - now | floor) else null end),
           .rate_limits.seven_day.used_percentage,
           (if .rate_limits.seven_day.resets_at
              then (.rate_limits.seven_day.resets_at - now | floor) else null end)
         ] | map(if . == null then "" else tostring end) | join("")' 2>/dev/null
)

cd "$cur_dir" 2>/dev/null || cd "$proj_dir" 2>/dev/null

# ── palette ──────────────────────────────────────────────────────────────────
# Real escape bytes, not the literal "\033[" text a %b would expand later: the
# justifier measures segments with ${#s}, which would otherwise count the
# backslashes as printed columns.
C_DIR=$'\033[36m' C_GIT=$'\033[35m' C_VER=$'\033[33m' C_PR=$'\033[34m'
C_MODEL=$'\033[32m' C_DIM=$'\033[90m' C_BAD=$'\033[31m' C_WARN=$'\033[33m'
C_ADD=$'\033[32m' C_DEL=$'\033[31m' R=$'\033[0m'
# Each budget keeps its own hue on the icon+label so the three brackets stay
# telling apart at a glance; only the bar and the number carry severity. Letting
# the gradient own the whole bracket made all three identical whenever the
# budgets happened to agree — which is most of the time.
C_CTX=$'\033[36m' C_5H=$'\033[33m' C_7D=$'\033[35m'

ICON_GIT='⎇' ICON_WT='⑂' ICON_PR='⇅' ICON_STASH='⚑' ICON_FAST='↯'
ICON_CTX='◔' ICON_5H='◷' ICON_7D='⊞' ICON_UNPUSHED='⇧'
# Single-width superscript (NOT emoji), like ↑/↓ above — appended to the version
# when the branch carries committed work beyond the cut release.
ICON_UNREL='⁺'
PIP_FULL='▰' PIP_EMPTY='▱'

# grad <badness 0-100> → $grad_out, a green→amber→red color. Truecolor when the
# terminal advertises it, else the 256-color cube. Replaces fixed thresholds, so
# a budget visibly warms up as it drains instead of snapping between three states.
if [[ ${COLORTERM:-} == *truecolor* || ${COLORTERM:-} == *24bit* ]]; then
  grad() { local b=$1 t r g v
    ((b < 0)) && b=0; ((b > 100)) && b=100
    if ((b <= 50)); then t=$((b * 2))                    # green → amber
      r=$((98 + (232 - 98) * t / 100))
      g=$((209 + (193 - 209) * t / 100))
      v=$((150 + (84 - 150) * t / 100))
    else t=$(((b - 50) * 2))                             # amber → red
      r=$((232 + (235 - 232) * t / 100))
      g=$((193 + (94 - 193) * t / 100))
      v=$((84 + (86 - 84) * t / 100))
    fi
    grad_out=$'\033[38;2;'"$r;$g;$v"'m'; }
else
  GRAMP=(46 82 118 154 190 226 220 214 208 202 196)
  grad() { local b=$1
    ((b < 0)) && b=0; ((b > 100)) && b=100
    grad_out=$'\033[38;5;'"${GRAMP[b / 10]}"'m'; }
fi

# ── layout primitives ────────────────────────────────────────────────────────
join() { local s=$1; shift; local IFS=; local out=; local first=1
  for x in "$@"; do [ -n "$x" ] || continue
    [ $first -eq 1 ] && out=$x || out="$out$s$x"; first=0; done
  printf '%s' "$out"; }

# strip <string> → $strip_out, the string minus its ANSI SGR escapes, so that
# ${#strip_out} is the printed width. Pure bash: this runs on every render.
strip() { local s=$1 out=
  while [[ $s == *$'\033['* ]]; do
    out+=${s%%$'\033['*}; s=${s#*$'\033['}; s=${s#*m}
  done
  strip_out=$out$s; }

vislen() { strip "$1"; printf '%s' "${#strip_out}"; }

# Terminal width. The harness gives this script no controlling terminal: stdout
# is a pipe, /dev/tty is "device not configured", and COLUMNS arrives as 0. So
# ask the nearest ancestor that *does* own a tty (the `claude` process) how wide
# its terminal is. Re-read every render, so a window resize is picked up.
cols=${CLAUDE_STATUSLINE_COLS:-}      # escape hatch; also how the tests drive it
pid=$PPID
[ -n "$cols" ] && pid=0
for _ in 1 2 3 4 5; do
  [ -n "$cols" ] && break
  read -r tty_name parent < <(ps -o tty=,ppid= -p "$pid" 2>/dev/null)
  case $tty_name in
    '' | '??' | '-') ;;
    *) # ps reports "ttys004" on macOS but bare "s004" on some BSDs.
      for dev in "/dev/$tty_name" "/dev/tty$tty_name"; do
        [ -c "$dev" ] || continue
        size=$(stty size <"$dev" 2>/dev/null) && { cols=${size#* }; break; }
      done
      [ -n "$cols" ] && break ;;
  esac
  [ -n "$parent" ] && [ "$parent" -gt 1 ] 2>/dev/null || break
  pid=$parent
done
[ "${cols:-0}" -ge 40 ] 2>/dev/null || cols=80

# The harness indents the status line ~2 columns and the last usable column is
# best left empty (a glyph in it can arm the terminal's pending-wrap). Raise this
# if a line ever wraps; lower it to push the right group closer to the edge.
MARGIN=${CLAUDE_STATUSLINE_MARGIN:-3}

# row <left> <right> → $row_out, one justified line. $row_fit is false when the
# two groups couldn't be kept apart, which is the signal to shed a segment.
row() { local l=$1 r=$2 lw rw gap
  row_fit=1
  if [ -z "$r" ]; then row_out=$l; return; fi
  if [ -z "$l" ]; then row_out=$r; return; fi
  lw=$(vislen "$l"); rw=$(vislen "$r")
  gap=$((cols - MARGIN - lw - rw))
  if [ "$gap" -lt 2 ]; then gap=1; row_fit=0; fi
  printf -v row_out '%s%*s%s' "$l" "$gap" "" "$r"; }

# bar <fill 0-100> <fill-color> → $bar_out. Filled pips take the severity color,
# the empty track stays dim, so the meter reads without shouting.
BAR_WIDTH=${CLAUDE_STATUSLINE_BAR_WIDTH:-8}
bar() { local pct=$1 color=$2 i filled full= empty=
  filled=$(((pct * BAR_WIDTH + 50) / 100))
  ((filled < 0)) && filled=0; ((filled > BAR_WIDTH)) && filled=$BAR_WIDTH
  for ((i = 0; i < filled; i++)); do full+=$PIP_FULL; done
  for ((i = filled; i < BAR_WIDTH; i++)); do empty+=$PIP_EMPTY; done
  bar_out="${color}${full}${R}${C_DIM}${empty}${R}"; }

# dur <seconds> → $dur_out, a compact "3d2h" / "2h14m" / "47m".
dur() { local s=$1 d h m
  ((s < 0)) && s=0
  d=$((s / 86400)) h=$((s % 86400 / 3600)) m=$((s % 3600 / 60))
  if ((d > 0)); then dur_out="${d}d ${h}h"
  elif ((h > 0)); then dur_out="${h}h ${m}m"
  else dur_out="${m}m"; fi; }

# ── where you are ────────────────────────────────────────────────────────────
# Just the folder name. When cwd is nested inside the project, show the project
# root plus the trailing path so "src/components" doesn't read as a bare "src".
place=""
if [ -n "$cur_dir" ]; then
  label=${cur_dir##*/}
  if [ -n "$proj_dir" ] && [ "$cur_dir" != "$proj_dir" ] && [ "${cur_dir#"$proj_dir"/}" != "$cur_dir" ]; then
    label="${proj_dir##*/}/${cur_dir#"$proj_dir"/}"
  fi
  place="${C_DIR}${label}${R}"
fi

# ── what the repo is doing ───────────────────────────────────────────────────
# One `git status` carries branch, upstream, ahead/behind, dirty, conflicts,
# untracked and stash count — it replaces three separate git calls and still
# tells us more than they did. --show-stash is newer than porcelain=v2, so fall
# back without it rather than losing every git segment on an older git.
branch='' oid='' upstream='' ahead=0 behind=0 stash=0 untracked=0 conflicts=0 dirty=''
in_repo=0
if status=$(git status --porcelain=v2 --branch --show-stash 2>/dev/null) ||
   status=$(git status --porcelain=v2 --branch 2>/dev/null); then
  in_repo=1
  while IFS= read -r ln; do
    case $ln in
      '# branch.head '*) branch=${ln#\# branch.head } ;;
      '# branch.oid '*) oid=${ln#\# branch.oid } ;;
      '# branch.upstream '*) upstream=${ln#\# branch.upstream } ;;
      '# branch.ab '*) ab=${ln#\# branch.ab }
        ahead=${ab%% *}; ahead=${ahead#+}
        behind=${ab##* }; behind=${behind#-} ;;
      '# stash '*) stash=${ln#\# stash } ;;
      '1 '* | '2 '*) dirty='*' ;;
      'u '*) conflicts=$((conflicts + 1)); dirty='*' ;;
      '? '*) untracked=$((untracked + 1)) ;;
    esac
  done <<<"$status"
  [ "$branch" = '(detached)' ] && branch=${oid:0:7}
fi

# Mid-operation is the one repo state where not knowing costs real time, so it
# gets a loud banner of its own rather than another quiet marker on the branch.
op=''
if [ "$in_repo" = 1 ] && gitdir=$(git rev-parse --git-dir 2>/dev/null); then
  if [ -d "$gitdir/rebase-merge" ]; then
    op='REBASING'
    if [ -f "$gitdir/rebase-merge/msgnum" ] && [ -f "$gitdir/rebase-merge/end" ]; then
      op="REBASING $(<"$gitdir/rebase-merge/msgnum")/$(<"$gitdir/rebase-merge/end")"
    fi
  elif [ -d "$gitdir/rebase-apply" ]; then op='REBASING'
  elif [ -f "$gitdir/MERGE_HEAD" ]; then op='MERGING'
  elif [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then op='CHERRY-PICKING'
  elif [ -f "$gitdir/REVERT_HEAD" ]; then op='REVERTING'
  elif [ -f "$gitdir/BISECT_LOG" ]; then op='BISECTING'
  fi
  [ -n "$op" ] && [ "$conflicts" -gt 0 ] && op+=" ✗$conflicts"
fi

# shorten <string> <max> — head-truncate, ellipsis included in the budget. Set 0
# to disable. Only a backstop now: the branch is right-aligned, so it grows into
# the empty middle of the line rather than displacing anything.
BRANCH_MAX=${CLAUDE_STATUSLINE_BRANCH_MAX:-30}
shorten() { local s=$1 max=$2
  if [ "${max:-0}" -ge 2 ] 2>/dev/null && [ ${#s} -gt "$max" ]; then
    printf '%s…' "${s:0:max-1}"
  else printf '%s' "$s"; fi; }

seg_branch='' seg_stash='' seg_untracked='' seg_diff='' seg_ver='' seg_pr='' seg_op=''

# branch_seg <max> → $seg_branch. Re-callable so the narrow tiers can shrink the
# branch instead of dropping it — a nameless line is worse than a clipped one.
branch_seg() { local max=$1 b bc
  b=$(shorten "$branch" "$max")
  # An unpublished branch is easy to miss and is how work gets lost, so it warms
  # the branch name itself rather than costing a column.
  bc=$C_GIT
  [ -z "$upstream" ] && bc=$C_WARN
  seg_branch="${bc}${ICON_GIT} ${b}${dirty}"
  [ "$ahead" -gt 0 ] 2>/dev/null && seg_branch+="↑$ahead"
  [ "$behind" -gt 0 ] 2>/dev/null && seg_branch+="↓$behind"
  seg_branch+="$R"
  [ -z "$upstream" ] && seg_branch+="${C_DIM}${ICON_UNPUSHED}${R}"
  [ -n "$wt" ] && seg_branch+=" ${C_DIM}${ICON_WT}${wt}${R}"; }

if [ "$in_repo" = 1 ]; then
  branch_seg "$BRANCH_MAX"

  [ "$stash" -gt 0 ] 2>/dev/null && seg_stash="${C_DIM}${ICON_STASH}${stash}${R}"
  [ "$untracked" -gt 0 ] && seg_untracked="${C_DIM}?${untracked}${R}"
  [ -n "$op" ] && seg_op="${C_BAD}${op}${R}"

  add=0 del=0
  while read -r a d _; do
    [[ $a == [0-9]* ]] || continue           # binary files report "-"
    add=$((add + a)); del=$((del + d))
  done < <(git diff HEAD --numstat 2>/dev/null)
  if [ "$add" -gt 0 ] || [ "$del" -gt 0 ]; then
    seg_diff="${C_ADD}+${add}${R}${C_DIM}/${R}${C_DEL}-${del}${R}"
  fi
fi

# Release version — universal across languages, first hit wins. release-please
# writes .release-please-manifest.json into every migrated repo (JS/Go/Python
# alike), and it's committed, so it names the release on THIS branch/commit — the
# one signal that works regardless of language. Language manifests catch repos not
# yet on release-please; the newest git tag is the last resort. All parsed
# in-process: this runs on a timer, so no jq/awk fork per lookup.
ver=''
for d in "$cur_dir" "$proj_dir"; do
  [ -n "$d" ] || continue

  # 1) release-please manifest — the "." package, else the first version value.
  if [ -z "$ver" ] && [ -f "$d/.release-please-manifest.json" ]; then
    first=''
    while IFS= read -r ln || [ -n "$ln" ]; do
      if [[ $ln =~ \"\.\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        ver=${BASH_REMATCH[1]}; break
      fi
      [ -z "$first" ] && [[ $ln =~ :[[:space:]]*\"([0-9][^\"]*)\" ]] && first=${BASH_REMATCH[1]}
    done <"$d/.release-please-manifest.json"
    [ -z "$ver" ] && ver=$first
  fi

  # 2) package.json (legacy / un-migrated JS repos)
  if [ -z "$ver" ] && [ -f "$d/package.json" ]; then
    while IFS= read -r ln || [ -n "$ln" ]; do
      if [[ $ln =~ \"version\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        ver=${BASH_REMATCH[1]}; break
      fi
    done <"$d/package.json"
  fi

  # 3) pyproject.toml (Python) — top-level `version = "…"` under [project] or
  #    [tool.poetry]; a dependency's version is indented, so anchor to column 0.
  if [ -z "$ver" ] && [ -f "$d/pyproject.toml" ]; then
    while IFS= read -r ln || [ -n "$ln" ]; do
      if [[ $ln =~ ^version[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
        ver=${BASH_REMATCH[1]}; break
      fi
    done <"$d/pyproject.toml"
  fi

  # 4) plain VERSION file (whatever else keeps one)
  if [ -z "$ver" ] && [ -f "$d/VERSION" ]; then
    IFS= read -r ver <"$d/VERSION"; ver=${ver//[[:space:]]/}
  fi

  [ -n "$ver" ] && break
done

# 5) last resort: newest reachable git tag (any tagged repo with no manifest).
if [ -z "$ver" ] && [ "$in_repo" = 1 ]; then
  t=$(git describe --tags --abbrev=0 2>/dev/null) && ver=${t#v}
fi

if [ -n "$ver" ]; then
  seg_ver="${C_VER}v${ver}${R}"
  # Unreleased marker: does HEAD's committed tree differ from the release tag's?
  # Tree-compare (not commit count) so a dev→main promote — a merge commit atop
  # the release's tree — still reads as released, while dev carrying real work
  # gets the ⁺. Only fires when the matching tag (v$ver, then $ver) is local.
  if [ "$in_repo" = 1 ]; then
    head_tree=$(git rev-parse -q --verify "HEAD^{tree}" 2>/dev/null)
    for tag in "v$ver" "$ver"; do
      tag_tree=$(git rev-parse -q --verify "refs/tags/$tag^{tree}" 2>/dev/null) || continue
      [ -n "$head_tree" ] && [ "$tag_tree" != "$head_tree" ] &&
        seg_ver="${C_VER}v${ver}${R}${C_DIM}${ICON_UNREL}${R}"
      break
    done
  fi
fi

if [ -n "$pr" ]; then
  case $pr_state in
    approved) mark='✓' ;;
    changes_requested) mark='✗' ;;
    draft) mark='◌' ;;
    *) mark='' ;;
  esac
  seg_pr="${C_PR}${ICON_PR} #${pr}${mark:+ $mark}${R}"
fi

# ── model ────────────────────────────────────────────────────────────────────
model=''
if [ -n "$name" ]; then
  base=${name%% (*}
  paren=${name#"$base"}
  model="${C_MODEL}${base}${R}"
  [ -n "$paren" ] && model+="${C_DIM}${paren}${R}"
  [ -n "$effort" ] && model+="${C_DIM}·${effort}${R}"
  [ "$thinking" = true ] && model+="${C_DIM}*${R}"
  [ "$fast" = true ] && model+=" ${C_WARN}${ICON_FAST}${R}"
fi

# ── budgets ──────────────────────────────────────────────────────────────────
# stats <bars?> <countdowns?> → $stats_out. All three are *spent* percentages, so
# a full bar always means nearly out and badness is just the number itself.
SHOW_BARS=${CLAUDE_STATUSLINE_BARS:-1}
stats() { local bars=$1 clocks=$2 keep=$3 out=() item pct fill bad hue n=0
  # ctx first: it's the one you can act on right now. 7d is the first to go.
  for w in "ctx:$used_ctx:$ICON_CTX:" "5h:$used_5h:$ICON_5H:$in_5h" "7d:$used_7d:$ICON_7D:$in_7d"; do
    IFS=: read -r lbl pct icon secs <<<"$w"
    [ -n "$pct" ] || continue
    n=$((n + 1)); [ "$n" -gt "$keep" ] && break
    pct=${pct%.*}
    case $lbl in
      ctx) hue=$C_CTX ;;
      5h) hue=$C_5H ;;
      *) hue=$C_7D ;;
    esac
    fill=$pct; bad=$pct
    grad "$bad"
    item="${C_DIM}[${R}${hue}${icon} ${lbl}${R} "
    if [ "$bars" = 1 ]; then bar "$fill" "$grad_out"; item+="${bar_out} "; fi
    item+="${grad_out}${pct}%${R}"
    if [ "$clocks" = 1 ] && [ -n "$secs" ]; then
      dur "$secs"; item+=" ${C_DIM}${dur_out}${R}"
    fi
    out+=("${item}${C_DIM}]${R}")
  done
  stats_out=$(join ' ' "${out[@]}"); }

# ── assemble, shedding the least useful segment until each line fits ─────────
# Ordered least-useful first. What you're on (branch) and the mid-operation
# banner survive to the end; the branch shrinks rather than disappearing.
line1=''
for tier in none untracked stash version diff pr branch16 branch8; do
  case $tier in
    untracked) seg_untracked='' ;;
    stash) seg_stash='' ;;
    version) seg_ver='' ;;
    diff) seg_diff='' ;;
    pr) seg_pr='' ;;
    branch16) [ "$in_repo" = 1 ] && branch_seg 16 ;;
    branch8) [ "$in_repo" = 1 ] && branch_seg 8 ;;
  esac
  row "$place" "$(join '  ' "$seg_op" "$seg_branch" "$seg_stash" "$seg_untracked" \
                            "$seg_diff" "$seg_ver" "$seg_pr")"
  line1=$row_out
  [ "$row_fit" = 1 ] && break
done

# Same idea: bars are decoration, the reset clocks are nice-to-know, the 7d
# window is the least urgent, and the model's "(1M context)" tail is the last
# thing worth a column.
model_short=${model%%"${C_DIM}"*}
line2=''
for tier in full nobars noclocks drop7d drop5h shortmodel; do
  case $tier in
    full) [ "$SHOW_BARS" = 1 ] && stats 1 1 3 || stats 0 1 3 ;;
    nobars) stats 0 1 3 ;;
    noclocks) stats 0 0 3 ;;
    drop7d) stats 0 0 2 ;;
    drop5h) stats 0 0 1 ;;
    shortmodel) model=$model_short ;;
  esac
  row "$model" "$stats_out"
  line2=$row_out
  [ "$row_fit" = 1 ] && break
done

# No trailing newline: the harness supplies the final break, and emitting our
# own would render as an empty third row.
if [ -n "$line2" ]; then
  printf '%s\n%s' "$line1" "$line2"
else
  printf '%s' "$line1"
fi
