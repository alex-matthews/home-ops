#!/usr/bin/env bash
# Runs the cases in .github/tests/chart-signing/cases/*.txt offline (#2145).
#
# Each case starts with "=== NAME"; each section starts with "--- SECTION".
# Discovery sections: manifest, responses, results, findings, errors,
# response FILE (tool stdout). Coverage sections: base PATH, head PATH,
# expected, exit, declared (defaults to false), head-ref (optional override).
# Section bodies are literal, including blank lines; an empty body is an
# empty file. A body containing only @fixtures/NAME.yaml copies that literal
# manifest unchanged. Expected outputs stay inline in each case.
# Marker lines are reserved. Paths are relative to the corresponding tree.
#
# Coverage cases build two commits in a temporary repository to exercise
# real git reads; yq also runs unchanged. Discovery output is compared
# byte-for-byte; Coverage output is sorted, retaining duplicates. The ORAS
# stand-in matches argument-string globs, not argument boundaries or call counts.
#
# usage: .github/tests/chart-signing/run.sh [CASE...]
# To update an expectation, edit its results/findings/errors or expected/exit
# section and review the diff. Expectations are never overwritten by a run.
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
here="$root/.github/tests/chart-signing"
check="$root/.github/scripts/chart-signing-check.sh"
coverage="$root/.github/scripts/chart-signing-coverage.sh"
failed=0; passed=0
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# Materialise one case as inputs and expectations in a temporary directory.
materialise() { # case-file name destination
  local source=$1 wanted=$2 dest=$3 number section path body reference
  mkdir -p "$dest" "$work/sections"
  awk -v wanted="$wanted" -v out="$work/sections" '
    /^=== / { active = (substr($0, 5) == wanted); next }
    !active { next }
    /^--- / {
      if (file != "") close(file)
      section = substr($0, 5)
      file = out "/" ++n
      printf "" > file
      print n "\t" section > (out "/index")
      next
    }
    { if (file == "") exit 1; print > file }
    END { if (n == 0) exit 1 }
  ' "$source"
  while IFS=$'\t' read -r number section; do
    case "$section" in
      manifest) path=ocirepository.yaml ;;
      responses) path=responses.psv ;;
      results) path=results.tsv ;;
      findings) path=findings.md ;;
      errors) path=errors.md ;;
      expected) path=expected.txt ;;
      exit) path=expected.exit ;;
      declared|head-ref) path="$section" ;;
      'response '*) path="${section#* }" ;;
      'base '*|'head '*) path="${section%% *}/${section#* }" ;;
      *) echo "unknown section: $section" >&2; return 1 ;;
    esac
    # Keep malformed fixture paths inside the temporary case directory.
    if [[ ! "$path" =~ ^[a-zA-Z0-9_./-]+$ || "$path" = /* || "/$path/" = */../* || "/$path/" = */./* ]]; then
      echo "invalid section path: $path" >&2; return 1
    fi
    [ ! -e "$dest/$path" ] || { echo "duplicate section path: $path" >&2; return 1; }
    mkdir -p "$(dirname "$dest/$path")"
    body="$work/sections/$number"
    reference="$(cat "$body")"
    if [[ "$reference" =~ ^@fixtures/[a-zA-Z0-9_-]+\.yaml$ ]] && [ "$(wc -l < "$body")" -eq 1 ]; then
      cp "$here/${reference#@}" "$dest/$path"
    else
      cp "$body" "$dest/$path"
    fi
  done < "$work/sections/index"
}

diff_or_fail() { # expected actual label
  if diff -u "$1" "$2" > "$work/diff"; then return 0; fi
  echo "  $3 differs:"; sed 's/^/    /' "$work/diff"; return 1
}

awk '/^=== / { print substr($0, 5) "\t" FILENAME }' "$here"/cases/*.txt | sort > "$scratch/catalog"
awk -F'\t' 'seen[$1]++ { print "duplicate case: " $1; bad=1 } END { exit bad }' "$scratch/catalog"
[ -s "$scratch/catalog" ] || { echo "no cases found" >&2; exit 1; }
cases=("$@")
if [ "${#cases[@]}" -eq 0 ]; then
  while IFS=$'\t' read -r name _; do cases+=("$name"); done < "$scratch/catalog"
fi
for name in "${cases[@]}"; do
  name="$(basename "${name%/}")"
  source="$(awk -F'\t' -v name="$name" '$1 == name { print $2 }' "$scratch/catalog")"
  [ -n "$source" ] || { echo "unknown case: $name" >&2; exit 1; }
  work="$(mktemp -d "$scratch/case.XXXXXX")"
  case="$work/input"
  materialise "$source" "$name" "$case"
  ok=1
  if [ -d "$case/head" ]; then
    repo="$work/repo"; mkdir -p "$repo"
    git -C "$repo" init -q -b main
    git -C "$repo" config user.email fixture@example.invalid; git -C "$repo" config user.name fixture
    cp -R "$case/base/." "$repo/"; git -C "$repo" add -A; git -C "$repo" commit -q -m base --allow-empty
    base="$(git -C "$repo" rev-parse HEAD)"
    find "$repo" -mindepth 1 -maxdepth 1 -not -name .git -exec rm -rf {} +
    cp -R "$case/head/." "$repo/"; git -C "$repo" add -A; git -C "$repo" commit -q -m head --allow-empty
    head="$(git -C "$repo" rev-parse HEAD)"
    declared="$(cat "$case/declared" 2> /dev/null || echo false)"
    # A case may name a head ref that does not exist, to test the ref check.
    [ -f "$case/head-ref" ] && head="$(cat "$case/head-ref")"
    set +e
    (cd "$repo" && CHART_SIGNING_TOOLS="$here/bin" "$coverage" "$base" "$head" "$declared" > "$work/out" 2>&1); code=$?
    set -e
    sort "$work/out" > "$work/out.sorted"; sort "$case/expected.txt" > "$work/exp.sorted"
    diff_or_fail "$work/exp.sorted" "$work/out.sorted" output || ok=0
    [ "$code" = "$(cat "$case/expected.exit")" ] || { echo "  exit $code, expected $(cat "$case/expected.exit")"; ok=0; }
  else
    : > "$work/findings.md"; : > "$work/errors.md"
    set +e
    (cd "$case" && CASE_DIR="$case" CHART_SIGNING_TOOLS="$here/bin" \
      FINDINGS_OUT="$work/findings.md" ERRORS_OUT="$work/errors.md" "$check" ocirepository.yaml > "$work/results.tsv" 2> "$work/stderr"); code=$?
    set -e
    [ "$code" = 0 ] || { echo "  script exited $code:"; sed 's/^/    /' "$work/stderr"; ok=0; }
    diff_or_fail "$case/results.tsv" "$work/results.tsv" results.tsv || ok=0
    diff_or_fail "$case/findings.md" "$work/findings.md" findings.md || ok=0
    diff_or_fail "$case/errors.md" "$work/errors.md" errors.md || ok=0
  fi
  if [ "$ok" = 1 ]; then echo "ok   $name"; passed=$((passed + 1)); else echo "FAIL $name"; failed=$((failed + 1)); fi
  rm -rf "$work"
done
echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
