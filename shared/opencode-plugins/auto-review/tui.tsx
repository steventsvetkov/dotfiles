// The terminal side of auto review: the /auto command switches it for the current session, and
// the prompt footer shows whether it is on.
import { Plugin } from "@opencode/plugin/tui"
import { createEffect, createSignal } from "solid-js"
import { AutoReview, type SessionState } from "./rpc"

export default Plugin.define({
  id: "auto-review.tui",
  setup(context) {
    const autoReview = context.client.rpc(AutoReview)

    // Known state per main session. A session missing here has not been asked yet and is on,
    // like every new session.
    const [states, setStates] = createSignal<Record<string, boolean>>({})

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

    return () => {
      stopListening()
      removeIndicator()
    }
  },
})
