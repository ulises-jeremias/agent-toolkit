#!/usr/bin/env python3
"""Daily GitHub contribution planner.

Inspect the gh-authenticated user's owned repos (forks + sources), open
pull requests, and recent contributions, then emit a prioritized plan
grouped by effort/impact buckets. Markdown by default; JSON via --json.

Designed to be invoked from the agent-toolkit `gh-contribution-planner` skill.
Stdlib only — relies exclusively on the `gh` CLI for GitHub access.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from shutil import which
from typing import Any

DEFAULT_SINCE = "90d"
DEFAULT_MAX_PER_BUCKET = 5
PARALLEL_FORK_COMPARES = 8
QUICK_WIN_DORMANT_DAYS = 60
STALE_ISSUE_DAYS_DEFAULT = 90
REVIEW_FEEDBACK_AGE_DAYS = 7

BUCKETS = (
    "quick_wins",
    "in_flight_prs",
    "review_feedback",
    "forks_to_sync",
    "maintenance",
    "external_contributions",
)

BUCKET_LABELS = {
    "quick_wins": "Quick wins (~15 min)",
    "in_flight_prs": "In-flight PRs",
    "review_feedback": "Review feedback",
    "forks_to_sync": "Forks needing sync",
    "maintenance": "Maintenance",
    "external_contributions": "External contributions",
}

DELEGATES = {
    "quick_wins": "github-cli-workflow",
    "in_flight_prs": "gh-fix-ci or github-cli-workflow",
    "review_feedback": "gh-address-comments",
    "forks_to_sync": "github-cli-workflow (gh repo sync)",
    "maintenance": "github-cli-workflow",
    "external_contributions": "github-cli-workflow",
}

CONTRIBUTIONS_GRAPHQL = """
query($login: String!, $since: DateTime!) {
  user(login: $login) {
    contributionsCollection(from: $since) {
      commitContributionsByRepository(maxRepositories: 50) {
        repository { nameWithOwner url isPrivate owner { login } }
        contributions { totalCount }
      }
      pullRequestContributionsByRepository(maxRepositories: 50) {
        repository { nameWithOwner url isPrivate owner { login } }
        contributions { totalCount }
      }
      issueContributionsByRepository(maxRepositories: 25) {
        repository { nameWithOwner url isPrivate owner { login } }
        contributions { totalCount }
      }
    }
  }
}
""".strip()

OPEN_PRS_GRAPHQL = """
query($queryString: String!) {
  search(query: $queryString, type: ISSUE, first: 100) {
    nodes {
      ... on PullRequest {
        url
        title
        number
        isDraft
        createdAt
        updatedAt
        state
        reviewDecision
        repository { nameWithOwner }
      }
    }
  }
}
""".strip()


class GhResult:
    def __init__(self, returncode: int, stdout: str, stderr: str) -> None:
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def run_gh(args: list[str], *, dry_run: bool = False) -> GhResult:
    if dry_run:
        print(f"+ gh {' '.join(args)}", file=sys.stderr)
        empty = "[]" if any(a == "--json" for a in args) else ""
        return GhResult(0, empty, "")
    proc = subprocess.run(["gh", *args], text=True, capture_output=True)
    return GhResult(proc.returncode, proc.stdout, proc.stderr)


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return parsed


def _non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Daily GitHub contribution planner. Analyzes the gh-authenticated "
            "user's repos and recent contributions, emitting a prioritized plan."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--since",
        default=DEFAULT_SINCE,
        help="Lookback window. Accepts e.g. 30d, 90d, 180d, or ISO date YYYY-MM-DD.",
    )
    parser.add_argument(
        "--max-per-bucket",
        type=_positive_int,
        default=DEFAULT_MAX_PER_BUCKET,
        help="Cap items per bucket (must be > 0).",
    )
    parser.add_argument(
        "--user",
        default=None,
        help="Override the gh-inferred login (testing or org planning).",
    )
    parser.add_argument(
        "--stale-issue-days",
        type=_non_negative_int,
        default=STALE_ISSUE_DAYS_DEFAULT,
        help="Issues older than this many days count as stale (must be >= 0).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON instead of Markdown.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the gh calls that would be issued and exit (no network).",
    )
    return parser.parse_args()


def parse_since(value: str) -> tuple[str, str]:
    """Return (iso_date, iso_datetime_utc) for the lookback window."""
    value = value.strip()
    match = re.fullmatch(r"(\d+)\s*d", value, flags=re.IGNORECASE)
    if match:
        days = int(match.group(1))
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)
        return cutoff.date().isoformat(), cutoff.replace(microsecond=0).isoformat()
    try:
        parsed = datetime.strptime(value, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise SystemExit(
            f"Invalid --since value: {value!r} (expected 30d/90d/.../YYYY-MM-DD)"
        ) from exc
    return parsed.date().isoformat(), parsed.replace(microsecond=0).isoformat()


def ensure_gh_available() -> bool:
    if which("gh") is None:
        print("Error: gh is not installed or not on PATH.", file=sys.stderr)
        return False
    result = run_gh(["auth", "status"])
    if result.returncode == 0:
        return True
    msg = (result.stderr or result.stdout or "").strip()
    print(msg or "Error: gh is not authenticated. Run `gh auth login`.", file=sys.stderr)
    return False


def resolve_user(override: str | None, *, dry_run: bool) -> str | None:
    if override:
        return override
    if dry_run:
        return "<gh-user>"
    result = run_gh(["api", "user", "--jq", ".login"])
    if result.returncode != 0:
        msg = (result.stderr or result.stdout or "").strip()
        print(msg or "Error: unable to resolve gh user.", file=sys.stderr)
        return None
    login = result.stdout.strip()
    if not login:
        print("Error: gh api user returned an empty login.", file=sys.stderr)
        return None
    return login


def fetch_owned_repos(user: str, *, dry_run: bool) -> list[dict[str, Any]]:
    fields = ",".join(
        [
            "nameWithOwner",
            "name",
            "owner",
            "description",
            "isFork",
            "isPrivate",
            "isArchived",
            "pushedAt",
            "updatedAt",
            "url",
            "defaultBranchRef",
            "primaryLanguage",
            "parent",
            "stargazerCount",
            "forkCount",
            "visibility",
        ]
    )
    result = run_gh(
        ["repo", "list", user, "--no-archived", "--limit", "1000", "--json", fields],
        dry_run=dry_run,
    )
    if result.returncode != 0:
        msg = (result.stderr or result.stdout or "").strip()
        print(f"Warning: gh repo list failed: {msg}", file=sys.stderr)
        return []
    return _parse_json_list(result.stdout)


def fetch_authored_open_prs(user: str, *, dry_run: bool) -> list[dict[str, Any]]:
    query_string = f"is:pr is:open author:{user}"
    if dry_run:
        print(
            f"+ gh api graphql -f query=<openPullRequests> -f queryString='{query_string}'",
            file=sys.stderr,
        )
        return []
    result = run_gh(
        [
            "api",
            "graphql",
            "-f",
            f"query={OPEN_PRS_GRAPHQL}",
            "-f",
            f"queryString={query_string}",
        ]
    )
    if result.returncode != 0:
        msg = (result.stderr or result.stdout or "").strip()
        print(f"Warning: open PRs GraphQL query failed: {msg}", file=sys.stderr)
        return []
    try:
        payload = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return []
    nodes = ((payload.get("data") or {}).get("search") or {}).get("nodes") or []
    return [node for node in nodes if isinstance(node, dict) and node]


def fetch_contributions_collection(
    user: str, since_iso_datetime: str, *, dry_run: bool
) -> dict[str, Any]:
    if dry_run:
        print(
            f"+ gh api graphql -f query=<contributionsCollection> -f login={user} "
            f"-f since={since_iso_datetime}",
            file=sys.stderr,
        )
        return {}
    result = run_gh(
        [
            "api",
            "graphql",
            "-f",
            f"query={CONTRIBUTIONS_GRAPHQL}",
            "-f",
            f"login={user}",
            "-f",
            f"since={since_iso_datetime}",
        ]
    )
    if result.returncode != 0:
        msg = (result.stderr or result.stdout or "").strip()
        print(f"Warning: contributionsCollection query failed: {msg}", file=sys.stderr)
        return {}
    try:
        payload = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return {}
    return ((payload.get("data") or {}).get("user") or {}).get("contributionsCollection") or {}


def fetch_owner_open_issues(
    user: str, *, label: str | None, no_assignee: bool, dry_run: bool
) -> list[dict[str, Any]]:
    fields = "repository,url,number,title,updatedAt,labels,assignees,author,state"
    args = [
        "search",
        "issues",
        "--owner",
        user,
        "--state",
        "open",
        "--limit",
        "200",
        "--json",
        fields,
    ]
    if label:
        args.extend(["--label", label])
    if no_assignee:
        args.append("--no-assignee")
    result = run_gh(args, dry_run=dry_run)
    if result.returncode != 0:
        msg = (result.stderr or result.stdout or "").strip()
        print(f"Warning: gh search issues failed: {msg}", file=sys.stderr)
        return []
    return _parse_json_list(result.stdout)


def fetch_fork_compare(fork: dict[str, Any]) -> dict[str, Any]:
    parent = fork.get("parent") or {}
    parent_owner = (parent.get("owner") or {}).get("login")
    parent_name = parent.get("name")
    fork_default = (fork.get("defaultBranchRef") or {}).get("name")
    parent_default = (parent.get("defaultBranchRef") or {}).get("name")
    fork_owner = (fork.get("owner") or {}).get("login")
    fork_name = fork.get("name")
    out: dict[str, Any] = {
        "fork": fork.get("nameWithOwner"),
        "fork_url": fork.get("url"),
        "parent": (f"{parent_owner}/{parent_name}" if parent_owner and parent_name else None),
        "behind": None,
        "ahead": None,
        "error": None,
    }
    missing = not (
        parent_owner
        and parent_name
        and fork_default
        and parent_default
        and fork_owner
        and fork_name
    )
    if missing:
        out["error"] = "Missing parent or default branch metadata."
        return out
    endpoint = (
        f"/repos/{parent_owner}/{parent_name}/compare/"
        f"{parent_default}...{fork_owner}:{fork_default}"
    )
    result = run_gh(["api", endpoint, "--jq", "{behind_by, ahead_by}"])
    if result.returncode != 0:
        out["error"] = (result.stderr or result.stdout or "").strip()[:200]
        return out
    try:
        data = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        out["error"] = "Unable to parse compare JSON."
        return out
    out["behind"] = data.get("behind_by")
    out["ahead"] = data.get("ahead_by")
    return out


def _parse_json_list(text: str) -> list[dict[str, Any]]:
    try:
        data = json.loads(text or "[]")
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def _iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _label_names(item: dict[str, Any]) -> list[str]:
    labels = item.get("labels") or []
    out: list[str] = []
    for label in labels:
        if isinstance(label, dict):
            name = label.get("name")
            if name:
                out.append(str(name))
        elif isinstance(label, str):
            out.append(label)
    return out


def _repo_full(value: Any) -> str:
    if isinstance(value, dict):
        return value.get("nameWithOwner") or ""
    return ""


def bucketize(
    *,
    user: str,
    since_iso: str,
    repos: list[dict[str, Any]],
    open_prs: list[dict[str, Any]],
    contributions: dict[str, Any],
    issues_good_first: list[dict[str, Any]],
    issues_help_wanted: list[dict[str, Any]],
    issues_owned: list[dict[str, Any]],
    fork_compares: list[dict[str, Any]],
    stale_issue_days: int,
    max_per_bucket: int,
) -> dict[str, list[dict[str, Any]]]:
    plan: dict[str, list[dict[str, Any]]] = {bucket: [] for bucket in BUCKETS}
    now = datetime.now(timezone.utc)

    # --- Filter issues to non-archived repos ---
    # `repos` is fetched with --no-archived so it only contains non-archived
    # repos. `gh search issues --owner <user>` does NOT exclude archived repos,
    # so issues from archived repos leak into the Maintenance and Quick wins
    # buckets. Filter them out here using the non-archived repo set as an
    # allow-list. Guard on non_archived_repos being non-empty so that a failed
    # repos fetch doesn't wipe all issue items (fall back to old behavior).
    non_archived_repos: set[str] = {(repo.get("nameWithOwner") or "") for repo in repos}
    if non_archived_repos:
        issues_good_first = [
            i for i in issues_good_first if _repo_full(i.get("repository")) in non_archived_repos
        ]
        issues_help_wanted = [
            i for i in issues_help_wanted if _repo_full(i.get("repository")) in non_archived_repos
        ]
        issues_owned = [
            i for i in issues_owned if _repo_full(i.get("repository")) in non_archived_repos
        ]

    # --- Quick wins ---
    quick: list[tuple[int, dict[str, Any]]] = []
    for repo in repos:
        if repo.get("isFork") or repo.get("isArchived"):
            continue
        pushed = _iso(repo.get("pushedAt"))
        if not pushed:
            continue
        age_days = (now - pushed).days
        if age_days >= QUICK_WIN_DORMANT_DAYS:
            quick.append((age_days, repo))
    quick.sort(key=lambda pair: pair[0], reverse=True)
    for age_days, repo in quick[:max_per_bucket]:
        plan["quick_wins"].append(
            {
                "repo": repo.get("nameWithOwner"),
                "url": repo.get("url"),
                "summary": (
                    f"Dormant for {age_days} days — README polish, dependency bump, "
                    "or CI badge update."
                ),
                "effort": "~15 min",
                "delegate": DELEGATES["quick_wins"],
                "signals": {
                    "pushed_days_ago": age_days,
                    "stars": repo.get("stargazerCount", 0),
                },
            }
        )

    # Top up quick_wins with unassigned good-first-issue / help-wanted in own repos.
    # Issues can carry both labels — dedupe by (repo, number) so each slot is unique.
    own_easy_raw = [i for i in issues_good_first if not (i.get("assignees") or [])] + [
        i for i in issues_help_wanted if not (i.get("assignees") or [])
    ]
    own_easy: list[dict[str, Any]] = []
    seen_easy: set[tuple[str, Any]] = set()
    for issue in own_easy_raw:
        key = (_repo_full(issue.get("repository")), issue.get("number"))
        if key in seen_easy:
            continue
        seen_easy.add(key)
        own_easy.append(issue)
    remaining = max(0, max_per_bucket - len(plan["quick_wins"]))
    for issue in own_easy[:remaining]:
        plan["quick_wins"].append(
            {
                "repo": _repo_full(issue.get("repository")),
                "url": issue.get("url"),
                "issue_number": issue.get("number"),
                "summary": f"Unassigned `{', '.join(_label_names(issue))}` issue: {issue.get('title')!r}",
                "effort": "~15 min",
                "delegate": DELEGATES["quick_wins"],
                "signals": {"labels": _label_names(issue)},
            }
        )

    # --- In-flight PRs ---
    def _pr_sort_key(pr: dict[str, Any]) -> tuple[int, datetime]:
        is_ready = 0 if pr.get("isDraft") else 1
        updated = _iso(pr.get("updatedAt")) or datetime.min.replace(tzinfo=timezone.utc)
        return (is_ready, updated)

    for pr in sorted(open_prs, key=_pr_sort_key, reverse=True)[:max_per_bucket]:
        updated = _iso(pr.get("updatedAt"))
        age_days = (now - updated).days if updated else None
        summary = pr.get("title") or ""
        if pr.get("isDraft"):
            summary = f"[draft] {summary}"
        plan["in_flight_prs"].append(
            {
                "repo": _repo_full(pr.get("repository")),
                "url": pr.get("url"),
                "pr_number": pr.get("number"),
                "summary": summary,
                "effort": "varies",
                "delegate": DELEGATES["in_flight_prs"],
                "signals": {
                    "is_draft": bool(pr.get("isDraft")),
                    "updated_days_ago": age_days,
                },
            }
        )

    # --- Review feedback ---
    # Filter strictly by reviewDecision == CHANGES_REQUESTED so this bucket
    # represents real unaddressed reviewer feedback, not just inactivity.
    candidates: list[tuple[int, dict[str, Any]]] = []
    for pr in open_prs:
        if pr.get("isDraft"):
            continue
        if pr.get("reviewDecision") != "CHANGES_REQUESTED":
            continue
        updated = _iso(pr.get("updatedAt"))
        age_days = (now - updated).days if updated else 0
        candidates.append((age_days, pr))
    candidates.sort(key=lambda pair: pair[0], reverse=True)
    for age_days, pr in candidates[:max_per_bucket]:
        plan["review_feedback"].append(
            {
                "repo": _repo_full(pr.get("repository")),
                "url": pr.get("url"),
                "pr_number": pr.get("number"),
                "summary": (
                    f"Reviewer requested changes ({age_days} days since last activity) "
                    "— address the feedback."
                ),
                "effort": "~30 min",
                "delegate": DELEGATES["review_feedback"],
                "signals": {
                    "review_decision": pr.get("reviewDecision"),
                    "updated_days_ago": age_days,
                },
            }
        )

    # --- Forks needing sync ---
    drift = [fc for fc in fork_compares if isinstance(fc.get("behind"), int) and fc["behind"] > 0]
    drift.sort(key=lambda fc: fc.get("behind") or 0, reverse=True)
    for fc in drift[:max_per_bucket]:
        plan["forks_to_sync"].append(
            {
                "repo": fc.get("fork"),
                "url": fc.get("fork_url"),
                "parent": fc.get("parent"),
                "summary": (
                    f"Fork is {fc.get('behind')} commits behind {fc.get('parent')}; "
                    f"ahead {fc.get('ahead') or 0}."
                ),
                "effort": "~5 min (clean sync) / ~30 min (conflicts)",
                "delegate": DELEGATES["forks_to_sync"],
                "signals": {
                    "behind": fc.get("behind"),
                    "ahead": fc.get("ahead"),
                },
            }
        )

    # --- Maintenance: stale issues in own repos (authored by others) ---
    stale_cutoff = now - timedelta(days=stale_issue_days)
    stale: list[tuple[int, dict[str, Any]]] = []
    for issue in issues_owned:
        updated = _iso(issue.get("updatedAt"))
        if not updated or updated > stale_cutoff:
            continue
        author = (issue.get("author") or {}).get("login", "")
        if author and author.lower() == user.lower():
            continue
        stale.append(((now - updated).days, issue))
    stale.sort(key=lambda pair: pair[0], reverse=True)
    for age_days, issue in stale[:max_per_bucket]:
        plan["maintenance"].append(
            {
                "repo": _repo_full(issue.get("repository")),
                "url": issue.get("url"),
                "issue_number": issue.get("number"),
                "summary": (f"Issue stale for {age_days} days: {issue.get('title')!r}"),
                "effort": "~20 min",
                "delegate": DELEGATES["maintenance"],
                "signals": {
                    "updated_days_ago": age_days,
                    "labels": _label_names(issue),
                },
            }
        )

    # --- External contributions ---
    aggregate: dict[str, dict[str, Any]] = {}

    def _ingest(section: str, weight: int) -> None:
        for node in contributions.get(section) or []:
            repo = node.get("repository") or {}
            repo_full = repo.get("nameWithOwner") or ""
            if not repo_full:
                continue
            owner = (repo.get("owner") or {}).get("login", "")
            if owner and owner.lower() == user.lower():
                continue
            entry = aggregate.setdefault(
                repo_full,
                {
                    "repo": repo_full,
                    "url": repo.get("url") or f"https://github.com/{repo_full}",
                    "score": 0,
                    "commits": 0,
                    "prs": 0,
                    "issues": 0,
                    "private": bool(repo.get("isPrivate")),
                },
            )
            count = (node.get("contributions") or {}).get("totalCount", 0)
            entry["score"] += weight * count
            if section.startswith("commit"):
                entry["commits"] += count
            elif section.startswith("pullRequest"):
                entry["prs"] += count
            elif section.startswith("issue"):
                entry["issues"] += count

    _ingest("pullRequestContributionsByRepository", weight=3)
    _ingest("commitContributionsByRepository", weight=2)
    _ingest("issueContributionsByRepository", weight=1)

    external = sorted(aggregate.values(), key=lambda entry: entry["score"], reverse=True)
    for entry in external[:max_per_bucket]:
        signals = {
            "recent_commits": entry["commits"],
            "recent_prs": entry["prs"],
            "recent_issues": entry["issues"],
        }
        plan["external_contributions"].append(
            {
                "repo": entry["repo"],
                "url": entry["url"],
                "summary": (
                    f"Active externally since {since_iso} "
                    f"(commits={entry['commits']}, prs={entry['prs']}, issues={entry['issues']}). "
                    "Scan for `good first issue` / `help wanted`."
                ),
                "effort": "varies",
                "delegate": DELEGATES["external_contributions"],
                "signals": signals,
            }
        )

    plan["quick_wins"] = plan["quick_wins"][:max_per_bucket]
    return plan


def render_markdown(plan: dict[str, list[dict[str, Any]]], *, user: str, since_iso: str) -> None:
    print(f"# Daily GitHub contribution plan — @{user}")
    print()
    print(f"_Lookback window: contributions since `{since_iso}`._")
    print()
    total = sum(len(items) for items in plan.values())
    if total == 0:
        print(
            "No actionable items found. Try widening `--since`, raising "
            "`--max-per-bucket`, or verifying `gh auth status`."
        )
        return
    for bucket in BUCKETS:
        items = plan.get(bucket) or []
        if not items:
            continue
        print(f"## {BUCKET_LABELS[bucket]} ({len(items)})")
        print()
        for item in items:
            repo = item.get("repo", "") or "(unknown)"
            url = item.get("url", "")
            summary = item.get("summary", "")
            effort = item.get("effort", "")
            delegate = item.get("delegate", "")
            line = f"- **{repo}** — {summary}"
            if url:
                line += f" ([link]({url}))"
            print(line)
            print(f"  - Effort: {effort} · Delegate: `{delegate}`")
        print()
    print("---")
    print()
    print(
        "After your approval, the host agent should dispatch one sub-agent per "
        "approved item (cap: 5 concurrent). Each sub-agent must open its PR as "
        "**draft** unless explicitly marked ready-for-review."
    )


def render_json(plan: dict[str, list[dict[str, Any]]], *, user: str, since_iso: str) -> None:
    print(
        json.dumps(
            {
                "user": user,
                "since": since_iso,
                "buckets": plan,
            },
            indent=2,
        )
    )


def main() -> int:
    args = parse_args()

    if not args.dry_run and not ensure_gh_available():
        return 1

    user = resolve_user(args.user, dry_run=args.dry_run)
    if not user:
        return 1

    try:
        since_iso, since_iso_datetime = parse_since(args.since)
    except SystemExit as exc:
        print(str(exc), file=sys.stderr)
        return 2

    repos = fetch_owned_repos(user, dry_run=args.dry_run)
    open_prs = fetch_authored_open_prs(user, dry_run=args.dry_run)
    contributions = fetch_contributions_collection(user, since_iso_datetime, dry_run=args.dry_run)
    issues_good_first = fetch_owner_open_issues(
        user, label="good first issue", no_assignee=True, dry_run=args.dry_run
    )
    issues_help_wanted = fetch_owner_open_issues(
        user, label="help wanted", no_assignee=True, dry_run=args.dry_run
    )
    issues_owned = fetch_owner_open_issues(
        user, label=None, no_assignee=False, dry_run=args.dry_run
    )

    forks = [r for r in repos if r.get("isFork") and r.get("parent")]
    fork_compares: list[dict[str, Any]] = []
    if forks and not args.dry_run:
        with ThreadPoolExecutor(max_workers=PARALLEL_FORK_COMPARES) as pool:
            futures = [pool.submit(fetch_fork_compare, fork) for fork in forks]
            for future in as_completed(futures):
                try:
                    fork_compares.append(future.result())
                except Exception as exc:
                    fork_compares.append(
                        {
                            "fork": None,
                            "fork_url": None,
                            "parent": None,
                            "behind": None,
                            "ahead": None,
                            "error": f"Fork compare task failed: {exc}",
                        }
                    )
    elif args.dry_run:
        for fork in forks:
            print(
                f"+ gh api /repos/<parent>/compare/...{fork.get('nameWithOwner')}",
                file=sys.stderr,
            )

    plan = bucketize(
        user=user,
        since_iso=since_iso,
        repos=repos,
        open_prs=open_prs,
        contributions=contributions,
        issues_good_first=issues_good_first,
        issues_help_wanted=issues_help_wanted,
        issues_owned=issues_owned,
        fork_compares=fork_compares,
        stale_issue_days=args.stale_issue_days,
        max_per_bucket=args.max_per_bucket,
    )

    if args.json:
        render_json(plan, user=user, since_iso=since_iso)
    else:
        render_markdown(plan, user=user, since_iso=since_iso)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
