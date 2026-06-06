#!/usr/bin/env bash
set -euo pipefail

output="${1:-codex-research.md}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

: "${PR_NUMBER:?PR_NUMBER is required}"
: "${REPOSITORY:?REPOSITORY is required}"
: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"

pr_json="${tmpdir}/pr.json"
urls_file="${tmpdir}/urls.txt"
repos_file="${tmpdir}/repos.txt"
compares_file="${tmpdir}/compares.txt"
external_urls_file="${tmpdir}/external-urls.txt"

gh pr view "${PR_NUMBER}" \
    --json title,body,author,baseRefName,headRefName,files,commits,labels \
    --jq . > "${pr_json}"

{
    echo "# Renovate Review Evidence"
    echo
    echo "## Pull Request"
    jq -r '
      "- Repository: " + env.REPOSITORY,
      "- Pull request: #" + env.PR_NUMBER,
      "- Title: " + .title,
      "- Author: " + .author.login,
      "- Base: " + .baseRefName + " @ " + env.BASE_SHA,
      "- Head: " + .headRefName + " @ " + env.HEAD_SHA,
      "- Labels: " + ([.labels[].name] | join(", "))
    ' "${pr_json}"
    echo
    echo "## Pull Request Body"
    jq -r '.body // ""' "${pr_json}"
    echo
    echo "## Changed Files"
    jq -r '.files[] | "- " + .path + " (+" + (.additions | tostring) + "/-" + (.deletions | tostring) + ", " + .changeType + ")"' "${pr_json}"
    echo
    echo "## Commits"
    jq -r '.commits[] | "- " + .oid[0:12] + " " + .messageHeadline' "${pr_json}"
    echo
    echo "## Unified Diff"
    git --no-pager diff --stat=200 "${BASE_SHA}" "${HEAD_SHA}"
    git --no-pager diff --unified=5 "${BASE_SHA}" "${HEAD_SHA}"
} > "${output}"

jq -r '.body // ""' "${pr_json}" \
    | tr '[]()<>' '\n' \
    | tr '[:space:]' '\n' \
    | sed -n 's#^\(https://[^[:space:]]*\).*#\1#p' \
    | sed 's/[),.;]*$//' \
    | sed 's#https://redirect.github.com/#https://github.com/#' \
    | awk '!seen[$0]++' > "${urls_file}" || true

{
    echo
    echo "## Links Found In Pull Request Body"
    if [ -s "${urls_file}" ]; then
        sed 's/^/- /' "${urls_file}"
    else
        echo "No URLs found."
    fi
} >> "${output}"

true > "${repos_file}"
true > "${compares_file}"
true > "${external_urls_file}"

