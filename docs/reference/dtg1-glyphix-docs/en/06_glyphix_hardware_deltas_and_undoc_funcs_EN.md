Source repository: https://github.com/purrrock/dtg1-glyphix-docs (MIT). This is an unofficial translation.

# Context File: 06_glyphix_hardware_deltas_and_undoc_funcs_EN.md
Environment constraints: MCU (No DOM), Zephyr RTOS, ATS3085S hardware platform.

> [REVERSE ENGINEERING FACTS]
============================================================
FILE_PATH: src/re_deltas/Features_and_limitations_of_real_watches.md

# Technical specification: Features and limitations of the DT NO.1 G1 platform (ATS3085S / Glyphix OS)

During reverse engineering and field tests the following critical limitations of the execution environment (JS Sandbox) on the real device were identified:

## 1. Graphics pipeline and Layout Engine
* **No Canvas API:** The `<canvas>` component and the methods of its context were removed at the hardware level by the manufacturer (Opaque Pointer Trap: `TypeError: not a function`). All custom rendering must be done through the DOM tree (many small `<div>` elements).
* **Flexbox and CSS limitations:** * The style parser ignores the value `relative` of the `position` property. Root containers must be built without it.
  * Absolute positioning of child nodes is measured strictly from the top-left corner of the screen `(0, 0)`.
  * The `transform: rotate()` property is **not supported** on the real hardware (it causes `WARN: unknown style property` and is ignored). Rotation of elements must be computed mathematically via `left`/`top`.
  * Dynamic binding of CSS classes is not supported.
* **Display geometry:** The screen is physically round with a resolution of $466 \times 466$ pixels.
  * **Safe Areas:** Text elements and UI components must be placed along the Y axis in the range `45px` (top) - `360px..370px` (bottom) so as not to be clipped by the bezel.

## 2. File system (VFS) and Storage (KV)
* **Mount points (RW access):** The app has full read and write access to three directories:
  * `internal://mass/` - Shared memory. Physically mapped to `/1:/data/mass/` on the watch (accessible over USB from a PC).
  * `internal://files/` - Private app memory.
  * `internal://cache/` - Private app cache.
* **Location in the PC emulator:** The emulator's virtual FS is mapped into the project folder: `.glyphix-work\image\default-watch-466x466\data\`.
* **Anomalies of the `@system.file` API (differences from the QuickApp standard):** * The `file.readText()` method on the watch returns a **string directly** (without the `{ text: "..." }` wrapper).
  * The `file.list()` method returns a **flat array of strings** with file names (for example, `["test.txt", "purrgo.gpx"]`), not an array of `{ uri, length }` objects. It is impossible to get a file size via `list()` on the current firmware.
* **FlashDB anomalies (`@system.storage`):**
  * The `storage.delete(key)` method accepts a **string directly**, not an object `{ key: "..." }` as in the standard. Passing an object results in an attempt to delete the string key `"[object Object]"` and does not clear the real memory, causing leaks and read failures.
  * When a nonexistent key is requested, the API sometimes returns the string `"undefined"` instead of the type `undefined`. Explicit casting and checks `String(val) !== 'undefined'` are mandatory.

## 3. CPU time and Watchdog
* **Aggressive Watchdog:** The microcontroller has no real multitasking. Blocking the main thread with heavy computations (for example, RegExp parsing of XML/GPX strings of 5-10 KB in a single loop) causes the device to hang.
* **Asynchronous pauses:** Any batch computations must be forcibly wrapped in macrotasks (for example, `setTimeout(..., 50)`) in order to give CPU time back to the OS to handle hardware interrupts.

## 4. Sensors and Throttling
* **Event Storm:** The hardware compass module (`@system.compass`) generates interrupts at a rate of up to 50 Hz.
* **Reactivity limits:** The Glyphix reactive data-binding engine cannot recompute dozens of inline `left`/`top` styles at a high rate. It is unacceptable to put sensor subscription IDs (`subscribeId`) into the reactive `data: {}` object.
* **Throttling:** DOM redrawing must be strictly limited to 5-10 frames per second (via lock flags and `setTimeout` of 100-200 ms), otherwise overheating, battery drain and an interface freeze are guaranteed.
* **C++ signature anomaly:** * `compass.subscribe()` accepts a **function directly**: `((data) => {})`. Passing an object causes the crash `InternalError: first args must is a function`. The direction (`direction`) arrives in **radians**.

