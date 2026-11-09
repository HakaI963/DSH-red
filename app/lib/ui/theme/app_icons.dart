import 'dsh_glyphs.dart';

/// Icon vocabulary: **Phosphor Regular** (1.5 stroke, round caps, geometric), with the **Fill** of
/// the same skeleton for selected / lit / on states. Spec: `docs/design/polish-guide.md` §1.
///
/// - Named by **role**, not by shape: one shape can serve several roles (`regenerate` and `refresh`
///   are both clockwise arrows) while one role owns exactly one shape. Business code writes only
///   `AppIcons.xxx` — never `Icons.*`, never `DshGlyphs.*`. Swapping a shape is one line here; swapping the whole set just regenerates [DshGlyphs].
/// - Glyphs come from the custom subset font `assets/fonts/DshIcons.ttf`. Phosphor leaves more
///   whitespace in its grid than Material; the font scales everything up 10% so the same `size:`
///   occupies the same box at the same visual size as a Material icon. Colour and size go through `IconTheme` / `DshColors`.
/// - Adding a role: write a line `static const foo = DshGlyphs.barBaz;` below (Phosphor name in
///   camelCase, `…Fill` for the Fill), then run `python3 tool/make_icon_font.py` from `app/`.
abstract final class AppIcons {
  // ── Navigation & shell ──────────────────────────────────────────────
  static const back = DshGlyphs.arrowLeft;
  static const forward = DshGlyphs.arrowRight;
  static const close = DshGlyphs.x;
  static const menu = DshGlyphs.list;
  static const more = DshGlyphs.dotsThree;

  /// The system 「⋮」 menu (only ever pointed out to users in the onboarding).
  static const moreVertical = DshGlyphs.dotsThreeVertical;

  /// Row-end "go in"; breadcrumb separator.
  static const disclosure = DshGlyphs.caretRight;
  static const expand = DshGlyphs.caretDown;
  static const collapse = DshGlyphs.caretUp;

  /// Switchable selectors: host, workspace, balance.
  static const dropdown = DshGlyphs.caretUpDown;
  static const openExternal = DshGlyphs.arrowSquareOut;
  static const openLink = DshGlyphs.arrowUpRight;
  static const openWith = DshGlyphs.dotsNine;
  static const allFeatures = DshGlyphs.dotsNine;
  static const browser = DshGlyphs.browser;
  static const scrollToBottom = DshGlyphs.arrowDown;
  static const sidebar = DshGlyphs.sidebarSimpleRight;
  static const dragHandle = DshGlyphs.dotsSixVertical;
  static const swap = DshGlyphs.arrowsLeftRight;

  /// Terminal arrow keys; the Enter hint in the completion panel.
  static const keyUp = DshGlyphs.caretUp;
  static const keyDown = DshGlyphs.caretDown;
  static const keyLeft = DshGlyphs.caretLeft;
  static const keyRight = DshGlyphs.caretRight;
  static const enterKey = DshGlyphs.arrowElbowDownLeft;

  /// Paging (plugin carousel): previous / next page. The previous caret mirrors in right-to-left languages.
  static const pagePrevious = DshGlyphs.caretLeft;
  static const pageNext = DshGlyphs.caretRight;

  // ── Composer ──────────────────────────────────────────────────
  static const send = DshGlyphs.arrowUp;

  /// The stop inside the composer's round key (generation, voice): a solid square.
  static const stopGenerating = DshGlyphs.stopFill;
  static const voice = DshGlyphs.microphone;

  /// Steer: fed in mid-turn.
  static const steer = DshGlyphs.arrowElbowDownRight;

  /// Queue: sent after the current turn ends.
  static const queued = DshGlyphs.clock;

  /// Interrupt: stops the turn, then sends.
  static const interrupt = DshGlyphs.stopCircle;
  static const camera = DshGlyphs.camera;
  static const gallery = DshGlyphs.images;
  static const files = DshGlyphs.folderOpen;
  static const addImage = DshGlyphs.image;

