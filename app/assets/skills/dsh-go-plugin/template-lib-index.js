// A local dsh-go plugin. Runs inside the DSH engine (Node); the dsh-go app draws
// what package.json "dshGo" declares and calls these handlers when tapped.
export const name = 'local-my-plugin'

export function apply(ctx) {
  // Runs only on hosts with the dsh-go bridge. Write ['dshGo'], never ['dshGo?'].
  ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.on('paste-quote', (scope, event) => {
      const text = (scope.clipboard ?? '').trim()
      if (text === '') return { toast: 'The clipboard is empty' }
      const quoted = text.split('\n').map((line) => `> ${line}`).join('\n')
      return { insert: `${quoted}\n\n`.slice(0, 2000) }
    })
  })
}