## 5. Geolocation (`@system.geolocation`) and GNSS hardware limits
* **No Promise support:** On the ATS3085S platform the `geolocation.getLocation()` method **does not return a Promise**. You must pass an object with `success` and `fail` callbacks. Trying to call it via `await getLocation()` will return `undefined`.
* **Changed Payload structure:** In the `success(data)` callback the target coordinates are not in the root of the response but in a nested `data` object (i.e. `data.data.latitude` / `data.data.longitude`).
* **Isolation of the built-in GNSS (Tethered stub):** On the production firmware the JS module `@system.geolocation` is cut off at the hardware level from the built-in chip. 
  * The method goes strictly to the Bluetooth bridge and requires an active connection to the companion app on the smartphone.
  * Without an active BT bridge the function immediately rejects the call through the `fail` callback with the error `Code: 1002` ("Currently not connected to the mobile phone Bluetooth network").
  * The continuous polling method `geolocation.subscribe()` likewise does not work standalone and stays "deaf" silent (does not invoke callbacks) if the phone is not connected.
  * **Direct access to the watch's GNSS chip in standalone mode is possible only by creating a Native Applet in C++** through the OS's internal HAL interface. Alternatively, firmware patching is possible to redirect the geolocation request to the watch's built-in GNSS chip.
  * The emulator has no GNSS at all and getLocation() always returns an error. If debugging is needed, you must detect that you are running in the emulator and mock the data.
  
## 6. Background operation, Task scheduler and Memory management (OOM Killer)
* **Aggressive OOM Killer (Watchdog):** On the real watch there is **no concept of "background work in RAM"**. Exactly 1 second after the display is turned off (`onHide`) the operating system forcibly and ruthlessly kills the app's JS context to free RAM. Any global variables, arrays (`this`) and also timers (`setTimeout`/`setInterval`) are irreversibly destroyed.
* **"Stateless Resurrection":** The system scheduler `@system.schedule` runs at the OS kernel level (C++) and **survives** the unloading of the JS context. When the schedule interval comes, the OS initializes the JS engine anew (waking the process from deep sleep), calls `onCreate`, and then immediately fires the scheduler's trigger callback (for example, `onLocationTick`).
* **Deep Sleep and hardware timeouts:** With the screen off the processor goes into deep sleep. During a brief (background) wake-up by the scheduler, the hardware and radio modules do not have enough time for a "cold start". Therefore background requests may fail on hardware timeouts (such as `code: 1002` after 10 seconds).
* **"Stateless Tracker" architectural pattern:**
  1. The app must rely fully on non-volatile memory (`@system.storage` or `@system.file`) to save intermediate points (Waypoints), the tracker state and identifiers (Job ID).
  2. The `schedule.scheduleJob()` task **MUST ABSOLUTELY NOT** be cancelled (do not call `cancel`) in the `onDestroy` method, otherwise the background "resurrection" cycle will be interrupted forever.
  3. In `onShow` you must check for an active task in `@system.storage`, so as not to spawn scheduler duplicates after the app has been killed and launched again by the user.
  
## 7. System notifications (`@system.notification`)
* **Aggressive trimming by the OEM launcher (DT NO.1):** On the real watch the notification center (shade) is implemented in the most primitive way and ignores most of the Glyphix specification:
  * The `icon` field is ignored. Custom app icons are not shown in notifications.
  * The `actionUri` field (deep-link transitions) is completely blocked. Tapping a notification cannot launch or expand the source app; the user can only dismiss the notification (swipe it away or tap the "trash can"). Notifications are purely passive (informational) in nature.
* **PC emulator shortcomings:** The official emulator does not implement the `notification.remove()` method (it causes the Warning: `remove notification is not implemented yet`). On the real watch, however, deleting or overwriting notifications by a constant `id` does not cause a Warning.

============================================================
FILE_PATH: src/re_deltas/glyphix_canvas_spec.md

