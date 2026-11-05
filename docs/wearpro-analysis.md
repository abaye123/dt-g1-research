# WearPro (com.dtno1.WearPro) reverse-engineering notes

Interoperability research for the DT G1 smartwatch (Actions ATS3085S, Glyphix OS).
Source: static analysis of `base.apk` (6x classes.dex, assets, resources.arsc) and
`split_config.iw.apk`. No device or network was contacted. All findings are from
string literals, class/method names, resource XML and asset files only.

The APK is a multi-device companion app: it drives many different watch chip
families through several bundled vendor SDKs. Only part of it is relevant to the
DT G1. Where a feature is handled by a non-DT-G1 SDK it is still documented, because
the server protocol and the UI flow are shared, and because the DT G1 path reuses
the same abstractions.

Confidence tags: facts are tagged UNKNOWN where the APK does not settle them.
Byte-level framing, opcodes and CRC live in native code / compiled bytecode and are
not recoverable from strings; those are marked UNKNOWN.

---

## 1. Transport (BLE + USB)

### Bundled BLE / connectivity stacks (evidence: class prefixes)
- `no.nordicsemi.android.ble.BleManager` and `no.nordicsemi.android.dfu.*` - the
  Nordic Android BLE host library (the real GATT client), plus Nordic DFU.
- `com.crrepa.ble.*` - the CRRepa / MoYoung multi-vendor smartwatch SDK (1399 string
  hits). This is the "GloryFit / DT No.1" family SDK. Also pulls in per-chip OTA and
  transfer sub-packages: `nrf` (Nordic), `ota/realtek`, `sifli/dfu`, `ota/hs` +
  `spp/hisilicon` (HiSilicon), JieLi beans, Bluetrum beans.
- `com.glyphix.mas.*` - Glyphix "MAS" (Micro App Service). Native libs
  `libglyphix-mas-android.so` (6.1 MB) and `libmasExtraFeature.so`. This is the
  Glyphix OS transport and is the layer the DT G1 (Glyphix OS) uses.
- `com.actions.ibluz` - Actions "iBluz" BLE/SPP SDK (`BluzDeviceSpp`,
  `com.actions.ibluz.data.disconnect`, `CHANNEL_TYPE_SPP`). Actions is the ATS3085S
  vendor, so this is also DT-G1-relevant.
- `com.sifli.serialtransport`, `com.sifli.watchfacelibrary`, `com.sifli.ezipmy` -
  SiFli chip support.

### DT G1 path: Glyphix MAS
Evidence: `com.glyphix.mas.GxMas`, `GxMas$MasCallback`, `GxMas$WriteCallback`,
`GxMas$RpcNativeCallnack`, API facade classes `GxApp`, `GxFile`, `GxMessage`
(`GxMessage$MessageResolver`), `GxSys`, `GxTime`, `GxSpeed`, `GxInterConnect`
(`GxInterConnection`), and `com.glyphix.mas.service.version.InterConnectManager`.
- The link carries **gRPC**: strings `grpc-java-okhttp/1.60.0-SNAPSHOT`,
  `io.grpc.okhttp.OkHttpFrameLogger`, `io.grpc.internal.*`. So MAS is a gRPC/protobuf
  RPC channel tunnelled over the BLE/SPP connection, with framing done in
  `libglyphix-mas-android.so`.
- Chunking is MTU-based: `spp mtu:`, `updateMtu`, `EXTRA_MTU`, `mtu=0x%04X`,
  `>> onMtuChanged(%s) mtu=%d`, `status=..,maxBufferSize=0x%04X, bufferCheckMtuSize=0x%04X`.
- File transfer to the watch is `GxFile` writing into `gxfileDir` (`writeFile`).
- **GATT service/characteristic UUIDs for the Glyphix MAS channel: UNKNOWN.** The
  APK contains many 128-bit UUIDs (see below) but none is unambiguously tied to the
  Glyphix channel from strings alone; the dex string pool is sorted alphabetically,
  so adjacency gives no grouping. Recovering them needs a BLE sniff or native-code
  analysis of `libglyphix-mas-android.so`.

