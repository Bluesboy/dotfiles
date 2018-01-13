# .bashrc

export HISTCONTROL=ignoredups
export HISTSIZE=10000

shopt -s histappend
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

shopt -s autocd

# Enable PowerLine
export PATH=~/.local/bin:"$PATH"
export POWERLINE_COMMAND=powerline
export POWERLINE_CONFIG_COMMAND=powerline-config

if [ -f `which powerline-daemon` ]; then
  powerline-daemon -q
  POWERLINE_BASH_CONTINUATION=1
  POWERLINE_BASH_SELECT=1
  source ~/.local/lib/python2.7/site-packages/powerline/bindings/bash/powerline.sh
fi

# Add openstack completion if openstack-python in installed

if [ -x "$(command -v openstack)" ]; then
  source <(openstack complete)
fi

# Add kubectl completion if kubectl in installed

if [ -x "$(command -v kubectl)" ]; then
  source <(kubectl completion bash)
fi
