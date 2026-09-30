/**
 * Generated from docs/surface/openapi.json — do not hand-edit.
 * Regenerate with: pnpm gen:api
 */
export interface paths {
  '/api/v1/help': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Print consumer-first help text */
    get: operations['help'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/version': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Print agent-toolkit version string */
    get: operations['version'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/install': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Install profiles for detected or selected AI tools */
    post: operations['install'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/update': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Refresh installed profiles from latest toolkit data */
    post: operations['update'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/uninstall': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Remove toolkit-owned files using install receipts */
    post: operations['uninstall'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/doctor': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Check toolkit data and tool availability */
    get: operations['doctor'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/diff': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Show changes vs installed plugin bundles */
    get: operations['diff'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/skills/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Sync, list, and validate skills */
    post: operations['skills'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/mcp/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** MCP provider setup, health, doctor, uninstall */
    post: operations['mcp'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/plugin/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Plugin bundle sync and check */
    post: operations['plugin'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/loops/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Loop engineering (init, run, status, audit, cost, schedule, sync, list, templates) */
    post: operations['loop'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/workspace/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Workspace lifecycle (init, context, sync, use-persona, handoff, history, personas, load, profiles, validate, budget) */
    post: operations['workspace'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/memory/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Knowledge base (add, search, inject, review, todo) */
    post: operations['memory'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/project/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Project index and scaffolding (init, clone, list, add, remove, scan) */
    post: operations['project'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/dc/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Background job queue + LLM policy status */
    post: operations['devcompanion'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/build': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Compile canonical capabilities into target artifacts */
    post: operations['build'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/inventory': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** List skills, agents, and products */
    get: operations['inventory'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/matrix': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Platform capability matrix */
    get: operations['matrix'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/swarms/{sub}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Multi-agent swarm orchestration */
    post: operations['swarm'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/insights': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** AI tool usage insights — opencode, cursor, claude, windsurf, copilot, codex, all */
    get: operations['insights'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/health': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (health) */
    get: operations['health'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/openapi.json': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (get_openapi) */
    get: operations['get_openapi'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/selfcheck': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (selfcheck) */
    get: operations['selfcheck'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/jobs': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Server-native endpoint (create_job) */
    post: operations['create_job'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/jobs/{id}/log': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (get_job_log) */
    get: operations['get_job_log'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/jobs/{id}/events': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (stream_job_events) */
    get: operations['stream_job_events'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/jobs/{id}/cancel': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Server-native endpoint (cancel_job) */
    post: operations['cancel_job'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/jobs/{id}': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    post?: never;
    /** Server-native endpoint (delete_job) */
    delete: operations['delete_job'];
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/doctor/fix': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Server-native endpoint (doctor_fix) */
    post: operations['doctor_fix'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/loops/{name}/status': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (loop_status_by_name) */
    get: operations['loop_status_by_name'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/loops/{name}/run': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Server-native endpoint (run_loop_by_name) */
    post: operations['run_loop_by_name'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/loops/{name}/schedule': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    get?: never;
    put?: never;
    /** Server-native endpoint (schedule_loop_by_name) */
    post: operations['schedule_loop_by_name'];
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/swarms': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (list_swarms) */
    get: operations['list_swarms'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
  '/api/v1/loops': {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    /** Server-native endpoint (list_loops) */
    get: operations['list_loops'];
    put?: never;
    post?: never;
    delete?: never;
    options?: never;
    head?: never;
    patch?: never;
    trace?: never;
  };
}
export type webhooks = Record<string, never>;
export interface components {
  schemas: never;
  responses: never;
  parameters: never;
  requestBodies: never;
  headers: never;
  pathItems: never;
}
export type $defs = Record<string, never>;
export interface operations {
  help: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  version: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  install: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  update: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  uninstall: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  doctor: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  diff: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  skills: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub: 'list' | 'sync' | 'validate' | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          domain?: string;
          tools?: string[];
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  mcp: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub: 'list' | 'setup' | 'health' | 'doctor' | 'uninstall' | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          provider?: string;
          offline?: boolean;
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  plugin: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub: 'sync' | 'check' | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': Record<string, never>;
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  loop: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub: 'init' | 'status' | 'audit' | 'cost' | 'schedule' | 'sync' | 'list' | 'ls' | 'templates' | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          workspace?: string;
          name?: string;
          custom_name?: string;
          force?: boolean;
          runner?: string;
          model?: string;
          pack?: string;
          no_llm?: boolean;
          dry_run?: boolean;
          cron?: string;
          /** @enum {string} */
          platform?: 'local' | 'github-actions';
          list_mode?: boolean;
          remove_mode?: boolean;
          status_mode?: boolean;
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  workspace: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub:
          | 'init'
          | 'context'
          | 'sync'
          | 'use-persona'
          | 'handoff'
          | 'history'
          | 'personas'
          | 'load'
          | 'profiles'
          | 'validate'
          | 'budget'
          | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          workspace?: string;
          dir?: string;
          name?: string;
          explain?: boolean;
          arg?: string;
          profile?: string;
          pack?: string;
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  memory: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub: 'add' | 'search' | 'inject' | 'review' | 'todo' | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          workspace?: string;
          /** @enum {string} */
          entry_type?: 'learning' | 'process' | 'todo';
          title?: string;
          content?: string;
          query?: string;
          stale_after?: number;
          fix?: boolean;
          show_done?: boolean;
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  project: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub: 'init' | 'clone' | 'list' | 'add' | 'remove' | 'scan' | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          workspace?: string;
          arg?: string;
          ssh?: boolean;
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  devcompanion: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub: 'queue' | 'run-once' | 'status' | 'done' | 'sync-todos' | 'llm-status' | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          workspace?: string;
          arg?: string;
          template?: string;
          request?: string;
          job_id?: string;
          no_llm?: boolean;
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  build: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  inventory: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  matrix: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  swarm: {
    parameters: {
      query?: never;
      header?: never;
      path: {
        sub:
          | 'recipes'
          | 'recipe'
          | 'backends'
          | 'doctor'
          | 'runners'
          | 'models'
          | 'start'
          | 'init'
          | 'plan'
          | 'activate'
          | 'deactivate'
          | 'promote'
          | 'list'
          | 'status'
          | 'approve'
          | 'reject'
          | 'cancel'
          | 'pause'
          | 'resume'
          | 'stop'
          | 'cleanup'
          | 'graph'
          | 'handoff'
          | 'task'
          | 'watch'
          | 'report'
          | 'artifacts'
          | 'handoffs'
          | 'logs'
          | 'approvals'
          | 'prune'
          | 'help';
      };
      cookie?: never;
    };
    requestBody?: {
      content: {
        'application/json': {
          workspace?: string;
          run_id?: string;
          gate_id?: string;
          recipe?: string;
          backend?: string;
          runner?: string;
          model_profile?: string;
          task?: string;
          reason?: string;
          dry_run?: boolean;
          force?: boolean;
          current?: boolean;
          issue_ref?: string;
          base_ref?: string;
          handoff_sub?: string;
          htype?: string;
          from_role?: string;
          to_role?: string;
          priority?: number;
          artifact?: string;
          commit?: string;
          branch?: string;
          blocking?: boolean;
          role?: string;
          handoff_id?: string;
          to_recipe?: string;
          older_than?: string;
        };
      };
    };
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description invalid request body or field */
      400: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied or path outside allowed roots */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description unknown subcommand or path not found */
      404: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  insights: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description ok */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description scope denied */
      403: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
      /** @description confirm required */
      428: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  health: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  get_openapi: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  selfcheck: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  create_job: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  get_job_log: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  stream_job_events: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  cancel_job: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  delete_job: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  doctor_fix: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  loop_status_by_name: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  run_loop_by_name: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  schedule_loop_by_name: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  list_swarms: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
  list_loops: {
    parameters: {
      query?: never;
      header?: never;
      path?: never;
      cookie?: never;
    };
    requestBody?: never;
    responses: {
      /** @description OK */
      200: {
        headers: {
          [name: string]: unknown;
        };
        content?: never;
      };
    };
  };
}
