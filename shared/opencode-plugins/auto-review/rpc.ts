// Lets the terminal UI read and switch auto review for a session, and hear about each action it
// approves. The server part owns the state, because that is where permission checks run.
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

const approval = {
  type: "object",
  properties: { sessionID: { type: "string" }, target: { type: "string" } },
  required: ["sessionID", "target"],
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
    // One action approved, e.g. { sessionID, target: "git status" }.
    approved: { schema: approval },
  },
})

export type SessionState = { sessionID: string; enabled: boolean }
export type Approval = { sessionID: string; target: string }
