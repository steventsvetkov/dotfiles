// The session sidebar: what you'd otherwise check in other windows, for the session's folder.
//   This branch   its ticket (Linear), how far it is from the main branch, its PR and CI
//   Servers       servers started from this checkout, and from the repo's other worktrees
//                 (so you can see which ports are taken before starting your own)
//   AI usage      how much of each AI plan's limits is left (folded by default)
// Click a heading to fold or unfold it. Click the ticket or the PR to open it in the browser.
// The data comes from git, gh, lsof and ai-usagebar (see data.ts).
import { Plugin } from "@opencode/plugin/tui"
import { execFile } from "node:child_process"
import { createEffect, createSignal, For, Show } from "solid-js"
import {
  readBranch,
  readServers,
  readTicket,
  readUsage,
  readWorktrees,
  ticketIdIn,
  type Branch,
  type Plan,
  type Server,
  type Ticket,
} from "./data"
import { foldedSections, Section } from "./section"

const SECOND = 1000
const MINUTE = 60 * SECOND

// Tickets are read from Linear with a personal API key (Linear → Settings → Security & access).
const LINEAR_API_KEY = process.env.LINEAR_API_KEY

function openInBrowser(url: string) {
  execFile("open", [url])
}

export default Plugin.define({
  id: "sidebar.tui",
  setup(context) {
    const sections = foldedSections(context, { usage: true })
    const theme = context.theme
    const colors = {
      base: theme.text.base,
      muted: theme.text.muted,
      good: theme.text.feedback.success.base,
      warning: theme.text.feedback.warning.base,
      bad: theme.text.feedback.error.base,
      info: theme.text.feedback.info.base,
    }

    // One line of text, cut off at the sidebar's edge instead of wrapping, like OpenCode's lists.
    function Line(props: { color: string; children: any; onClick?: () => void }) {
      return (
        <text fg={props.color} wrapMode="none" truncate onMouseDown={props.onClick}>
          {props.children}
        </text>
      )
    }

    // The folder of the session on screen. Branch and servers are read for it.
    const [directory, setDirectory] = createSignal<string>()

    // Each reading remembers the folder it was made for, so switching sessions never
    // shows another checkout's data while the new one loads.
    const [branch, setBranch] = createSignal<{ directory: string; branch?: Branch }>()
    const [servers, setServers] = createSignal<{ directory: string; servers?: Server[] }>()
    const [usage, setUsage] = createSignal<Plan[]>()
    const [tickets, setTickets] = createSignal<Record<string, Ticket | undefined>>({})
    const ticketsReadAt: Record<string, number> = {}

    const currentBranch = () => (branch()?.directory === directory() ? branch()?.branch : undefined)
    const currentServers = () => (servers()?.directory === directory() ? servers()?.servers : undefined)
    const currentTicketId = () => {
      const name = currentBranch()?.name
      return name ? ticketIdIn(name) : undefined
    }

    async function refreshBranch() {
      const folder = directory()
      if (!folder) return
      const result = await readBranch(folder)
      setBranch({ directory: folder, branch: result })

      // Tickets change rarely: read each one at most every 5 minutes.
      const id = result ? ticketIdIn(result.name) : undefined
      if (id && LINEAR_API_KEY && Date.now() - (ticketsReadAt[id] ?? 0) > 5 * MINUTE) {
        ticketsReadAt[id] = Date.now()
        const ticket = await readTicket(id, LINEAR_API_KEY)
        setTickets((previous) => ({ ...previous, [id]: ticket }))
      }
    }

    // Servers of every checkout of this repo, so a port taken by another worktree shows too.
    async function refreshServers() {
      const folder = directory()
      if (!folder) return
      const worktrees = await readWorktrees(folder)
      setServers({ directory: folder, servers: await readServers(worktrees) })
    }

    async function refreshUsage() {
      const plans = await readUsage()
      // Offline or a failed read: keep the last numbers.
      if (plans) setUsage(plans)
    }

    const timers = [
      setInterval(refreshBranch, MINUTE),
      setInterval(refreshServers, 15 * SECOND),
      setInterval(refreshUsage, 5 * MINUTE),
    ]
    void refreshUsage()

    // --- This branch ---------------------------------------------------------------

    function BranchSection() {
      const ticket = () => {
        const id = currentTicketId()
        return id ? tickets()[id] : undefined
      }

      const summary = () => {
        const parts = [currentTicketId() ?? currentBranch()?.name ?? ""]
        const pullRequest = currentBranch()?.pullRequest
        if (pullRequest) {
          const checks = pullRequest.checks
          const mark = checks.failed ? "✗" : checks.pending ? "…" : "✓"
          parts.push(`PR #${pullRequest.number} ${mark}`)
        }
        return parts.join(", ")
      }

      const ticketColor = (stateType: string) => {
        if (stateType === "completed") return colors.good
        if (stateType === "started") return colors.info
        return colors.muted
      }

      const review = (decision: string | null) => {
        if (decision === "APPROVED") return { text: ", approved", color: colors.good }
        if (decision === "CHANGES_REQUESTED") return { text: ", changes requested", color: colors.bad }
        if (decision === "REVIEW_REQUIRED") return { text: ", review needed", color: colors.warning }
        return { text: "", color: colors.muted }
      }

      return (
        <Show when={currentBranch()}>
          {(current) => (
            <Section
              title="This branch"
              summary={summary()}
              collapsed={sections.isFolded("branch")}
              onToggle={() => sections.toggle("branch")}
            >
              <Show when={ticket()}>
                {(found) => (
                  <box flexDirection="column" marginBottom={1} onMouseDown={() => openInBrowser(found().url)}>
                    <text fg={colors.base} wrapMode="none" truncate>
                      <b>{found().id}</b>
                      <span style={{ fg: ticketColor(found().stateType) }}>{"  " + found().state}</span>
                    </text>
                    <Line color={colors.muted}>{found().title}</Line>
                    <Show when={found().assignee || found().priority}>
                      <Line color={colors.muted}>{[found().assignee, found().priority].filter(Boolean).join(", ")}</Line>
                    </Show>
                  </box>
                )}
              </Show>
              <Show when={currentTicketId() && !LINEAR_API_KEY}>
                <Line color={colors.muted}>{`${currentTicketId()}: set LINEAR_API_KEY to show it`}</Line>
              </Show>

              <Line color={colors.base}>{current().name}</Line>
              <Line color={colors.muted}>
                {`${current().ahead} ahead, ${current().behind} behind ${current().base.replace(/^origin\//, "")}`}
              </Line>
              <Line color={current().changedFiles ? colors.warning : colors.muted}>
                {current().changedFiles ? `${current().changedFiles} files changed` : "No local changes"}
              </Line>

              <Show when={current().pullRequest} fallback={<Line color={colors.muted}>No pull request</Line>}>
                {(pullRequest) => (
                  <box flexDirection="column" marginTop={1} onMouseDown={() => openInBrowser(pullRequest().url)}>
                    <text fg={colors.base} wrapMode="none" truncate>
                      <b>{`PR #${pullRequest().number}`}</b>
                      <span style={{ fg: pullRequest().isDraft ? colors.muted : colors.info }}>
                        {"  " + (pullRequest().isDraft ? "draft" : pullRequest().state.toLowerCase())}
                      </span>
                      <span style={{ fg: review(pullRequest().review).color }}>{review(pullRequest().review).text}</span>
                    </text>
                    <Show when={pullRequest().checks.failed}>
                      <Line color={colors.bad}>{`${pullRequest().checks.failed} checks failed`}</Line>
                    </Show>
                    <Show when={pullRequest().checks.pending}>
                      <Line color={colors.warning}>{`${pullRequest().checks.pending} checks running`}</Line>
                    </Show>
                    <Show when={!pullRequest().checks.failed && !pullRequest().checks.pending}>
                      <Line color={colors.good}>
                        {pullRequest().checks.passed ? `${pullRequest().checks.passed} checks passed` : "No checks"}
                      </Line>
                    </Show>
                  </box>
                )}
              </Show>
            </Section>
          )}
        </Show>
      )
    }

    // --- Servers -------------------------------------------------------------------

    function ServersSection() {
      const all = () => currentServers() ?? []
      const here = () => all().filter((server) => server.worktree === directory())
      const elsewhere = () => all().filter((server) => server.worktree !== directory())

      const ports = (list: Server[]) => list.map((server) => `:${server.ports[0]}`).join(" ")
      const summary = () => {
        const parts = []
        if (here().length) parts.push(`here ${ports(here())}`)
        if (elsewhere().length) parts.push(`taken ${ports(elsewhere())}`)
        return parts.join(", ")
      }

      // "core-1324-lease-refund" for its worktree folder, the repo's name for the main checkout.
      const worktreeName = (path: string) => path.slice(path.lastIndexOf("/") + 1)

      function ServerLine(props: { server: Server; where: string; dotColor: string }) {
        return (
          <text fg={colors.base} wrapMode="none" truncate>
            <span style={{ fg: props.dotColor }}>{"• "}</span>
            <b>{props.server.ports.map((port) => `:${port}`).join(" ")}</b>
            {"  " + props.server.command + "  "}
            <span style={{ fg: colors.muted }}>{props.where}</span>
          </text>
        )
      }

      return (
        <Show when={all().length}>
          <Section
            title="Servers"
            summary={summary()}
            collapsed={sections.isFolded("servers")}
            onToggle={() => sections.toggle("servers")}
          >
            <Show when={here().length}>
              <Line color={colors.muted}>Here</Line>
              <For each={here()}>
                {(server) => <ServerLine server={server} where={server.folder} dotColor={colors.good} />}
              </For>
            </Show>
            <Show when={elsewhere().length}>
              <box marginTop={here().length ? 1 : 0}>
                <Line color={colors.muted}>Other worktrees (ports taken)</Line>
              </box>
              <For each={elsewhere()}>
                {(server) => (
                  <ServerLine server={server} where={worktreeName(server.worktree)} dotColor={colors.warning} />
                )}
              </For>
            </Show>
          </Section>
        </Show>
      )
    }

    // --- AI usage ------------------------------------------------------------------

    function UsageSection() {
      const left = (percentUsed: number) => 100 - percentUsed

      const leftColor = (percentLeft: number) => {
        if (percentLeft <= 10) return colors.bad
        if (percentLeft <= 30) return colors.warning
        return colors.good
      }

      // A 10-block bar of what is left, like ■■■■■■■□□□.
      const bar = (percentLeft: number) => {
        const filled = Math.round(percentLeft / 10)
        return "■".repeat(filled) + "□".repeat(10 - filled)
      }

      // Folded: the first (shortest) limit of each plan, e.g. "Claude 68%, Codex 98%".
      const summary = () =>
        (usage() ?? [])
          .map((plan) => {
            const first = plan.limits.find((limit) => limit.percentUsed !== undefined)
            return first ? `${plan.name} ${left(first.percentUsed!)}%` : plan.name
          })
          .join(", ")

      return (
        <Show when={usage()?.length}>
          <Section
            title="AI usage"
            summary={summary()}
            collapsed={sections.isFolded("usage")}
            onToggle={() => sections.toggle("usage")}
          >
            <box flexDirection="column" gap={1}>
              <For each={usage()}>
                {(plan) => (
                  <box flexDirection="column">
                    <text fg={colors.base} wrapMode="none" truncate>
                      <b>{plan.name}</b>
                      <span style={{ fg: colors.muted }}>{"  " + (plan.plan ?? "")}</span>
                    </text>
                    <For each={plan.limits}>
                      {(limit) => (
                        <Show
                          when={limit.percentUsed !== undefined}
                          fallback={<Line color={colors.muted}>{`${limit.label}  ${limit.value}`}</Line>}
                        >
                          <text fg={colors.muted} wrapMode="none" truncate>
                            {limit.label.padEnd(14).slice(0, 14) + " "}
                            <span style={{ fg: leftColor(left(limit.percentUsed!)) }}>
                              {`${bar(left(limit.percentUsed!))} ${left(limit.percentUsed!)}%`}
                            </span>
                          </text>
                          <Show when={limit.resets}>
                            <Line color={colors.muted}>{"  " + limit.resets}</Line>
                          </Show>
                        </Show>
                      )}
                    </For>
                  </box>
                )}
              </For>
            </box>
          </Section>
        </Show>
      )
    }

    const removeSidebar = context.ui.slot({
      append: "sidebar.content",
      render: ({ sessionID }) => {
        // Follow the session on screen: read its folder's branch and servers right away.
        createEffect(() => {
          const session = context.data.session.get(sessionID)
          const folder = session?.location?.directory ?? context.location?.directory
          if (folder && folder !== directory()) {
            setDirectory(folder)
            void refreshBranch()
            void refreshServers()
          }
        })

        // The same gap between sections as OpenCode puts between its own.
        return (
          <box flexDirection="column" gap={1}>
            <BranchSection />
            <ServersSection />
            <UsageSection />
          </box>
        )
      },
    })

    return () => {
      timers.forEach(clearInterval)
      removeSidebar()
    }
  },
})
