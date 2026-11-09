// What the activity pill says while a turn runs: copy pools, slot-based phrase
// rotation (adjacent windows never repeat), easter eggs keyed on time and on
// the last tool, and the model's `⏵` narration.

import '../../l10n/l10n.dart';
import 'run_info.dart';

// -----------------------------------------------------------------------------
// Rotation: one line per window, and the same window always shows the same line

/// How long one line stays up.
const phraseWindow = Duration(seconds: 4);

/// The first thinking pass of a turn has a 1/150 chance of swapping the whole stretch for a rare easter egg.
const rareOdds = 150;

/// How long the one-off reminder (long runs) shows.
const reminderWindow = Duration(seconds: 8);

int _imul(int a, int b) {
  a &= 0xFFFFFFFF;
  b &= 0xFFFFFFFF;
  final low = (a & 0xFFFF) * b;
  final high = ((a >>> 16) * b) & 0xFFFF;
  return (low + (high << 16)) & 0xFFFFFFFF;
}

/// Deterministic 32-bit mix of the seed and the window index (low 32 bits after avalanche mixing).
///
/// What we want is repeatability, not randomness: the same input always gives the same output, so however many
/// times per second the UI repaints, this window's line never changes.
int mixSlot(int seed, int slot) {
  var h = (_imul(seed, 0x9E3779B1) ^ _imul(slot, 0x85EBCA6B)) & 0xFFFFFFFF;
  h = _imul(h ^ (h >>> 15), 0x2545F491);
  h = _imul(h ^ (h >>> 13), 0x9E3779B1);
  return (h ^ (h >>> 16)) & 0xFFFFFFFF;
}

/// The line for window [slot]; the pool does not vary by window. See [_rotateAt].
String pickAt(List<String> pool, int seed, int slot) => _rotateAt(seed, slot, (_) => pool);

/// The line for window [slot]; [poolAt] gives the pool each window uses (late night, thinking
/// too long, and the pool changes).
///
/// Two adjacent windows never *display* the same line (compared by text; two keys translating
/// to the same line still counts as a clash), and this needs no replay from window 0: even windows
/// take their line straight by hash from their own pool; odd windows start from their hash and
/// skip the two lines the even windows on either side actually show. It still holds if a neighbor
/// switched pools, since each neighbor is computed from its own pool. With only two distinct lines in a pool they alternate; with one there is nothing left but to repeat.
String _rotateAt(int seed, int slot, List<String> Function(int slot) poolAt) {
  List<String> lines(int k) {
    final pool = poolAt(k).toSet().toList();
    assert(pool.isNotEmpty);
    return pool;
  }

  String plain(int k) {
    final pool = lines(k);
    if (pool.length <= 2) return pool[(mixSlot(seed, 0) + k) % pool.length];
    return pool[mixSlot(seed, k) % pool.length];
  }

  final pool = lines(slot);
  if (slot.isEven || pool.length <= 2) return plain(slot);
  final before = plain(slot - 1);
  final after = plain(slot + 1);
  final start = mixSlot(seed, slot) % pool.length;
  for (var i = 0; i < pool.length; i++) {
    final line = pool[(start + i) % pool.length];
    if (line != before && line != after) return line;
  }
  return pool[start]; // unreachable: three different lines leave one free
}

// -----------------------------------------------------------------------------
// Copy pools

/// The model is thinking (reasoning is streaming).
List<String> get thinkingPhrases => [
  appL10n.activityThinkingUntangle,
  appL10n.activityThinkingWorkThrough,
  appL10n.activityThinkingGears,
  appL10n.activityThinkingSecond,
  appL10n.activityThinkingSmoking, //
  appL10n.activityThinkingOnIt,
  appL10n.activityThinkingNoRush,
  appL10n.activityThinkingPonder,
  appL10n.activityThinkingLogic,
  appL10n.activityThinkingBrain,
  appL10n.activityThinkingSort,
  appL10n.activityThinkingMemory,
  appL10n.activityThinkingStorm,
  appL10n.activityThinkingSavor,
  appL10n.activityThinkingMoment,
  appL10n.activityThinkingHeadScratch,
  appL10n.activityThinkingPlayOut,
  appL10n.activityThinkingLoading,
  appL10n.activityThinkingMulling,
  appL10n.activityThinkingBreakDown,
  appL10n.activityThinkingTrain,
  appL10n.activityThinkingSomething,
  appL10n.activityThinkingJog,
  appL10n.activityThinkingPicture,
  appL10n.activityThinkingBubbles,
  appL10n.activityThinkingWaves,
  appL10n.activityThinkingCoffee,
  appL10n.activityThinkingDraft,
  appL10n.activityThinkingComing,
  appL10n.activityThinkingBubbling,
  appL10n.activityThinkingTackle,
  appL10n.activityThinkingSpark,
  appL10n.activityThinkingLogicFirst,
  appL10n.activityThinkingLocate,
  appL10n.activityThinkingInvestigate,
  'loading 99%',
  appL10n.activityThinkingGif,
  appL10n.activityThinkingLook,
  appL10n.activityThinkingInteresting,
  appL10n.activityThinkingHands,
];