# Glyphix OS: Canvas API specification and profiling
**Status:** Factually confirmed on the emulator, requires additional verification on the real device

---

## 1. System features of the Canvas API
1. **Initialization:** Performed by calling the `getContext('2d')` (or `getContext()`) method of the native `<canvas>` element in the `onReady` lifecycle phase.
2. **Opaque Pointer mechanism (C++ Proxy):** The context object is a proxy wrapper over the native C++ graphics pipeline.
3. **Danger of `if (ctx.method)` checks:** Trying to check for the presence of a method before calling it always returns `true` (the wrapper function). Calling a method not implemented in C++ causes the fatal exception `TypeError: not a function` and a crash of the JS context. **Strictly** only the confirmed list of functions may be called.

---

## 2. Final API support matrix

### 2.1. Supported methods and properties

| Category | Supported entities | Usage|
| :--- | :--- | :--- |
| **Style properties** | `fillStyle`, `strokeStyle`, `lineWidth` | Controlling the color of the track, cursor and text, and the line thickness |
| **Basic shapes** | `fillRect`, `strokeRect`, `rect`, `fill` | Clearing the frame (`fillRect`), drawing plates and backgrounds |
| **Paths (Path)** | `beginPath`, `moveTo`, `lineTo`, `stroke` | Drawing the route line (Polyline) and cursor vectors |
| **Curves** | `arc`, `arcTo`, `bezierCurveTo`, `quadraticCurveTo` | Drawing POI markers (`arc`), roundings and the compass scale |
| **Transformations** | `save`, `restore`, `translate`, `rotate`, `scale` | Hardware rotation and shift of the canvas to match the direction of travel |
| **Text** | `fillText` | Direct rendering of distance, speed and hints on the Canvas |

### 2.2. Missing methods

| Missing method | Reason / Alternative (Fallback) |
| :--- | :--- |
| `clearRect` | **Critical.** Replaced by filling with the background color: `ctx.fillRect(0, 0, width, height)` |
| `ellipse` | Emulated via `arc()` |
| `transform` | Use a combination of `translate()` and `rotate()` |
| `strokeText`, `measureText` | Use only `fillText()`. Set text alignment with fixed offsets |
| `getImageData`, `putImageData` | Direct work with the pixel buffer in JS is unavailable |
| `clip` | Masking by clipping is unavailable |
| `createLinearGradient` | Gradients are not supported. Use a solid color (`fillStyle`) |

---

## 3. Architectural advantages of the confirmed API

1. **Hardware transformations (`rotate` / `translate` / `save` / `restore`):**
   The presence of these methods makes it possible to completely drop manual vector-rotation trigonometry in JS (`Math.cos`/`Math.sin`). It is enough to shift the coordinate system to the center of the screen via `translate(cx, cy)` and rotate by the azimuth angle `rotate(heading)`.

2. **Drawing curves (`arc` / `arcTo`):**
   Allows rendering round markers of the current location, intermediate points (Waypoints), and interface elements (compass scale, speedometer).

3. **Direct text rendering (`fillText`):**
   Removes the need to lay out overlays from Flexbox `<text>` tags on top of the `<canvas>`, reducing the number of nodes in the element tree and lowering the MCU's RAM consumption.

---

## 4. Canonical pattern for clearing and drawing a frame

```javascript
renderFrame() {
  // 1. Clear the screen (Replacement for the missing clearRect)
  this.ctx.fillStyle = '#000000';
  this.ctx.fillRect(0, 0, 466, 466);

  // 2. Save the state of the transformation matrix
  this.ctx.save();

  // 3. Shift the coordinate origin and rotate the canvas to the azimuth (Heading)
  this.ctx.translate(233, 233);
  this.ctx.rotate(this.userHeading);

  // 4. Draw objects (cursor/track) relative to the new center
  // ...

  // 5. Restore the original state of the matrix
  this.ctx.restore();

  // 6. Output static telemetry on top of the frame
  this.ctx.fillStyle = '#00ff00';
  this.ctx.fillText('150m', 200, 420);
}
```

