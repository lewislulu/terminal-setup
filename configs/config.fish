if status is-interactive
    # Commands to run in interactive sessions can go here
end

fish_add_path /opt/homebrew/bin

# set nvm path
set --global nvm_data ~/.nvm

source (/opt/homebrew/bin/starship init fish --print-full-init | psub)

# pnpm
set -gx PNPM_HOME "/Users/$USER/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
