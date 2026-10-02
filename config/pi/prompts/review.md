---
description: Ревью текущих изменений без исправлений
argument-hint: "[фокус ревью]"
---
Review the current repository changes. Focus: ${@:-correctness, security, compatibility, and regressions}.

- Read repository instructions and git status first. Review staged and unstaged diffs and relevant non-sensitive new files.
- Do not edit files, install packages, commit, or mutate infrastructure. Do not read credentials or session files.
- Report only actionable findings introduced by these changes; avoid speculative issues and unrelated style suggestions.
- For each finding, include severity, file path and line, concrete impact, and a minimal fix.
- For infrastructure changes, check selectors, probes, resources, security contexts, RBAC, disruption budgets, topology, and exposure as applicable.
- If no issues are found, say so and note any validation gaps. Respond concisely in Russian.
