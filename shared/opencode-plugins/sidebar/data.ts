// Reads what the sidebar shows, by running the same tools you would: git, gh, lsof and
// ai-usagebar, plus Linear's API for tickets. Every reader returns undefined when its
// tool is missing or fails, so a section just stays hidden.
import { execFile } from "node:child_process"

// Runs a command and returns its output, or undefined if it fails or takes over 20 seconds.
function run(command: string, args: string[], cwd?: string): Promise<string | undefined> {
  return new Promise((resolve) => {
    execFile(command, args, { cwd, timeout: 20_000, maxBuffer: 20_000_000 }, (error, stdout) => {
      resolve(error ? undefined : stdout)
    })
  })
}

function parseJson<T>(text: string | undefined): T | undefined {
  if (!text) return undefined
  try {
    return JSON.parse(text) as T
  } catch {
    return undefined
  }
}

// --- Branch and pull request ------------------------------------------------

export type Checks = { passed: number; failed: number; pending: number }

export type PullRequest = {
  number: number
  title: string
  url: string
  state: string // OPEN, MERGED, CLOSED
  isDraft: boolean
  review: string | null // APPROVED, CHANGES_REQUESTED, REVIEW_REQUIRED
  checks: Checks
}

export type Branch = {
  name: string
  base: string // e.g. origin/main
  ahead: number
  behind: number
  changedFiles: number
  pullRequest?: PullRequest
}

