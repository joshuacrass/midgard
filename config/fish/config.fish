if status is-interactive
    # Commands to run in interactive sessions can go here
end
fish_add_path --global "$HOME/.local/bin"
if test -x "$HOME/.local/bin/mise"
    "$HOME/.local/bin/mise" activate fish | source
end
