# Agent Toolkit Complete

Full stable skill catalog coverage for consumers who want everything (#50)

## Available Skills

- **assistant**: Assistant — on any repo, scan README→docs→AGENTS→CONTRIBUTING→PR templates→task 
- **dev-companion**: WHAT — Dev Companion (general): layered companion for client delivery; modes, ga
- **onboarding**: Getting started guide for new users. Walks through setup validation, the skill/a
- **output-handshake**: WHAT — Default gate for any deliverable: confirm where the final artifact will b
- **pr-fallback**: WHAT — When the repo has no GitHub PR template, structure the pull-request body 
- **workspace-knowledge-sync**: Syncs knowledge to the ai-workspace knowledge base. Use when the assistant disco
- **dbt-validation**: HOW — Run dbt checks as documented in the target repo (parse, compile, test, sel
- **snowflake-validation**: HOW — Read-only Snowflake validation patterns: use repo-documented CLI (snowflak
- **adr**: WHAT — Create and maintain Architecture Decision Records (ADRs) per the process.
- **agreement**: WHAT - Capture explicit agreements, terms, parties involved, dates, validity, an
- **bug**: WHAT - Draft and review bugs using the Bug Template; classifies whether an issue
- **decision-log**: WHAT - Capture lightweight project, product, or operational decisions that do no
- **development-workflow**: WHAT - Default development workflow, task lifecycle, DoR, DoD, validation, and e
- **epic**: WHAT - Draft and review epics using the Best Practices Epic Template; includes o
- **incident**: WHAT - Draft and review incident reports and RCA notes using Incident Management
- **management-unit-assessment**: WHAT - Evidence-based management unit assessment for governance, delivery, colla
- **meeting-minutes**: WHAT - Create structured meeting minutes from notes or transcripts using meeting
- **planning**: WHAT - Planning, estimation, task breakdown, and iteration capacity fallback bas
- **prd**: WHAT — Draft and review a Product Requirements Document (PRD) using the template
- **project-assessment**: WHAT - Interactive project assessment router: define assessment scope and units,
- **project-assessment-evidence**: WHAT - Interactive evidence intake for project assessments. Ask the user where e
- **spike**: WHAT - Produce spike and research findings using the spike template; captures pu
- **task**: WHAT - Draft and review technical tasks using the Best Practices Task Template; 
- **technical-unit-assessment**: WHAT - Evidence-based technical unit assessment for repositories, platforms, fro
- **trd**: WHAT — Draft and review a Technical Requirements Document (TRD) using the templa
- **user-story**: WHAT - Draft and review user stories using the task template plus the As a/I wan
- **work-item**: WHAT - Router for creating and refining epics, user stories, tasks, bugs, and in
- **workflow-client-bootstrap**: WHAT — Interactive interview to capture client delivery context and store it ins
- **workflow-generic-project**: WHAT — Generic client delivery: Jira or ClickUp, full repo context, human gates,
- **figma**: Use the Figma MCP server to fetch design context, screenshots, variables, and as
- **figma-code-connect-components**: Connects Figma design components to code components using Code Connect mapping t
- **figma-create-design-system-rules**: Generates custom design system rules for the user's codebase. Use when user says
- **figma-create-new-file**: Create a new blank Figma file. Use when the user wants to create a new Figma des
- **figma-implement-design**: Translates Figma designs into production-ready application code with 1:1 visual 
- **ui-ux-pro-max**: UI/UX design intelligence. 67 styles, 96 palettes, 57 font pairings, 25 charts, 
- **gh-address-comments**: Triage and address open GitHub PR review and conversation comments using the gh 
- **gh-contribution-planner**: Daily GitHub contribution planner — analyzes the gh-logged-in user's non-archive
- **gh-fix-ci**: Diagnose failing GitHub Actions checks on a PR via gh, summarize the failure con
- **github-cli-workflow**: HOW — GitHub CLI (gh): push branch, create draft PR with title/body from templat
- **gitlab-cli-workflow**: HOW — GitLab CLI (glab): push branch, create draft MR with title/body; fallback 
- **workflow-client-bootstrap**: DEPRECATED alias. Use workflow-client-bootstrap instead.
- **workflow-generic-project**: DEPRECATED alias. Use workflow-generic-project instead.
- **clickup-cli**: ClickUp CLI for managing tasks, sprints, comments, statuses, and Docs. Use when 
- **linear**: Manage Linear issues, projects and cycles via the Linear MCP server. Use when th
- **slack-assistant**: Interact with Slack workspaces for reading channels/messages, sending messages, 
- **slack-cli**: Interact with the official Slack CLI to create, run, deploy, and manage Slack ap
- **loop-runner**: Execute and manage loop engineering primitives (init, run, status, audit) from a
- **docs-generator**: WHAT — Generate or update documentation from code: README.md from repo structure
- **llm-cost-advisor**: WHAT — Recommend the most cost-effective LLM provider for a given task type. Sho
- **triage**: Workstation health triage — validate tooling, directory layout, and run doctor w
- **jupyter-notebook**: Create, scaffold, or refactor Jupyter notebooks (.ipynb) for experiments and tut
- **playwright-cli**: Drive a real browser from the terminal using the Playwright CLI (snapshot, click

## Scope

These instructions are project-scoped. Rules in `rules/` provide always-on behavioral constraints. Skills in `skills/` are on-demand procedures invoked explicitly.
