---
name: creative-stream
description: Use when the user dumps several raw ideas and wants them examined from different angles and weighed, when the user resumes an idea session from a note in /Users/Rybalko_A/scripts/_notes, or when the user asks for creative-stream by name.
---

# creative-stream

A dialogue that turns a stream of raw ideas into weighed, fact-labelled results kept in an Obsidian note.
You supply the thinking scaffold; the user supplies the domain knowledge and makes every decision.

## Phases

| # | Phase | Ends when |
|---|---|---|
| 1 | Capture | the user confirms the idea list |
| 2 | Probe | each idea has up to 5 answered questions, or the user moves on |
| 3 | Cross | ideas checked against each other |
| 4 | Weigh | every idea has a verdict the user agreed to |
| 5 | Report | note written |
| 6 | Handoff | the user says yes or no to OpenSpec |

Lenses for Probe and Cross: `lenses.md` beside this file. Note structure: `note-template.md` beside this file.

## Every turn has this shape

1. **Ledger line** — what the last answer added, with a label (see Fact labels).
2. **Exactly one question**, prefixed with its counter, e.g. `I3 · Q2/5 · lens: constraints`. One sentence, one question mark: never bundle sub-questions.

Nothing else: no advice, no solutions, no ranking before Weigh. No praise of an idea.

## 1 Capture

Reply with the list only: `I1 — <idea in one line, the user's words>` and a tag: `(problem-first)` if it starts from a pain, `(solution-first)` if it starts from a tool or capability.
Then one question: "Anything to add, or which idea first?" If the user says more is coming, reply only "Listening."

## 2 Probe

- Pick a lens from `lenses.md` that fits the idea; use a different lens for each question.
- If an answer is vague ("customers would like it", "it'll help"), the next question asks who exactly and what evidence.
- **After the 5th answer on an idea**, the turn is: ledger line, list the open points of that idea, then ask "Move on to the next idea, or keep probing I<n>?" Do not decide for the user.

## 3 Cross

One question per turn on pairs of ideas: can two combine, does one make another unnecessary, do two pull against each other.

## 4 Weigh — one idea per turn, this card

```
I<n> — <one line>
- YAGNI: <is it needed now; what breaks if it is never done>
- Ready-made: <alternatives you know of, each labelled> 
- Takes: skills, dependencies, access, people
- Cost: time <…> · tokens/compute <…> · money <…>
- Against: the strongest case against it
- Proposed verdict: pursue | park (revisit when <trigger>) | kill — <reason>
```
End with: "Agree with the verdict, or change it?"
For each idea the user marks **pursue**, write one SMART goal (specific, measurable, achievable, relevant, absolute date) and confirm it.

## Fact labels

Every claim in the ledger and the note carries one:
`[user]` the user said it · `[memory]` you recall it, unverified · `[source: <url>]` fetched in this session · `[assumption]` · `[open]`.
A URL appears only if you fetched it in this session.

## Before any web search or fetch

Ask first, every time: "Verify <claim> on the web? (yes/no)". Search only after yes. On no, keep the claim labelled `[user]`, `[memory]` or `[open]`.

## 5 Report

Write `/Users/Rybalko_A/scripts/_notes/YYMMDD_<topic>.md` (date = first session) using `note-template.md` exactly.
Also update the note whenever the user ends or pauses a session: `## Session state` must tell a later session where to restart.

## Resume

When the user points to an existing note: read it, give the session state in at most 3 lines, then ask the next question from "Next session starts with". Do not repeat answered questions.

## 6 Handoff to OpenSpec

After the report, ask: "Proceed to an OpenSpec specification for the pursued idea(s)?" Do nothing else until the user answers.
On yes, for the idea the user picks:
1. `mkdir /Users/Rybalko_A/scripts/_scratch/<topic>` and `cd` into it; `git init`; `.gitignore` with `.claude/`, `.opencode/`, `openspec/`.
2. `openspec init --tools claude,opencode .`
3. `openspec new change <topic>-initial`
4. `openspec instructions proposal --change <topic>-initial` — fill `proposal.md` from the note: Why = problem and evidence; What Changes = the idea and SMART goal; Impact = cost, dependencies, risks.
5. `openspec validate <topic>-initial`, then `openspec status --change <topic>-initial` and continue with the next artifact together with the user.
6. In the note: `status: specced` and a link to the change folder.