============================================================
FILE_PATH: src/re_deltas/Glyphix_API_full_and_undocummented.md

# Glyphix API specification (ATS3085S hardware platform)

### API module: @system.device
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `getInfo` | Get the main device information | Yes | Yes | Standard functionality |
| `getId` | Get the unique identifier | Yes | Yes | Standard functionality |
| `getDeviceId` | Get the hardware device ID | Yes | Yes | Standard functionality |
| `getSerial` | Get the serial number | Yes | Yes | Standard functionality |
| `getTotalStorage` | Total ROM capacity | Yes | Yes | Standard functionality |
| `getAvailableStorage` | Available ROM capacity | Yes | Yes | Standard functionality |
| `screenWidth` | Screen width in pixels (Property) | Yes | Yes | Standard functionality |
| `screenHeight` | Screen height in pixels (Property) | Yes | Yes | Standard functionality |
| `screenDensity` | Pixel density (Property) | Yes | Yes | Standard functionality |
| `screenShape` | Screen shape (rect/circle) (Property) | Yes | Yes | Standard functionality |
| `memoryProfile` | RAM allocation profile (Property) | Yes | Yes | Standard functionality |

### API module: @system.fetch
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `fetch` | Network HTTP request | Yes | Yes | Standard functionality (requires MAS/Bluetooth) |

### API module: @system.prompt
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `showToast` | Short popup notification | Yes | Yes | Standard functionality |
| `showPopup` | Dialog window | Yes | Yes | Standard functionality |
| `showIme` | Invoke the on-screen keyboard | Yes | Yes | Standard functionality |

### API module: @system.storage
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `set` | Write a key-value pair to the DB | Yes | Yes | Standard functionality |
| `get` | Read a value from the DB | Yes | Yes | Standard functionality |
| `delete` | Delete a key from the DB | Yes | Yes | Standard functionality |
| `clear` | Clear the entire app database | Yes | Yes | Standard functionality |

### API module: @system.router
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `push` | Add a page to the stack | Yes | Yes | Standard functionality |
| `replace` | Replace the current page in the stack | Yes | Yes | Standard functionality |
| `back` | Return to the previous page | Yes | Yes | Standard functionality |
| `close` | Close the app/router | Yes | Yes | Standard functionality |
| `clear` | Clear the router stack | Yes | Yes | Standard functionality |
| `getLength` | Get the length of the page stack | Yes | Yes | Standard functionality |
| `getPages` | Get the list of page objects | Yes | Yes | Standard functionality |
| `getPagesName` | Get the names of the pages in the stack | Yes | Yes | Standard functionality |
| `getPage` | Get a specific page | Yes | Yes | Standard functionality |
| `getIndex` | Get the index of the current page | Yes | Yes | Standard functionality |
| `queryPage` | Search for a page by parameters | Yes | Yes | Standard functionality |
| `queryIndex` | Search for an index by parameters | Yes | Yes | Standard functionality |

### API module: @system.app
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `getInfo` | Get information about the current app | Yes | Yes | Standard functionality |
| `loadLibrary` | Dynamic loading of libraries | Yes | Yes | Standard functionality |
| `terminate` | Forced termination of the process | Yes | Yes | Standard functionality |
| `keepForeground` | Keep the process in the foreground | Yes | **No** | **Removed by the OEM.** Headless mode operation is impossible. |

### API module: @system.geolocation
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `getLocation` | Single coordinates request | Yes | Yes | Standard functionality |
| `subscribe` | Subscribe to the geodata stream | Yes | Yes | Standard functionality |
| `unsubscribe` | Unsubscribe from the geodata stream | Yes | Yes | Standard functionality |
| `getSupportedCoordTypes` | Query the supported projection types | Yes | **No** | **Removed by the OEM.** |

### API module: @system.compass
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `subscribe` | Subscribe to the azimuth | Yes | Yes | Standard functionality |
| `unsubscribe` | Unsubscribe from the compass sensor | Yes | Yes | Standard functionality |
| `calibration` | Start magnetometer calibration | Yes | Yes | Standard functionality |
| `getValue` | Single read of the azimuth value | Yes | Yes | Standard functionality |

