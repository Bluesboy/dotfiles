# Global agent instructions

## Communication

- Reply to the user in Russian.
- Use English only for code, commands, paths, API names and exact tool output.
- Be concise and technical. Give detailed explanations on request, or when omitting them would make a decision unsafe.
- Do not repeat context that is already known and do not paste large listings without need.

## Instruction priority

- Before working, take the current project's `AGENTS.md` and `AGENTS.override.md` into account.
- More specific project instructions take precedence over this file.
- On conflicting requirements or significant uncertainty, ask one short clarifying question.

## Workstation

- Host: `king.deus.pro`, Arch Linux x86_64.
- CPU: AMD Ryzen 7 9700X, 16 logical CPUs; RAM: approximately 64 GiB.
- GPU: AMD Radeon RX 580 plus integrated AMD graphics.
- Desktop: Niri on Wayland.
- Interactive shell: Fish; terminal sessions commonly run inside tmux.
- Pi's `bash` tool executes Bash. Do not use Fish-only syntax in Bash commands.
- Locale: `ru_RU.UTF-8`; terminal supports truecolor.
- Editor: Neovim (`nvim`).
- Package managers: `pacman` for official Arch packages, `paru` for AUR packages.
- Common CLI tools available: `rg`, `fd`, `fzf`, `bat`, `eza`, `yazi`, `lazygit`.
- Infrastructure tools available: Docker, kubectl, Helm, k9s, Terraform/OpenTofu, libvirt and Nix.

## Persistent workstation configuration

- Persistent workstation changes belong in `~/.dotfiles` and should be managed through its Ansible playbooks.
- Prefer editing source files under `~/.dotfiles/config/` instead of files symlinked into `$HOME`.
- Always install packages with Ansible playbooks in `~/.dotfiles` and `make apply` in that repo.
- Use repository-supported commands such as `make syntax`, `make lint`, `make check` and `make apply`.
- Do not install, remove or replace system packages unless explicitly requested.
- Do not execute privileged or destructive system operations without explicit user approval.
- Keep changes minimal; do not reformat or refactor unrelated files.

## Safety

- Never read, print, copy or modify credentials, tokens, private keys, authentication stores or session files unless the user explicitly requests it.
- Treat files such as `.env`, `auth.json`, kubeconfigs, cloud credentials, password stores and SSH/GPG private keys as sensitive.
- Before a destructive command, state what will be affected and obtain confirmation.
- Prefer reversible and idempotent operations.

## Git

- Inspect `git status` before editing a repository.
- Preserve existing user changes and untracked files.
- Do not run `git reset --hard`, `git clean`, force pushes or equivalent destructive operations unless explicitly requested.
- Do not commit, amend, tag or push unless explicitly requested.
- Never add the agent as a commit co-author.

## Kubernetes and infrastructure

- Before cluster mutations, check the active context and namespace.
- Require explicit confirmation before `kubectl apply/delete/patch`, Helm install/upgrade/uninstall, Terraform/OpenTofu apply/destroy, or changes to remote infrastructure.
- When reviewing Kubernetes resources, check selectors, probes, requests/limits, security contexts, RBAC, disruption budgets, topology constraints and external exposure.
- Highlight destructive actions, replacement operations and backward-incompatible infrastructure changes.

## Execution and validation

- Inspect relevant files before editing; prefer targeted searches and reads.
- Use existing project commands and tooling instead of inventing ad-hoc workflows.
- After edits, run the smallest relevant validation first, then broader checks when justified.
- Report changed file paths, validation results and anything not validated.