  /// 「传文件到电脑」 (Remote workspace upload).
  static const uploadToHost = DshGlyphs.boxArrowUp;

  // ── Message actions ────────────────────────────────────────────────
  static const copy = DshGlyphs.copy;
  static const quote = DshGlyphs.quotes;
  static const share = DshGlyphs.export;
  static const qrCode = DshGlyphs.qrCode;
  static const shareImage = DshGlyphs.image;

  /// The share sheet's other two destinations: file, text.
  static const shareFile = DshGlyphs.fileText;
  static const shareText = DshGlyphs.textAlignLeft;

  /// The 「停止分享」 on a freshly made link.
  static const stopSharing = DshGlyphs.linkBreak;

  /// Shared content has keys and personal paths redacted.
  static const redacted = DshGlyphs.shieldCheck;

  static const selectText = DshGlyphs.textT;
  static const fork = DshGlyphs.gitFork;
  static const regenerate = DshGlyphs.arrowClockwise;
  static const edit = DshGlyphs.pencilSimple;
  static const reply = DshGlyphs.arrowBendUpLeft;

  /// Auto-wrap toggle for code and diffs.
  static const wrapLines = DshGlyphs.textWrap;
  static const save = DshGlyphs.downloadSimple;
  static const preview = DshGlyphs.eye;

  /// The receipt of a finished action: copied, saved.
  static const done = DshGlyphs.check;

  // ── Common actions ────────────────────────────────────────────────
  static const add = DshGlyphs.plus;

  /// The "add this entry" at the composer's tail.
  static const addEntry = DshGlyphs.plusCircleFill;
  static const increment = DshGlyphs.plus;
  static const decrement = DshGlyphs.minus;
  static const remove = DshGlyphs.minusCircle;
  static const rename = DshGlyphs.pencilSimpleLine;
  static const delete = DshGlyphs.trash;

  /// Placeholder for a file that has since been deleted.
  static const deleted = DshGlyphs.trash;

  /// Clears the input box.
  static const clear = DshGlyphs.xCircleFill;
  static const clearAll = DshGlyphs.broom;
  static const paste = DshGlyphs.clipboard;
  static const download = DshGlyphs.downloadSimple;
  static const refresh = DshGlyphs.arrowClockwise;
  static const retry = DshGlyphs.arrowClockwise;
  static const restart = DshGlyphs.arrowCounterClockwise;
  static const search = DshGlyphs.magnifyingGlass;
  static const configure = DshGlyphs.slidersHorizontal;
  static const settings = DshGlyphs.gearSix;
  static const link = DshGlyphs.link;
  static const showSecret = DshGlyphs.eye;
  static const hideSecret = DshGlyphs.eyeSlash;
  static const newChat = DshGlyphs.notePencil;
  static const newFolder = DshGlyphs.folderPlus;
  static const newPost = DshGlyphs.notePencil;
  static const moveToFolder = DshGlyphs.folderArrowRight;
  static const multiSelect = DshGlyphs.checkCircle;
  static const archive = DshGlyphs.archive;
  static const unarchive = DshGlyphs.boxArrowUp;
  static const exportLog = DshGlyphs.archive;
  static const pin = DshGlyphs.pushPin;
  static const pinActive = DshGlyphs.pushPinFill;
  static const logout = DshGlyphs.signOut;
  static const power = DshGlyphs.power;

  /// Play / pause / stop in rows and capsules: outlined like every other action.
  static const play = DshGlyphs.play;
  static const pause = DshGlyphs.pause;
  static const stop = DshGlyphs.stop;

  /// The replay play key: media controls use solid glyphs by convention.
  static const mediaPlay = DshGlyphs.playFill;
  static const mediaPause = DshGlyphs.pauseFill;

  /// After a replay ends, start it over from the top.
  static const replay = DshGlyphs.arrowCounterClockwise;

