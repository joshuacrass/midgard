#!/usr/bin/env bash
# Primary outbound IP for this host, coloured by scope:
#   amber = public, green = private (RFC1918 / loopback).
# Reads the active theme's palette so the colour matches the current theme.
DIR="$HOME/.config/tmux"
name=$(cat "$DIR/.current-theme" 2>/dev/null || echo mocha)
# shellcheck disable=SC1090
[ -f "$DIR/themes/$name.sh" ] && . "$DIR/themes/$name.sh"
AMBER=${AMBER:-#f9e2af}
GREEN=${GREEN:-#a6e3a1}

ip=$(tailscale ip -4 2>/dev/null | head -n1)
[ -z "$ip" ] && ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+')
[ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')

case "$ip" in
  10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*|127.*) color="$GREEN" ;;
  *) color="$AMBER" ;;
esac

printf '#[fg=%s]%s' "$color" "$ip"