/// Thinking too long: the pool changes by how long this thinking stretch has run (decided when a window starts).
List<(Duration, List<String>)> get thinkingTiers => <(Duration, List<String>)>[
  (
    const Duration(minutes: 5),
    [
      appL10n.activityThinkingFiveMinutes,
      appL10n.activityThinkingSerious,
      appL10n.activityThinkingTricky,
      appL10n.activityThinkingAscend,
      appL10n.activityThinkingAlmostPromise, //
      appL10n.activityThinkingLongWay,
      appL10n.activityThinkingWrapping,
      appL10n.activityThinkingSong,
      appL10n.activityThinkingBigMove,
      appL10n.activityThinkingSimple,
    ],
  ),
  (
    const Duration(minutes: 1),
    [
      appL10n.activityThinkingOneMinute,
      appL10n.activityThinkingChallenge,
      appL10n.activityThinkingDig,
      appL10n.activityThinkingNotSimple,
      appL10n.activityThinkingDeep, //
      appL10n.activityThinkingBurning,
      appL10n.activityThinkingNearlyClear,
      appL10n.activityThinkingTwisty,
      appL10n.activityThinkingWorkout,
      appL10n.activityThinkingStay,
    ],
  ),
  (
    const Duration(seconds: 30),
    [
      appL10n.activityThinkingCloser,
      appL10n.activityThinkingThirtySeconds,
      appL10n.activityThinkingSoon,
      appL10n.activityThinkingAnotherPass, //
      appL10n.activityThinkingTrack,
      appL10n.activityThinkingLead,
      appL10n.activityThinkingCircles,
      appL10n.activityThinkingAnyMoment,
      appL10n.activityThinkingStillLocate,
    ],
  ),
];

/// The request is out, not a single character back yet.
List<String> get waitingPhrases => [
  appL10n.activityWaitingCall,
  appL10n.activityWaitingOnWay,
  appL10n.activityWaitingSpeak,
  appL10n.activityWaitingWords,
  appL10n.activityWaitingAwake, //
  appL10n.activityWaitingStretch,
  appL10n.activityWaitingYawn,
  appL10n.activityWaitingComing,
  appL10n.activityWaitingText,
  appL10n.activityWaitingQueue,
  appL10n.activityWaitingBrew,
  appL10n.activityWaitingWater,
  appL10n.activityWaitingWarmup,
  appL10n.activityWaitingMeditate,
  appL10n.activityWaitingBlink,
  appL10n.activityWaitingMoment,
];

/// The reply body is streaming.
List<String> get writingPhrases => [
  appL10n.activityWritingWords,
  appL10n.activityWritingTyping,
  appL10n.activityWritingInspired,
  appL10n.activityWritingOnIt,
  appL10n.activityWritingCareful, //
  appL10n.activityWritingFlow,
  appL10n.activityWritingPlain,
  appL10n.activityWritingIdeas,
  appL10n.activityWritingKeys,
  appL10n.activityWritingAlmost,
  appL10n.activityWritingTell,
  appL10n.activityWritingFast,
  appL10n.activityWritingBreeze,
  appL10n.activityWritingFormat,
];

/// Mixed into the thinking pools from 00:00–06:00.
List<String> get nightPhrases => [
  appL10n.activityNightAscend,
  appL10n.activityNightHello,
  appL10n.activityNightOwl,
  appL10n.activityNightMoon,
  appL10n.activityNightSlow, //
  appL10n.activityNightChampion,
  appL10n.activityNightSleepy,
  appL10n.activityNightMidnight,
  appL10n.activityNightOpen,
  appL10n.activityNightStars,
  appL10n.activityNightDawn,
];

