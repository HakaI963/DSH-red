// This context is mounted only by the companion-full preset.
import { companionFullRules, renderCompanionProfile } from './full-persona.js';
export const name = 'dsh-go-companion-full-context';
export const inject = ['systemPrompt'];

export function apply(ctx) {
  // A dependency child follows bridge replacement while this full-context
  // mount stays alive. Its disposer removes only that service's registration.
  if (typeof ctx.inject === 'function') {
    ctx.inject(['dshGoCompanionRecall'], (owner) => {
      const service = owner.get('dshGoCompanionRecall');
      if (typeof service?.registerContext === 'function') {
        owner.effect(() => service.registerContext(ctx), 'companion-recall.context');
      }
    });
  }
  // Optional on an older Host: ordinary full-mode context remains available
  // when the pinned recall engine is unsupported. Registration itself grants
  // no recall; bind still proves this exact scope, service owner and mount.
  const recall = typeof ctx.inject === 'function' ? undefined : ctx.get?.('dshGoCompanionRecall');
  if (typeof recall?.registerContext === 'function') {
    ctx.effect(() => recall.registerContext(ctx), 'companion-recall.context');
  }
  // The preset no longer mounts dsh-persona beside this provider: duplicate
  // named sections in the same scope are rejected by 0.2.2-rc.1.
  ctx.systemPrompt.section({
    name: 'deployment:persona-prefix',
    order: ctx.systemPrompt.getSectionOrder('DEPLOYMENT_PERSONA_PREFIX'),
    interpolate: false,
    text: ({ agent } = {}) => renderCompanionProfile(agent && ctx.get('dshGoCompanionContext')?.profile(agent)),
  });
  ctx.systemPrompt.section({
    name: 'deployment:persona-suffix',
    order: ctx.systemPrompt.getSectionOrder('DEPLOYMENT_PERSONA_SUFFIX'),
    interpolate: false,
    text: companionFullRules,
  });
  ctx.systemPrompt.section({
    name: 'app:web-surface',
    order: ctx.systemPrompt.getSectionOrder('WEB_SURFACE'),
    interpolate: false,
    text: 'You interact with the user through the Companion room of the dsh-go phone app. When the user says "this app" or "here" without naming another target, they mean dsh-go; files on the current host and the phone screen are different environments. The interface does not implicitly provide the screen, the DOM, or screenshots; only what the tools actually returned this round counts as an observed result.',
  });
  ctx.systemPrompt.context({
    name: 'app:web-surface',
    order: ctx.systemPrompt.getContextOrder('WEB_SURFACE'),
    interpolate: false,
    // Engine-owned, source-attributed runtime snapshots are persisted only on
    // change. They must be filtered from the human backlog by source.kind.
    text: ({ agent } = {}) => agent ? ctx.get('dshGoCompanionContext')?.render(agent) ?? '' : '',
  });
}
