# Review contract

Governs how a review of drafted prose is conducted and reported. Domain
rules live in `AGENTS.md` and the guides; the reviewer defers to them and
flags a conflict with them rather than restating them.

## Lenses

Two passes catch disjoint defects; run both.

- **Adversarial-factual**: try to falsify claims, weakest first. On a
  restyle, enumerate every sentence that is new since the last verified
  pass — fluent rewrites reopen factual risk on every touched sentence.
- **Cold reader**: read as an uninitiated human operator. A readability
  finding counts when that reader would misread a fact or a decision.
  The verdict names the audience it certifies; five expert passes once
  certified prose the owner found unreadable.

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
- Sentence-level patchwork collapses readability within two rounds; after
  two, the fix is a holistic rewrite that preserves the agreed facts.
