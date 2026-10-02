---
description: План изменений без редактирования файлов
argument-hint: "[задача]"
---
Plan the following task: ${@:-the task discussed in this conversation}.

- Read the applicable repository instructions and inspect the relevant code and git status.
- Do not edit files, install packages, commit, or mutate infrastructure.
- Identify the smallest safe change, affected file paths, risks, and validation commands.
- Preserve existing user changes. Do not read credentials or session files.
- Ask a clarifying question only if a blocking ambiguity remains.
- Return a concise numbered plan in Russian. Do not implement it yet.
