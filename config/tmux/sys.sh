#!/usr/bin/env bash
# 1-minute load average, color-graded against core count.
# green  : < 60% of cores busy
# amber  : 60%–100%
# red    : oversubscribed
read -r load _ </proc/loadavg
cores=$(nproc 2>/dev/null || echo 1)
color=$(awk -v l="$load" -v c="$cores" 'BEGIN{
  if (l < c*0.6) print "#a6e3a1";
  else if (l < c)  print "#f9e2af";
  else             print "#f38ba8";
}')
printf '#[fg=%s]%s' "$color" "$load"
