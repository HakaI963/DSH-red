import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { projectRoot, readConfig, validateConfig, applyMetadata, printReport } from './release-tools.mjs';
try {
  const config = await readConfig();
  const report = await validateConfig(config);
  printReport(report);
  if (report.errors.length) {
    console.error('Publish preparation stopped; index.html was not modified.');
    process.exitCode = 1;
  } else {
    const file = resolve(projectRoot, 'dist/index.html');
    const html = await readFile(file, 'utf8');
    await writeFile(file, applyMetadata(html, config.metadata), 'utf8');
    console.log('Wrote the share title, description and the provided links/cover into dist/index.html. After reviewing the reminders and the manual acceptance checklist, you can upload everything inside dist.');
  }
} catch (error) { console.error(`[error] publish preparation failed: ${error.message}`); process.exitCode = 1; }
