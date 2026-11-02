// The terminal side of auto review: the /auto command switches it for the current session,
// the prompt footer shows whether it is on, a line above the prompt lists this turn's
// approvals, and flagged actions show why they need approval.
import { Plugin } from "@opencode/plugin/tui"
import { createEffect, createSignal, For, Show } from "solid-js"
import { AutoReview, type Approval, type SessionState } from "./rpc"

// The server part starts every message it attaches to a permission request with this.
const MESSAGE_PREFIX = "Auto review"

type FlaggedRequest = { sessionID: string; message: string }

// Splits the server's message ("Auto review: <reason>", or "Auto review failed, ...: <error>")
// into a heading and the reason itself.
function describe(message: string): { title: string; reason: string } {
  const separator = message.indexOf(":")
  const reason = separator === -1 ? message : message.slice(separator + 1).trim()
  if (message.startsWith(`${MESSAGE_PREFIX} failed`)) {
    return { title: "Auto review could not check this action", reason }
  }
  return { title: "Auto review flagged this action", reason }
}

export default Plugin.define({
  id: "auto-review.tui",
  setup(context) {
    const autoReview = context.client.rpc(AutoReview)

    // Known state per main session. A session missing here has not been asked yet and is on,
    // like every new session.
    const [states, setStates] = createSignal<Record<string, boolean>>({})

    // What auto review approved in each main session's current turn, since your last message
    // (shown above the prompt).
    const [approvedThisTurn, setApprovedThisTurn] = createSignal<Record<string, string[]>>({})

    function remember(state: SessionState) {
      setStates((previous) => ({ ...previous, [state.sessionID]: state.enabled }))
    }

    // Subagents follow their main session, so state is always kept for the main one.
    function currentMainSession(): string | undefined {
      const route = context.ui.router.current()
      if (route.type !== "session") return undefined
      return context.data.session.root(route.sessionID)
    }

    function isEnabled(sessionID: string | undefined): boolean {
      if (!sessionID) return true
      return states()[sessionID] ?? true
    }

    async function toggle() {
      const sessionID = currentMainSession()
      if (!sessionID) {
        context.ui.toast.show({ message: "Open a session to switch auto review", variant: "warning" })
        return
      }

      const state = await autoReview.set({ sessionID, enabled: !isEnabled(sessionID) })
      remember(state as SessionState)
      context.ui.toast.show(
        state.enabled
          ? { title: "Auto review on", message: "Shell and MCP calls are checked before they run", variant: "success" }
          : { title: "Auto review off", message: "Only your permission rules apply", variant: "warning" },
      )
    }

    // Another terminal may switch the same session.
    const stopListening = autoReview.events.on("changed", (event) => remember(event.data as SessionState))

    const stopApproved = autoReview.events.on("approved", (event) => {
      const { sessionID, target } = event.data as Approval
      setApprovedThisTurn((previous) => ({ ...previous, [sessionID]: [...(previous[sessionID] ?? []), target] }))
    })

    // A new message from you in a main session starts a new turn. Subagents' tasks arrive as
    // messages in their own sessions and do not count.
    const stopNewTurn = context.data.on("session.inbox.enqueued", (event) => {
      const { sessionID, item } = event.data
      if (item.type !== "user" || context.data.session.root(sessionID) !== sessionID) return
      setApprovedThisTurn((previous) => ({ ...previous, [sessionID]: [] }))
    })

    // "git status && git diff --stat" → "git status", "github_get_me" stays as it is.
    function shortName(target: string): string {
      const firstCommand = target.split(" && ")[0]
      return firstCommand.split(/\s+/).slice(0, 2).join(" ")
    }

    // OpenCode's permission prompt shows the command but not the reason the server part gives,
    // so the reason is shown above the prompt until the request is answered.
    const [flagged, setFlagged] = createSignal<Record<string, FlaggedRequest>>({})

    const stopAsked = context.data.on("permission.asked", (event) => {
      const { id, sessionID, message } = event.data
      if (!message?.startsWith(MESSAGE_PREFIX)) return

      setFlagged((previous) => ({ ...previous, [id]: { sessionID, message } }))
    })

    const stopReplied = context.data.on("permission.replied", (event) => {
      setFlagged((previous) => {
        const remaining = { ...previous }
        delete remaining[event.data.requestID]
        return remaining
      })
    })

    // Requests from the open session and its subagents.
    function flaggedInCurrentSession(): FlaggedRequest[] {
      const mainSession = currentMainSession()
      return Object.values(flagged()).filter((request) => context.data.session.root(request.sessionID) === mainSession)
    }

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "auto-review.toggle",
          title: "Toggle auto review",
          group: "Auto review",
          palette: true,
          slash: { name: "auto" },
          run: toggle,
        },
      ],
    }))

    const removeIndicator = context.ui.slot({
      append: "prompt.footer.status",
      render: () => {
        // Ask the server once for each session that is opened, so a session switched off earlier shows it.
        createEffect(() => {
          const sessionID = currentMainSession()
          if (!sessionID || sessionID in states()) return
          autoReview
            .get({ sessionID })
            .then((state) => remember(state as SessionState))
            .catch((error) => console.warn("[auto-review] could not read state", error))
        })

        const on = () => isEnabled(currentMainSession())
        return (
          <text fg={on() ? context.theme.text.feedback.success.base : context.theme.text.feedback.warning.base}>
            {on() ? "auto ✓" : "auto off"}
          </text>
        )
      },
    })

    // Under the latest turn, just above the prompt: what auto review approved since your last
    // message, e.g. "✓ Auto review · 3 approved · git status, gh pr, workmux list". Styled like
    // OpenCode's own line under each reply ("Build · Opus 5.5 · 2m 17s"): indented 3 columns,
    // the name first, the rest in grey. A blank line keeps it off the prompt box.
    const removeApproved = context.ui.slot({
      append: "session.composer.top",
      render: () => {
        const approved = () => approvedThisTurn()[currentMainSession() ?? ""] ?? []
        const names = () => [...new Set(approved().map(shortName))].join(", ")
        const count = () => approved().length

        return (
          <Show when={count()}>
            <box paddingLeft={3} marginBottom={1}>
              <text fg={context.theme.text.feedback.success.base} wrapMode="none" truncate>
                {"✓ Auto review"}
                <span style={{ fg: context.theme.text.muted }}>{` · ${count()} approved · ${names()}`}</span>
              </text>
            </box>
          </Show>
        )
      },
    })

    // A panel with a yellow bar on the left, like OpenCode's own notices.
    const removeReasons = context.ui.slot({
      append: "session.composer.top",
      render: () => (
        <For each={flaggedInCurrentSession()}>
          {(request) => {
            const { title, reason } = describe(request.message)
            return (
              <box
                border={["left"]}
                borderColor={context.theme.text.feedback.warning.base}
                paddingLeft={1}
                marginBottom={1}
              >
                <text fg={context.theme.text.feedback.warning.base}>⚠ {title}</text>
                <text fg={context.theme.text.base}>{reason}</text>
                <text fg={context.theme.text.muted}>Approve or reject it below.</text>
              </box>
            )
          }}
        </For>
      ),
    })

    return () => {
      stopListening()
      stopApproved()
      stopNewTurn()
      stopAsked()
      stopReplied()
      removeIndicator()
      removeApproved()
      removeReasons()
    }
  },
})
