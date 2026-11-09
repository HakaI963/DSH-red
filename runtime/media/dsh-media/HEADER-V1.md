# dsh-media generation-header v1

The authoritative spec is `docs/design/media-generation.md` §4.6; the authoritative shared samples are `app/test/media/fixtures/header_grammar_v1.json`, and the plugin's `src/header.js` aligns with them. This document only covers parameter headers in ordinary user messages and the grammar's consistency with the installed catalogue; tool results keep using the existing `dsh-go/media` v1.

## Entry point and three outcomes

Only the beginning of the first line of the current user message can become a generation instruction. The prefix is `〔生成图像` or `〔生成视频`, and the character immediately after the type word must be `〕`, `·`, JavaScript trim whitespace, or the end of the text. Anything else returns null and is treated as an ordinary message. For example, `〔生成图像的方法〕示例` is plain text; `〔生成图像·1:1〕` followed by a newline and a description is a recognized generation message with an illegal separator and returns a fixed error.

Leading spaces, a BOM or quote markers are not accepted as generation entry points. Web pages, files, tools, references and assistant content cannot authorize generation. The valid structure is:

```text
〔生成图像[ · 比例][ · N 张][ · 质量=值][ · 模型]〕
原样描述

〔生成视频[ · 比例][ · S 秒][ · 清晰度][ · 模型]〕
原样描述
```

In the above, square brackets mark optional parts and are not actual characters. Field order is fixed and each kind appears at most once; the separator must be ASCII space + middle dot + ASCII space. The first LF ends the header line, and a CR immediately before it still belongs to the header line; the description that follows is preserved character by character, with no trimming.

## Fields and identity

Aspect is two decimal positive integers of 1–99 joined by a colon without leading zeros; images allow 1–4 张; videos allow 1–60 whole 秒. Image quality is 1–32 ASCII letters/digits plus `_.-`, starting with a letter or digit; video resolution is `[1-9]\d{2,3}p`. These are only expressible grammar; the tools still validate against the actual catalogue, services and host limits.

A model is a verbatim label, optionally with `〈serviceId/modelId〉`. serviceId starts with a lowercase letter, continues with lowercase letters/digits/underscores, total length ≤32; modelId starts with an ASCII letter/digit, then allows letters/digits and `_.:/-`, total length ≤160. The label is at most 160 UTF-8 bytes, has no leading/trailing whitespace, contains no control characters or brackets/middle dots, does not start with "质量=", and cannot masquerade on its own as an aspect, a count, seconds or a resolution.

**The marker cannot mask the label's classification.** `1.5p`, `-3:4`, `1.5 张` and similar are still invalid model labels even when followed by `〈office/model〉`; the marked branch returns `invalid_model`. Unmarked segments keep following the spec's classification and error precedence; e.g. the unmarked formatter label `1.5p` in the shared golden still returns `invalid_quality`. The shared golden is owned by the App copy; the plugin never edits it separately.

Per the finalized spec, the App always emits the marker. Plugin selection must still match an enabled service with configured credentials against the model catalogue; it never guesses a same-named model or silently switches services. v1 has no audio field and no namespace; no serviceId was added to v1 result requests.

## Length, errors and the catalogue

The header line is at most 1024 UTF-8 bytes; the description is at most 4096 bytes with at least one non-whitespace character; lone UTF-16 surrogates in a generation message are rejected. Once recognized, checks run in spec order: newline/non-empty description, length and encoding, header structure, field classification, field order. Errors only give a fixed code and a Chinese message, and never echo the input.

`config.js` reuses the formatter's validation of model labels/IDs, ratios and qualities when loading the current static model catalogue. The standalone grammar helper can also validate video resolutions, but the current M0 catalogue and capabilities are images only, video=false; no installed video tooling is claimed from it. Each label is first validated in its unmarked form, then in its marked identity form, so the catalogue can never offer a model name that cannot be expressed consistently.

## Shared tests and scope

From inside the repository run `TZ=Asia/Shanghai node --test test/header.test.js` (working directory `runtime/media/dsh-media`). The test reads the App-owned shared JSON directly from the repository; when copying the plugin out for standalone verification, place the provided byte-identical reference file at the same repository-relative path — never fork a second golden.

The shared file has 119 cases: the plugin runs the valid/plain/invalid/format/formatRejects groups, 107 cases; the 12 `titles` cases belong to the App's title path. The valid group additionally runs parse→format→parse round trips, comparing canonical items byte for byte. Extra tests keep 384 legal-combination round trips and cover the reserved shapes of marked labels plus model names that legitimately contain similar fragments.

For how to run headless and where its evidence stops, see `test/headless/HEADLESS-RECOVERY.md`; overall verification status is in `VERIFICATION.md`. The two local scripted-model sessions only prove scheduling, tools, actual saving and the session log chain; they do not prove real-model compliance, cloud billing, App display, Android/PRoot or M1 completion.
