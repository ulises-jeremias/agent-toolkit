export const publicDocs = [
  {
    slug: "getting-started",
    source: "GETTING_STARTED.md",
    title: "Getting started",
    description:
      "Install the portable CLI, preview capability targets and validate provenance.",
    group: "Start here",
  },
  {
    slug: "installation",
    source: "INSTALLATION.md",
    title: "Installation",
    description:
      "Install the supported native CLI and learn about the Veasel graphical application.",
    group: "Start here",
  },
  {
    slug: "concepts",
    source: "CONCEPTS.md",
    title: "Concepts",
    description:
      "How portable skills, agents, context packs, workflows and tools fit together.",
    group: "Understand the model",
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
    description:
      "Compose reusable workflows and run bounded automation from supported CLI integrations.",
    group: "Use Agent Toolkit",
  },
  {
    slug: "swarms",
    source: "SWARMS.md",
    title: "Swarm v1 retirement",
    description:
      "Current Toolkit builds reject new Swarm v1 runs and preserve existing user data.",
    group: "Migration",
  },
  {
    slug: "swarm-v1-disposition",
    source: "SWARM_V1_DISPOSITION.md",
    title: "Swarm v1 migration boundary",
    description:
      "Preserve and inspect old Swarm v1 records; new runs belong in Veasel Code.",
    group: "Migration",
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
    slug: "upstream-sync",
    source: "UPSTREAM_SYNC.md",
    title: "Upstream sync",
    description:
      "How pinned upstream content is checked, proposed, reviewed and released without automatic trust promotion.",
    group: "Trust and build",
  },
  {
    slug: "architecture",
    source: "ARCHITECTURE.md",
    title: "Architecture",
    description:
      "The portable Toolkit CLI, capability distribution and integration boundaries.",
    group: "Trust and build",
  },
  {
    slug: "compatibility",
    source: "COMPATIBILITY.md",
    title: "Compatibility",
    description:
      "Review verified target support and limitations for coding tools and capability formats.",
    group: "Trust and build",
  },
];

export const publicDocBySource = new Map(
  publicDocs.map((document) => [document.source, document]),
);
