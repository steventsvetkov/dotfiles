// Shell commands that only read, so auto review can let them through without asking the model.
//
// OpenCode gives the plugin a shell command as a list of pieces: "git diff | head -5" arrives as
// "git diff" and "head -5". The command skips the model only when EVERY piece is on the list
// below. One unknown piece sends the whole command to the model, as before.
//
// The list is strict on purpose. A wrong "no" costs one model call; a wrong "yes" runs something
// unreviewed. So each rule names the exact commands it allows, and flags that write or run other
// programs (sed -i, find -exec, rg --pre, git diff --output) are refused.

// Redirects that change nothing: "2>&1" and ">/dev/null". Taken out before the checks below.
const HARMLESS_REDIRECTS = /\d*>&\d|\d*>>?\s*\/dev\/null/g

// What must not appear in a piece: command substitution, a redirect to a file, a heredoc, or
// another command chained on with ; | or &. OpenCode already splits those into pieces, so if one
// is still here, the piece is not what it looks like.
const NOT_SIMPLE = /\$\(|`|[<>;|&\n]/

// Flags that write files or run other programs, whatever command they are given to.
const DANGEROUS_FLAGS = /(^|\s)(--output\b|--ext-diff\b|--pre\b|--in-place\b|-exec\b|-execdir\b|-ok\b|-okdir\b|-delete\b|-fprint\b|-fls\b)/

// Commands that never change anything, whatever their arguments (apart from the flags above).
const PLAIN_COMMANDS = [
  "grep", "rg", "head", "tail", "cat", "ls", "wc", "cut", "tr", "nl", "column", "diff",
  "which", "type", "basename", "dirname", "realpath", "readlink", "pwd", "stat", "file", "du", "df",
  "date", "echo", "printf", "sleep", "true", "test", "cd",
]

const GIT_READ_COMMANDS = [
  "status", "diff", "log", "show", "ls-files", "ls-tree", "cat-file", "merge-base", "rev-parse",
  "blame", "describe", "shortlog",
]

const RULES: RegExp[] = [
  new RegExp(`^(${PLAIN_COMMANDS.join("|")})(\\s|$)`),

  // sort and uniq can write to a file given as an argument (sort -o, uniq in out).
  /^sort(?!.*\s(-o|--output))(\s|$)/,
  /^uniq( -[a-zA-Z0-9]+)*$/,

  // sed edits files with -i, and its w command writes to a file.
  /^sed(?!.*(\s-[a-zA-Z]*i|--in-place|[\s;{}/'"0-9,$]w\s))(\s|$)/,

  /^jq(\s|$)/,

  // git -C <folder> works too. "git -c" can run programs through config, so it is not allowed.
  new RegExp(`^git( -C \\S+)? (${GIT_READ_COMMANDS.join("|")})(\\s|$)`),
  /^git( -C \S+)? (remote( -v)?|worktree list|stash list|branch( --show-current| -[avr]+)?|config --get \S+)$/,

  /^brew (info|list|search|outdated|deps|leaves|config|desc|--prefix|--repository|--version)(\s|$)/,
  /^gh (pr|issue|run|repo|release|workflow) (view|list|status|checks|diff)(\s|$)/,
  /^gh auth status$/,
  /^mise (ls|list|settings get|which|where|current|outdated|--version)(\s|$)/,
  /^tmux (list-\S+|show-\S+|display-message|has-session)(\s|$)/,
  /^aerospace (list-\S+|--version)(\s|$)/,
  /^sketchybar --query(\s|$)/,
  /^dotfiles status$/,
  /^opencode api get(\s|$)/,
  /^find(\s|$)/,

  // xargs runs whatever follows it, so only read-only commands are allowed there.
  /^xargs( -[a-zA-Z0-9]+)* (grep|rg|cat|ls|wc|head|tail)(\s|$)/,
]

function isReadOnlyPiece(piece: string): boolean {
  const command = piece.replace(HARMLESS_REDIRECTS, "").trim()
  if (!command || NOT_SIMPLE.test(command)) return false
  if (DANGEROUS_FLAGS.test(command)) return false
  return RULES.some((rule) => rule.test(command))
}

export function isReadOnlyShell(pieces: readonly string[]): boolean {
  return pieces.length > 0 && pieces.every(isReadOnlyPiece)
}
