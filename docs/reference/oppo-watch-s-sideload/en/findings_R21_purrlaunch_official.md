> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# findings_R21 - Official PurrLaunch (built from GitHub source) installed on the watch successfully (2026-10-11 11:24-11:29)

## Origin
- Located after a hint from the user: github.com/purrrock/PurrLaunch (MIT, "Launcher PKG for smartwatchs")
- release v1.2.2 has a prebuilt com.xfaith.woodenfish.pkg, but downloads from github.com are blocked
- -> pulled the full source tree (17 files) through api.github.com, built locally with gx, with two OWS adaptations:
  1. Added `icon: /assets/icon.png` to the manifest (cat paw image, OWS mandatory validation)
  2. versionCode 1 -> **9** (to overwrite the purrlaunch-lite v8 that we installed ourselves earlier in this window)

## Features (as stated by the author in UNDER-THE-HOOD.md, reverse engineered on the DT NO.1 G1)
- **The desktop menu is hardcoded, the OS does not dynamically scan the package directory** -> the only way for a third-party app onto the desktop = take over a hardcoded slot (Wooden Fish)
- Tapping the slot -> AppletKit (C++) looks up the ADBT_Applet library -> hands control to the JS app with that package name
- Built in: app list (pkg.list+getInfo, excluding itself/emulators), **USB direct pkg install** (VFS staging with an 800ms I/O barrier ->
  pkg.install({src,force:true,verify:false}), bypassing the sandbox), file manager, uninstall page, system info, text viewer
- Install signature: `{src:"internal://files/app.pkg", force:true, verify:false}` (the vendor JSI only recognizes the src key;
  passing a string to pkg.remove crashes silently - an ATS3085S JSI exception, OWS may differ but it is worth referencing)

## Verification
```
11:28:01.594  安装应用 成功 (36512B, upgrade-overwriting lite v8)
11:29:29.092  启动应用 成功
```
- Source (OWS-adapted version): G:/oppo/PurrLaunch/ (includes the cat paw icon assets)
- Also found that the user had installed com.rtos.libraryqr on their own (7104B, installed 11:18, launched 11:21) - the pipeline has already been reused ✓

## Final conclusion on the icon problem
- The desktop slot icon = an OS-side resource (hardcoded menu + a separate `icon_<pkg>` registration when the store installs)
- Sideloaded packages (whether through the debug channel or with an icon inside the package) always fall back to the gear on the desktop - **no package-side fix**, an OWS desktop defect
- Usability is unaffected: the launcher list shows names and package names, and tapping launches the app
- To fix it at the root in future: the probe already has the ability to push `icon_<pkg>` files (ftprobe18 R20b modification, not verified this time -
  the probe launch was blocked by Android 14 "did not call finish", and needs to be run with the phone unlocked), or wait for Guiyuan Assistant v1.3

---

## Addendum: `icon_<package name>` push experiment (R21b, 2026-10-11 11:55) - awaiting acceptance after restart

**Hypothesis**: the OWS desktop icon is data-driven (Wooden Fish had an icon after store install -> became a gear after our debug overwrite = registration lost),
and the store's icon registration convention = the `icon_<package name>` file delivered separately over the sid=272 file channel (FileInfo=appstore_uri_icon).

**Experiment** (ftprobe18 R20b modification, with a 432px icon PNG built into assets):
```
handleAuthentication -> 1001 (needs the authentication_state=1 bypass; set back to 0 after the run)
peerFound=true liveAccId=9486
cid=10 precheck → pkg push ×3 candidates (transId 2102272838/1876337960/288563888, all handleTransferComplete)
icon push: transId 291786294, FT_SETUP_REQ fileName:icon_com.rtos.qrwatch,
           Total 843 Read 843 ✓ → handleTransferComplete: Completed :icon_com.rtos.qrwatch ✓
           md5:49d7136194c8c411f003343a5e88a8b7
```
**On the wire this replicates the store sequence 1:1 (pkg→icon, same channel, same convention), with zero errors.**

**Acceptance**: restart the watch -> check whether the desktop "启动器" (Launcher) slot icon turns into a QR code pattern.
- If it changes -> icon problem solved (the `icon_<package name>` push = the icon registration method, can be written into DEV_GUIDE)
- If it is still a gear -> the OWS desktop (nucleus 0.7.0-68) icon source is not this convention (not isomorphic with the G1),
  there is no more package-side leverage, and the remaining paths are only: Guiyuan Assistant v1.3 / accept the gear

**Engineering notes**: the probe must have authentication_state=1 to pass framework authentication (1001), remember to set it back to 0 after each run;
if the probe Activity is started while the phone is locked / screen off, Android 14 force-kills it ("did not call finish"), so run it with the screen on and unlocked.

---

## ✅ R21b acceptance result (2026-10-11 12:2x): **the icon registration method works**
The user visually confirmed: after restarting the watch, the desktop "扫码卡片" (QR Card) (com.rtos.qrwatch) icon has changed into a QR code pattern.
The `icon_<package name>` push method is officially promoted to the standard SOP (DEV_GUIDE.md 5.3).

## R21c dual-icon batch registration (12:19)
```
12:19:11  FT_SETUP_REQ fileName:icon_com.rtos.qrwatch      (843B)  → handleTransferComplete ✅
12:19:23  FT_SETUP_REQ fileName:icon_com.xfaith.woodenfish (1364B) → handleTransferComplete ✅
```
- ftprobe18 was changed to loop over a multi-icon icons[][] array (fireIconPush(acc, peer, assetName, wireName))
- Awaiting the user's restart to confirm the launcher slot icon (cat paw)
- After the run authentication_state was set back to 0 ✓
