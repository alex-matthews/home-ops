# Review contract

Governs how a review of drafted prose is conducted and reported. Domain
rules live in `AGENTS.md` and the guides; the reviewer defers to them and
flags a conflict with them rather than restating them.

## Lenses

Three passes catch disjoint defects, run in this order.

- **Cold reader**: read the draft before the fact sheet, as the reader
  `docs/guides/writing-style.md` names, and answer that guide's three
  questions (what changed, why now, and is it safe), noting the position
  of the sentence that answers each. A readability finding counts only if
  that reader would misread a fact or a decision.
  The verdict names the audience it certifies. Five expert passes once
  certified prose the owner found unreadable (#1233).
- **Technical writing**: apply the style guide to every sentence, with
  the external references it lists as the check behind each rule. Report
  a rule that produced worse prose as a finding against the rule.
- **Adversarial-factual**: try to falsify claims, weakest first, against
  the fact sheet and the artifacts the draft describes. On a restyle,
  enumerate every sentence that is new since the last verified pass,
  because fluent rewrites reopen factual risk on every touched sentence.

## The gate

Every agent-drafted artifact passes an editor before the owner reads it.
The author and the editor are different agent instances; the owner is
the repository owner. One editor runs all three lenses. A second editor
joins for a body about storage, authentication, or a decision. The
editor works from a fact sheet the author writes first, in two parts.
Must-preserve holds the decisions and facts no edit may add, drop,
soften, or reinterpret. May-cut holds the context an editor may shorten
or remove. An editor who is unsure whether an edit changes meaning
leaves it and lists it.

Each pass records three measures in the evidence log
(`.private/prose-evidence-log.md`): for the first draft and for the
revised draft, the position of the sentence that answered each of the
three questions, counted from the top, or "unanswered"; and the owner's
yes or no to posting the result without a further edit round. A model
has no clock, so seconds it reports are estimates and are logged only as
a courtesy, from the same model each time. The first-draft positions
track the author's drafting, the revised-draft positions the body that
ships. Briefs for the editor and the reader are in
[editor-briefs.md](editor-briefs.md).

## Findings

- Severity-ranked, most severe first; each labelled Wrong, Unsupported,
  Missing, or Disagree, and blocking or non-blocking.
- Preferences are labelled as preferences and never block.
- Never write "confirmed" for a source not read. Unverifiable claims are
  reported as unknowns, not blockers. Re-verify numbers; never inherit
  them.
- No praise findings; omit sections with nothing to report; a trivial
  artifact gets the compact form — verdict plus one line per item.

## Verdict

- Computed from the findings list: any actionable finding forces "accept
  with changes". Style preferences alone cannot lower a verdict.
- The reviewer declares a stop when the remaining work is testing, not
  prose. A review loop without a declared stop diverges.

## Convergence

- Fix a wrong claim by removing or shortening it, never by fencing it
  with qualifiers. A fix that lengthens the sentence it corrects needs
  justification; qualifier accretion hands the next round a new target.
- Probe classifications and counts ("is N the right number?", "are these
  obvious?") — owner probing is the most effective lens on record, and a
  reviewer should apply it before the owner has to.
- Sentence-level patchwork collapses readability; once it accumulates,
  the fix is a holistic rewrite that preserves the agreed facts.