  /// The 「全文」 of the replay page.
  static const fullText = DshGlyphs.article;
  static const enterPath = DshGlyphs.cursorText;
  static const viewConfig = DshGlyphs.fileText;

  /// Grab a command to run in the terminal.
  static const command = DshGlyphs.terminalWindow;
  static const fetchModels = DshGlyphs.cloudArrowDown;
  static const testConnection = DshGlyphs.broadcast;
  static const markAllRead = DshGlyphs.checks;
  static const manageFolders = DshGlyphs.arrowsDownUp;

  /// /compact: compress the context.
  static const compact = DshGlyphs.arrowsInLineVertical;

  /// After a turn finishes, fold its thinking and tool calls into one line.
  static const foldTurns = DshGlyphs.arrowsInLineVertical;

  // ── Selection and toggles (Fill marks the selected / on state)──────────────────────
  /// The list's currently selected item.
  static const selected = DshGlyphs.check;
  static const allowed = DshGlyphs.check;
  static const radioOn = DshGlyphs.checkCircleFill;
  static const radioOff = DshGlyphs.circle;
  static const checkboxOn = DshGlyphs.checkSquareFill;
  static const checkboxOff = DshGlyphs.square;
  static const isDefault = DshGlyphs.checkCircleFill;
  static const setDefault = DshGlyphs.checkCircle;
  static const favorite = DshGlyphs.star;
  static const favoriteActive = DshGlyphs.starFill;
  static const bookmark = DshGlyphs.bookmarkSimple;
  static const bookmarkActive = DshGlyphs.bookmarkSimpleFill;
  static const postLike = DshGlyphs.heart;
  static const postLikeActive = DshGlyphs.heartFill;
  static const notifications = DshGlyphs.bell;
  static const notificationsOn = DshGlyphs.bellFill;
  static const notificationsOff = DshGlyphs.bellSlash;

  // ── Status ────────────────────────────────────────────────────
  static const success = DshGlyphs.checkCircleFill;
  static const completed = DshGlyphs.checkCircle;
  static const error = DshGlyphs.warningCircle;
  static const warning = DshGlyphs.warning;
  static const info = DshGlyphs.info;
  static const question = DshGlyphs.question;
  static const attention = DshGlyphs.exclamationMark;
  static const caution = DshGlyphs.warningOctagon;

  /// The failure cross of tool calls and the like (paired with the danger colour).
  static const failed = DshGlyphs.x;
  static const stopped = DshGlyphs.stopCircle;
  static const paused = DshGlyphs.pauseCircle;
  static const blocked = DshGlyphs.prohibit;
  static const pending = DshGlyphs.circle;
  static const inProgress = DshGlyphs.radioButton;
  static const stepFailed = DshGlyphs.xCircleFill;
  static const stepSkipped = DshGlyphs.minusCircle;
  static const loading = DshGlyphs.hourglass;
  static const waiting = DshGlyphs.hourglassHigh;
  static const running = DshGlyphs.lightning;
  static const cannotDisplay = DshGlyphs.prohibit;
  static const empty = DshGlyphs.tray;
  static const toConfirm = DshGlyphs.checkCircle;
  static const allRead = DshGlyphs.checks;
  static const outputLimit = DshGlyphs.textAlignLeft;
  static const imageBroken = DshGlyphs.imageBroken;
  static const noResults = DshGlyphs.magnifyingGlassX;
  static const noMatches = DshGlyphs.funnelX;
  static const noFolder = DshGlyphs.folderSlash;

  /// The host or its version does not support this capability.
  static const unsupported = DshGlyphs.puzzlePieceSlash;
  static const taskBlocked = DshGlyphs.lockSimple;

