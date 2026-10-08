---
description: Generate a Conventional Commits message (and optionally a branch name) from staged changes
---
Review the current staged changes (`git diff --cached`) and output a commit message.

**Arguments ($ARGUMENTS):**

- `-b` / `branch` — additionally output a **branch name** before the commit message: `<type>/<short-kebab-slug>` (Conventional Commits type prefix, slug max 5 words).
- Empty — output the commit message only.

**Commit message format (following Conventional Commits):**

- **Title (required):** `<type>(<scope>): <description>`, max 72 characters. Never exceed it — shorten the description before abbreviating the scope.
- **Body (conditional):** Only include a body when the change carries something the diff cannot show — a non-obvious decision, a trade-off, a behavior change, a worked-around constraint, or when one commit spans many files and the title cannot summarize it. Separate it from the title with a blank line, wrap each line at max 72 characters, and explain *why* rather than *what*.
  - **Format as a terse bullet list** (`- ` prefix), one point per bullet — never prose paragraphs. Keep each bullet short and scannable; drop filler words. Wrap continuation lines at 72 characters, indented to align under the bullet text.
- **Skip the body** for trivial changes (typo, formatting, config-value tweaks); output the title alone.

Output only the requested items — no extra explanation. If there are no staged changes, inform the user.

Examples:

- `/gitmsg` — commit message only. Trivial change: title alone, no body:

  ```
  docs(readme): fix typo in install section
  ```

- `/gitmsg -b` — branch name above the message (`branch` works too). Body only for decisions the diff cannot show, as terse bullets:

  ```
  feat/aliases-target-select

  feat(aliases): add deploy target selection with system-wide default

  - default to /etc/profile.d/.alias so all users share one copy;
    ~/.alias remains selectable for per-user installs
  - refuse bashrc edit when the end sentinel is missing — range
    deletion would otherwise run to end-of-file
  ```
