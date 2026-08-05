"""Security tests: profiles/ must not ship secrets or private hostnames."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent.parent
PROFILES_DIR = REPO_ROOT / "profiles"

SECRET_PATTERNS = [
    (r"ghp_[A-Za-z0-9]{36}", "GitHub personal access token"),
    (r"gho_[A-Za-z0-9]{36}", "GitHub OAuth token"),
    (r"ghu_[A-Za-z0-9]{36}", "GitHub user token"),
    (r"ghs_[A-Za-z0-9]{36}", "GitHub server token"),
    (r"ghr_[A-Za-z0-9]{36}", "GitHub refresh token"),
    (r"sk-[A-Za-z0-9]{20,}", "OpenAI API key"),
    (r"sk-ant-[A-Za-z0-9-]+", "Anthropic API key"),
    (r"xox[baprs]-[A-Za-z0-9-]+", "Slack token"),
    (r"AKIA[0-9A-Z]{16}", "AWS access key ID"),
    (r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", "Private key block"),
]

PRIVATE_HOSTNAME_NEEDLES = (
    ".local",
    "colibri",
    "skypiea",
    "192.168.",
    "10.",
)

PROFILE_SUFFIXES = {".json", ".yaml", ".yml", ".md", ".mdc", ".toml", ".txt"}


def _iter_profile_files() -> list[Path]:
    assert PROFILES_DIR.is_dir(), f"Missing profiles directory: {PROFILES_DIR}"
    return [
        path
        for path in PROFILES_DIR.rglob("*")
        if path.is_file() and path.suffix.lower() in PROFILE_SUFFIXES
    ]


def _assert_no_private_hostnames(path: Path, text: str) -> None:
    lower = text.lower()
    for needle in PRIVATE_HOSTNAME_NEEDLES:
        if needle in (".local", "10."):
            if re.search(rf"https?://[^\s\"']*{re.escape(needle)}", text, re.I):
                pytest.fail(f"Private hostname pattern {needle!r} in {path}")
            if needle == "10." and re.search(r"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", text):
                pytest.fail(f"Private IPv4 10.x address in {path}")
            continue
        if needle == "192.168." and re.search(r"\b192\.168\.\d{1,3}\.\d{1,3}\b", text):
            pytest.fail(f"Private IPv4 192.168.x address in {path}")
            continue
        if needle in lower:
            pytest.fail(f"Private hostname pattern {needle!r} in {path}")


def _assert_no_secrets(path: Path, text: str) -> None:
    for pattern, label in SECRET_PATTERNS:
        match = re.search(pattern, text)
        if match:
            snippet = match.group()[:24]
            pytest.fail(f"{label} pattern in {path}: {snippet}...")


@pytest.fixture(scope="module")
def profile_files() -> list[Path]:
    files = _iter_profile_files()
    assert files, "profiles/ contains no scannable files"
    return files


def test_profiles_directory_exists():
    assert PROFILES_DIR.is_dir()


def test_profiles_have_scannable_files(profile_files):
    assert len(profile_files) >= 1


@pytest.mark.parametrize("pattern_label", [label for _, label in SECRET_PATTERNS])
def test_no_secret_patterns_in_profiles(profile_files, pattern_label):
    """Installer profiles must not contain credential-like values."""
    patterns = dict(SECRET_PATTERNS)
    pattern = next(p for p, label in SECRET_PATTERNS if label == pattern_label)
    for path in profile_files:
        text = path.read_text(encoding="utf-8", errors="replace")
        match = re.search(pattern, text)
        if match:
            pytest.fail(
                f"{pattern_label} in {path.relative_to(REPO_ROOT)}: "
                f"{match.group()[:24]}..."
            )


def test_no_private_hostnames_in_profiles(profile_files):
    """Installer profiles must not ship private LAN hostnames or org-specific hosts."""
    for path in profile_files:
        text = path.read_text(encoding="utf-8", errors="replace")
        _assert_no_private_hostnames(path, text)


def test_no_private_ipv4_literals_in_profiles(profile_files):
    """Explicit scan for RFC1918-style IPv4 literals in profile configs."""
    ipv4_private = re.compile(
        r"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|"
        r"172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"
    )
    for path in profile_files:
        text = path.read_text(encoding="utf-8", errors="replace")
        match = ipv4_private.search(text)
        if match:
            pytest.fail(f"Private IPv4 {match.group()} in {path.relative_to(REPO_ROOT)}")
