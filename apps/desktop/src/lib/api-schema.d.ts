/**
 * Generated from docs/surface/openapi.json — do not hand-edit.
 * Regenerate with: pnpm gen:api
 */
export interface paths {
    "/api/v1/help": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Print consumer-first help text */
        get: operations["help"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/version": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Print agent-toolkit version string */
        get: operations["version"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/install": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Install profiles for detected or selected AI tools */
        post: operations["install"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/update": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Refresh installed profiles from latest toolkit data */
        post: operations["update"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/uninstall": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Remove toolkit-owned files using install receipts */
        post: operations["uninstall"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/doctor": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Check toolkit data and tool availability */
        get: operations["doctor"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/diff": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Show changes vs installed plugin bundles */
        get: operations["diff"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/skills/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Sync, list, and validate skills */
        post: operations["skills"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/mcp/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** MCP provider setup, health, doctor, uninstall */
        post: operations["mcp"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/plugin/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Plugin bundle sync and check */
        post: operations["plugin"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Loop engineering (init, run, status, audit, cost, schedule, sync, list, templates) */
        post: operations["loop"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/workspace/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Workspace lifecycle (init, context, sync, use-persona, handoff, history, personas, load, profiles, validate, budget) */
        post: operations["workspace"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/memory/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Knowledge base (add, search, inject, review, todo) */
        post: operations["memory"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/project/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Project index and scaffolding (init, clone, list, add, remove, scan) */
        post: operations["project"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/dc/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Background job queue + LLM policy status */
        post: operations["devcompanion"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/build": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Compile canonical capabilities into target artifacts */
        post: operations["build"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/inventory": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List skills, agents, and products */
        get: operations["inventory"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/matrix": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Platform capability matrix */
        get: operations["matrix"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/{sub}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Multi-agent swarm orchestration */
        post: operations["swarm"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/insights": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** AI tool usage insights — opencode, cursor, claude, windsurf, copilot, codex, all */
        get: operations["insights"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/mcp/providers": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List MCP providers and secret-free local configuration state */
        get: operations["mcp_providers"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/install/preview": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Preview profile installation targets and conflicts without writing files */
        get: operations["install_preview"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/install/reviewed": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Install Toolkit capabilities only for explicitly reviewed targets */
        post: operations["install_reviewed"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/install/copilot-project/preview": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Review install or receipt-backed removal of Copilot instructions for a linked project */
        get: operations["copilot_project_install_preview"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/install/copilot-project/reviewed": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Apply reviewed Copilot instruction install or receipt-backed removal for a linked project */
        post: operations["copilot_project_install_reviewed"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/install/receipts": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List secret-free receipts proving Toolkit capability installations */
        get: operations["install_receipts"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/uninstall/preview": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Preview Toolkit-owned file removal and preserve modified files without writing */
        get: operations["uninstall_preview"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/uninstall/reviewed": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Remove files only if the receipt-backed plan still matches its reviewed token */
        post: operations["uninstall_reviewed"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/recipes": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List canonical swarm recipes and available session adapters */
        get: operations["list_swarm_recipes"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/health": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (health) */
        get: operations["health"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/openapi.json": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (get_openapi) */
        get: operations["get_openapi"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/selfcheck": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (selfcheck) */
        get: operations["selfcheck"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/jobs": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List jobs keyed by id */
        get: operations["list_jobs"];
        put?: never;
        /** Server-native endpoint (create_job) */
        post: operations["create_job"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/people": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List validated durable People in a workspace */
        get: operations["list_people"];
        put?: never;
        /** Create a reviewed durable Person */
        post: operations["create_person"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/sessions": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List durable Person session lifecycle records */
        get: operations["list_person_sessions"];
        put?: never;
        /** Validate a Person launch and create a session record */
        post: operations["create_person_session"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/sessions/{id}/status": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Record a PTY lifecycle transition reported by Desktop */
        post: operations["update_person_session_status"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/people/bindings": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List validated workspace default People for swarm roles */
        get: operations["list_people_bindings"];
        /** Save reviewed default People for selected recipe roles */
        put: operations["update_people_bindings"];
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/people/{id}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (get_person) */
        get: operations["get_person"];
        /** Server-native endpoint (update_person) */
        put: operations["update_person"];
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/people/{id}/archive": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (archive_person) */
        post: operations["archive_person"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/jobs/{id}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Get one job */
        get: operations["get_job"];
        put?: never;
        post?: never;
        /** Server-native endpoint (delete_job) */
        delete: operations["delete_job"];
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/jobs/{id}/log": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (get_job_log) */
        get: operations["get_job_log"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/jobs/{id}/events": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (stream_job_events) */
        get: operations["stream_job_events"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/jobs/{id}/cancel": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (cancel_job) */
        post: operations["cancel_job"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/jobs/{id}/retry": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Re-run a failed or canceled job as a new job */
        post: operations["retry_job"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/events": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Global server event stream (SSE) */
        get: operations["stream_events"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/agents": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Persona catalog from agents/*\/AGENT.md */
        get: operations["list_agents"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/tools": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Coding-agent CLI discovery (detected/configured/enabled/verified) */
        get: operations["list_tools"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/providers": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Swarm runner CLIs */
        get: operations["list_providers"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/models": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Swarm model profile slots */
        get: operations["list_models"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/memory": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Memory files (learnings, processes, todos). Empty when no workspace. */
        get: operations["list_memory"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/memory/hits": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Case-insensitive memory search */
        get: operations["search_memory"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/memory/file": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Read one memory markdown file */
        get: operations["read_memory"];
        /** Replace a memory markdown file */
        put: operations["edit_memory"];
        /** Add a learning, process, or todo entry */
        post: operations["add_memory"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/memory/file/archive": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Move a memory file under knowledge/archive/ */
        post: operations["archive_memory"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/doctor/fix": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (doctor_fix) */
        post: operations["doctor_fix"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops/{name}/status": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (loop_status_by_name) */
        get: operations["loop_status_by_name"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops/{name}/audit": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (loop_audit_by_name) */
        get: operations["loop_audit_by_name"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops/{name}/history": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (loop_history_by_name) */
        get: operations["loop_history_by_name"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops/{name}/cost": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (loop_cost_by_name) */
        get: operations["loop_cost_by_name"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops/{name}/run": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (run_loop_by_name) */
        post: operations["run_loop_by_name"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops/{name}/schedule": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (schedule_loop_by_name) */
        post: operations["schedule_loop_by_name"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (list_swarms) */
        get: operations["list_swarms"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (get_swarm_run) */
        get: operations["get_swarm_run"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}/handoffs": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (list_swarm_handoffs) */
        get: operations["list_swarm_handoffs"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}/tasks": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (list_swarm_tasks) */
        get: operations["list_swarm_tasks"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}/approvals": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (list_swarm_approvals) */
        get: operations["list_swarm_approvals"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}/artifacts": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (list_swarm_artifacts) */
        get: operations["list_swarm_artifacts"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}/approve": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (approve_swarm_run) */
        post: operations["approve_swarm_run"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}/reject": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (reject_swarm_run) */
        post: operations["reject_swarm_run"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/swarms/runs/{id}/stop": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        get?: never;
        put?: never;
        /** Server-native endpoint (stop_swarm_run) */
        post: operations["stop_swarm_run"];
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/loops": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Server-native endpoint (list_loops) */
        get: operations["list_loops"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/files": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** List workspace files or a registered project's files */
        get: operations["list_files"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/files/hits": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Search workspace files or a registered project's files */
        get: operations["search_files"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
    "/api/v1/files/content": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Read one workspace or registered project file */
        get: operations["read_file"];
        /** Server-native endpoint (write_file) */
        put: operations["write_file"];
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
    schemas: {
        /** @description Error body for every non-2xx JSON response. */
        ApiError: {
            ok: boolean;
            error: string;
        };
        /** @description Generic success acknowledgement. */
        MessageResponse: {
            ok: boolean;
            message: string;
        };
        /** @description Read-only preview of installation or removal targets and conflicts. */
        InstallPreviewResponse: {
            ok: boolean;
            message: string;
            data: {
                [key: string]: string;
            };
        };
        InstallReviewedRequest: {
            tools: string[];
        };
        CopilotProjectInstallRequest: {
            workspace: string;
            project: string;
            /** @enum {string} */
            action: "install" | "remove";
            review_token: string;
        };
        CopilotProjectInstallResponse: {
            ok: boolean;
            message: string;
            project: string;
            path: string;
            content: string;
            status: string;
            review_token: string;
            files_written: number;
            files_removed: number;
        };
        InstallReceiptSummary: {
            product: string;
            target: string;
            scope: string;
            version: string;
            installed_at: string;
            artifact_count: number;
            created_count: number;
            merged_count: number;
            receipt_path: string;
        };
        InstallReceiptsResponse: {
            ok: boolean;
            receipts: components["schemas"]["InstallReceiptSummary"][];
        };
        /** @description Secret-free MCP provider catalogue and local setup state. */
        McpProviderInfo: {
            id: string;
            display_name: string;
            package: string;
            required_env: string[];
            missing_env: string[];
            configured: boolean;
            enabled: boolean;
            template_available: boolean;
            template_sha: string;
            template_is_pinned: boolean;
            template_matches_pin: boolean;
        };
        McpProvidersResponse: {
            ok: boolean;
            message: string;
            config_path: string;
            providers: components["schemas"]["McpProviderInfo"][];
        };
        VersionResponse: {
            ok: boolean;
            version: string;
            commit: string;
            uptime_s: number;
        };
        SelfcheckCheck: {
            name: string;
            /** @enum {string} */
            status: "ok" | "warn" | "err";
            detail: string;
        };
        SelfcheckResponse: {
            ok: boolean;
            version: string;
            commit: string;
            checks: components["schemas"]["SelfcheckCheck"][];
        };
        /** @description A supervised `agent-toolkit` subprocess run. */
        Job: {
            id: string;
            cmd: string;
            args: string[];
            /** @enum {string} */
            status: "queued" | "running" | "completed" | "failed" | "canceled" | "rejected";
            started_at: string;
            ended_at: string;
            exit_code: number;
            workspace: string;
            retry_of: string;
        };
        /** @description One entry of the global event stream (GET /api/v1/events). `seq` is monotonic per server process, `boot` identifies that process, and the SSE `id` is `<boot>-<seq>`. `subject` is the job id, loop name, swarm run id or memory entry type the event is about; `exit_code` is only meaningful for job.* and loop.* events. */
        ApiEvent: {
            seq: number;
            boot: string;
            /** @enum {string} */
            type: "backend.ready" | "backend.resync" | "job.created" | "job.updated" | "job.deleted" | "loop.started" | "loop.finished" | "swarm.changed" | "memory.changed" | "install.started" | "install.finished";
            at: string;
            subject: string;
            status: string;
            exit_code: number;
            ref: string;
            message: string;
        };
        /** @description One persona from agents/<id>/AGENT.md. */
        AgentInfo: {
            id: string;
            name: string;
            kind: string;
            description: string;
            source_file: string;
        };
        AgentsResponse: {
            ok: boolean;
            agents: components["schemas"]["AgentInfo"][];
        };
        /** @description Coding-agent CLI discovery. detected = binary on PATH; configured = a known settings sentinel exists; enabled is `unknown` until serve owns an enablement store; verified = `--version` exited 0. install_hint is empty unless a real first-party install argv exists. */
        ToolInfo: {
            id: string;
            tool_name: string;
            detected: boolean;
            configured: boolean;
            /** @enum {string} */
            enabled: "unknown" | "true" | "false";
            verified: boolean;
            resolved_path: string;
            config_paths: string[];
            version: string;
            reason: string;
            install_hint: string;
        };
        ToolsResponse: {
            ok: boolean;
            tools: components["schemas"]["ToolInfo"][];
        };
        /** @description A swarm runner CLI. `auto` is a resolver and is omitted. */
        ProviderInfo: {
            id: string;
            bin: string;
            available: boolean;
            capability: string;
            version: string;
        };
        ProvidersResponse: {
            ok: boolean;
            providers: components["schemas"]["ProviderInfo"][];
        };
        /** @description One (profile, runner) slot from swarm_model_profiles. */
        ModelInfo: {
            profile: string;
            runner: string;
            model: string;
        };
        ModelsResponse: {
            ok: boolean;
            models: components["schemas"]["ModelInfo"][];
        };
        PersonRoleBinding: {
            role: string;
            person_id: string;
            preferred_people: string[];
        };
        PersonBindingsResponse: {
            ok: boolean;
            roles: components["schemas"]["PersonRoleBinding"][];
        };
        PersonBindingsRequest: {
            workspace: string;
            recipe: string;
            roles: {
                [key: string]: string;
            };
        };
        /** @description Durable lifecycle evidence for a real local PTY bound to a Person. */
        PersonSession: {
            id: string;
            person_id: string;
            person: string;
            role: string;
            project_id: string;
            cwd: string;
            provider: string;
            model: string;
            /** @enum {string} */
            status: "launching" | "running" | "completed" | "failed" | "stopped" | "timed_out" | "interrupted";
            started_at: string;
            ended_at: string;
            exit_code: number;
        };
        PersonSessionsResponse: {
            ok: boolean;
            sessions: components["schemas"]["PersonSession"][];
        };
        PersonSessionResponse: {
            ok: boolean;
            session: components["schemas"]["PersonSession"];
        };
        PersonSessionCreateRequest: {
            workspace: string;
            person_id: string;
            project_id: string;
            provider: string;
            model: string;
        };
        PersonSessionStatusRequest: {
            workspace: string;
            /** @enum {string} */
            status: "running" | "completed" | "failed" | "stopped" | "timed_out" | "interrupted";
            exit_code: number;
        };
        /** @description Honest origin for a knowledge file. author is the last git committer on read when `.git` exists; agent is empty unless a real source records it. timestamp is the first YYYY-MM-DD in the file, else mtime. */
        MemoryProvenance: {
            file: string;
            author: string;
            timestamp: string;
            project: string;
            agent: string;
        };
        /** @description One memory file (learnings, processes, or todos). body is set on read and empty on list. Other knowledge/*.md files are not memory. */
        MemoryEntry: {
            id: string;
            kind: string;
            title: string;
            snippet: string;
            body: string;
            tags: string[];
            provenance: components["schemas"]["MemoryProvenance"];
        };
        /** @description One line match from GET /api/v1/memory/hits. */
        MemoryHit: {
            path: string;
            line: number;
            snippet: string;
            kind: string;
        };
        MemoryListResponse: {
            ok: boolean;
            entries: components["schemas"]["MemoryEntry"][];
        };
        MemorySearchResponse: {
            ok: boolean;
            query: string;
            hits: components["schemas"]["MemoryHit"][];
        };
        MemoryReadResponse: {
            ok: boolean;
            entry: components["schemas"]["MemoryEntry"];
        };
        MemoryWriteResponse: {
            ok: boolean;
            message: string;
            path: string;
        };
        SwarmRunInfo: {
            run_id: string;
            recipe: string;
            backend: string;
            run_state: string;
            created_at: string;
            task: string;
            person_bindings?: {
                [key: string]: string;
            };
        };
        SwarmListResponse: {
            ok: boolean;
            runs: components["schemas"]["SwarmRunInfo"][];
        };
        SwarmBudgetView: {
            max_total_tokens: number;
            total_tokens: number;
            max_cost_usd: number;
            total_cost: number;
            max_wall_seconds: number;
            /** @enum {string} */
            cost_status: "accounted" | "unavailable";
        };
        SwarmGate: {
            id: string;
            description: string;
            required: boolean;
            approved: boolean;
            rejected: boolean;
            reason: string;
        };
        SwarmHandoffView: {
            id: string;
            htype: string;
            from_role: string;
            to_role: string;
            priority: number;
            artifact: string;
            commit: string;
            branch: string;
            blocking: boolean;
            state: string;
            created_at: string;
        };
        SwarmTaskView: {
            id: string;
            status: string;
            priority: number;
            owner: string;
            from_role: string;
            dependencies: string;
            blocked_reason: string;
            created_at: string;
        };
        SwarmArtifactView: {
            name: string;
            path: string;
            size: number;
        };
        SwarmRunResponse: {
            ok: boolean;
            run: components["schemas"]["SwarmRunInfo"];
            runner: string;
            model: string;
            budget: components["schemas"]["SwarmBudgetView"];
            approvals: components["schemas"]["SwarmGate"][];
            handoffs: components["schemas"]["SwarmHandoffView"][];
            tasks: components["schemas"]["SwarmTaskView"][];
            artifacts: components["schemas"]["SwarmArtifactView"][];
            trace_tail: string[];
        };
        SwarmRecipeRoleView: {
            name: string;
            persona: string;
            policy: string;
            model_profile: string;
            receive_mode: string;
            consumes: string[];
            produces: string[];
            skills: string[];
        };
        SwarmRecipeBudgetView: {
            max_total_tokens: number;
            max_cost_usd: number;
            max_wall_seconds: number;
            max_concurrency: number;
        };
        SwarmRecipeView: {
            name: string;
            description: string;
            roles: components["schemas"]["SwarmRecipeRoleView"][];
            budget: components["schemas"]["SwarmRecipeBudgetView"];
            workspace_strategy: string;
            keep_on_failure: boolean;
            max_concurrency: number;
            max_wall_seconds: number;
            require_plan_approval: boolean;
            require_final_approval: boolean;
            allow_direct_base_merge: boolean;
            allow_push: boolean;
        };
        SwarmBackendView: {
            name: string;
            available: boolean;
            detail: string;
        };
        SwarmRecipesResponse: {
            ok: boolean;
            recipes: components["schemas"]["SwarmRecipeView"][];
            backends: components["schemas"]["SwarmBackendView"][];
        };
        SwarmHandoffsResponse: {
            ok: boolean;
            run_id: string;
            handoffs: components["schemas"]["SwarmHandoffView"][];
        };
        SwarmTasksResponse: {
            ok: boolean;
            run_id: string;
            tasks: components["schemas"]["SwarmTaskView"][];
        };
        SwarmApprovalsResponse: {
            ok: boolean;
            run_id: string;
            approvals: components["schemas"]["SwarmGate"][];
        };
        SwarmArtifactsResponse: {
            ok: boolean;
            run_id: string;
            artifacts: components["schemas"]["SwarmArtifactView"][];
        };
        SwarmActionResponse: {
            ok: boolean;
            message: string;
            run_id: string;
            status: string;
        };
        LoopInfo: {
            name: string;
            tier: string;
            cadence: string;
            goal: string;
            runs: number;
            last: string;
            status: string;
        };
        LoopListResponse: {
            ok: boolean;
            loops: components["schemas"]["LoopInfo"][];
        };
        LoopBudgetView: {
            max_tokens: number;
            max_runs_per_day: number;
            max_wall_seconds: number;
            /** @enum {string} */
            cost_status: "unavailable" | "accounted";
        };
        LoopStatusResponse: {
            ok: boolean;
            info: components["schemas"]["LoopInfo"];
            budget: components["schemas"]["LoopBudgetView"];
        };
        LoopAuditResponse: {
            ok: boolean;
            name: string;
            completed: number;
            failed: number;
            tokens: number;
            rate: string;
        };
        LoopHistoryEntry: {
            id: string;
            status: string;
        };
        LoopHistoryResponse: {
            ok: boolean;
            name: string;
            last_id: string;
            last: string;
            status: string;
            runs: components["schemas"]["LoopHistoryEntry"][];
        };
        LoopCostResponse: {
            ok: boolean;
            name: string;
            /** @enum {string} */
            cost_status: "unavailable" | "accounted";
            detail: string;
        };
        WorkspaceFileNode: {
            name: string;
            path: string;
            /** @enum {string} */
            kind: "file" | "dir";
            size: number;
            depth: number;
            masked: boolean;
        };
        WorkspaceFileListResponse: {
            ok: boolean;
            root: string;
            nodes: components["schemas"]["WorkspaceFileNode"][];
        };
        WorkspaceFileReadResponse: {
            ok: boolean;
            path: string;
            name: string;
            content: string;
            size: number;
            binary: boolean;
            truncated: boolean;
            masked: boolean;
        };
        WorkspaceFileHit: {
            path: string;
            line: number;
            snippet: string;
        };
        WorkspaceFileSearchResponse: {
            ok: boolean;
            query: string;
            hits: components["schemas"]["WorkspaceFileHit"][];
        };
        WorkspaceFileWriteResponse: {
            ok: boolean;
            message: string;
            path: string;
        };
    };
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
                sub: "list" | "sync" | "validate" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
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
                sub: "list" | "setup" | "health" | "doctor" | "uninstall" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
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
                sub: "sync" | "check" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": Record<string, never>;
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
                sub: "init" | "status" | "audit" | "cost" | "schedule" | "sync" | "list" | "ls" | "templates" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
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
                    platform?: "local" | "github-actions";
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
                sub: "init" | "context" | "sync" | "use-persona" | "handoff" | "history" | "personas" | "load" | "profiles" | "validate" | "budget" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
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
                sub: "add" | "search" | "inject" | "review" | "todo" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
                    workspace?: string;
                    /** @enum {string} */
                    entry_type?: "learning" | "process" | "todo";
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
                sub: "init" | "clone" | "list" | "add" | "remove" | "scan" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
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
                sub: "queue" | "run-once" | "status" | "done" | "sync-todos" | "llm-status" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
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
                sub: "recipes" | "recipe" | "backends" | "doctor" | "runners" | "models" | "start" | "init" | "plan" | "activate" | "deactivate" | "promote" | "list" | "status" | "approve" | "reject" | "cancel" | "pause" | "resume" | "stop" | "cleanup" | "graph" | "handoff" | "task" | "watch" | "report" | "artifacts" | "handoffs" | "logs" | "approvals" | "prune" | "help";
            };
            cookie?: never;
        };
        requestBody?: {
            content: {
                "application/json": {
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
                    person_bindings?: {
                        [key: string]: string;
                    };
                    launch_sessions?: boolean;
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
    mcp_providers: {
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
                content: {
                    "application/json": components["schemas"]["McpProvidersResponse"];
                };
            };
        };
    };
    install_preview: {
        parameters: {
            query?: {
                tools?: string;
            };
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
                content: {
                    "application/json": components["schemas"]["InstallPreviewResponse"];
                };
            };
        };
    };
    install_reviewed: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["InstallReviewedRequest"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["InstallPreviewResponse"];
                };
            };
            /** @description target selection is empty or unsupported */
            422: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    copilot_project_install_preview: {
        parameters: {
            query: {
                workspace: Record<string, never>;
                project: Record<string, never>;
                action?: "install" | "remove";
            };
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
                content: {
                    "application/json": components["schemas"]["CopilotProjectInstallResponse"];
                };
            };
            /** @description workspace or project is missing */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description action is not install or remove */
            422: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    copilot_project_install_reviewed: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["CopilotProjectInstallRequest"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["CopilotProjectInstallResponse"];
                };
            };
            /** @description request body is invalid */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description project changed since review; no mutation is applied */
            409: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description required field is missing or action is unsupported */
            422: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    install_receipts: {
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
                content: {
                    "application/json": components["schemas"]["InstallReceiptsResponse"];
                };
            };
        };
    };
    uninstall_preview: {
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
                content: {
                    "application/json": components["schemas"]["InstallPreviewResponse"];
                };
            };
        };
    };
    uninstall_reviewed: {
        parameters: {
            query: {
                review_token: Record<string, never>;
            };
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
                content: {
                    "application/json": components["schemas"]["InstallPreviewResponse"];
                };
            };
            /** @description review_token is required */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description removal plan changed since review */
            409: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_swarm_recipes: {
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
                content: {
                    "application/json": components["schemas"]["SwarmRecipesResponse"];
                };
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
                content: {
                    "application/json": components["schemas"]["VersionResponse"];
                };
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
                content: {
                    "text/plain": string;
                };
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
                content: {
                    "application/json": components["schemas"]["SelfcheckResponse"];
                };
            };
        };
    };
    list_jobs: {
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
                content: {
                    "application/json": {
                        [key: string]: components["schemas"]["Job"];
                    };
                };
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
                content: {
                    "application/json": components["schemas"]["Job"];
                };
            };
            /** @description invalid JSON body or workspace path */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace outside allowed roots */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description cmd is required */
            422: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description max concurrent jobs reached */
            429: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_people: {
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
                content: {
                    "application/json": Record<string, never>;
                };
            };
        };
    };
    create_person: {
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
                content: {
                    "application/json": Record<string, never>;
                };
            };
        };
    };
    list_person_sessions: {
        parameters: {
            query?: {
                workspace?: string;
            };
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
                content: {
                    "application/json": components["schemas"]["PersonSessionsResponse"];
                };
            };
        };
    };
    create_person_session: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["PersonSessionCreateRequest"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["PersonSessionResponse"];
                };
            };
            /** @description Person, project, provider or model cannot be launched */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace or Person not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    update_person_session_status: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["PersonSessionStatusRequest"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["PersonSessionResponse"];
                };
            };
            /** @description invalid session status */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description session not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description invalid lifecycle transition */
            409: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_people_bindings: {
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
                content: {
                    "application/json": components["schemas"]["PersonBindingsResponse"];
                };
            };
            /** @description workspace not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    update_people_bindings: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody: {
            content: {
                "application/json": components["schemas"]["PersonBindingsRequest"];
            };
        };
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["PersonBindingsResponse"];
                };
            };
            /** @description invalid recipe role or Person id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace outside allowed roots or symlink storage */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace or Person not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    get_person: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": Record<string, never>;
                };
            };
        };
    };
    update_person: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": Record<string, never>;
                };
            };
        };
    };
    archive_person: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": Record<string, never>;
                };
            };
        };
    };
    get_job: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["Job"];
                };
            };
            /** @description invalid job id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description job not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    delete_job: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["MessageResponse"];
                };
            };
            /** @description invalid job id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description job not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description job is running (use ?force=true) */
            409: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    get_job_log: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "text/plain": string;
                };
            };
        };
    };
    stream_job_events: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "text/event-stream": string;
                };
            };
        };
    };
    cancel_job: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["Job"];
                };
            };
            /** @description invalid job id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description job not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description job already terminal */
            409: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    retry_job: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["Job"];
                };
            };
            /** @description invalid job id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace outside allowed roots */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description job or workspace not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description job is not failed or canceled */
            409: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description max concurrent jobs reached */
            429: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    stream_events: {
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
                content: {
                    "text/event-stream": string;
                };
            };
            /** @description invalid since or Last-Event-ID */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description too many event subscribers */
            503: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_agents: {
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
                content: {
                    "application/json": components["schemas"]["AgentsResponse"];
                };
            };
        };
    };
    list_tools: {
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
                content: {
                    "application/json": components["schemas"]["ToolsResponse"];
                };
            };
        };
    };
    list_providers: {
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
                content: {
                    "application/json": components["schemas"]["ProvidersResponse"];
                };
            };
        };
    };
    list_models: {
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
                content: {
                    "application/json": components["schemas"]["ModelsResponse"];
                };
            };
        };
    };
    list_memory: {
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
                content: {
                    "application/json": components["schemas"]["MemoryListResponse"];
                };
            };
            /** @description invalid workspace */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace outside allowed roots */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    search_memory: {
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
                content: {
                    "application/json": components["schemas"]["MemorySearchResponse"];
                };
            };
            /** @description query is required */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace outside allowed roots */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    read_memory: {
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
                content: {
                    "application/json": components["schemas"]["MemoryReadResponse"];
                };
            };
            /** @description invalid path */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description path outside knowledge/ */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description memory file not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    edit_memory: {
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
                content: {
                    "application/json": components["schemas"]["MemoryWriteResponse"];
                };
            };
            /** @description invalid path or content */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description path outside knowledge/ */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description memory file not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    add_memory: {
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
                content: {
                    "application/json": components["schemas"]["MemoryWriteResponse"];
                };
            };
            /** @description invalid body or entry_type */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace outside allowed roots */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    archive_memory: {
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
                content: {
                    "application/json": components["schemas"]["MemoryWriteResponse"];
                };
            };
            /** @description invalid path */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description path outside knowledge/ */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description memory file not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description already archived */
            409: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
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
                content: {
                    "application/json": components["schemas"]["MessageResponse"];
                };
            };
        };
    };
    loop_status_by_name: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                name: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["LoopStatusResponse"];
                };
            };
            /** @description invalid loop name */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description loop not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    loop_audit_by_name: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                name: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["LoopAuditResponse"];
                };
            };
            /** @description invalid loop name */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description loop not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    loop_history_by_name: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                name: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["LoopHistoryResponse"];
                };
            };
            /** @description invalid loop name */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description loop not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    loop_cost_by_name: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                name: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["LoopCostResponse"];
                };
            };
            /** @description invalid loop name */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description loop not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    run_loop_by_name: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                name: string;
            };
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
            path: {
                name: string;
            };
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
                content: {
                    "application/json": components["schemas"]["SwarmListResponse"];
                };
            };
        };
    };
    get_swarm_run: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmRunResponse"];
                };
            };
            /** @description invalid run_id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_swarm_handoffs: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmHandoffsResponse"];
                };
            };
            /** @description invalid run_id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_swarm_tasks: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmTasksResponse"];
                };
            };
            /** @description invalid run_id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_swarm_approvals: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmApprovalsResponse"];
                };
            };
            /** @description invalid run_id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    list_swarm_artifacts: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmArtifactsResponse"];
                };
            };
            /** @description invalid run_id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    approve_swarm_run: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmActionResponse"];
                };
            };
            /** @description invalid gate_id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run or gate not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    reject_swarm_run: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmActionResponse"];
                };
            };
            /** @description reason required */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run or gate not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    stop_swarm_run: {
        parameters: {
            query?: never;
            header?: never;
            path: {
                id: string;
            };
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description OK */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["SwarmActionResponse"];
                };
            };
            /** @description invalid run_id */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description run not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
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
                content: {
                    "application/json": components["schemas"]["LoopListResponse"];
                };
            };
        };
    };
    list_files: {
        parameters: {
            query?: {
                path?: string;
                depth?: string;
                workspace?: string;
                project?: string;
            };
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
                content: {
                    "application/json": components["schemas"]["WorkspaceFileListResponse"];
                };
            };
            /** @description invalid project */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description path outside workspace */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace, registered project, or path not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    search_files: {
        parameters: {
            query: {
                q: string;
                workspace?: string;
                project?: string;
            };
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
                content: {
                    "application/json": components["schemas"]["WorkspaceFileSearchResponse"];
                };
            };
            /** @description invalid project */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description registered project not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    read_file: {
        parameters: {
            query: {
                path: string;
                workspace?: string;
                project?: string;
            };
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
                content: {
                    "application/json": components["schemas"]["WorkspaceFileReadResponse"];
                };
            };
            /** @description invalid project */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description path outside workspace */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description registered project or file not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
    write_file: {
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
                content: {
                    "application/json": components["schemas"]["WorkspaceFileWriteResponse"];
                };
            };
            /** @description invalid path or binary content */
            400: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description path outside workspace */
            403: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
            /** @description workspace not found */
            404: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["ApiError"];
                };
            };
        };
    };
}
