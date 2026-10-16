# Get started with Agent Toolkit Desktop

This guide takes you from a fresh install to a working project, a configured
Person and a real coding session. The graphical setup is the normal path: you
do not need to install the CLI, edit Toolkit configuration files or clone the
repository to use Desktop.

## 1. Install Desktop

Download the latest [Agent Toolkit Desktop release](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)
for your system. Choose the AppImage or `.deb` on Linux, the `.dmg` on macOS,
or the Windows installer. Desktop includes the matching Toolkit backend and
world assets.

For platform-specific notes and CLI/automation installation, see
[Installation](INSTALLATION.md). The CLI is an optional path for scripting,
CI, remote hosts and terminal-first use.

## 2. Create or open your workspace

Launch **Agent Toolkit Desktop**. On first run, choose **Create a workspace**
and select a location, or open an existing Agent Toolkit workspace. A workspace
is the shared valley: its projects, People, capabilities, memory and operations
are all managed from this context.

You can switch workspaces later from **Settings → Workspace**. The current
workspace is shown in the Desktop header so you can check context before
starting work.

## 3. Check your coding tools and sign in

Open **Library → Coding tools** to see which supported coding tools Desktop can
detect. Open **Settings → Tool profiles** to update Toolkit-managed files.
Install a coding tool from its publisher if it is not present, then return to
Desktop and refresh detection.

Toolkit can manage capability profiles for Claude Code, Cursor, OpenCode,
Windsurf, Pi and Muse Code. GitHub Copilot setup is project-scoped. The exact
targets available depend on your operating system and installed tools. Codex
and other runners may be available for starting sessions without being a
Toolkit profile-install target; the picker shows the current choices.

Sign in through each tool's own application or documented sign-in flow. Agent
Toolkit does not need your provider password or API key to detect a local
runner. Never paste credentials into a Skill, Agent Definition, Person note or
ordinary workspace file.

## 4. Review and install capabilities

Open **Library** to browse Skills, Agent Definitions and integrations.
Select a capability to inspect its source and requirements. Before a profile
installation, Desktop previews the target tools, paths, conflicts and changes.
Review that preview, then apply it from the Library. The receipt shows what was
actually written; a catalog entry alone does not mean a capability is
installed.

Start with only what you need. Installing a Skill profile does not sign a
provider in, configure an MCP secret or start an agent. MCP setup is a separate
review-and-probe flow in **Library → MCP**.

## 5. Open a project

From **World**, select a project house to enter the project. Use the
**Workspace** view to link an existing project directory or manage project
context. The project remains a real filesystem location; the world is its
spatial view, not a copy of its files.

Inside the project, use its Files, Knowledge, Memory and Terminal objects to
open those canonical resources. You can also reach the same destinations from
the main navigation and command palette (`Ctrl/Cmd+K`). Walking around is
optional.

## 6. Create a reusable Person and start a session

Open **People → Create Person**. Give the collaborator a name and role, then
choose an Agent Definition, preferred runner/model, Skills, MCP references,
appearance and limits as appropriate. These settings describe a durable Person;
they do not start a process. Skills and MCP references are selected from the
available catalogs where possible. An offline Person does not appear as a
worker in the World.

Choose **Start**, select a project and available runner/model, review the
session details and start. Desktop creates a real local session. You can open
its real terminal, inspect runtime status and stop it from the Person panel. A
runner that is unavailable is reported as unavailable; Toolkit will not invent
a session. The Person remains in the roster when the session ends.

You can also open **Terminal → New session** for a direct shell session that
is not tied to a Person.

## 7. Observe work and use Swarms or Loops

**Operations** is the shared place for jobs, loops, swarms, approvals and
failures. Use it to inspect real runtime state and recover from errors.

- **Swarms:** choose a recipe and task, review roles, runner/model choices,
  People preferences, permissions, gates and budgets, then start. People are
  optional; Toolkit can use an ephemeral role session when no compatible
  Person is selected. Herdr or tmux may be needed for multi-session layouts.
- **Loops:** open a loop to inspect its definition and last report, run it once,
  or review the scheduler plan before enabling a schedule.
- **Approvals:** inspect the proposed action and its scope before approving or
  rejecting it.

The world shows where confirmed work is happening. **Operations** shows the
details of what each run is doing.

## 8. Verify setup and recover

Open **Settings → Self-check** when the backend or a capability is unavailable.
The report identifies the failed check and a next step. Check tool availability
in **Library → Coding tools**. For an individual integration, open its Library
page to validate or probe it. Do not reinstall over existing files just to clear
a warning; inspect the preview and conflict behavior first.

If you need help, see [Troubleshooting](TROUBLESHOOTING.md), [Trust and
security](TRUST.md), and the focused guides linked from the public
[documentation index](/docs/).

## Optional: CLI and automation

For scripting or headless operation, install the CLI using one of the methods
in [Installation](INSTALLATION.md), then use:

```bash
agent-toolkit doctor
agent-toolkit inventory
agent-toolkit --help
```

The CLI and Desktop use the same canonical Toolkit operations. Prefer `--help`
for the installed version instead of copying commands from an older guide.
