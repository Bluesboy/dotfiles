---
description: Диагностика ошибки без изменения настроек
argument-hint: "[ошибка или симптом]"
---
Diagnose this problem: ${@:-the failure described in this conversation}.

- Read applicable instructions and inspect relevant configuration and code with read-only operations.
- Do not read credentials, authentication stores, private keys, or session files. Avoid broad log dumps that could expose sensitive data.
- Distinguish confirmed facts from hypotheses. Reproduce only when it is safe and does not modify user files or remote systems.
- Do not edit files, restart services, install packages, commit, or mutate infrastructure.
- Identify the likely root cause, supporting evidence, a minimal proposed fix, and how to verify it.
- If a necessary diagnostic operation is unsafe or needs sensitive data, ask for permission first. Respond concisely in Russian.