  // ── Connection, hosts and engine ────────────────────────────────────────
  static const offline = DshGlyphs.cloudSlash;
  static const disconnected = DshGlyphs.linkBreak;
  static const reconnecting = DshGlyphs.arrowsClockwise;
  static const engine = DshGlyphs.cpu;
  static const engineStarting = DshGlyphs.lightning;
  static const autoSwitch = DshGlyphs.arrowsClockwise;
  static const cloud = DshGlyphs.cloud;
  static const computer = DshGlyphs.laptop;
  static const thisPhone = DshGlyphs.deviceMobile;
  static const sshHost = DshGlyphs.terminalWindow;
  static const remoteHost = DshGlyphs.devices;
  static const remoteHosts = DshGlyphs.devices;
  static const webConsole = DshGlyphs.globe;
  static const checkUpdate = DshGlyphs.arrowCircleUp;
  static const autoUpdate = DshGlyphs.clockClockwise;

  // ── Security and permissions ──────────────────────────────────────────────
  static const lock = DshGlyphs.lockSimple;
  static const lockActive = DshGlyphs.lockSimpleFill;
  static const unlock = DshGlyphs.lockSimpleOpen;

  /// Credentials never leave this device.
  static const localOnly = DshGlyphs.lockKey;
  static const approval = DshGlyphs.shieldWarning;
  static const securityWarning = DshGlyphs.shieldWarning;
  static const permissions = DshGlyphs.shield;
  static const safeMode = DshGlyphs.shieldPlus;
  static const verified = DshGlyphs.shieldCheck;
  static const fingerprint = DshGlyphs.fingerprint;
  static const apiKey = DshGlyphs.key;
  static const noApiKey = DshGlyphs.keySlash;
  static const autoApprove = DshGlyphs.checks;

  // ── Files and content ──────────────────────────────────────────────
  static const folder = DshGlyphs.folder;

  /// Solid folder carrying the group colour (drawer folders, file lists).
  static const folderMark = DshGlyphs.folderFill;
  static const folderOpen = DshGlyphs.folderOpen;
  static const workspace = DshGlyphs.folder;
  static const workspaceGroup = DshGlyphs.folders;
  static const defaultFolder = DshGlyphs.folderStar;
  static const sharedStorage = DshGlyphs.folderUser;
  static const home = DshGlyphs.house;
  static const phoneStorage = DshGlyphs.deviceMobile;
  static const downloads = DshGlyphs.downloadSimple;
  static const document = DshGlyphs.fileText;
  static const instructions = DshGlyphs.fileText;
  static const file = DshGlyphs.file;
  static const fileNew = DshGlyphs.filePlus;
  static const diff = DshGlyphs.gitDiff;
  static const pdf = DshGlyphs.filePdf;
  static const image = DshGlyphs.image;
  static const videoFile = DshGlyphs.fileVideo;
  static const video = DshGlyphs.filmStrip;
  static const audioFile = DshGlyphs.fileAudio;
  static const audio = DshGlyphs.musicNote;
  static const zip = DshGlyphs.fileZip;
  static const slides = DshGlyphs.slideshow;
  static const spreadsheet = DshGlyphs.table;
  static const article = DshGlyphs.article;
  static const plainText = DshGlyphs.textAlignLeft;
  static const summary = DshGlyphs.textAlignLeft;
  static const code = DshGlyphs.code;
  static const diagram = DshGlyphs.graph;
  static const artifacts = DshGlyphs.package;
  static const shareBundle = DshGlyphs.package;

  /// The file is still being generated.
  static const generating = DshGlyphs.sparkle;

  // ── Image & video generation (docs/design/media-generation.md)──────────────
  /// The 「生成」 tile of the ＋ panel; 设置 › 图像与视频.
  static const generateMedia = DshGlyphs.magicWand;

  /// Mode capsules and the parameter sheet: image / video.
  static const generateImage = DshGlyphs.image;
  static const generateVideo = DshGlyphs.filmStrip;

  /// Viewer: 「详情」.
  static const mediaDetails = DshGlyphs.info;

  /// Viewer: vary, edit, upscale.
  static const mediaVary = DshGlyphs.stack;
  static const mediaEdit = DshGlyphs.pencilSimple;
  static const mediaUpscale = DshGlyphs.arrowsInLineVertical;