### CRRepa / MoYoung GATT profile (the other watch families)
16-bit shorthand present: `fee1 fee2 fee3 fee5 fee6 fee7 fee8` and `FEEA`, plus the
full `0000fee7-0000-1000-8000-00805f9b34fb`. This matches the documented MoYoung
profile (service `0xFEEA`; `0xFEE2` write / `0xFEE3` notify for commands;
`0xFEE5`/`0xFEE6` big-data IN/OUT for watch-face and file transfer). Treat the exact
assignment as **likely, not proven from this APK**. Framing is a length+opcode
framed packet handled in SDK bytecode; **header/length/opcode/CRC bytes: UNKNOWN**.
Other custom 128-bit UUIDs seen (used by the various vendor stacks, not necessarily
DT G1): `6e40ff02/6e40ff03-b5a3-f393-e0a9-e50e24dcca9e` (Nordic-UART-like),
`e49a25e0/25f8/28e1/3001-3003-f69a-11e8-...`, `75728ae0/ae1-...`,
`26078ae0/ae1-...`, `506ef921-924-...`, `C3E6C1A0-A2 / C3E6FEA0-A2-E966-...`,
`a6ed0402/0403-...`, `...-6473_5f696c666973` (ASCII "sifli_sd", SiFli OTA).

### USB
- The app does use USB: `android.hardware.usb.UsbManager` (`usbDevice`,
  "Unable to initialize mUsbManager", `mUsbGatt is null ...`), and Nordic DFU has
  USB-endpoint support (`getUsbEndPointInAddr/OutAddr`).
- AT-style serial command literals exist for one SPP watch family:
  `XBT A D 0 15 X1,PSET,TFMT,`, `X1,PSET,XFindDevice,1`,
  "the mltcodeTXRXCharacteristic is not connected". These are comma-delimited
  AT-like commands over an SPP/BLE characteristic.
- **Relationship to the watch's `AT+WRX` USB-serial channel: UNKNOWN / probably not
  used by this app.** No `AT+WRX` literal appears in the dex. The `AT+WRX` CDC channel
  documented for the DT G1 appears to be the watch's own USB protocol (for a PC tool),
  not something WearPro speaks. WearPro is BLE-first; its USB usage is for
  UsbManager/DFU and for the flashing agents below.
- `assets/Download_Agent/6260` and `6261` contain MTK-style flash download agents
  (`EPP`, `EXT_RAM`, `INT_SYSRAM`, `NAND_FLASH_TABLE`, `NOR_FLASH_TABLE`). These are
  for flashing an auxiliary chip on some watch variant, not the DT G1 BLE path.

Feasibility (Rust desktop): Re-implementing the **Glyphix MAS gRPC-over-BLE** channel
is the critical unknown. You can reach the DT G1 two ways: (a) over the documented
`AT+WRX` USB-serial channel in Charging mode (independent of this app, best starting
point for a desktop tool), or (b) over BLE by replaying the MAS gRPC frames, which
first requires sniffing the GATT UUIDs and the protobuf schema. Rust has good BLE
(`btleplug`) and serial (`serialport`) crates. Recommend starting on USB `AT+WRX`.

---

## 2. Watch-face / dial backgrounds

The server base is `https://dt1pro.wanruxia.com/xky-api/`. There are **two** dial
systems in the app:

### A. clockDial (device-native dials - the DT / Glyphix path)
- Endpoints: `clockDial/findByClockDials`, `clockDial/upgrade`, `clockDial/upload`,
  `adapter/findByDevicePlanAndNumber`, `watchFace/adapter/{devicePlan}/{number}`.
- Local DB `clockDialTable` columns: `originId, number, devicePlan, name,
  appDisplayImage, upgradeFile, backgroundWidth, backgroundHeight, thumbnailWidth,
  thumbnailHeight, editable`. The downloadable artifact is `upgradeFile`.
- UI: `ClockDialActivity`, `DialUpgradeActivity`, `ClockDialAdapter`,
  server beans `ServerClockDialBean`, `ServerClockDialGroupBean`.
- A dial is keyed by `(devicePlan, number)`; the watch model is a `devicePlan`.

### B. watchFace (MoYoung store dials)
- MoYoung store: `https://api.moyoung.com/v2/faces`.
- xky-api endpoints: `watchFace/index`, `watchFace/hot(/Page)`, `watchFace/new(/Page)`,
  `watchFace/nonFree(/Page)`, `watchFace/dynamic(/Page)`, `watchFace/theme`,
  `watchFace/theme/{id}`, `watchFace/mine`, `watchFace/banners`, `watchFace/{id}`,
  `watchFace/custom`, `watchFace/custom/create`, `watchFace/install/upload`,
  `pay/{uid}/watchFaces`. Local DB `watchFaceTable`.
- Transfer for crrepa devices: `CRPUiTransInitiator` and `CRPTpTransInitiator`
  (UI/resource and "TP" transfer initiators), `CRPFileTransListener`.

