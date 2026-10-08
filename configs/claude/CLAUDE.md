# CLAUDE.md — Global Personal Rules

Personal cross-project rules, deployed to `~/.claude/CLAUDE.md` by
`system/claude.sh`. They apply in every project and every session; a
project's own CLAUDE.md wins on conflict.

## Git commit convention (Conventional Commits)

Apply to every commit message written in any project — whether or not
`/gitmsg` was invoked.

- **Title (required):** `<type>(<scope>): <description>`, max 72 characters. Never exceed it — shorten the description before abbreviating the scope.
- **Body (conditional):** Only include a body when the change carries something the diff cannot show — a non-obvious decision, a trade-off, a behavior change, a worked-around constraint, or when one commit spans many files and the title cannot summarize it. Separate it from the title with a blank line, wrap each line at max 72 characters, and explain *why* rather than *what*.
  - **Format as a terse bullet list** (`- ` prefix), one point per bullet — never prose paragraphs. Keep each bullet short and scannable; drop filler words. Wrap continuation lines at 72 characters, indented to align under the bullet text.
- **Skip the body** for trivial changes (typo, formatting, config-value tweaks); output the title alone.
- **Branch names:** `<type>/<short-kebab-slug>` (Conventional Commits type prefix, slug max 5 words).
