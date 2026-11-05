# Under the Hood: PurrLaunch Architecture and Reverse Engineering

This document describes the internals of the **PurrLaunch** launcher for the DT NO.1 G1 smartwatch (Actions Semiconductor ATS3085S chip, Glyphix OS). The application was created by reverse-engineering the vendor's closed platform and exploits a series of architectural features and undocumented APIs.

---

## 1. Attack Vector: System Slot Spoofing (App Spoofing)

The graphical user interface (GUI) of the smartwatch relies on a hardcoded list of applications. The OS does not dynamically scan the package directory to build the main menu.

To gain an Entry Point, PurrLaunch uses manifest spoofing. The `manifest.json` of the launcher overrides the system `package` ID of one of the pre-installed apps (in this case, "Wooden Fish"):

```json
{
  "package": "com.xfaith.woodenfish",
  "name": "PurrLaunch",
  "permissions": [
    { "name": "watch.permission.SYSTEM" }
  ]
}
```

When the user taps the "Wooden Fish" icon in the main menu, the C++ `AppletKit` daemon looks up the ID `com.xfaith.woodenfish` in the `ADBT_Applet` database and hands control over to our JavaScript code, granting it system privileges.

---

## 2. Sandbox Isolation (VFS vs POSIX)

The most complex technical challenge was implementing the installation of new packages (`pkg.install()`) directly from a USB drive.

The smartwatch uses a **Virtual File System (VFS)** on top of the physical file system (FatFS). The user USB zone mounts as `internal://mass/`. The JS application has read access to this directory via the `@system.file` wrapper.

However, the system installer (`AppletKit`), written in C++, runs in an isolated context and accesses files directly via POSIX-like calls. If we pass the virtual path `internal://mass/app.pkg` to it, the parser fails to resolve the path and throws a `package file is not exist` error.

### Solution: The "Staging Cache" Pattern
To bypass this sandbox isolation, PurrLaunch performs a two-stage installation:
1. Using the JS VFS module, the package is asynchronously copied from the public USB zone (`internal://mass/`) to the app's private sandbox directory (`internal://files/`).
2. The path to this copied file is then passed to the C++ installer. Since this directory is owned by the app itself, the OS correctly resolves the physical path and grants the installer read permissions.
3. Once the system unpacks the archive, the temporary file is deleted.

---

## 3. Hardware I/O Barrier (Race Condition)

The ATS3085S MCU lacks the complex file system caching mechanisms found in full-fledged operating systems like Linux or Android.

During development, a critical I/O Race Condition was discovered: the JS promise for `file.copy()` resolved immediately after the RAM buffer was filled, *before* the SPI flash memory controller physically flushed the data to the storage and closed the file descriptor. Calling `pkg.install()` instantly after the promise resolved led to a read error (the C++ daemon saw the file as empty or locked).

**Solution:** Implementing an artificial hardware I/O Barrier.

```javascript
// 1. Start copying
await file.copy({ srcUri: vfsUri, dstUri: targetUri });

// 2. I/O Barrier: Freeze the JS thread with a macro-task, 
// giving the RTOS CPU time to flush flash memory buffers.
await new Promise(resolve => setTimeout(resolve, 800));

// 3. Now it is safe to call the C++ API
await pkg.install(config);
```

---

## 4. C++ Binding OEM Anomalies (JSI Analysis)

While the Glyphix platform standardizes its API, the hardware manufacturer (Actions Semiconductor) introduced critical changes to the C++ binding signatures (JSI - JavaScript Interface) of the `@system.package` module.

1. **Strict Argument Typing:** The C++ parser drops calls if a primitive (string) is passed instead of a configuration object. For example, running `pkg.remove("com.app")` causes a *Silent Crash* (the thread dies without throwing a JS exception).
2. **Non-standard Keys:** Standard documentation suggests passing the `uri` or `path` key for installation. An analytical brute-force script revealed that the vendor hardcoded the C++ parser to exclusively expect the **`src`** key.

Final working signature for installation:
```json
{
  "src": "internal://files/app.pkg",
  "force": true,
  "verify": false
}
```

Final "Fat Object" signature for safe uninstallation:
```json
{
  "package": "com.target.app",
  "id": "com.target.app",
  "app": "com.target.app",
  "pkg": "com.target.app"
}
```

---

## 5. UI Framework Degradation

To reduce RAM consumption, the manufacturer aggressively stripped down the watch's built-in graphics engine:

* **Virtual Nodes Banned:** The `<block>` tag, standard for QuickApp/Glyphix, causes an XML parser crash (`unsupported component: Block`). Classic `<div>` tags must be used instead.
* **System Dialogs Deleted:** The `@system.prompt` module is disabled. Calling `prompt.showDialog()` throws a `TypeError`.
