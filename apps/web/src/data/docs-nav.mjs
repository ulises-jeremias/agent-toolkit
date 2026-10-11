export const publicDocs = [
  {
    slug: "getting-started",
    source: "GETTING_STARTED.md",
    title: "Getting started",
    description: "Install Agent Toolkit and make your first capability useful.",
    group: "Start here",
  },
  {
    slug: "desktop",
    source: "desktop/README.md",
    title: "Desktop",
    description:
      "Tour the semantic workspace, projects, People, Library and Operations.",
    group: "Use Agent Toolkit",
  },
  {
    slug: "world",
    source: "desktop/SEMANTIC_WORLD.md",
    title: "The semantic world",
    description:
      "Why projects, landmarks and runtime presence have spatial meaning.",
    group: "Understand the model",
  },
  {
    slug: "installation",
    source: "INSTALLATION.md",
    title: "Installation",
    description:
      "Desktop, native CLI, package managers and supported platforms.",
    group: "Start here",
  },
  {
    slug: "concepts",
    source: "CONCEPTS.md",
    title: "Concepts",
    description:
      "How projects, capabilities, People, sessions and orchestration fit together.",
    group: "Understand the model",
  },
  {
    slug: "people",
    source: "PEOPLE.md",
    title: "People",
    description:
      "Durable collaborators, reusable definitions and real runtime sessions.",
    group: "Use Agent Toolkit",
  },
  {
    slug: "skills",
    source: "SKILLS.md",
    title: "Skills",
    description: "Discover, install and author reusable agent capabilities.",
    group: "Capabilities",
  },
  {
    slug: "mcp",
    source: "MCP.md",
    title: "MCP",
    description:
      "Configure providers with explicit credentials and safety boundaries.",
    group: "Capabilities",
  },
  {
    slug: "loops",
    source: "LOOPS.md",
    title: "Loops",
    description: "Run and schedule recurring workflows with bounded autonomy.",
    group: "Use Agent Toolkit",
  },
  {
    slug: "swarms",
    source: "SWARMS.md",
    title: "Swarms",
    description:
      "Coordinate temporary roles, approvals and isolated worktrees.",
    group: "Use Agent Toolkit",
  },
  {
    slug: "swarm-roles",
    source: "SWARM_ROLES.md",
    title: "Swarm roles",
    description: "Temporary responsibilities and the canonical role taxonomy.",
    group: "Use Agent Toolkit",
  },
  {
    slug: "cli",
    source: "CLI_SURFACES.md",
    title: "CLI",
    description:
      "Use Toolkit commands for automation, scripting and headless work.",
    group: "Use Agent Toolkit",
  },
  {
    slug: "trust",
    source: "TRUST.md",
    title: "Trust and security",
    description:
      "Understand installation evidence, provenance and safe defaults.",
    group: "Trust and build",
  },
  {
    slug: "architecture",
    source: "ARCHITECTURE.md",
    title: "Architecture",
    description:
      "The shared V engine, API, CLI and Electron Desktop boundaries.",
    group: "Trust and build",
  },
];

export const publicDocBySource = new Map(
  publicDocs.map((document) => [document.source, document]),
);
