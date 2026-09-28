// Production entry point: apply any pending migrations, then start the API.
// migrate.js is idempotent (it records applied files in `_migrations`), so
// running it on every boot is safe and means a deploy that ships a new
// migration can't go live against an old schema. It runs in a child process
// because it closes its own DB pool when done. If it fails, the server still
// starts so a migration problem never takes the whole API down with it.
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const result = spawnSync(process.execPath, [path.join(__dirname, 'migrate.js')], { stdio: 'inherit' });
if (result.status !== 0) {
  console.error(`migrations failed (exit ${result.status}) — starting the API anyway`);
}

await import('../src/index.js');