### API module: @system.media
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `createAudioPlayer` | Create an audio player instance | Yes | Yes | Standard functionality |
| `createAudioRecord` | Create a microphone recording instance | Yes | Yes | Standard functionality |
| `setVolume` | Set the system volume | Yes | Yes | Standard functionality |
| `getVolume` | Get the current volume | Yes | Yes | Standard functionality |
| `parseSongAttributes` | Read ID3/meta tags of an audio file | Yes | **No** | **Removed by the OEM.** |

### API module: @system.file
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `readText` | Asynchronous reading of text from a file | Yes | Yes | Standard functionality |
| `writeText` | Asynchronous writing of text to a file | Yes | Yes | Standard functionality |
| `read` | Asynchronous reading of binary data | Yes | Yes | Standard functionality |
| `write` | Asynchronous writing of binary data | Yes | Yes | Standard functionality |
| `copy` | Copy a file | Yes | Yes | Standard functionality |
| `rename` | Rename a file | Yes | Yes | Standard functionality |
| `list` | Read a directory listing | Yes | Yes | Standard functionality |
| `access` | Check access to a file/folder | Yes | Yes | Standard functionality |
| `mkdir` | Create a directory | Yes | Yes | Standard functionality |
| `remove` | Delete a file or folder | Yes | Yes | Standard functionality |
| `stat` | Read file metadata (size, date) | Yes | Yes | Standard functionality |
| `readSync` | Synchronous binary read | Yes | Yes | Standard functionality |
| `writeSync` | Synchronous binary write | Yes | Yes | Standard functionality |

### API module: @system.request
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `download` | Download a file over the network | Yes | Yes | Standard functionality |

### API module: @system.launch
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `launch` | Launch an app by packageId | Yes | Yes | Standard functionality |
| `inactive` | Switch to inactive mode | Yes | Yes | Standard functionality |
| `exit` | Exit the current app | Yes | Yes | Standard functionality |
| `getRunning` | Query running processes | Yes | Yes | Standard functionality |

### API module: @system.package
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `list` | List of installed packages | Yes | Yes | Standard functionality |
| `countOf` | Number of packages | Yes | Yes | Standard functionality |
| `getInfo` | Information about an installed package | Yes | Yes | Standard functionality |
| `manifest` | Read the package's manifest.json | Yes | Yes | Standard functionality |
| `install` | Request to install a package | Yes | Yes | Standard functionality |
| `remove` | Request to remove a package | Yes | Yes | Standard functionality |

### API module: @system.path
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `dirname` | Get the directory from a path | Yes | Yes | Standard functionality |
| `basename` | Get the file name from a path | Yes | Yes | Standard functionality |
| `extname` | Get the file extension | Yes | Yes | Standard functionality |
| `isAbsolute` | Check whether a path is absolute | Yes | Yes | Standard functionality |
| `join` | Join a path | Yes | Yes | Standard functionality |
| `normalize` | Normalize slashes in a path | Yes | Yes | Standard functionality |
| `relative` | Compute a relative path | Yes | Yes | Standard functionality |

### API module: @system.exchange
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `set` | Write to the global storage | Yes | Yes | Standard functionality |
| `get` | Read from the global storage | Yes | Yes | Standard functionality |
| `delete` | Delete from the global storage | Yes | Yes | Standard functionality |
| `watch` | Subscribe to changes of an exchange key | Yes | Yes | Standard functionality |
| `unwatch` | Unsubscribe from changes | Yes | Yes | Standard functionality |

### API module: @system.battery
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `getStatus` | Query the charge level and status | Yes | Yes | Standard functionality |

### API module: @system.schedule
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `scheduleJob` | Schedule a deferred task | Yes | Yes | Standard functionality |
| `cancel` | Cancel a task | Yes | Yes | Standard functionality |
| `cancelByKey` | Cancel a task by key | Yes | **No** | **Removed by the OEM.** |

### API module: @system.notification
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `publish` | Send a notification to the shade | Yes | Yes | Standard functionality |
| `remove` | Dismiss a notification programmatically | Yes | **No** | **Removed by the OEM.** |