  /// Permission capsule: looser than editing inside the workspace.
  static const permissionRisky = DshGlyphs.warning;
  static const web = DshGlyphs.globe;
  static const readText = DshGlyphs.note;

  // ── Features ────────────────────────────────────────────────────
  static const terminal = DshGlyphs.terminalWindow;
  static const plugin = DshGlyphs.puzzlePiece;
  static const pluginInventory = DshGlyphs.listBullets;
  static const skill = DshGlyphs.bookOpen;
  static const model = DshGlyphs.cpu;
  static const providers = DshGlyphs.sparkle;

  /// One model in the model list.
  static const modelItem = DshGlyphs.cpu;
  static const subagents = DshGlyphs.treeStructure;
  static const workflow = DshGlyphs.flowArrow;
  static const todo = DshGlyphs.listChecks;
  static const goal = DshGlyphs.flag;
  static const plan = DshGlyphs.mapTrifold;
  static const planMode = DshGlyphs.mapTrifold;
  static const jobs = DshGlyphs.clipboardText;
  static const automation = DshGlyphs.alarm;
  static const recurring = DshGlyphs.repeat;
  static const scheduled = DshGlyphs.clock;
  static const time = DshGlyphs.clock;
  static const timeZone = DshGlyphs.globe;
  static const commandTimeout = DshGlyphs.timer;
  static const agentLoop = DshGlyphs.arrowsClockwise;
  static const webSearch = DshGlyphs.globeHemisphereWest;
  static const webApp = DshGlyphs.globe;
  static const mention = DshGlyphs.at;
  static const translate = DshGlyphs.translate;
  static const history = DshGlyphs.clockCounterClockwise;
  static const sessionDetails = DshGlyphs.chartLineUp;
  static const trajectory = DshGlyphs.path;
  static const diagnostics = DshGlyphs.stethoscope;
  static const cordis = DshGlyphs.squaresFour;

  /// An interactive panel sent by a Bot.
  static const panel = DshGlyphs.squaresFour;
  static const feedback = DshGlyphs.chatCenteredDots;
  static const tool = DshGlyphs.wrench;
  static const tip = DshGlyphs.lightbulb;

  /// 伙伴小屋: she now and then asks you to rest with her (companion_page.dart).
  static const companionInvite = DshGlyphs.chatTeardropText;

  /// 伙伴小屋: her words read aloud (companion_voice.dart). Not the microphone: that is the person's voice.
  static const companionVoice = DshGlyphs.musicNote;

  /// 「问 AI」: a question about the app for the agent (ui/common/ask_ai.dart).
  static const askAi = DshGlyphs.sparkle;

  /// 「给 dsh-go 点个 star」: the project on GitHub (ui/star/).
  static const starProject = DshGlyphs.star;
  static const important = DshGlyphs.sealWarning;
  static const theme = DshGlyphs.palette;
  static const textSize = DshGlyphs.textAa;
  static const phoneLayout = DshGlyphs.deviceMobile;
  static const account = DshGlyphs.userCircle;
  static const profile = DshGlyphs.user;
  static const avatar = DshGlyphs.userFill;
  static const balance = DshGlyphs.wallet;
  static const shareConfig = DshGlyphs.export;
  static const chart = DshGlyphs.chartBar;

  /// 设置 › 宠物.
  static const pet = DshGlyphs.smiley;

  /// 设置 › 隐私与分享.
  static const privacy = DshGlyphs.lockKey;

