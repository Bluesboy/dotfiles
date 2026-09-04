#Use by default
# fish_key_bindings

#Use VI mode by default
fish_vi_key_bindings

# fish_vi_key_bindings sends its own DECSCUSR cursor-shape escapes on every
# mode change, which overrides wezterm's default_cursor_style/cursor_blink_rate
# with a non-blinking cursor unless told otherwise here.
set -g fish_cursor_default block blink
set -g fish_cursor_insert line blink
set -g fish_cursor_replace_one underscore blink
set -g fish_cursor_visual block blink

#Set Catpuccin Macchiato theme
fish_config theme choose "catppuccin-macchiato"

# Initialize Starship prompt
starship init fish | source

# Hand Ctrl+R and Up over to atuin. fzf.fish binds Ctrl+R from conf.d, which
# fish loads before this file, so its history binding is switched off here
# while its five other bindings are reinstalled. Up goes to atuin as well so
# that both keys read the one shared database: fish's own history is per
# session and ignores commands from sessions started later, which is why every
# pane used to see a different past. --disable-ai keeps `?` a vi motion instead
# of a prompt to a remote service.
fzf_configure_bindings --history=
atuin init fish --disable-ai | source

# Set Neovim as default editor
set -gx EDITOR nvim

# Set Starship config directory compatible with new standards
set -gx STARSHIP_CONFIG ~/.config/starship/config.toml

# Set Starship config directory compatible with new standards
set -gx N_PREFIX ~/.local/share/n

# Set TTY for pass-git-helper
set -gx GPG_TTY (tty)

# Use gcloud-gke-auth-plugin by default
set -gx USE_GKE_GCLOUD_AUTH_PLUGIN True

# Use system URI for libvirt by default
set -gx LIBVIRT_DEFAULT_URI qemu:///system

# Use Nix daemon
set -gx NIX_REMOTE daemon

# Use Nix daemon
set -gx CLIPBOARD_THEME ansi

# Set go-task binary name
set -gx GO_TASK_PROGNAME go-task

# Setup PATH from .bash_profile
fish_add_path -gm ~/.local/bin
fish_add_path -gm $N_PREFIX/bin
fish_add_path -gm ~/.cargo/bin

# Do not display greeting
functions -e fish_greeting

# Bind Yazi start to CTRL+Y
function fish_user_key_bindings
  bind -M insert \co 'y'
end

# Setup abbreviations
if status --is-interactive
  abbr --add --global -- aurox 'gcloud config configurations activate aurox && kubectx aurox'
  abbr --add --global -- dr 'docker run -it --rm'
  abbr --add --global -- flux 'gcloud config configurations activate flux && kubectx flux'
  abbr --add --global -- tta 'gcloud config configurations activate tta && kubectx tta'
  abbr --add --global -- swaps 'gcloud config configurations activate aurox-swaps && kubectx swaps'
  abbr --add --global -- stage 'gcloud config configurations activate stage && kubectx stage'
  abbr --add --global -- g git
  abbr --add --global -- gvm g
  abbr --add --global -- ga 'git add'
  abbr --add --global -- gb 'gh browse'
  abbr --add --global -- gc 'git commit -m'
  abbr --add --global -- gca 'git commit --amend'
  abbr --add --global -- glo 'git lo'
  abbr --add --global -- gp 'git push'
  abbr --add --global -- gpu 'git pull'
  abbr --add --global -- gs 'git status'
  abbr --add --global -- gsw 'git switch'
  abbr --add --global -- gd 'git difftool'
  abbr --add --global -- hl 'helm ls'
  abbr --add --global -- k kubectl
  abbr --add --global -- kc kubectx
  abbr --add --global -- kn kubens
  abbr --add --global -- ka 'kubectl apply -f'
  abbr --add --global -- lg lazygit
  abbr --add --global -- lm lazymake
  abbr --add --global -- lad lazydocker
  abbr --add --global -- tf terraform
  abbr --add --global -- tp 'terraform plan'
  abbr --add --global -- fishconf 'vim ~/.config/fish/config.fish'
  abbr --add --global -- ck 'kubectl get pod --all-namespaces | grep -i \'terminated\|nodeshutdown\|error\|nodeaffinity\|completed\' | awk \'{ print $1, $2 }\' | xargs -n2 kubectl delete pod -n'
  abbr --add --global -- tm 'tmux'
  abbr --add --global -- c 'clear'
  abbr --add --global -- wm 'wiremix'
  abbr --add --global -- v 'vim'
end

set -gx GOPATH $HOME/go; set -gx GOROOT $HOME/.go; fish_add_path -gm $GOPATH/bin; # g-install: do NOT edit, see https://github.com/stefanmaric/g

# Enable krew
set -q KREW_ROOT; and fish_add_path -g $KREW_ROOT/.krew/bin; or fish_add_path -g $HOME/.krew/bin

fish_add_path -gm ~/.luarocks/bin/
