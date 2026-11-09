# CLAUDE.md — Global Personal Rules

Personal cross-project rules, deployed to `~/.claude/CLAUDE.md` by the
dotfiles `claude` module (`install.sh claude`). They apply in every project and every session; a
project's own CLAUDE.md wins on conflict.

## Language

Always reply to Roger in Traditional Chinese (繁體中文, Taiwan usage), however
long the session and whatever language the tool output, code or comments are
in. Code, commands, commit messages and files keep their own language (and the
project's own rules for them).

## Git commit convention (Conventional Commits)

Apply to every commit message written in any project — whether or not
`/gitmsg` was invoked.

- **Title (required):** `<type>(<scope>): <description>`, max 72 characters. Never exceed it — shorten the description before abbreviating the scope.
- **Body (conditional):** Only include a body when the change carries something the diff cannot show — a non-obvious decision, a trade-off, a behavior change, a worked-around constraint, or when one commit spans many files and the title cannot summarize it. Separate it from the title with a blank line, wrap each line at max 72 characters, and explain *why* rather than *what*.
  - **Format as a terse bullet list** (`- ` prefix), one point per bullet — never prose paragraphs. Keep each bullet short and scannable; drop filler words. Wrap continuation lines at 72 characters, indented to align under the bullet text.
- **Skip the body** for trivial changes (typo, formatting, config-value tweaks); output the title alone.
- **Branch names:** `<type>/<short-kebab-slug>` (Conventional Commits type prefix, slug max 5 words).

## CI artifacts (GitHub Actions)

Every `actions/upload-artifact` step sets `retention-days` (GitHub's default is 90):

- **Builds kept to try out** (ordinary pushes, runs started by hand): `14`.
- **Files only handed to a later job in the same run** (packaging for a release): `1`. The release assets are the permanent copy; never rely on artifacts for that.
- **One upload serving both** (a workflow run by tags and by branches or by hand): pick by the ref, `retention-days: ${{ startsWith(github.ref, 'refs/tags/v') && 1 || 14 }}`.
