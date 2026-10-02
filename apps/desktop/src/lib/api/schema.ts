/**
 * Type-level bridge from the generated OpenAPI contract (api-schema.d.ts,
 * `pnpm gen:api`) to the client. Nothing here exists at runtime.
 *
 * Every client call names its route as a literal that must exist in
 * `paths` for the given method, so regenerating the schema after a route is
 * removed or renamed breaks the build at the call site. Response bodies are
 * taken from the schema when it documents them (`ResponseOf`) and fall back
 * to the hand-declared contracts in contracts.ts until it does.
 */
import type { paths } from '../api-schema';

export type HttpMethod = 'get' | 'post' | 'put' | 'delete';

/** Route templates that declare `method` in the OpenAPI contract. */
export type PathWith<M extends HttpMethod> = {
  [P in keyof paths]: [NonNullable<paths[P][M]>] extends [never] ? never : P;
}[keyof paths];

export type OperationOf<P extends keyof paths, M extends HttpMethod> = NonNullable<paths[P][M]>;

type Json200<Op> = Op extends { responses: { 200: { content: { 'application/json': infer R } } } } ? R : never;

/** Documented 200 JSON body, else `Fallback` (the server contract we mirror by hand). */
export type ResponseOf<Op, Fallback> = [Json200<Op>] extends [never] ? Fallback : Json200<Op>;

export type BodyOf<Op> = Op extends { requestBody?: { content: { 'application/json': infer B } } } ? B : never;

type SubTemplate = Extract<keyof paths, `/api/v1/${string}/{sub}`>;

/** Command families exposed as `/api/v1/<family>/{sub}` (skills, mcp, swarms, ...). */
export type SubFamily = SubTemplate extends `/api/v1/${infer F}/{sub}` ? F : never;

type SubPath<F extends SubFamily> = Extract<SubTemplate, `/api/v1/${F}/{sub}`>;

export type SubOperation<F extends SubFamily> = OperationOf<SubPath<F>, 'post'>;

/** Allowlisted subcommands for a family (server returns 404 for anything else). */
export type SubCommand<F extends SubFamily> =
  SubOperation<F> extends { parameters: { path: { sub: infer S } } } ? S : never;

/** Typed request body for a family; the route path, never the body, names the subcommand. */
export type SubBody<F extends SubFamily> = BodyOf<SubOperation<F>>;
