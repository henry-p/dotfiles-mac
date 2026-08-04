---
name: wayfinder
description: Plan work too large and uncertain for one agent session as a shared map of decision tickets, then resolve one decision at a time until the route to implementation is clear. Invoke explicitly with /skill:wayfinder.
license: MIT; see LICENSE
compatibility: Adapted for the Pi coding agent. Uses Pi questions, subagents, filesystem tools, and configured issue-tracker tools including Linear MCP.
disable-model-invocation: true
metadata:
  source: https://github.com/mattpocock/skills/tree/main/skills/engineering/wayfinder
  adapted-for: pi
---

# Wayfinder for Pi

Wayfinder turns a large, foggy effort into a shared map of **decision tickets**. It plans; it does not implement the destination. A ticket resolves a question or prerequisite, not a slice of build work. The map is complete when nothing material remains to decide before implementation can begin.

Invoke it as:

```text
/skill:wayfinder <loose idea>
/skill:wayfinder <map URL, issue number, or local map path> [optional ticket name]
```

## Pi operating rules

- Use Pi's `AskUserQuestion` tool for decisions when available. Ask **one question at a time**, include a recommended answer, and wait. If the tool is unavailable, ask the same question in chat.
- Look up facts from the repository and tools instead of asking the user.
- For delegated research, first call the Pi `subagent` tool with `{ action: "list" }`, then use only an executable research/read-only agent. Prefer fresh context. Parallelize independent research tickets. If no suitable subagent exists, research in the parent session.
- Keep the parent as the only writer in the current working tree. Research agents should return findings or write declared artifacts outside the working tree. Use isolated worktrees only when intentionally requested.
- Never resolve more than one non-research ticket per invocation/session. Research tickets may complete in parallel.
- Do not invoke other slash commands as if they were tools. When this document says to grill, model the domain, research, or prototype, follow the inline Pi-native procedures below.
- Obey the repository's `AGENTS.md`, memory/context files, and tracker documentation before modifying anything.

## Core concepts

### Destination

Name the destination before creating tickets. It is the state Wayfinder is finding a route toward: usually an implementation-ready spec, a locked decision, or a precisely described change. Keep it to one or two lines. Measure every ticket against it.

### Map

One canonical map contains:

```markdown
## Destination

<the end state this effort is finding a route toward>

## Notes

<domain, standing preferences, and context/skills each session should consult>

## Decisions so far

- [<closed ticket name>](link) — <one-line gist; detail stays in the ticket>

## Not yet specified

<in-scope fog that cannot yet be phrased as a precise question>

## Out of scope

<work consciously ruled beyond this destination>
```

The map is an **index**, not a store. Each decision's full reasoning and resolution live in exactly one ticket. Refer to maps and tickets by linked **name**, never only by an id such as `#42`.

### Decision tickets

Each ticket contains:

```markdown
## Question

<the precise decision or investigation this ticket resolves>
```

Size it to one substantial agent session. Assign exactly one type:

- `wayfinder:research` — **AFK**. Find facts from primary sources or repository evidence.
- `wayfinder:prototype` — **HITL**. Make a cheap, explicitly throwaway artifact so the user can react to behavior or appearance.
- `wayfinder:grilling` — **HITL**. Resolve a decision through live, one-question-at-a-time conversation.
- `wayfinder:task` — **AFK or HITL**. Complete a prerequisite that must happen before a decision can be made. It must unblock a decision, not deliver the destination.

A HITL ticket cannot be resolved by the agent answering on the human's behalf.

A ticket is **frontier** work only when it is open, unblocked, and unclaimed. Claim it before doing work. Native tracker assignment is the claim; for local Markdown use `claimed_by: pi:<PI_SESSION_ID>` (fall back to `pi:<USER>`).

### Fog of war

Put a question in a ticket when it can be stated precisely now, even if it cannot yet be answered. Put it under **Not yet specified** when the future decision is visible only vaguely. As decisions resolve, graduate newly precise fog into tickets and remove the duplicated fog text.

Fog exists only toward the destination. Anything beyond the destination belongs under **Out of scope** and never graduates. If an existing ticket proves out of scope, close it, link a one-line explanation under Out of scope, and do not list it under Decisions so far.

## Tracker selection

Before creating or changing map artifacts:

1. Read `docs/agents/issue-tracker.md` if it exists and follow its **Wayfinding operations** exactly.
2. If it configures Linear MCP, confirm the MCP client is loaded and authenticated, then discover the current Linear tool schemas before mutation. Use the documented workspace/team/project routing, native parent-child hierarchy, native blocking relations, statuses, labels, comments, and authenticated-user assignment. Do not guess tool names or silently fall back when an existing Linear journey is unavailable.
3. Otherwise inspect the git remote and available authenticated CLI (`gh` for GitHub, `glab` for GitLab). Do not mutate a remote tracker until the user has confirmed that tracker choice.
4. If no tracker is configured or the user does not choose a remote tracker, use local Markdown without additional setup.

