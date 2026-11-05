# 🐾 PurrLaunch

**PurrLaunch** is a launcher and full-featured package manager for smartwatches based on Glyphix OS (e.g., DT NO.1 and compatibles on the Actions Semiconductor ATS3085S / Zephyr RTOS hardware platform).

Due to the closed ecosystem of smartwatches, launching and installing third-party applications "out of the box" is severely restricted. PurrLaunch solves this problem: it allows you to install any `.pkg` applications directly from the watch's USB flash memory, launch them, and safely uninstall them.

To bypass system restrictions, the launcher disguises itself as the system application **Wooden Fish**.

---

## ⚙️ Installing PurrLaunch on the Watch

Since the watch initially lacks a built-in file manager, the first installation of the launcher itself is performed through standard channels:

1. Download the [latest release zip archive](https://github.com/purrrock/PurrLaunch/releases/latest). Inside the archive, you will find the launcher package `com.xfaith.woodenfish.pkg` and the service utility `ser_set_real_u_py2.exe`.
2. Install the launcher on the watch. Depending on your capabilities, this can be done:
   * Via the standard companion app on a smartphone.
   * Or manually (via developer tools): use the `ser_set_real_u_py2.exe` utility to place the `.pkg` file on the watch into the `\gui\apps` folder of the system partition and manually edit the `\gui\pkgs.db` file by adding the following block:

```json
{
  "apps": {
    "com.xfaith.woodenfish": {
      "uri": "pkg://com.xfaith.woodenfish"
    }
  },
  "dials": {}
}
```

   After that, you need to add our spoofed Wooden Fish to the watch menu using the [dtg1-menu-editor](https://github.com/purrrock/dtg1-menu-editor) utility.

After installation, the "Wooden Fish" icon in your watch menu will become the entry point to PurrLaunch.

---

## 📦 How to Install New Applications (.pkg)

With PurrLaunch, installing new applications, games, or utilities becomes simple:

1. On the watch, go to Settings and change the **USB Mode** from `Mass Storage` to `Charging mode`.
2. **Connect the watch to the PC:** Use the provided magnetic cable. 
3. Run `ser_set_real_u_py2.exe` (located in the downloaded release zip archive). This utility will mount the hidden system partition of the watch as a new logical drive on your PC (the computer will recognize the watch as two USB drives).
4. **Copy the files:** Transfer the downloaded applications (`.pkg` files) into the `/data/mass` folder of the watch's system drive (usually the second of the mounted drives).
5. **Disconnect and reboot the watch:** Safely eject the device and perform a reboot via the watch menu.
6. **Open the launcher:** In the main menu of the watch, find the **Wooden Fish** application and launch it.
7. **Start the installation:**
   * Tap the **Menu** button, then select **File Manager**.
   * Ensure the **Mass** tab is active. You will see a list of all files, including the copied `.pkg` files.
   * Tap on the desired application file (`.pkg`) to begin the two-stage extraction process.
8. **Auto-cleanup:** After successful extraction, the launcher will offer to delete the original `.pkg` file from the USB drive (**Keep** / **Delete** buttons). Agree to avoid cluttering the watch's memory. 

After installation, return to the main screen by swiping right - the icon of the new application will appear there.

---

## 🚀 Usage and Launching

When you open PurrLaunch, you will see a list of all installed third-party applications (the list is automatically sorted alphabetically). 
Simply **tap on the name or icon** of any application to launch it instantly.

*To return to previous launcher screens or exit to the watch face, use the system swipe from left to right or the hardware button on the watch.*

---

## 🧰 System Tools (Menu)

On the main screen, tap the **Menu** button to open additional system utilities:

* **📊 System Info:** Displays detailed device data (model, runtime environment - watch/emulator, display shape and resolution), as well as memory monitoring (free space on the flash drive and allocated RAM profile).
* **📁 File Manager:** A built-in manager for navigating the hidden virtual drives of the watch (`mass` - public flash storage, `files` - isolated sandbox, `cache` - temporary files).
  * **Package Installation:** Tapping any `.pkg` file automatically starts the installer.
  * **File Deletion:** Allows safe deletion of any leftover junk files (**DEL** button) without connecting to a PC.
  * **Text Viewer:** Automatically recognizes text formats (`.txt`, `.log`, `.md`, `.json`, `.xml`, `.ux`, `.js`, etc.) and allows you to read their contents fullscreen directly from your wrist.
* **🗑️ Manage / Delete Apps:** Enters the management mode for installed packages to uninstall them.

---

## 🗑️ How to Uninstall Applications

If you no longer need an installed third-party application:

1. Open PurrLaunch and navigate to **Menu**.
2. Select **Manage / Delete Apps**.
3. Find the unwanted application in the list and press the red **DEL** button.
4. A confirmation dialog will appear. Tap **Uninstall**.

The system will completely erase the application and clear all its temporary files and cache. 

---

## ⚠️ Compatibility and Warnings

* The project was tested on **DT NO.1 G1** smartwatches (ATS3085S chip, Glyphix OS).
* Built-in protection prevents you from accidentally deleting PurrLaunch itself via its own interface or displaying critical system services. If you need to uninstall the launcher, do so via the companion app on a smartphone or manually via USB.
* Only use third-party `.pkg` packages from trusted sources.