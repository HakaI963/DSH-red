"""python3 -m unittest discover -s app/tool -p 'test_guide_sync.py'"""
import json
import tempfile
import unittest
from pathlib import Path

import guide_sync

REPO = Path(__file__).resolve().parents[2]

SKILL = """---
# dsh-go:managed — the dsh-go app keeps this skill up to date
name: dsh-go-guide
description: The guide.
whenToUse: How to use the app.
---

Read [README](README.md).
"""

PAGE = (
    '# Engine\n\n<!-- nav: commonSettings,hubSettingsEngine -->\n'
    '`Settings › Engine` · [Open](dshgo://open/engine)\n\n'
    'Tap **Start**, or **Stop actions**. See [Settings](02-settings.md).\n'
)

PAGE_LINKS = """const catalogPageLinks = <String>{
  'schedules',
};
"""

SPOTS = """final _pages = <SettingsPageMeta>[
  SettingsPageMeta(SettingsPageId.hub, title: (l) => l.commonSettings, links: const ['settings']),
  SettingsPageMeta(
    SettingsPageId.engine,
    title: (l) => l.hubSettingsEngine,
    links: const ['engine', 'phone'],
  ),
];
static final darkMode = SettingSpot('dark-mode', page: SettingsPageId.appearance, link: 'dark-mode');
"""


class GuideSyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.guide = self.repo / 'docs/guide'
        self.write('app/pubspec.yaml', 'name: app\nversion: 0.9.2+1\n')
        self.write('app/lib/l10n/parts/hub_en.arb', json.dumps(
            {'commonSettings': 'Settings', 'hubSettingsEngine': 'Engine', 'phoneEngineStart': 'Start', 'count': '{n}'}))
        res = 'app/android/app/src/main/res'
        self.write(f'{res}/values/s.xml', '<resources><string name="stop">Stop actions</string></resources>')
        self.write('app/lib/links/page_links.dart', PAGE_LINKS)
        self.write('app/lib/ui/settings/index/spots.dart', SPOTS)
        self.write('docs/guide/SKILL.md', SKILL)
        self.write('docs/guide/README.md', '# Guide\n\n> dsh-go 0.9.2\n\n- [Engine](en/01-engine.md)\n')
        self.write('docs/guide/en/01-engine.md', PAGE)
        self.write('docs/guide/en/02-settings.md', '# Settings\n')

    def write(self, rel, text):
        path = self.repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def errors(self):
        return guide_sync.check(self.repo, self.guide)

    def assertFails(self, needle):
        errors = self.errors()
        self.assertTrue(any(needle in e for e in errors), f'{needle!r} not in {errors}')

    def test_valid_guide_builds_and_then_checks_clean(self):
        self.assertEqual(self.errors(), [])
        self.assertEqual(guide_sync.run(self.repo, write=True), [])
        self.assertEqual(guide_sync.run(self.repo, write=False), [])
        assets = self.repo / 'app/assets/skills/dsh-go-guide'
        manifest = json.loads((assets / 'manifest.json').read_text())
        self.assertEqual(manifest['name'], 'dsh-go-guide')
        self.assertEqual(manifest['files']['en-01-engine.md'], 'en/01-engine.md')
        self.assertEqual(set(manifest['files']), {p.name for p in assets.iterdir()} - {'manifest.json'})
        for flat, target in manifest['files'].items():
            self.assertEqual((assets / flat).read_bytes(), (self.guide / target).read_bytes())

    def test_generated_assets_cannot_drift(self):
        guide_sync.run(self.repo, write=True)
        assets = self.repo / 'app/assets/skills/dsh-go-guide'
        (assets / 'en-01-engine.md').write_text('edited by hand')
        self.assertTrue(any('out of date' in e for e in guide_sync.run(self.repo, write=False)))
        guide_sync.run(self.repo, write=True)
        (assets / 'stale.md').write_text('old page')
        self.assertTrue(any('stale.md' in e for e in guide_sync.run(self.repo, write=False)))
        guide_sync.run(self.repo, write=True)
        self.assertFalse((assets / 'stale.md').exists())

    def test_nav_label_must_match_the_arb(self):
        self.write('docs/guide/en/01-engine.md', PAGE.replace('`Settings › Engine`', '`Settings › Runtime`'))
        self.assertFails('want `Settings › Engine`')

    def test_nav_key_must_exist(self):
        self.write('docs/guide/en/01-engine.md', PAGE.replace('hubSettingsEngine', 'hubSettingsGone'))
        self.assertFails('no en ARB key hubSettingsGone')

    def test_nav_labels_come_from_the_en_arb(self):
        self.write('docs/guide/en/01-engine.md', PAGE.replace('`Settings › Engine`', '`设置 › 引擎`'))
        self.assertFails('want `Settings › Engine`')

    def test_placeholder_labels_are_not_paths(self):
        self.write('docs/guide/en/02-settings.md', '# Settings\n\n<!-- nav: count -->\n`{n}`\n')
        self.assertFails('not a plain label')

    def test_path_without_annotation_fails(self):
        self.write('docs/guide/en/02-settings.md', '# Settings\n\nIn `Settings › Engine`.\n')
        self.assertFails('path without a nav annotation')

    def test_malformed_annotation_fails(self):
        self.write('docs/guide/en/02-settings.md',
                   '# Settings\n\n<!-- nav: commonSettings, hubSettingsEngine -->\n`Settings › Engine`\n')
        self.assertFails('malformed annotation')

    def test_bold_must_be_an_en_ui_label(self):
        self.write('docs/guide/en/02-settings.md', '# Settings\n\nTap **Begin**.\n')
        self.assertFails('**Begin** is not a en UI label')
        self.write('docs/guide/en/02-settings.md', '# Settings\n\nTap **启动**.\n')
        self.assertFails('**启动** is not a en UI label')

    def test_links_must_resolve_and_page_links_must_be_allowed(self):
        self.write('docs/guide/en/02-settings.md', '# Settings\n\nSee [Pets](06-pets.md).\n')
        self.assertFails('broken link 06-pets.md')
        self.write('docs/guide/en/02-settings.md', '# Settings\n\n[Open](dshgo://open/terminal)\n')
        self.assertFails('dshgo://open/terminal is not a page link')
        self.write('docs/guide/en/02-settings.md', '# Settings\n\n[Open](dshgo://open/settings)\n')
        self.assertEqual(self.errors(), [])
        # A row's link and a feature-catalog page open too.
        self.write('docs/guide/en/02-settings.md',
                   '# Settings\n\n[Dark](dshgo://open/dark-mode) [Schedules](dshgo://open/schedules)\n')
        self.assertEqual(self.errors(), [])

    def test_version_must_match_pubspec(self):
        self.write('app/pubspec.yaml', 'version: 0.9.3+1\n')
        self.assertFails('`> dsh-go 0.9.3`')

    def test_zh_pages_are_not_part_of_the_guide(self):
        self.write('docs/guide/zh/01-engine.md', '# 引擎\n')
        self.assertFails('zh/01-engine.md: not part of the guide')

    def test_missing_en_pages_fail(self):
        (self.guide / 'en/01-engine.md').unlink()
        (self.guide / 'en/02-settings.md').unlink()
        self.assertFails('/en: no pages')

    def test_skill_front_matter(self):
        self.write('docs/guide/SKILL.md', SKILL.replace('# dsh-go:managed — the dsh-go app keeps this skill up to date\n', ''))
        self.assertFails('# dsh-go:managed')
        self.write('docs/guide/SKILL.md', SKILL.replace('whenToUse', 'when'))
        self.assertFails('needs whenToUse')
        self.write('docs/guide/SKILL.md', SKILL.replace('description: The guide.', 'description: The guide: where things are.'))
        self.assertFails('description must be a plain one-line value')

    def test_stray_files_fail(self):
        self.write('docs/guide/notes.txt', 'draft')
        self.assertFails('notes.txt: not part of the guide')


class RepositoryGuideTest(unittest.TestCase):
    def test_docs_guide_matches_the_app_and_its_assets(self):
        self.assertEqual(guide_sync.run(REPO, write=False), [])


if __name__ == '__main__':
    unittest.main()
