// A sidebar section with a heading you click to fold it away, drawn like OpenCode's own MCP
// section: a ▼/▶ arrow, the title in bold and, while folded, a short summary in brackets.
import { usePlugin } from "@opencode/plugin/tui"
import { Show, type JSX } from "solid-js"

export function Section(props: {
  title: string
  summary?: string
  collapsed: boolean
  onToggle: () => void
  children: JSX.Element
}) {
  const context = usePlugin()
  return (
    <box flexDirection="column">
      <box flexDirection="row" gap={1} onMouseDown={props.onToggle}>
        <text fg={context.theme.text.base}>{props.collapsed ? "▶" : "▼"}</text>
        <text fg={context.theme.text.base}>
          <b>{props.title}</b>
          <Show when={props.collapsed && props.summary}>
            <span style={{ fg: context.theme.text.muted }}>{` (${props.summary})`}</span>
          </Show>
        </text>
      </box>
      <Show when={!props.collapsed}>{props.children}</Show>
    </box>
  )
}

// Which sections are folded, saved in the plugin's storage so it survives restarts.
// `defaults` lists the sections that start folded.
export function foldedSections(context: any, defaults: Record<string, boolean>) {
  const [saved, update] = context.storage.store("folded", { initial: {} as Record<string, boolean> })
  return {
    isFolded: (id: string): boolean => saved[id] ?? defaults[id] ?? false,
    toggle: (id: string) => {
      const folded = saved[id] ?? defaults[id] ?? false
      void update((draft: Record<string, boolean>) => {
        draft[id] = !folded
      })
    },
  }
}
