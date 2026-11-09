// Reply in Chinese when Han characters make up >= 20% of (Han + letters) in
// the title+body, or there are >= 12 of them. Template comments, code blocks
// and URLs are stripped first so API names don't inflate the letter count.
export function detectReplyLocale(title, body) {
  const text = `${title || ''}\n${body || ''}`
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`[^`]+`/g, ' ')
    .replace(/https?:\/\/\S+/g, ' ')
  const cjk = (text.match(/\p{Script=Han}/gu) || []).length
  const latin = (text.match(/[A-Za-z]/g) || []).length
  if (cjk === 0) return 'en'
  if (latin === 0) return 'zh'
  return (cjk / (cjk + latin) >= 0.2 || cjk >= 12) ? 'zh' : 'en'
}