### Dial file format / on-watch location
- Resolution 466x466 confirmed: `sm_px_466`, `queryPhotoWatchFaceAvailableSize`,
  `CRPPhotoWatchFaceLayoutInfo{maxAvailableSize=}`.
- A packed image container "pgf" appears (`[pgf"`, alongside `JpgFromRaw`). Per-chip
  image encoders are bundled (see custom dial). The crrepa layout model
  `CRPWatchFaceLayoutInfo{timePosition=}` and pointer types describe hand/time
  placement.
- **Exact on-watch dial folder and exact `.pgf` layout: UNKNOWN** from the APK. For
  the DT G1 the dial is pushed as the `upgradeFile` via Glyphix `GxFile`; the watch
  menu/partition docs in `docs/` are the better reference for where it lands.

### Custom photo dial ("custom_album", "move_photo_album", "move_video_album")
- UI: `ic_dial_custom_album`, `iv_photo_album`, `move_photo_album`,
  `move_video_album`, `sspz_photo_album_icon`; activities
  `startDialMarketCustomAlbumActivity`, `startDialMarketCustomVideoActivity`,
  `DialWatchFaceCustomForVideoActivity`, `DialWatchFaceCustomFreeForVideoActivity`,
  `activity_dial_watchface_custom_free`, `adapter_item_dial_watchface_custom`.
- Image pipeline:
  1. Crop/select with the yalantis uCrop library (`com.yalantis.ucrop`, `libucrop.so`).
  2. Resize to the watch resolution (466x466).
  3. Convert to the watch image format with a per-chip native encoder:
     - JieLi: `com.jieli.bmp_convert.BmpConvert` / `ConvertParam` / `ConvertResult`,
       native entry `bmpConvert_native`, `libjl_bmp_convert.so`.
     - SiFli: `com.sifli.ezipmy.sifliEzipUtil`, `libezipmy.so`.
     - Realtek: `com.realsil.sdk.dfu.image.wrapper.BinImageWrapper`.
     - crrepa generic: `CRPPhotoWatchFaceInfo`, `CRPWatchFaceBackgroundInfo{bitmap=}`,
       `CRPPhotoWatchFaceLayoutInfo`, `compressPhotoWatchFace`,
       `CRPPhotoWatchFaceDisplayMode`, pointer types.
  4. Push the packed image as a file over the device transfer channel
     (`CRPPhotoWatchFaceTransListener`, or `GxFile` on DT G1).
- Colors / style: the assets `AZURE.png BLUE.png CYAN.png GREEN.png MAGENTA.png
  ORANGE.png RED.png ROSE.png VIOLET.png YELLOW.png` are selectable accent-color
  backgrounds for custom dials; time/hand style comes from
  `CRPWatchFaceLayoutInfo{timePosition}` and the pointer-type enums.
- **Which encoder the DT G1 uses: UNKNOWN.** The "pgf" container suggests a
  Glyphix-specific packed format rather than the JieLi/SiFli ones; confirm on-device.

Feasibility: Medium. The whole pipeline (crop -> 466x466 -> encode -> file push) is
reconstructable in Rust (`image` crate for resize). The one blocker is the exact
on-watch image container ("pgf") and the file-push framing. This is the
highest-value DT G1 feature but needs the image format pinned down first.

---

## 3. Weather sync

- Server: `openWeather/day` (also a `/weather/weatherInfo?` query). AMap weather is
  an alternate source (`com.amap.api.services.weather.LocalDayWeatherForecast`).
- App flow: `getOpenWeather` -> `onResponseWeatherInfo` -> build crrepa beans
  `CRPTodayWeatherInfo{city=}`, `CRPFutureWeatherInfo{future=}` (`FutureBean`),
  `CRPWeatherId`; push with `sendWeatherData`, `sendFutureWeather`,
  `setWeatherForecast`, `setWeatherDay`, `setWeatherId`, `setWeatherSetting`,
  listener `CRPWeatherChangeListener`.
- The push goes through an adapter ("sendWeatherData adapter is null",
  "sendWeatherData adapter weather is false"), i.e. a device-abstraction layer that
  dispatches to the crrepa SDK or to Glyphix MAS depending on the connected watch.
- Payload fields: city, today condition + `tempMin`/`tempMax`, numeric `weatherId`
  condition code, and a multi-day forecast list.
- For the DT G1 the weather is pushed as a Glyphix MAS message (GxMessage). **Exact
  on-wire bytes: UNKNOWN** (native framing).

Feasibility: Easy (logic), once the MAS message framing or the `AT+WRX` equivalent is
known. The data model is small and public weather can be sourced from any API.

---