/// Weekends: the first line of the first thinking pass of a turn.
List<String> get weekendPhrases => [
  appL10n.activityWeekendChill,
  appL10n.activityWeekendHere,
  appL10n.activityWeekendCompany,
  appL10n.activityWeekendOnline,
  appL10n.activityWeekendSneak, //
  appL10n.activityWeekendWorking,
  appL10n.activityWeekendMode,
  appL10n.activityWeekendBugs,
  appL10n.activityWeekendSkin,
];

/// Holidays (keyed by `MM-DD`), likewise the first line of a turn's first thinking pass.
Map<String, List<String>> get holidayPhrases => <String, List<String>>{
  '01-01': [
    appL10n.activityNewYearCheers,
    appL10n.activityNewYearDay,
    appL10n.activityNewYearBugs,
    appL10n.activityNewYearFirstLine,
    appL10n.activityNewYearWork,
  ],
  '02-14': [
    appL10n.activityValentineCode,
    appL10n.activityValentineLove,
    appL10n.activityValentineDate,
    appL10n.activityValentineKeyboard,
  ],
  '03-14': [appL10n.activityPiDay, '3.1415926…', appL10n.activityPiCircle],
  '04-01': [
    appL10n.activityAprilFools,
    appL10n.activityAprilBug,
    appL10n.activityAprilErrors,
    appL10n.activityAprilKidding,
  ],
  '05-01': [appL10n.activityLaborWorking, appL10n.activityLaborPride, appL10n.activityLaborSpirit],
  '06-01': [appL10n.activityChildrenDay, appL10n.activityChildrenHeart, appL10n.activityChildrenCode],
  '10-24': [
    appL10n.activityProgrammerCheers,
    appL10n.activityProgrammerDay,
    appL10n.activityProgrammer1024,
    appL10n.activityProgrammerCode,
  ],
  '10-31': [appL10n.activityHalloween, appL10n.activityHalloweenTreat, appL10n.activityHalloweenCode],
  '12-24': [appL10n.activityChristmasEve, appL10n.activityChristmasEveThinking, appL10n.activityChristmasEveGift],
  '12-25': [
    appL10n.activityChristmas,
    appL10n.activityChristmasCompany,
    appL10n.activityChristmasEgg,
    appL10n.activityChristmasReindeer,
  ],
  '12-31': [
    appL10n.activityYearEndEve,
    appL10n.activityYearEndLast,
    appL10n.activityYearEndReady,
    appL10n.activityYearEndSeeYou,
  ],
};

/// The seven Spring Festival days (counting from lunar new year's day). Add a row each year; tests go red when the table expires.
const lunarNewYearDays = <String>[
  '2025-01-29', '2026-02-17', '2027-02-06', '2028-01-26', '2029-02-13', //
  '2030-02-03', '2031-01-23', '2032-02-11', '2033-01-31', '2034-02-19',
  '2035-02-08',
];

List<String> get _zodiac => [
  appL10n.activityZodiacRat,
  appL10n.activityZodiacOx,
  appL10n.activityZodiacTiger,
  appL10n.activityZodiacRabbit,
  appL10n.activityZodiacDragon,
  appL10n.activityZodiacSnake,
  appL10n.activityZodiacHorse,
  appL10n.activityZodiacGoat,
  appL10n.activityZodiacMonkey,
  appL10n.activityZodiacRooster,
  appL10n.activityZodiacDog,
  appL10n.activityZodiacPig,
];

List<String> lunarNewYearPhrases(int year) => [
  appL10n.activityLunarCheers,
  appL10n.activityLunarCode,
  appL10n.activityLunarEnvelope,
  appL10n.activityLunarSpring,
  appL10n.activityLunarGreeting, //
  appL10n.activityLunarCodeGreeting,
  appL10n.activityLunarZodiac(_zodiac[(year - 4) % 12]),
];

/// Rare easter eggs (once per turn, chosen by the seed).
List<String> get rarePhrases => [
  appL10n.activityRareSsr,
  appL10n.activityRareUr,
  appL10n.activityRareLegend,
  appL10n.activityRareOrange,
  appL10n.activityRareEgg,
  appL10n.activityRareChosen, //
  appL10n.activityRareHidden,
  appL10n.activityRareChat,
  appL10n.activityRareMax,
  appL10n.activityRareLucky,
  appL10n.activityRareCritical,
  appL10n.activityRareNextLevel,
];

