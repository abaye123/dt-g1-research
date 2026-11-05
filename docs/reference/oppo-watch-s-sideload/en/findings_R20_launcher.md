> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# findings_R20 - Building Purrlaunch-lite ourselves: a launcher that occupies the Wooden Fish slot (2026-10-11 10:41-10:47)

## Background
The user asked to change the desktop icon. The thread's original solution = install Purrlaunch (the rpk exists only as the Mitan attachment 10856.webp, and the account permissions cannot get it).
No mirror anywhere online (GitHub/Gitee/Coolapk/cloud drives) -> **build an equivalent ourselves**: the essence of Purrlaunch = occupy com.xfaith.woodenfish
(a store app slot that the desktop renders correctly) + provide a third-party app list/launcher.

## Implementation (source in G:/oppo/purrlaunch-lite/)
- Package name **com.xfaith.woodenfish**, versionCode **8** (> the store Wooden Fish's 7), name=启动器 (Launcher), icon=/assets/icon.png
- Page: `@system.package.list('app')` lists all apps -> `pkg.getInfo(pkg)` gets the name -> `@system.launch.launch(pkg)` launches on tap
- Excludes itself; system packages (prefixes com.heytap/oplus/coloros/android) sorted last; a scroll component for the scrolling list
- Build: gx build -d oppo-rtos-watch -f -> bundle.pkg 3200B

## Installation and verification
```
10:41:19.653  安装应用 成功 (total_size:3200)    ← the debug channel directly "upgrade-overwrites" the store Wooden Fish, no signature/version block
10:42:09.083  lvgl: exit application com.xfaith.woodenfish success   ← the old Wooden Fish was exited
10:42:39.166  app.life: call onDestroy in pkg://com.xfaith.woodenfish
10:47:11.509  app.life: call onShow in pkg://com.xfaith.woodenfish          ← the new launcher is running
10:47:11.514  app.life: call onInit / onReady in .../main/index.uo          ← full page lifecycle
10:47:11.612  gx_on_screen_on → eventLoop refresh 1-5(rendering done, no errors)
```

## Conclusions
- **Upgrade-overwriting a store app works fully** (the debug channel does no signature check; versionCode just needs to be higher than the installed version)
- From now on every newly installed third-party app will appear in the launcher list (list('app') enumerates dynamically)
- To get Wooden Fish back: reinstall it from the watch app store (that in turn overwrites the launcher, it is one or the other)
- Awaiting user confirmation: whether the desktop slot's name/icon now shows "启动器" (Launcher) (a restart may be needed to refresh)