### API module: @system.network
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `subscribe` | Subscribe to the network status | Yes | Yes | Standard functionality |
| `unsubscribe` | Unsubscribe from the network status | Yes | Yes | Standard functionality |
| `getType` | Get the connection type | Yes | Yes | Standard functionality |

### API module: @system.vibrator
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `vibrate` | Activate the vibration motor | Yes | Yes | Standard functionality |

### API module: @system.internal
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `globalComponent` | Invoke an internal OS component | Yes | Yes | Standard functionality |
| `setDefaultKeyHandler` | Intercept hardware buttons | Yes | Yes | Standard functionality |

### API module: @system.test
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `getByTag` | Find a UI element by tag | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `getByClass` | Find a UI element by class | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `getById` | Find a UI element by ID | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `getHasText` | Find a UI element by text | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `atPage` | Switch the testing context | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `wait` | Wait (sleep) in a test | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `testcase` | Define a test case | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `testsuite` | Define a test suite | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `run` | Run an automated test | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |
| `terminate` | Stop testing | Yes | **No** | **Module cleared (EMPTY_OBJECT).** |

### API module: @system.devtools
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `[Entire module]` | Developer tools | **No** | **No** | **BLOCKED/NOT FOUND** on both platforms. |

### API module: @system.audiokit
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `getPlayers` | Get the audio player pool | Yes | Yes | Standard functionality |
| `getActivePlayer` | Get the active audio player | Yes | Yes | Standard functionality |
| `subscribe` | Subscribe to audiokit events | Yes | Yes | Standard functionality |
| `unsubscribe` | Unsubscribe from audiokit events | Yes | Yes | Standard functionality |

### API module: @system.interconnect
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `instance` | Communication bridge with the smartphone | Yes | **No** | **Module blocked (NOT FOUND) on the watch.** |

### API module: @system.cipher
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `base64Encode` | Asynchronous Base64 encoding | Yes | Yes | Standard functionality |
| `base64Decode` | Asynchronous Base64 decoding | Yes | Yes | Standard functionality |
| `aes` | Asynchronous AES encryption | Yes | Yes | Standard functionality |
| `hash` | Asynchronous hashing | Yes | Yes | Standard functionality |
| `hmac` | Asynchronous HMAC | Yes | Yes | Standard functionality |
| `rsa` | Asynchronous RSA encryption | Yes | Yes | Standard functionality |
| `sign` | Asynchronous cryptographic signature | Yes | Yes | Standard functionality |
| `hkdf` | Key derivation (HKDF) | Yes | **No** | **Removed by the OEM.** |
| `pbkdf2` | Password-based key derivation (PBKDF2) | Yes | **No** | **Removed by the OEM.** |
| `generatePairKey` | Key pair generation (RSA) | Yes | **No** | **Removed by the OEM.** |
| `base64EncodeSync` | Synchronous Base64 encoding | Yes | **No** | **Removed by the OEM.** |
| `base64DecodeSync` | Synchronous Base64 decoding | Yes | **No** | **Removed by the OEM.** |
| `aesSync` | Synchronous AES encryption | Yes | **No** | **Removed by the OEM.** |
| `hmacSync` | Synchronous HMAC | Yes | **No** | **Removed by the OEM.** |
| `hashSync` | Synchronous hashing | Yes | **No** | **Removed by the OEM.** |
| `rsaSync` | Synchronous RSA encryption | Yes | **No** | **Removed by the OEM.** |
| `signSync` | Synchronous cryptographic signature | Yes | **No** | **Removed by the OEM.** |
| `hkdfSync` | Synchronous HKDF derivation | Yes | **No** | **Removed by the OEM.** |
| `pbkdf2Sync` | Synchronous PBKDF2 derivation | Yes | **No** | **Removed by the OEM.** |
| `generatePairKeySync` | Synchronous key generation | Yes | **No** | **Removed by the OEM.** |

### API module: @vendor.device
| Function | Short description | Emulator access | Watch access | Delta / Status (Hardware limitations) |
| :--- | :--- | :--- | :--- | :--- |
| `[Entire module]` | Vendor hardware extensions | **No** | **No** | **BLOCKED/NOT FOUND** on both platforms. |