while IFS= read -r url; do
    if [[ "${url}" =~ ^https://github\.com/([^/]+)/([^/#?]+) ]]; then
        repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
        if [ "${repo}" = "renovatebot/renovate" ]; then
            continue
        fi
        echo "${repo}" >> "${repos_file}"

        if [[ "${url}" =~ ^https://github\.com/[^/]+/[^/]+/compare/([^?#]+) ]]; then
            echo "${repo} ${BASH_REMATCH[1]}" >> "${compares_file}"
        fi
    elif [[ "${url}" =~ ^https:// ]]; then
        echo "${url}" >> "${external_urls_file}"
    fi
done < "${urls_file}"

sort -u -o "${repos_file}" "${repos_file}"
sort -u -o "${compares_file}" "${compares_file}"
sort -u -o "${external_urls_file}" "${external_urls_file}"

append_github_file() {
    local repo="$1"
    local path="$2"
    local target="${tmpdir}/content"

    if gh api "repos/${repo}/contents/${path}" -H "Accept: application/vnd.github.raw" > "${target}" 2>/dev/null; then
        if [ -s "${target}" ]; then
            {
                echo
                echo "#### ${path}"
                echo
                head -c 30000 "${target}"
                echo
            } >> "${output}"
        fi
    fi
}

repo_count=0
while IFS= read -r repo; do
    [ -n "${repo}" ] || continue
    repo_count=$((repo_count + 1))
    [ "${repo_count}" -le 8 ] || break

    {
        echo
        echo "## GitHub Research: ${repo}"
        echo
        echo "### Repository Metadata"
    } >> "${output}"

    gh api "repos/${repo}" \
        --jq '
          "- URL: " + .html_url,
          "- Description: " + (.description // ""),
          "- Default branch: " + .default_branch,
          "- Homepage: " + (.homepage // ""),
          "- Pushed at: " + .pushed_at,
          "- Topics: " + ((.topics // []) | join(", "))
        ' >> "${output}" 2>/dev/null || echo "Repository metadata unavailable." >> "${output}"

    {
        echo
        echo "### Recent GitHub Releases"
    } >> "${output}"

    gh release list -R "${repo}" --limit 12 >> "${output}" 2>/dev/null \
        || echo "No GitHub releases found or releases unavailable." >> "${output}"

    {
        echo
        echo "### Changelog And Migration Files"
    } >> "${output}"

    found_file=false
    for path in \
        CHANGELOG.md \
        changelog.md \
        CHANGELOG \
        CHANGES.md \
        RELEASES.md \
        UPGRADING.md \
        MIGRATION.md \
        README.md \
        docs/CHANGELOG.md \
        docs/UPGRADING.md \
        docs/MIGRATION.md
    do
        before_size="$(wc -c < "${output}")"
        append_github_file "${repo}" "${path}"
        after_size="$(wc -c < "${output}")"
        if [ "${after_size}" -gt "${before_size}" ]; then
            found_file=true
        fi
    done

    if [ "${found_file}" = false ]; then
        echo "No common changelog or migration files found." >> "${output}"
    fi
done < "${repos_file}"

if [ -s "${compares_file}" ]; then
    {
        echo
        echo "## GitHub Compare Summaries"
    } >> "${output}"

    compare_count=0
    while read -r repo compare; do
        [ -n "${repo}" ] || continue
        [ -n "${compare}" ] || continue
        compare_count=$((compare_count + 1))
        [ "${compare_count}" -le 8 ] || break

        {
            echo
            echo "### ${repo}: ${compare}"
        } >> "${output}"

        gh api "repos/${repo}/compare/${compare}" \
            --jq '
              "- Status: " + .status,
              "- Ahead by: " + (.ahead_by | tostring),
              "- Behind by: " + (.behind_by | tostring),
              "",
              "Commits:",
              (.commits[:50][] | "- " + .sha[0:12] + " " + (.commit.message | split("\n")[0]))
            ' >> "${output}" 2>/dev/null || echo "Compare metadata unavailable." >> "${output}"
    done < "${compares_file}"
fi

safe_external_url() {
    local url="$1"
    local host
    host="${url#https://}"
    host="${host%%/*}"

    case "${host}" in
        localhost | localhost:* | 127.* | 10.* | 192.168.* | 169.254.*)
            return 1
            ;;
    esac

    if [[ "${host}" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        return 1
    fi

    return 0
}

if [ -s "${external_urls_file}" ]; then
    {
        echo
        echo "## Linked External Pages"
    } >> "${output}"

    external_count=0
    while IFS= read -r url; do
        [ -n "${url}" ] || continue
        safe_external_url "${url}" || continue
        external_count=$((external_count + 1))
        [ "${external_count}" -le 10 ] || break

        target="${tmpdir}/external"
        {
            echo
            echo "### ${url}"
            echo
        } >> "${output}"

        if curl -fsSL --max-time 10 --retry 1 --location --max-filesize 200000 "${url}" > "${target}" 2>/dev/null; then
            head -c 40000 "${target}" >> "${output}"
            echo >> "${output}"
        else
            echo "Unable to fetch linked page." >> "${output}"
        fi
    done < "${external_urls_file}"
fi
