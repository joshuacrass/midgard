#!/usr/bin/env bash
# Apply a status-bar theme by name, or cycle with next/prev.
#   theme.sh                -> (re)apply the saved/current theme
#   theme.sh mocha          -> apply a specific theme
#   theme.sh next | prev    -> cycle through THEMES
# The active theme name is persisted so it survives reloads/restarts.
set -u

DIR="$HOME/.config/tmux"
THEME_DIR="$DIR/themes"
STATE="$DIR/.current-theme"

# Order used by next/prev and the picker menu.
THEMES=(mocha nord gruvbox dracula rose-pine cobalt2)

current() { cat "$STATE" 2>/dev/null || echo "${THEMES[0]}"; }

index_of() {
  local want="$1" i
  for i in "${!THEMES[@]}"; do
    [ "${THEMES[$i]}" = "$want" ] && { echo "$i"; return; }
  done
  echo 0
}

arg="${1:-}"
case "$arg" in
  ""        ) name="$(current)" ;;
  next      ) i=$(index_of "$(current)"); name="${THEMES[$(((i + 1) % ${#THEMES[@]}))]}" ;;
  prev      ) i=$(index_of "$(current)"); name="${THEMES[$(((i - 1 + ${#THEMES[@]}) % ${#THEMES[@]}))]}" ;;
  *         ) name="$arg" ;;
esac

pal="$THEME_DIR/$name.sh"
if [ ! -f "$pal" ]; then
  tmux display-message "theme '$name' not found in $THEME_DIR"
  exit 1
fi

# shellcheck disable=SC1090
NAME="$name"; . "$pal"
printf '%s\n' "$name" > "$STATE"

# --- apply palette to the layout -----------------------------------------
tmux set -g status-style "bg=$BG,fg=$TEXT"

# row 0: half-height padding strip. Lower-half block glyphs (▄) drawn in the
# bar background over a transparent (terminal default) top — looks like ~half
# a line of bar. Over-long string is clipped to the client width by tmux.
TOPBAR=$(printf '▄%.0s' $(seq 1 500))
tmux set -g status-format[0] "#[fg=$BG,bg=default]$TOPBAR"

# row 3: mirrored half-strip at the bottom edge. Upper-half blocks (▀) put the
# bar background on the TOP half (continuous with the info row) and leave the
# bottom transparent — symmetric half-line padding below the bar.
BOTBAR=$(printf '▀%.0s' $(seq 1 500))
tmux set -g status-format[3] "#[fg=$BG,bg=default]$BOTBAR"

# window tabs: dim "number·name"; active one wrapped in accent brackets
tmux set -g window-status-format        "#[fg=$DIM,bg=$BG] #I#[fg=$EDGE]·#[fg=$DIM]#W "
tmux set -g window-status-current-format "#[fg=$ACCENT,bg=$BG,bold][#I·#W]#[default]"
tmux set -g window-status-activity-style "fg=$AMBER,bg=$BG"
tmux set -g window-status-bell-style     "fg=$RED,bg=$BG,bold"

# row 2 (bottom): session ● name · path  (left)   git · load · date · clock (right)
tmux set -g status-format[2] "#[fill=$BG]#[align=left]#[fg=$ACCENT] ●#[fg=$ACCENT,bold] #S #[fg=$EDGE,nobold]· #[fg=$DIM,nobold]#{host_short} #(~/.config/tmux/ip.sh) #[fg=$EDGE]·#[fg=$DIM]  #{=-40:pane_current_path} #[align=right]#[fg=$GREEN]#(~/.config/tmux/git.sh '#{pane_current_path}')  #[fg=$EDGE]│  #(~/.config/tmux/sys.sh)#[fg=$EDGE]  │  #[fg=$ACCENT]%a %d %b  #[fg=$ACCENT,bold]%H:%M:%S#[default]  "

# cohesive theming: borders, messages, modes
tmux set -g pane-border-style        "fg=$SURFACE"
tmux set -g pane-active-border-style "fg=$ACCENT"
tmux set -g message-style            "fg=$BG,bg=$ACCENT,bold"
tmux set -g message-command-style    "fg=$TEXT,bg=$SURFACE"
tmux set -g mode-style               "fg=$BG,bg=$AMBER,bold"
tmux setw -g clock-mode-colour       "$ACCENT"

tmux display-message "theme: $NAME"
