# Contributing a Language Pack

Help translate QManager into your language. No coding required — just edit JSON files.

## TL;DR

1. Fork the repo, make a branch.
2. Copy `public/locales/en/` to `public/locales/<your-code>/`.
3. Translate the **values** in each JSON file (never the keys).
4. Register the language in `lib/i18n/available-languages.ts`.
5. Run `bun run i18n:check`.
6. Open a pull request **against the `development-home` branch** (not `main`).

## 1. Set up

Use a standard [BCP-47 code](https://r12a.github.io/app-subtags/) for the folder name:

| Language | Code |
| -------- | ---- |
| German | `de` |
| Spanish | `es` |
| French | `fr` |
| Japanese | `ja` |
| Arabic | `ar` |
| Traditional Chinese | `zh-TW` |

```bash
cp -r public/locales/en public/locales/de
```

## 2. Translate

Open each JSON file in your new folder and translate the right side of every `":"`.

```json
{
  "save": "Save",            ← key: don't touch
  "cancel": "Cancel"         ← value: translate this
}
```

**Rules:**

- **Keep keys unchanged.** Only edit values.
- **Keep `{{placeholders}}` intact.** Move them where they fit grammatically — `"Connected to {{apn}}"` can become `"{{apn}} に接続しました"`.
- **Keep plural siblings** (`_one` / `_other`). Languages with more forms may add `_zero`, `_two`, `_few`, `_many` — see the [i18next plural table](https://www.i18next.com/translation-function/plurals).
- **Don't translate technical terms**: `AT+CSQ`, `dBm`, `APN`, `IMEI`, `LTE`, `N78`, `Tailscale`, `OpenWRT`, IP addresses, log levels (`DEBUG`, `INFO`).
- **ARIA keys** (ending in `_aria`) describe actions for screen readers. Be descriptive.
- **Partial translations are fine** — missing keys fall back to English.

## 3. Register the language

Add an entry to `lib/i18n/available-languages.ts`:

```ts
{
  code: "de",
  native_name: "Deutsch",
  english_name: "German",
  rtl: false,      // true for Arabic, Hebrew, Persian
  bundled: false,  // true only if shipping with the app binary
}
```

Most community packs should leave `bundled: false` — they load dynamically from the manifest and don't bloat the firmware.

## 4. Verify

```bash
bun run i18n:check
```

Errors (extra or malformed keys) must be fixed. Missing-key warnings are OK while drafting.

## 5. Submit

Open a pull request to the `development-home` branch. CI runs `bun run i18n:check` and `bun tsc --noEmit`. Title your PR `i18n(<code>): add <language>` — for example, `i18n(de): add German`.

## Improving an existing translation

Just edit the JSON values directly and open a PR against `development-home` — no other steps needed.

## Style

- **Tone**: friendly, clear, low-jargon.
- **Capitalization**: follow your language's norms, not English title-case.
- **Punctuation**: use native marks (`。`, `«…»`, French non-breaking space before `:`).

## Help

Open a GitHub issue with the `i18n` label or start a discussion. Partial work is welcome.
