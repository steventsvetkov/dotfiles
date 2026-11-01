// Lets the terminal UI read and switch auto review for a session. The server part owns the state,
// because that is where permission checks run.
import { Rpc } from "@opencode/plugin/rpc"

const session = {
  type: "object",
  properties: { sessionID: { type: "string" } },
  required: ["sessionID"],
  additionalProperties: false,
}

const sessionState = {
  type: "object",
  properties: { sessionID: { type: "string" }, enabled: { type: "boolean" } },
  required: ["sessionID", "enabled"],
  additionalProperties: false,
}

export const AutoReview = Rpc.define({
  id: "auto-review",
  methods: {
    get: { input: session, output: sessionState },
    set: { input: sessionState, output: sessionState },
  },
  events: {
    changed: { schema: sessionState },
  },
})

export type SessionState = { sessionID: string; enabled: boolean }
