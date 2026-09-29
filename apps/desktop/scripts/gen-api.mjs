import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import openapiTS, { astToString } from 'openapi-typescript';

const here = path.dirname(fileURLToPath(import.meta.url));
const appDir = path.resolve(here, '..');
const openapiPath = path.resolve(appDir, '..', '..', 'docs', 'surface', 'openapi.json');
const outPath = path.resolve(appDir, 'src', 'lib', 'api-schema.d.ts');

const source = fs.readFileSync(openapiPath, 'utf8');
const ast = await openapiTS(JSON.parse(source));
const header = `/**
 * Generated from docs/surface/openapi.json — do not hand-edit.
 * Regenerate with: pnpm gen:api
 */
`;
fs.writeFileSync(outPath, header + astToString(ast));
console.log(`wrote ${path.relative(appDir, outPath)}`);
