/**
 * Dangerfile for agent-toolkit
 * Runs on every PR to enforce conventions and catch common mistakes.
 *
 * Checks:
 *   1. CHANGELOG.md updated for non-trivial changes
 *   2. PR title follows Conventional Commits
 *   3. New skills include SKILL.md (no skill.json required)
 *   4. skill.json files are not being re-introduced
 *   5. Dangerous settings not re-introduced in profiles
 *   6. No private hostnames in committed config
 *   7. Loop templates include required safety fields
 */

const { danger, warn, fail, message } = require("danger");

const pr = danger.github.pr;
const files = danger.git.modified_files.concat(danger.git.created_files);
const allFiles = files.concat(danger.git.deleted_files);

// ── 1. CHANGELOG check ────────────────────────────────────────────────────────
const isTrivial = pr.title.match(/^(docs|chore|style|ci):/i);
const hasChangelog = allFiles.some((f) => f.includes("CHANGELOG"));

if (!isTrivial && !hasChangelog) {
  warn(
    "No CHANGELOG.md entry for this PR. " +
    "Please add an entry under `## [Unreleased]` describing the change."
  );
}

// ── 2. PR title format (Conventional Commits) ────────────────────────────────
const CONVENTIONAL = /^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert|security)(\(.+\))?!?: .+/;
if (!CONVENTIONAL.test(pr.title)) {
  warn(
    `PR title \`${pr.title}\` does not follow Conventional Commits format. ` +
    "Use: `feat(scope): description` or `fix: description`"
  );
}

// ── 3. New skills must have SKILL.md ─────────────────────────────────────────
const newSkillDirs = danger.git.created_files.filter(
  (f) => f.match(/^skills\/[^/]+\/[^/]+\//) && !f.match(/\/SKILL\.md$/)
);

const newSkillMDs = danger.git.created_files.filter(
  (f) => f.match(/^skills\/[^/]+\/[^/]+\/SKILL\.md$/)
);

if (newSkillDirs.length > 0 && newSkillMDs.length === 0) {
  fail(
    "New files detected in a `skills/` directory but no `SKILL.md` found. " +
    "Every skill must have a `SKILL.md` as its primary file."
  );
}

// ── 4. skill.json must not be re-introduced ──────────────────────────────────
const newSkillJsons = danger.git.created_files.filter(
  (f) => f.match(/\/skill\.json$/)
);
if (newSkillJsons.length > 0) {
  fail(
    `\`skill.json\` files must not be added: ${newSkillJsons.join(", ")}. ` +
    "Agent-toolkit uses SKILL.md frontmatter only (Agent Skills spec). " +
    "See ADR-001 and the Skills Reference."
  );
}

// ── 5. Dangerous Claude Code settings ───────────────────────────────────────
const settingsFile = danger.git.created_files
  .concat(danger.git.modified_files)
  .find((f) => f.includes("profiles/claude-code/settings.json"));

if (settingsFile) {
  // Danger can access file content via danger.github.utils.fileContents
  danger.github.utils.fileContents(settingsFile).then((content) => {
    if (content.includes("skipDangerousModePermissionPrompt")) {
      fail(
        "`skipDangerousModePermissionPrompt` must not appear in `profiles/claude-code/settings.json`. " +
        "This bypasses user safety prompts and must never ship as a public default."
      );
    }
  });
}

// ── 6. Private hostnames in opencode.json ───────────────────────────────────
const openCodeFile = danger.git.created_files
  .concat(danger.git.modified_files)
  .find((f) => f.includes("profiles/opencode/opencode.json"));

if (openCodeFile) {
  danger.github.utils.fileContents(openCodeFile).then((content) => {
    const privateHostPatterns = [/\.local[:/]/, /192\.168\./, /10\.\d+\.\d+\./, /172\.(1[6-9]|2\d|3[01])\./];
    const hasPrivateHost = privateHostPatterns.some((p) => p.test(content));
    if (hasPrivateHost) {
      fail(
        "`profiles/opencode/opencode.json` contains a private hostname or IP address. " +
        "Public distributions must never contain machine-specific provider URLs. " +
        "Use `${ENV_VAR}` placeholders instead."
      );
    }
  });
}

// ── 7. Loop templates — required safety fields ───────────────────────────────
const newLoopFiles = danger.git.created_files.filter(
  (f) => f.match(/^loops\/[^/]+\/loop\.yaml$/)
);

for (const loopFile of newLoopFiles) {
  danger.github.utils.fileContents(loopFile).then((content) => {
    const missingFields = [];
    if (!content.includes("deny:")) missingFields.push("`deny`");
    if (!content.includes("budget:")) missingFields.push("`budget`");
    if (!content.includes("exit_conditions:")) missingFields.push("`exit_conditions`");

    if (missingFields.length > 0) {
      warn(
        `\`${loopFile}\` is missing required safety fields: ${missingFields.join(", ")}. ` +
        "All loop templates must declare deny list, budget, and exit conditions."
      );
    }
  });
}

// ── 8. Surface sync reminder ─────────────────────────────────────────────────
const skillOrAgentChanged = files.some(
  (f) => f.startsWith("skills/") || f.startsWith("agents/")
);
const pluginBundleChanged = files.some((f) => f.startsWith("plugins/"));

if (skillOrAgentChanged && !pluginBundleChanged) {
  message(
    "Skills or agents were modified but no plugin bundle was updated. " +
    "If these changes should be reflected in plugin bundles, run: " +
    "`python3 scripts/gen-surfaces.py` and commit the result."
  );
}

// ── 9. Compiler output reminder ──────────────────────────────────────────────
const distributionsChanged = files.some((f) => f.startsWith("distributions/"));
if (distributionsChanged) {
  message(
    "`distributions/` was modified. Verify the compiler still produces valid output: " +
    "`agent-toolkit build --check`"
  );
}

message(
  "Thank you for contributing to agent-toolkit! " +
  "See [CONTRIBUTING.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/CONTRIBUTING.md) " +
  "for the full contribution guide."
);
