import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { projectRoot, readConfig, validateConfig, applyMetadata, printReport } from './release-tools.mjs';
try {
  const config = await readConfig();
  const report = await validateConfig(config);
  if (!report.errors.length) {
    const html = await readFile(resolve(projectRoot, 'dist/index.html'), 'utf8');
    if (applyMetadata(html, config.metadata) !== html) report.warnings.push('metadata: the static HTML is not in sync with the config yet; run npm run prepare:publish before uploading.');
  }
  printReport(report);
  process.exitCode = report.errors.length ? 1 : 0;
} catch (error) { console.error(`[error] cannot check config: ${error.message}`); process.exitCode = 1; }