## 4. Offline maps

### URLs found (do not fetch)
- `https://www.dt1pro.cn/map/maps.html` - map download/help page (China).
- `https://lotussmartime.com/maps/china_maps.html` - international map page.
- `https://www.dt1pro.cn`, `https://www.dt1pro.cn/i.htm`,
  `https://www.dt1pro.cn/video_conversion.html`.
- xky-api: `maps/getOfflineMap`, `airoha/optionalMap/generateFile`, `/map/styles`,
  `/sdk/map/styles`; config fields `mapsResource`, `mapsResourceIntl`.
- AMap/AutoNavi: `restsdk.amap.com/v3/iasdkauth`, `apilocate.amap.com/mobile/binary`,
  `mst01.is.autonavi.com/appmaptile`, `adiu.amap.com/ws/device/adius`,
  `lbs-3dtiles-service.amap.com/basemap/tiles/staging`, `cgicol.amap.com`,
  `mpsapi.amap.com`.
- Google: `maps.googleapis.com/maps/api/geocode/json`,
  `maps.googleapis.com/maps/api/directions/json`, `www.google.com/maps/dir/`.
- Baidu: `api.map.baidu.com`.

### Flow (phone vs PC) - the answer is BOTH
- In-app on the **phone**: the app embeds AMap's offline-map downloader
  `com.amap.api.maps.offlinemap.*` (`OfflineMapManager`, `OfflineMapProvince`,
  `OfflineMapCity`, `DownLoadExpandListView`), with app methods `getOfflineMap`,
  `getOfflineMapProvinceList`, `getOfflineMapCityList`,
  `getDownloadOfflineMapProvinceList`.
- Then it generates the watch map package and syncs it: `generateMapFile`,
  `vMapFileNames`, `WatchMap{index=}`, `watchMaps`, `currentDeleteWatchMap`,
  `MapOfflineWatchMapAdapter`. UI strings (resources.arsc): "Offline map",
  "Download offline map resources to your watch", "Sync map data to the watch",
  "Swipe left to delete downloaded map".
- Alternatively on a **PC**: UI string "Download map via computer" points the user to
  the `dt1pro.cn/map/maps.html` / `china_maps.html` page to fetch a prebuilt map pack,
  which is then synced to the watch. So maps.html is the PC download route; the in-app
  AMap downloader is the phone route. Either way the pack is pushed to the watch over
  the app link.

### On-watch map format
- Vector "world" map: `loadWorldVectorMap`, `setWorldVectorMapStyle`,
  `getWorldVectorMapStyle`, `getWorldVectorMapLanguage`,
  `mWorldVectorOfflineMapStyleFilePath` / `...AssetsPath`.
- Style layers are JSON with exactly the layer names documented on-device:
  `"roads"`, `"roadsBeingBuilt"`, `"water"`, plus `MAP_MAP_ASSETS_STYLE_DATA_ABROAD`,
  `MAP_MAP_ASSETS_STYLE_DATA_TERRAIN`, `map_assets/style_1_17_for_terrain.data`,
  `MAP_MAP_ASSETS_CUSTOM_BACKGROUND_NAME`, `map_custom/skybox`, `map_custom/terrain`.
  These match the documented on-watch `roads.mlp/idx`, `landuse`, `water` files (the
  `.data`/`.mlp` are AMap vector tiles; the JSON above is the render style).
- Turn-by-turn route beans for some chips:
  `com.crrepa.ble.spp.hisilicon.write.map.bean.Node` / `Duration`.
- App-side map bean package: `com.wear.lib_core.bean.map.*` (`WatchMap`, `MyRoute`,
  `MapConfig`, `OfflineMap`).

Feasibility: Hard. Replicating AMap's offline tile download and the watch pack layout
is a large effort and depends on AMap keys. The pragmatic desktop path is to reuse the
PC `maps.html` route to obtain the pack, then implement only the file-sync-to-watch.

---

## 5. Other reusable watch capabilities

- Contacts push: `CRPContactInfo{id=}`, `CRPContactConfigInfo{supported=}`,
  `CRPContactListener`, `CRPContactCountCallback`, `CRPContactConfigCallback`,
  `CRPContactNumberSymbolCallback`.
- Music transfer: `CRPMusicTrainsInitiator` (file transfer of audio to the watch),
  `com.wear.lib_core.bean.music.SendMusic{fileFlag=}`, `sendMusic`, `abortSendMusic`,
  `closeMusicController`, `RemoteMusicController`; bundled `assets/music/Alarm_Beep_03.ogg`.
