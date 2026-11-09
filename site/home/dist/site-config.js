/* Authors only need to edit this file; see site/home/README.md for how to fill it in.
   Everything here is shown publicly, so never enter secrets or private information. Put images in assets/author/.
   The avatar and QR code must use this site's assets/ paths: the page's CSP only allows same-site images, so external images won't display.
   Empty links don't navigate; leaving contributors empty won't invent names. Save and refresh the page to apply. */
window.DSH_GO_CONFIG = {
  // Share metadata: after filling this in, run npm run prepare:publish to write it into the static HTML.
  // Keep the title and description unless rebranding; siteUrl is the final full URL — directory URLs end with /.
  metadata: {
    title: "DSH Go · Everything is a plugin, now on the go",
    description: "DSH Go, the unofficial DeepSeek Harness mobile app crafted by ccchimneyyy, author of DSH-TUI. Everything is a plugin — now on the go.",
    siteUrl: "https://go.dshtui.com/",
    shareImage: "assets/author/share.png", // Optional: a same-site image or a full HTTPS image URL; 1200×630 PNG/JPEG recommended
    shareImageAlt: "DSH Go on phone and tablet: DeepSeek Harness in your pocket"
  },
  author: {
    avatar: "assets/dsh-go.svg", // Replace with assets/author/avatar.png
    id: "ccch1mneyyy",
    message: "DSH Go is the unofficial DeepSeek Harness mobile client crafted by ccchimneyyy, author of DSH-TUI. We want to bring the \"everything is a plugin\" experience to your phone, so inspiration is never limited by where you are."
  },
  download: {
    label: "Download DSH Go",
    platform: "Android 8.0+",
    title: "Get DSH Go",
    description: "DSH Go 1.0 is out, supporting phones on Android 8.0 and above. The download page lists the currently available download routes.",
    qrImage: "assets/author/download-qr-v2.png", // Encodes the url below; regenerate it and change the file name when the url changes
    qrNote: "Scan to open the download page",
    url: "https://go.dshtui.com/download", // Download entry: the download page; inside WeChat/QQ it prompts you to switch browsers
    urlLabel: "Open the download page",
    altUrl: "https://github.com/ccch1mneyyy/dsh-go/releases/latest", // Second entry: latest GitHub Releases version; an empty value hides it
    altLabel: "Download from GitHub"
  },
  // Both the code box and the Star bubble link here; the Star count on the bubble comes from this site's
  // /api/github/stars (services/share-worker/src/github.ts, hardcoded to ccch1mneyyy/dsh-go).
  repository: {
    label: "github / ccch1mneyyy / dsh-Go", // The whole line of text can be edited
    url: "https://github.com/ccch1mneyyy/dsh-Go"
  },
  // Three rows scroll right to left. Each entry may set row: 1, 2 or 3; if omitted, rows are assigned round-robin.
  // name is only for a plain name without platform links. A platform object's label is the display name on that platform.
  // Example: { name: "contributor ID", row: 1 }
  // Example: { github: { label: "GitHub ID", url: "https://github.com/username" }, row: 2 }
  // Example: { bilibili: { label: "Bilibili nickname", url: "https://space.bilibili.com/numeric-id" } }
  // Writing both github and bilibili in one entry yields "GitHub ID / Bilibili nickname".
  contributors: [
    { github: { label: "ccch1mneyyy", url: "https://github.com/ccch1mneyyy" }, row: 1 }
  ]
};