  // ── Phone control ────────────────────────────────────────────────
  static const phoneControl = DshGlyphs.handTap;
  static const readScreen = DshGlyphs.scan;
  static const askFirst = DshGlyphs.handPalm;
  static const askPerTask = DshGlyphs.circleHalf;
  static const noConfirm = DshGlyphs.lightning;
  static const appRules = DshGlyphs.listChecks;
  static const dndMode = DshGlyphs.stack;
  static const keepAlive = DshGlyphs.batteryPlus;
  static const operate = DshGlyphs.handPointing;
  static const alarmClock = DshGlyphs.alarm;
  static const returnToApp = DshGlyphs.arrowBendUpLeft;
  static const backgroundPrompt = DshGlyphs.bell;
  static const overlayOpacity = DshGlyphs.slidersHorizontal;
  static const overlayBall = DshGlyphs.radioButton;

  /// 解除限制, its 「已解除限制」 tag, and its three rules.
  static const unlocks = DshGlyphs.lockSimpleOpen;
  static const unlockSystem = DshGlyphs.gearSix;
  static const unlockSecrets = DshGlyphs.key;
  static const unlockOwnApp = DshGlyphs.browser;

  /// 解除限制's confirmation page: what can go wrong, and the disclaimer.
  static const riskWarning = DshGlyphs.shieldWarning;

  // ── System permissions (the per-feature 「按功能开启」 screen at first launch, and 设置 › 系统权限)──────
  static const systemAccess = DshGlyphs.shieldCheck;
  static const fileAccess = DshGlyphs.folderUser;
  static const accessibility = DshGlyphs.scan;
  static const overlayPermission = DshGlyphs.stack;
  static const highPower = DshGlyphs.lightning;
  static const autostart = DshGlyphs.power;
  static const backgroundPopUp = DshGlyphs.boxArrowUp;

  // ── DS Bot and group chat ───────────────────────────────────────────
  static const bot = DshGlyphs.robot;
  static const groupChat = DshGlyphs.chats;
  static const newGroupChat = DshGlyphs.userPlus;
  static const addMember = DshGlyphs.userPlus;
  static const removeMember = DshGlyphs.userMinus;
  static const makeAdmin = DshGlyphs.crownSimple;
  static const team = DshGlyphs.usersThree;
  static const conversations = DshGlyphs.chats;
  static const chat = DshGlyphs.chatCircle;
  static const announcement = DshGlyphs.megaphone;
  static const nameTag = DshGlyphs.identificationBadge;
  static const botRole = DshGlyphs.briefcase;
  static const color = DshGlyphs.palette;
  static const today = DshGlyphs.calendarDot;
  static const lastWeek = DshGlyphs.calendarDots;
  static const lastMonth = DshGlyphs.calendar;
  static const fullLog = DshGlyphs.receipt;
  static const working = DshGlyphs.hammer;
  static const presetStandard = DshGlyphs.wrench;
  static const presetMinimal = DshGlyphs.square;
  static const presetCordis = DshGlyphs.magicWand;
  static const presetPtc = DshGlyphs.cards;

  // ── Forum and community ──────────────────────────────────────────────
  static const forum = DshGlyphs.chats;
  static const community = DshGlyphs.usersFour;
  static const newTopic = DshGlyphs.chatTeardropText;
  static const moved = DshGlyphs.folderArrowRight;
  static const invite = DshGlyphs.userPlus;
  static const reminder = DshGlyphs.alarm;
  static const reaction = DshGlyphs.smiley;
  static const badgeEarned = DshGlyphs.medal;
  static const poll = DshGlyphs.chartBar;
  static const playVideo = DshGlyphs.playCircle;
  static const mail = DshGlyphs.envelopeSimple;
  static const write = DshGlyphs.notePencil;
  static const featured = DshGlyphs.sparkle;
  static const bug = DshGlyphs.bug;
  static const school = DshGlyphs.graduationCap;
  static const travel = DshGlyphs.suitcase;
  static const calendar = DshGlyphs.calendarBlank;

  /// External channels of the community.
  static const wechat = DshGlyphs.chatCircleFill;
  static const qq = DshGlyphs.usersThreeFill;
  static const telegram = DshGlyphs.paperPlaneRight;
  static const discord = DshGlyphs.headset;
}
