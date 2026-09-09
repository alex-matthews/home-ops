# Writing Style

**When to use:** Drafting or editing any prose a human will read: issue and
pull request bodies, comments, ADRs, guides, operations notes, the README.
This guide is craft. [`pr-and-issue-writing.md`](pr-and-issue-writing.md)
owns policy: what belongs where, public safety, and linking. A skill
reference a human follows is in scope. `AGENTS.md` and every `SKILL.md`
router are not, and follow the vendored writing-for-agents skill instead.

Rules here enter and leave only through the evidence loop in #2047. A rule
enters only if the same defect appears twice on different artifacts, and
leaves only in a distillation session, the sitting in which the repository
owner reads the evidence log and amends this guide. The rule sections,
Ordering through Cutting, are capped at about 400 words. Each rule carries
in brackets the pull request or issue whose drafting rounds supplied its
evidence. The owner seeded the first set from the 9 September rounds, and
the two-artifact bar applies from then on.

## The reader

A human operator who knows Kubernetes and Flux and has never seen this
repository. A body that describes a change succeeds only if that reader
can answer three questions in one pass: what changed, why now, and is it
safe. A document succeeds only if that reader can answer what it is for,
what to do, and what not to do. Every rule below serves that reader. If
two rules conflict, the one that answers a question sooner wins.

## Ordering

- Lead with the trigger and the change together, never with the diff.
  The exception is a deliberate non-change, which a diff cannot show.
  (#2046)
- State the verdict before its proof, and let it name what it covers:
  "changes nothing about how requests are handled", never "changes no
  behaviour". (#2046)
- After the lead, problem before change. "Today" and "After this change"
  open paragraphs only if the body has two or more concerns or a long
  causal chain. Below about 200 words of body they restate. (#2042, #2046)
- In a body that describes a change, a heading names the change, never
  the problem, and the first box of a checklist is the first move.
  (#2042, #2047)

## Sentences

- One causal link per sentence, "because" or "so", never a chain. Do not
  fragment a chain into staccato either. There is no length cap (see
  Departures). (#2046, #2043)
- Name the actor. (#2043)
- Print a configuration name or value in code font and gloss it in the
  direction the name reads. Gloss `DisabledForLocalAddresses` as exempting
  local addresses, not as demanding remote authentication. (#2046)
- Placeholders take the form `<APP>__AUTH__REQUIRED`, never a character
  that is also a literal value in the document, because `*__` failed once
  `*` became a setting. (#2046)
- Define a term in the sentence that first depends on it, and use one name
  per thing throughout. (#2047)
- A condition reads "if" or "only if", never "when". (#2047)
- A body with more than one role lists them once and says which can be the
  same person. (#2047)
- A measurement states its unit and its baseline in the same sentence.
  (#2047)

## Punctuation

- A label colon ("Validation:") is fine. A colon joining two clauses is
  not, so end the sentence. A semicolon or an em dash is rare: only
  where it improves flow, never as compression. (#2043, #2046, owner)
- An aside goes in brackets, never between a subject and its verb. (#2046)

## Cutting

- Cut history the reader never acts on: merge dates, resolved quirks,
  precedents. (#2046)
- No clock outside a Current state section: no "today", no "recently", no
  forecasts about other repositories. (#2046, #2047)
- Mark every unobserved outcome once, up front: "Expected after reconcile,
  not yet observed:". (#2046)
- A body does not exceed what its decisions need. One mirroring a peer's
  change does not exceed the peer's body without naming what the extra
  words buy. (#2046)
- Restate a peer's reasoning in local terms and your own sentences. The
  body must stand if the peer's body vanished; summarise and link only if
  the peer's reasoning is sound. (#2046)

## Departures

This guide records two departures so that editors stop re-flagging them.

- No sentence-length or paragraph-length targets. ASD-STE100 and the pstack
  skills set 20-word and six-sentence caps. The draft that met them was the
  one the owner could not follow. Count causal links per sentence and
  unresolved referents per paragraph instead. (#2046)
- Semicolons and em dashes are allowed, rarely. The unslop skill bans em
  dashes and ASD-STE100 bans semicolons. The owner prefers restrained use
  to a ban.

## Resources

A pool of candidate rules. Nothing here is adopted wholesale. A rule moves
from this pool into the sections above only through the evidence loop.

- pstack `technical-writing` and `unslop` skills
- ASD-STE100 Simplified Technical English, via the `asd-ste100` skill
- Google engineering practices, "Writing good CL descriptions"
- Linux kernel documentation, "Describing your changes"
- GOV.UK content design style guide
- Google and Microsoft developer documentation style guides, for mechanics
