---
description: Запуск проверок проекта без исправлений
argument-hint: "[область проверки]"
---
Validate this repository. Scope: ${@:-current changes}.

- Read repository instructions, git status, and the existing validation entry points.
- Treat the scope as a description, not a shell command.
- Run the smallest relevant checks first; use the repository's supported commands.
- For this dotfiles repository, run make syntax and make lint when Ansible files changed, and git diff --check.
- Do not edit files, install dependencies, commit, run bootstrap/apply/deploy commands, or mutate infrastructure.
- Do not read credentials or session files. If a check needs unavailable dependencies or unsafe side effects, report it instead of proceeding.
- Report checks run, pass/fail results, and what remains unvalidated. Respond concisely in Russian.