export async function readBranch(directory: string): Promise<Branch | undefined> {
  const name = (await run("git", ["rev-parse", "--abbrev-ref", "HEAD"], directory))?.trim()
  if (!name) return undefined

  const base = (await run("git", ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"], directory))?.trim() || "origin/main"
  const counts = (await run("git", ["rev-list", "--left-right", "--count", `${base}...HEAD`], directory))?.trim()
  const [behind, ahead] = (counts ?? "0 0").split(/\s+/).map(Number)
  const status = (await run("git", ["status", "--porcelain"], directory)) ?? ""
  const changedFiles = status.split("\n").filter((line) => line.trim()).length

  const branch: Branch = { name, base, ahead, behind, changedFiles }
  if (name !== "HEAD" && `origin/${name}` !== base) {
    branch.pullRequest = await readPullRequest(directory)
  }
  return branch
}

type RawCheck = { conclusion?: string | null; status?: string | null; state?: string | null }

async function readPullRequest(directory: string): Promise<PullRequest | undefined> {
  const fields = "number,title,url,state,isDraft,reviewDecision,statusCheckRollup"
  const raw = parseJson<{
    number: number
    title: string
    url: string
    state: string
    isDraft: boolean
    reviewDecision: string | null
    statusCheckRollup: RawCheck[] | null
  }>(await run("gh", ["pr", "view", "--json", fields], directory))
  if (!raw) return undefined

  return {
    number: raw.number,
    title: raw.title,
    url: raw.url,
    state: raw.state,
    isDraft: raw.isDraft,
    review: raw.reviewDecision || null,
    checks: countChecks(raw.statusCheckRollup ?? []),
  }
}

// GitHub reports checks two ways: workflow runs (status + conclusion) and commit statuses
// (state). Skipped, neutral and cancelled checks count as neither passed nor failed.
function countChecks(checks: RawCheck[]): Checks {
  const counts: Checks = { passed: 0, failed: 0, pending: 0 }
  for (const check of checks) {
    const result = (check.conclusion || check.state || "").toUpperCase()
    if (result === "SUCCESS") counts.passed += 1
    else if (["FAILURE", "ERROR", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE"].includes(result)) counts.failed += 1
    else if (!result || ["PENDING", "EXPECTED", "IN_PROGRESS", "QUEUED"].includes(result)) counts.pending += 1
  }
  return counts
}

// --- Ticket (Linear) ----------------------------------------------------------

export type Ticket = {
  id: string // e.g. CORE-1324
  title: string
  url: string
  state: string // e.g. In Progress
  stateType: string // backlog, unstarted, started, completed, canceled
  assignee?: string
  priority?: string
}

// Branch names like "core-1324/lease-refund" or "fix/CORE-1324-refund" carry a ticket id.
export function ticketIdIn(branch: string): string | undefined {
  const match = branch.match(/(?:^|[/_-])([a-z][a-z0-9]{1,9}-\d+)(?=$|[/_-])/i)
  return match?.[1].toUpperCase()
}

export async function readTicket(id: string, apiKey: string): Promise<Ticket | undefined> {
  const query = `query ($id: String!) {
    issue(id: $id) { identifier title url priorityLabel state { name type } assignee { name } }
  }`
  try {
    const response = await fetch("https://api.linear.app/graphql", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: apiKey },
      body: JSON.stringify({ query, variables: { id } }),
      signal: AbortSignal.timeout(15_000),
    })
    const body = (await response.json()) as { data?: { issue?: any } }
    const issue = body.data?.issue
    if (!issue) return undefined
    return {
      id: issue.identifier,
      title: issue.title,
      url: issue.url,
      state: issue.state?.name ?? "",
      stateType: issue.state?.type ?? "",
      assignee: issue.assignee?.name,
      priority: issue.priorityLabel && issue.priorityLabel !== "No priority" ? issue.priorityLabel : undefined,
    }
  } catch {
    return undefined
  }
}

// --- Servers running from a checkout --------------------------------------------

export type Server = {
  command: string // e.g. java, node
  worktree: string // the checkout it runs from (absolute path)
  folder: string // where it runs, relative to that checkout, e.g. api/server or . for the root
  ports: number[]
}

// Every checkout of the repo the folder belongs to: the main one and each git worktree.
export async function readWorktrees(directory: string): Promise<string[]> {
  const list = await run("git", ["worktree", "list", "--porcelain"], directory)
  const worktrees = (list ?? "")
    .split("\n")
    .filter((line) => line.startsWith("worktree "))
    .map((line) => line.slice("worktree ".length))
  return worktrees.length ? worktrees : [directory]
}

// Ports from 49152 up are the range the system hands out on request; apps and agents listen
// there for their own internal use, while dev servers use fixed ports below it.
const FIRST_TEMPORARY_PORT = 49152

// Every program listening on a TCP port whose working folder is inside one of the given
// checkouts: the dev servers you (or an agent) started there, whatever started them.
export async function readServers(worktrees: string[]): Promise<Server[] | undefined> {
  const listening = await run("lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"])
  if (listening === undefined) return undefined

  // lsof -F prints one field per line: p<pid>, c<command>, n<address>.
  const byPid = new Map<string, { command: string; ports: number[] }>()
  let pid = ""
  for (const line of listening.split("\n")) {
    const field = line[0]
    const value = line.slice(1)
    if (field === "p") {
      pid = value
      byPid.set(pid, { command: "", ports: [] })
    } else if (field === "c") {
      byPid.get(pid)!.command = value
    } else if (field === "n") {
      const port = Number(value.slice(value.lastIndexOf(":") + 1))
      const ports = byPid.get(pid)!.ports
      if (port && port < FIRST_TEMPORARY_PORT && !ports.includes(port)) ports.push(port)
    }
  }
  if (byPid.size === 0) return []

  const folders = await run("lsof", ["-a", "-d", "cwd", "-F", "n", "-p", [...byPid.keys()].join(",")])
  const servers: Server[] = []
  for (const record of (folders ?? "").split("\np").map((text) => text.replace(/^p/, ""))) {
    const [recordPid, ...lines] = record.split("\n")
    const folder = lines.find((line) => line.startsWith("n"))?.slice(1)
    const program = byPid.get(recordPid)
    if (!folder || !program || program.ports.length === 0) continue

    // The checkout holding the folder. The longest match wins, for worktrees kept inside
    // the main checkout.
    const worktree = worktrees
      .filter((path) => folder === path || folder.startsWith(path + "/"))
      .sort((a, b) => b.length - a.length)[0]
    if (!worktree) continue

    servers.push({
      command: program.command,
      worktree,
      folder: folder === worktree ? "." : folder.slice(worktree.length + 1),
      ports: program.ports.sort((a, b) => a - b),
    })
  }
  return servers.sort((a, b) => a.ports[0] - b.ports[0])
}

// --- AI plan usage (ai-usagebar) -------------------------------------------------

export type Limit = { label: string; percentUsed?: number; value: string; resets?: string }
export type Plan = { provider: string; name: string; plan?: string; limits: Limit[] }

const PROVIDER_NAMES: Record<string, string> = { anthropic: "Claude", openai: "Codex" }

// The plans ai-usagebar can read (logged in, no error), with each limit.
export async function readUsage(): Promise<Plan[] | undefined> {
  const raw = parseJson<{ entries?: any[] }>(await run("mise", ["exec", "--", "ai-usagebar", "usage", "--json"]))
  if (!raw?.entries) return undefined
  return raw.entries
    .filter((entry) => !entry.error && entry.metrics?.length)
    .map((entry) => ({
      provider: entry.id,
      name: PROVIDER_NAMES[entry.id] ?? entry.name ?? entry.id,
      plan: entry.plan ?? undefined,
      limits: entry.metrics.map((metric: any) => ({
        label: metric.label,
        percentUsed: typeof metric.percent === "number" ? metric.percent : undefined,
        value: metric.value ?? "",
        resets: metric.detail ? String(metric.detail).split(" · ")[0] : undefined,
      })),
    }))
}