For remote trackers, use native child relationships and blocking relationships when the configured workflow supports them. Create all issues first, then wire relationships in a second pass. Read before each mutation and verify afterward. Never fake a native relationship in prose when the tracker document provides a real operation.

### Linear MCP

Pi has no built-in MCP client. When Linear is configured, use the installed Pi MCP adapter and the official `https://mcp.linear.app/mcp` endpoint. Authentication must use OAuth and the OS credential store; never request, print, or persist a Linear token in the repository.

With a proxy-style MCP adapter, search for and describe the required Linear operation before calling it. Resolve human-readable team, project, status, label, user, and issue names to live identifiers. If a required capability—especially child issues, blocking relationships, comments, labels, assignment, or status updates—is unavailable, stop and tell the user instead of degrading the map's semantics.

### Local Markdown fallback

Store one journey under:

```text
.scratch/wayfinder/<journey-slug>/
├── map.md
└── tickets/
    ├── T001-<ticket-slug>.md
    └── T002-<ticket-slug>.md
```

Use this frontmatter for `map.md`:

```yaml
---
type: wayfinder-map
name: <map name>
status: open
created_at: <ISO-8601 timestamp>
---
```

Use this frontmatter for tickets:

```yaml
---
type: wayfinder-ticket
name: <ticket name>
status: open
mode: HITL # or AFK
label: wayfinder:grilling # research, prototype, grilling, or task
blocked_by: [] # ticket filenames
claimed_by: null
---
```

For local tickets, append the resolution under `## Resolution`, set `status: closed`, clear the claim only after closure, and add a relative linked gist to the map's Decisions so far. The frontier is the ordered set of open tickets with no open filenames in `blocked_by` and no `claimed_by` value.

## Mode 1: Chart a map

Use this when the argument is a loose idea.

1. **Orient.** Read project instructions and durable context. Inspect relevant code and docs enough to avoid asking factual questions.
2. **Name the destination.** Grill one question at a time. Challenge vague or overloaded domain terms, compare answers with existing code/glossaries, and propose precise canonical language. Record glossary changes only when repository conventions call for it.
3. **Map breadth-first.** Fan across the whole decision space rather than diving into one thread. Surface precise decisions, prerequisites, dependencies, likely fog, and explicit scope boundaries. Continue one question at a time.
4. **Small-journey gate.** If there is no meaningful fog and the route fits one session, do not create a map. Explain that Wayfinder is unnecessary and ask whether to produce a normal plan/spec or implement directly.
5. **Confirm before mutation.** Show the proposed destination, tracker location, initial tickets with type/mode, dependency edges, fog, and out-of-scope items. Ask for approval.
6. **Create the map.** Use the chosen tracker and apply `wayfinder:map` where labels exist.
7. **Create tickets, then wire.** Create every currently precise ticket first. Add child and blocking relationships only after identities exist.
8. **Launch research.** For each initial research ticket, claim it and delegate it using Pi subagents. Require primary sources, citations, a concise resolution, and residual uncertainty. Do not let research agents mutate the shared tracker or current working tree; the parent records accepted results.
9. **Stop.** Charting does not hand-resolve a HITL or ordinary task ticket.

## Mode 2: Work through a map

Use this when the argument identifies an existing map.

1. Load only the map's low-resolution body plus tracker metadata. Do not eagerly load every ticket.
2. If the user named a ticket, verify it is a child and eligible. Otherwise select the first frontier ticket in tracker order.
3. Claim the ticket before work. Re-read it after claiming in case another session changed it.
4. Resolve according to type:
   - **Research:** delegate or research from primary sources; preserve citations and uncertainty.
   - **Grilling:** ask one decision question at a time with a recommendation; wait after each.
   - **Prototype:** first state the exact question. Make the smallest throwaway artifact, mark it clearly, avoid persistence and polish, expose relevant state, and solicit the user's reaction. Do not merge prototype code into production as part of Wayfinder.
   - **Task:** do only the prerequisite or give the human a precise checklist. Stop if credentials, authorization, or a human-only action is needed.
5. Before closing, summarize the proposed resolution and obtain human confirmation for every HITL ticket.
6. Record the full answer as the ticket's resolution/comment, close it, and append only a linked one-line gist to Decisions so far.
7. Reassess the map: create newly precise tickets, wire blockers in a second pass, remove graduated fog, close newly out-of-scope tickets, and repair invalidated tickets.
8. Stop after that one non-research ticket. State whether the route is now clear and identify the next frontier by linked name.

## Completion

The journey is complete when there are no open decision/prerequisite tickets and no material in-scope fog. Mark the map complete/closed and recommend the next appropriate action:

- produce an implementation-ready spec or plan when the work is large;
- break an already-understood plan into build tickets;
- implement directly only when the remaining work is genuinely small.

Wayfinder itself does not perform that implementation.

## Attribution

Adapted for Pi from Matt Pocock's `wayfinder` skill:
https://github.com/mattpocock/skills/tree/main/skills/engineering/wayfinder