/// After the previous tool call failed.
List<String> get failPhrases => [
  appL10n.activityFailCrash,
  appL10n.activityFailOops,
  appL10n.activityFailRun,
  appL10n.activityFailTrip,
  appL10n.activityFailWrong,
  appL10n.activityFailHiccup,
  appL10n.activityFailBroken, //
  appL10n.activityFailLocal,
  appL10n.activityFailYesterday,
  appL10n.activityFailTough,
  appL10n.activityFailCrack,
  appL10n.activityFailPressure,
  appL10n.activityFailCareless,
  appL10n.activityFailSlip,
  appL10n.activityFailTryAgain,
  appL10n.activityFailChance,
];

/// After a test command ran / did not run.
List<String> get testPassPhrases => [
  appL10n.activityTestGreen,
  appL10n.activityTestAllGreen,
  appL10n.activityTestFirstTry,
  appL10n.activityTestNoErrors,
  appL10n.activityTestPassed,
  appL10n.activityTestSolid,
];
List<String> get testFailPhrases => [
  appL10n.activityTestRed,
  appL10n.activityTestInvestigate,
  appL10n.activityTestStubborn,
  appL10n.activityTestFix,
];

/// After a git commit / push.
List<String> get gitCommitPhrases => [
  appL10n.activityGitCommitSave,
  appL10n.activityGitSaved,
  appL10n.activityGitCommitRelief,
];
List<String> get gitPushPhrases => [appL10n.activityGitPushed, appL10n.activityGitPushDone, appL10n.activityGitCodeOut];

/// After dependencies finished installing.
List<String> get installPhrases => [
  appL10n.activityInstallDone,
  appL10n.activityInstallInternet,
  appL10n.activityInstallPackages,
];

/// After the Nth tool call of a turn.
Map<int, String> get toolMilestones => <int, String>{
  5: appL10n.activityMilestoneFive,
  10: appL10n.activityMilestoneTen,
  20: appL10n.activityMilestoneTwenty,
  50: appL10n.activityMilestoneFifty,
};

/// The service asked us to retry (rate limit / transient error).
List<String> get retryPhrases => [appL10n.activityRetryWait, appL10n.activityRetryBackoff, appL10n.activityRetryKnock];
List<String> get rateLimitPhrases => [appL10n.activityRateLimited, appL10n.activityRate429, appL10n.activityRateQueue];

/// Compressing the context.
List<String> get compactionPhrases => [
  appL10n.activityCompactContext,
  appL10n.activityCompactBag,
  appL10n.activityCompactSpace,
  appL10n.activityCompactMemory,
  appL10n.activityCompactChats,
];

// -----------------------------------------------------------------------------
// Dates & tools

bool isNight(DateTime local) => local.hour < 6;

bool isWeekend(DateTime local) => local.weekday == DateTime.saturday || local.weekday == DateTime.sunday;

String _two(int n) => n.toString().padLeft(2, '0');

/// Today's holiday copy pool; Spring Festival takes priority, null when there is none.
List<String>? holidayPool(DateTime local) {
  final day = DateTime(local.year, local.month, local.day);
  for (final first in lunarNewYearDays) {
    final start = DateTime.parse(first);
    final offset = day.difference(start).inDays;
    if (offset >= 0 && offset < 7) return lunarNewYearPhrases(start.year);
  }
  return holidayPhrases['${_two(local.month)}-${_two(local.day)}'];
}

final _testCommand = RegExp(
  r'\b(flutter test|dart test|npm (run )?test|pnpm (run )?test|yarn test|'
  r'pytest|go test|cargo test|jest|vitest|gradlew? test|mvn test)\b',
);
final _gitPush = RegExp(r'\bgit\s+push\b');
final _gitCommit = RegExp(r'\bgit\s+commit\b');
final _install = RegExp(
  r'\b(npm (i|install|ci)|pnpm (i|install|add)|yarn (install|add)|'
  r'pip3? install|flutter pub get|dart pub get|cargo fetch|apt(-get)? install)\b',
);