- Notifications / messages: `CRPMessageInfo{message=}`, `CRPMessageListCallback`,
  `CRPMessageLengthCallback`, app-notification mirroring (StatusBarNotification
  listener). (`com.tencent.mm.opensdk` / QQ are social share, not watch push.)
- Alarms / reminders: `sendAlarm`, `setAlarm2`, `CRPAlarmInfo`,
  `AlarmClockReminderAdapter`; drink-water reminder `CRPNewDrinkWaterPeriodInfo{enable=}`.
- Find device: `findDevice`, `X1,PSET,XFindDevice,1`, `icon_device_findwatch`,
  `isLoadFindDevice`.
- Firmware OTA: `FirmwareUpgradeActivity`, crrepa `FirmwareUpgradePresenter`,
  `CRPFirmwareUpgradeType`, `CRPBleFirmwareUpgradeListener`; multi-vendor DFU engines:
  Nordic (`nrf/dfu`, `DfuBaseService`), Realtek (`ota/realtek`, `libRtkAesJni`,
  `com.realsil.sdk.dfu`), SiFli (`sifli/dfu`), JieLi, HiSilicon (`HsDfuController`,
  `AudioHisiliconTransInitiator`). Server `firmware/checkUpdate`; MoYoung
  `api.moyoung.com/v2/upgrade/{beta,factory}`. DT G1 OTA is most likely a Glyphix MAS
  file push - **exact mechanism UNKNOWN**.
- Also present: AI watch face (`CRPAiWatchFacePreviewInfo`,
  `sendAiWatchFaceActivateRecording`), Alexa integration, sport-track upload
  (`sportTracks/*`), health report upload, device bind/auth (`device/auth`,
  `device/bind`, `device/unbind`).

Feasibility: Find-device, alarms, contacts and notifications are small structured
messages and are the cheapest to port. Music and OTA are large file transfers that
depend on the same file-push channel as dials.

---

## 6. Third-party services integrated (names only; no key values)

Evidence is SDK package presence / endpoints. No key material is reproduced here, and
the watch's `APIConfig.json` is not shipped inside this APK (it lives on the watch).

- AMap / AutoNavi (maps, location, search, weather) - `com.amap.api.*`, `libAMapSDK_MAP_*.so`.
- Google Maps Platform (geocoding, directions, maps, KML) - `com.google.android.gms.maps`,
  `com.google.maps.android.data.kml`.
- Baidu Map - `api.map.baidu.com`.
- Tencent: QQ Connect (`com.tencent.connect` / `tauth` / `open`), WeChat SDK
  (`com.tencent.mm.opensdk`), Bugly crash reporting (`com.tencent.bugly`).
- Umeng analytics - `com.umeng.*`, `libumeng-spy.so`.
- Google Firebase / Play Services (ads, auth, fitness, app-set) - `com.google.firebase.*`,
  `com.google.android.gms.*`.
- Facebook Login - `login/facebook`.
- PayPal - `com.paypal.*`; Alipay - `com.alipay.*` (payments).
- Strava - `api.strava.com` (activity upload / OAuth).
- Vendor push services: vivo, xiaomi, huawei, oppo (`assets/supplierconfig.json`).
- BLE / OTA chip SDKs: Nordic Semiconductor, Realtek, JieLi, SiFli, HiSilicon,
  Actions (iBluz), Glyphix.

---

## 7. Prioritized porting order (easiest first)

1. **Find device** - a single fire-and-forget command (`XFindDevice` / a MAS "find"
   RPC), no payload parsing, no file transfer. Smallest possible first milestone to
   prove the transport works end to end.
2. **Weather push** - tiny structured payload (city, today min/max + condition id,
   multi-day forecast). Server source is trivial to replace; only the on-wire message
   format needs capturing.
3. **Time / alarms / notifications / contacts sync** - small structured messages that
   reuse the same command channel as weather; high utility, low marginal cost once (1)
   and (2) work.

Higher value but harder, do after the channel is solid:
- **Custom photo dial** (crop -> 466x466 -> encode to the watch image container -> file
  push). The flagship DT G1 feature; blocked only on pinning the "pgf" format.
- **Offline maps** and **firmware OTA** - large file transfers; defer until the
  file-push path is reliable, and prefer reusing the `maps.html` PC route for the map
  pack rather than re-implementing AMap's downloader.

Transport recommendation: build the desktop tool first on the watch's `AT+WRX`
USB-serial channel in Charging mode (self-contained, documented in `docs/`), then add
BLE once the Glyphix MAS GATT UUIDs and protobuf schema are captured from a sniff.
