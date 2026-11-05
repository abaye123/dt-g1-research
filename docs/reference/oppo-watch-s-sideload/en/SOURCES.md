> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# Provenance and Attribution of External Resources (SOURCES)

> **Principle**: only write fields that can be checked on the spot. If it cannot be found, write "not stated"; **never fill in a name on someone's behalf**.
> Every entry carries a verification date; if it disagrees with upstream, upstream wins, and issues pointing this out are welcome.

---

## 1. Guiyuan Assistant (Glyphix Assistant)

| Item | Value | How to verify |
|---|---|---|
| Package name | `com.glyphix.assistant` | release page / APK |
| **Original release page** | https://www.pgyer.com/glyphix-assistant | open directly |
| Latest upstream version | **v1.3 (build 3, 2026-10-08)**, release note "supports OHealth" | release page |
| Mirrored in this repo | **v1.2 (build 2, 2026-08-21)** | release page version history |
| Author / developer | **Not stated on the release page; this repo does not fill it in** | neither the web page nor the Pgyer API has this field |
| Lineage | Per the tutorial text: since 2.5.0, `glyphixdebug` split "bridge mode" out into Guiyuan Assistant | Mitan (bandbbs) thread 29508 |
| GitHub | No related repo or source | searches for "瑰元助手", "com.glyphix.assistant", "glyphix assistant" on 2026-10-21 all returned nothing |

**How this release page was determined** (reproducible, not just searched):

```bash
# 1) Extract the app's built-in update check URL from the mirrored APK
unzip -p glyphix-assistant-v1.2.apk classes.dex | strings \
  | grep -o 'pgyer.com/apiv2/app/check[^"]*'
# 2) Query the Pgyer app info with the same appKey
curl 'https://www.pgyer.com/apiv2/app/view?_api_key=<api_key from step 1>&appKey=<appKey from step 1>'
```

In the JSON returned by step 2: `buildName` = 瑰元助手, `buildIdentifier` = com.glyphix.assistant,
`buildShortcutUrl` = glyphix-assistant -> the distribution page address above; `buildVersion` / `buildCreated` match the version and date in the table.

> The `api_key` is a read-only key built into the app; this repo does not repost it, to avoid abuse.

---

## 2. Mitan tutorial: `[教程]OPPO WatchS 如何侧载应用` ([Tutorial] How to sideload apps on OPPO Watch S)

- Link: https://www.bandbbs.cn/threads/29508/
- Author: **libiao0418** (Mitan UID 3485823, visible on the thread page)
- **Only the tutorial author**, not the author of Guiyuan Assistant, merely a user of the tool - clarified by the author himself in issue #1
- On 2026-10-10 the thread added a cloud drive link for the tools used in the tutorial (password in the original thread); attachments such as the Purrlaunch rpk are to be obtained as the original thread instructs

---

## 3. PurrLaunch

- Upstream: https://github.com/purrrock/PurrLaunch (MIT, v1.2.2)
- Author: **purrrock** (shown on GitHub as PurrRock CatsBand)
- Relationship to this repo: `apps/purrlaunch-ows/` is the minimal delta that makes it install on the OWW262; not original work
- There is **no** attribution relationship with the tutorial author in item 2 above

---

## 4. Official Glyphix documentation

- https://github.com/glyphix-os/web-docs
- Use: the authoritative source for page syntax, the component list, and the `@system.*` API

---

## 5. glyphix-cli (build toolchain)

- npm package: `glyphix-cli`, the registry shows latest = **0.8.0-rc** (updated 2026-03-24)
- The installed `gx` version is **v0.11.0** (the two numbers are not the same thing; README and DEV_GUIDE are worded accordingly)

---

## 6. Wrong attribution that once appeared (kept on record to avoid repeating it)

- The "tutorial author" was once written as the "Guiyuan Assistant author", and on top of that a **baseless** third-party platform account was attached
  (nothing in GitHub, the Mitan thread, or the Purrlaunch repo links to it; the account name is not repeated here, to avoid spreading it a second time).
- All of it was deleted on 2026-10-21 per issue #1. Apart from "tutorial author libiao0418", the repo now contains no personal attribution.

---

**Maintenance rule**: for any new third-party tool/resource, first register its provenance and verification date in this table, then write it into the body text;
if no provenance can be found, write only the link + "not stated", and do not write a name.