/// Whether the tool that just finished deserves a line; null if it doesn't.
List<String>? afterToolPool(AfterTool tool) {
  final command = tool.command;
  final isTest = command != null && _testCommand.hasMatch(command);
  if (tool.failed) return isTest ? testFailPhrases : failPhrases;
  if (command == null) return null;
  if (isTest) return testPassPhrases;
  if (_gitPush.hasMatch(command)) return gitPushPhrases;
  if (_gitCommit.hasMatch(command)) return gitCommitPhrases;
  if (_install.hasMatch(command)) return installPhrases;
  return null;
}

/// Reminders for a turn that has run long: at 10 minutes, half an hour, then every full hour, each shown for
/// [reminderWindow]; null outside those windows.
String? longTurnReminder(Duration elapsed) {
  String? within(Duration mark, String text) {
    final past = elapsed - mark;
    return !past.isNegative && past < reminderWindow ? text : null;
  }

  final hours = elapsed.inHours;
  if (hours >= 1) {
    return within(Duration(hours: hours), appL10n.activityReminderHours(hours));
  }
  return within(const Duration(minutes: 30), appL10n.activityReminderWater) ??
      within(const Duration(minutes: 10), appL10n.activityReminderTenMinutes);
}

// -----------------------------------------------------------------------------
// Model self-narration (`⏵` lines)

const _narrationMaxColumns = 80;

bool _wide(int rune) =>
    (rune >= 0x1100 && rune <= 0x115F) ||
    (rune >= 0x2E80 && rune <= 0xA4CF) ||
    (rune >= 0xAC00 && rune <= 0xD7A3) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0xFE30 && rune <= 0xFE4F) ||
    (rune >= 0xFF00 && rune <= 0xFF60) ||
    (rune >= 0xFFE0 && rune <= 0xFFE6) ||
    (rune >= 0x1F000 && rune <= 0x1FAFF) ||
    (rune >= 0x20000 && rune <= 0x3FFFD);

/// The latest `⏵ what it's doing` line the model wrote in the body; null when there is none.
///
/// `⏵` must start the line (an `⏵` mid-sentence is the model *mentioning* the format, not
/// using it); take only up to the first sentence-ending punctuation, cut to 80 display columns (~40 CJK glyphs), strip control characters.
String? extractNarration(String text) {
  final matches = RegExp(r'(?:^|\n)⏵[ \t]*([^\n⏵]*)').allMatches(text);
  if (matches.isEmpty) return null;
  var line = matches.last.group(1)!.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  if (line.isEmpty) return null;
  // l10n:keep narration punctuation parser
  final end = RegExp(r'[。．!?！？;；]|\.(?=\s|$|[A-Z][a-z])').firstMatch(line);
  if (end != null) line = line.substring(0, end.end);

  var width = 0;
  var cut = line.length;
  var offset = 0;
  for (final rune in line.runes) {
    final w = _wide(rune) ? 2 : 1;
    if (width + w > _narrationMaxColumns) {
      cut = offset;
      break;
    }
    width += w;
    offset += rune > 0xFFFF ? 2 : 1;
  }
  if (cut < line.length) {
    final head = line.substring(0, cut);
    final soft = [
      ' ',
      '，', // l10n:keep narration punctuation boundary
      '、', // l10n:keep narration punctuation boundary
      ',',
      ';',
      '；', // l10n:keep narration punctuation boundary
    ].map(head.lastIndexOf).fold(-1, (a, b) => a > b ? a : b);
    line = soft > 0 ? head.substring(0, soft) : head;
  }
  // l10n:keep narration punctuation parser
  line = line.replaceFirst(RegExp(r'[。．.!！,，、;；]+$'), '').trim();
  return line.isEmpty ? null : line;
}

// -----------------------------------------------------------------------------
// The line on the pill at this moment

enum FlavorSource {
  /// Model self-narration (`⏵`).
  narration,

  /// Easter eggs: holidays, weekends, rare ones, tool context, long-run reminders.
  egg,

  /// Ordinary rotating copy.
  phrase,
}

/// The line after the activity bar's title.
typedef ActivityFlavor = ({String text, FlavorSource source});

