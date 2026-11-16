// A tmux-style leader key: Ctrl+B (keys.json) opens this popup, the next key runs a command.
// Herdr has no key sequences of its own, so the popup takes the keyboard and reads one key.
// Any key that is not listed, and Esc, closes it without doing anything.
// The keys follow ~/.config/tmux/tmux.conf where Herdr has the same command.
// The popup opens at once, to catch the next key, but stays invisible for SHOW_AFTER_MS: a quick
// Ctrl+B % never flashes it, and the list only shows when you wait, like Vim's which-key.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, props, closeOverlay, theme } from "herdr";

const SHOW_AFTER_MS = 500;

const split = (direction) => ({ command: "pane.split", args: { direction } });
const go = (direction) => ({ command: "pane.go", args: { direction } });

// key: the typed character (so % and P work without spelling out shift), or the key's name for
// keys that type nothing (arrows). label: shown in the popup; rows without one are extra keys
// for a row above (the arrows next to h j k l, 2-9 next to 1).
const BINDINGS = [
  { key: "c", label: "new tab", command: "tab.new" },
  { key: "n", label: "next tab", command: "tab.next" },
  { key: "N", label: "previous tab", command: "tab.prev" },
  { key: ",", label: "rename tab", command: "tab.rename" },
  { key: "&", label: "close tab", command: "tab.close" },
  { key: "1-9", label: "go to tab" },
  { key: "|", label: "split right", ...split("right") },
  { key: "%", ...split("right") },
  { key: "-", label: "split down", ...split("down") },
  { key: '"', ...split("down") },
  { key: "h j k l", label: "move to pane" },
  { key: "h", ...go("left") },
  { key: "j", ...go("down") },
  { key: "k", ...go("up") },
  { key: "l", ...go("right") },
  { key: "left", ...go("left") },
  { key: "down", ...go("down") },
  { key: "up", ...go("up") },
  { key: "right", ...go("right") },
  { key: "z", label: "zoom pane", command: "pane.zoom" },
  { key: "x", label: "close pane", command: "pane.close" },
  { key: "C", label: "new space", command: "space.new" },
  { key: ")", label: "next space", command: "space.next" },
  { key: "(", label: "previous space", command: "space.prev" },
  { key: "$", label: "rename space", command: "space.rename" },
  { key: "a", label: "next agent", command: "agent.next" },
  { key: "p", label: "spaces and tabs", command: "mod.open", args: { name: "picker" } },
  { key: "P", label: "command palette", command: "app.palette" },
  { key: "?", label: "help", command: "app.help" },
];

for (let index = 1; index <= 9; index++) {
  BINDINGS.push({ key: String(index), command: "tab.select", args: { index } });
}

// The typed character first, so Shift+P runs P's command and not p's.
function findBinding(event) {
  return (
    BINDINGS.find((b) => b.command && b.key === event.key_char) ??
    BINDINGS.find((b) => b.command && !event.key_char && b.key === event.key)
  );
}

export default class Leader extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    // The picker re-focuses after it opens too: the popup can miss the keyboard on the first frame.
    cx.timer.after(100, () => this.handle.focus());

    this.visible = false;
    cx.timer.after(SHOW_AFTER_MS, (cx) => {
      this.visible = true;
      cx.notify();
    });
  }

  press(event) {
    const binding = findBinding(event);
    closeOverlay(props().overlay);
    if (binding) run(binding.command, binding.args ?? {});
  }

  render(cx) {
    const t = theme();
    const rows = BINDINGS.filter((b) => b.label);
    const half = Math.ceil(rows.length / 2);
    const column = (part) =>
      v_flex()
        .flex_1()
        .gap(5)
        .children(
          part.map((b) =>
            h_flex()
              .gap(10)
              .child(div().w(52).text_color(t.accent).font_semibold().child(b.key))
              .child(div().text_color(t.foreground).truncate().child(b.label)),
          ),
        );

    // mod.json sets frame "none", so this draws the whole popup, and nothing until it is visible.
    return v_flex()
      .id("leader")
      .track_focus(this.handle)
      .on_key_down((event, cx) => {
        this.press(event);
        cx.stop_propagation();
      })
      .size_full()
      .when(this.visible, (el) =>
        el
          .p(14)
          .gap(10)
          .rounded(8)
          .border_1()
          .border_color(t.border)
          .bg(t.popover)
          .text_size(13)
          .child(h_flex().gap(16).child(column(rows.slice(0, half))).child(column(rows.slice(half))))
          .child(div().text_size(11).text_color(t.dim).child("Any other key closes this")),
      );
  }
}