/// [now] is the device's local time (holidays, weekends, late night are computed from it, and at the
/// moment each window starts: one line never changes within its own window); elapsed time follows the Host clock
/// (`now - activity.skew`). Only model phases, retries and compaction carry this line; tools,
/// waiting-for-your-confirmation and waiting-for-your-answer have their own targets and get no extra copy.
///
/// The rotated line never repeats what the adjacent window actually showed ([_rotateAt]); the same input
/// always gives the same output. Dedup ignores time zones (seed and windows come from timestamps and elapsed time); holidays,
/// weekends and late night still use local time.
ActivityFlavor? activityFlavor(RunActivity a, DateTime now) {
  final hostNow = now.subtract(a.skew);
  final phaseStart = a.since ?? a.turnStart;
  final elapsed = phaseStart == null ? Duration.zero : _nonNegative(hostNow.difference(phaseStart));
  final slot = elapsed.inMilliseconds ~/ phraseWindow.inMilliseconds;
  final seed = (phaseStart?.millisecondsSinceEpoch ?? 0) ^ (a.turnStart?.millisecondsSinceEpoch ?? 0);

  /// Device-local time when window [k] began.
  DateTime windowStart(int k) => now.subtract(elapsed - phraseWindow * k);

  ActivityFlavor phrase(List<String> pool) => (text: pickAt(pool, seed, slot), source: FlavorSource.phrase);

  switch (a.kind) {
    case ActivityKind.stopping || ActivityKind.tool || ActivityKind.approval || ActivityKind.question:
      return null;
    case ActivityKind.compaction:
      return phrase(compactionPhrases);
    case ActivityKind.retry:
      return phrase(a.rateLimited ? rateLimitPhrases : retryPhrases);
    case ActivityKind.waiting || ActivityKind.thinking || ActivityKind.writing:
      break;
  }

  final narration = a.narration;
  if (narration != null) {
    return (text: narration, source: FlavorSource.narration);
  }

  // What window k draws from. The first window may open with an egg; a rare
  // turn rotates through the rare lines; otherwise the phase's own copy, and
  // for thinking the longer-thinking tiers, both judged at the window's start
  // so crossing 30 s or 06:00 halfway through a window doesn't swap the line
  // under the reader. The neighbours' pools are what [_rotateAt] compares with.
  (List<String>, FlavorSource) poolAt(int k) {
    if (k == 0) {
      final after = a.after;
      final afterPool = after == null ? null : afterToolPool(after);
      if (afterPool != null) return (afterPool, FlavorSource.egg);
      final milestone = toolMilestones[a.toolsDone];
      if (after != null && milestone != null) return ([milestone], FlavorSource.egg);
      if (a.firstStep) {
        final local = windowStart(0);
        final holiday = holidayPool(local);
        if (holiday != null) return (holiday, FlavorSource.egg);
        if (rareTurn(a.turnStart)) return (rarePhrases, FlavorSource.egg);
        if (isWeekend(local)) return (weekendPhrases, FlavorSource.egg);
      }
    }
    if (a.firstStep && rareTurn(a.turnStart)) return (rarePhrases, FlavorSource.egg);
    switch (a.kind) {
      case ActivityKind.waiting:
        return (waitingPhrases, FlavorSource.phrase);
      case ActivityKind.writing:
        return (writingPhrases, FlavorSource.phrase);
      default:
        for (final (at, pool) in thinkingTiers) {
          if (phraseWindow * k >= at) return (pool, FlavorSource.phrase);
        }
        final night = isNight(windowStart(k));
        return (night ? [...thinkingPhrases, ...nightPhrases] : thinkingPhrases, FlavorSource.phrase);
    }
  }

  final (_, source) = poolAt(slot);
  // A first-window egg outranks the long-turn reminder; the reminder outranks
  // the rest.
  final turnStart = a.turnStart;
  if (turnStart != null && !(slot == 0 && source == FlavorSource.egg)) {
    final reminder = longTurnReminder(_nonNegative(hostNow.difference(turnStart)));
    if (reminder != null) return (text: reminder, source: FlavorSource.egg);
  }
  return (text: _rotateAt(seed, slot, (k) => poolAt(k).$1), source: source);
}

Duration _nonNegative(Duration d) => d.isNegative ? Duration.zero : d;

/// Whether this turn drew the rare easter egg (from the seed, no dice roll: every read gives the same answer).
bool rareTurn(DateTime? turnStart) =>
    turnStart != null && mixSlot(turnStart.millisecondsSinceEpoch, 0x5EED) % rareOdds == 0;
