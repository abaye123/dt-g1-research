Source repository: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). This is an unofficial translation.

##  Step-by-step guide: Modification and flashing

### Step 0.

How to download the factory OTA firmware for your watch.
There is a link: https://dt1pro.wanruxia.com/xky-api/firmware/checkUpdate?devicePlan=10&number=88265
Instead of the number 88265 at the end you need to substitute your own. You can see it on the watch in the menu 'Settings - About watch'.
There will be a line like Version1.73.21-88265R, and the last digits are what we need.
Substitute your number into the link and you will see JSON. In the "file": field there is a link to your OTA firmware:
```json
{
  "code": 200,
  "message": "Request successful",
  "success": true,
  "data": {
    "id": 1161,
    "createTime": "2026-01-31 16:49:30",
    "updateTime": "2026-03-04 10:34:54",
    "name": "C175C1",
    "adapterId": 1108,
    "limitationId": null,
    "version": "V1.73.21",
    "versionNum": 830021,
    "file": "https://assets2.dt1pro.cn/fw/26/03/02/1772439053925.bin",
    "fileSize": 4274688,
    "originFileName": "ota_A5S10GLY_C175G_A3-2026-02-28-17-03_V1_73_21.bin",
    "forceUpdate": false,
    "description": null,
    "prodType": true
  },
  "fail": false
}
```


### Step 1. Unpacking the original OTA firmware
[README.md](README.md)

---

### Step 2. Replacing the kernel file (`app.bin`)

Replace the original `app.bin` with your modified `app.bin` file.

---

### Step 3. Reverse assembly of the custom firmware
[README.md](README.md)
---

### Step 4. Installing the firmware on the watch

You can install the resulting file `ota_patched_custom.bin` in one of two ways.

---

#### Method A. Flashing directly from a PC (`dt_ota_flasher.py`) (DOES NOT WORK YET!)

This method does not require a smartphone, the WearPro app or spoofing of server responses.

1. Charge the watch to at least 50%.
2. Disconnect the watch from the WearPro app on the smartphone (and turn off Bluetooth on the smartphone to free the watch's GATT server).
3.  Find out the watch's MAC address:
   * **On the watch:** In the settings menu - 'About watch'
   * **Windows / Linux:** A MAC address of the form `AA:BB:CC:DD:EE:FF` (can be viewed in the device properties or with a BLE scanning utility such as `nRF Connect`).
4. Run the console flasher:

```bash
python dt_ota_flasher.py AA:BB:CC:DD:EE:FF ota_patched_custom.bin
```

Example of a successful transfer process:

```text
[*] Подготовка данных: 4274688 байт...
[*] Файл разбит на 18586 BLE-пакетов.
[*] Подключение к часам (MAC: AA:BB:CC:DD:EE:FF)...
[+] Подключено. Инициализация AOTA сессии...
[*] Текущий размер MTU соединения: 247 байт
[+] Инициализация успешна. Начинаем заливку прошивки...
    Прогресс: 1000/18586 пакетов (5.4%)
    ...
    Прогресс: 18586/18586 пакетов (100.0%)
[+] Передача завершена. Отправка команды Reboot...
[*] Успешно! Часы уходят в перезагрузку.
```

(Translation of the sample output above, for reference: Preparing data: 4274688 bytes... / The file was split into 18586 BLE packets. / Connecting to the watch (MAC: AA:BB:CC:DD:EE:FF)... / Connected. Initializing AOTA session... / Current connection MTU size: 247 bytes / Initialization successful. Starting firmware upload... / Progress: 1000/18586 packets (5.4%) / Progress: 18586/18586 packets (100.0%) / Transfer complete. Sending Reboot command... / Success! The watch is rebooting.)

---

#### Method B. Flashing via the WearPro app (HTTP Mocking)

If you want to use the stock mobile WearPro app, sending the firmware can be forced by intercepting the HTTP update-check request.

**Interception tool:** [HTTP Toolkit](https://httptoolkit.com/) (with ADB interception enabled on a rooted Android smartphone or through an emulator).

##### 1. Setting up a Mock response for the update server

In HTTP Toolkit create a rule (**Mock Rule**) to intercept the version-check request:
* **Match Request:** `URL` -> `Contains` -> `/xky-api/firmware/checkUpdate`
* **Action:** `Provide response`
* **Status:** `200`
* **Headers:** `Content-Type: application/json`
* **Body (JSON):**
  ```json
    {
    "code": 200,
    "message": "Request successful",
    "success": true,
    "data": {
      "id": 1182,
      "createTime": "2026-03-02 16:12:11",
      "updateTime": "2026-03-04 10:35:00",
      "name": "C175GA3",
      "adapterId": 1203,
      "limitationId": null,
      "version": "V1.73.23",
      "versionNum": 830023,
      "file": "https://ota.local/firmware.bin",
      "fileSize": 6438400,
      "originFileName": "ota_A5S10GLY_C175G_A3-2026-02-28-17-03_V1_73_23.bin",
      "forceUpdate": true,
      "description": "null",
      "prodType": true
    },
    "fail": false
  }
  
  ```
  *(The `fileSize` value must exactly match the byte size of your `ota_patched_custom.bin`)*.

##### 2. Setting up the rule that serves the binary file
Add a second rule in HTTP Toolkit to intercept the firmware download:
* **Match Request:** `URL` -> `Equals` -> `https://ota.local/firmware.bin`
* **Action:** `Provide response`
* **Status:** `200`
* **Headers:** `Content-Type: application/octet-stream`
* **Body:** Choose `From File` and specify the path to `ota_patched_custom.bin` on your PC.

##### 3. Starting the update
1. Force-stop the WearPro app on the smartphone to clear the cache.
2. Open WearPro -> the **Device** section -> **Firmware update**.
3. The app will detect "version V1.73.23", download the generated file from `ota.local` and upload it into the watch over Bluetooth.

---

## 🔧 Diagnostics and troubleshooting

1. **The WearPro app stops at "Preparing firmware 0%":**
   * **Cause:** The byte size of the `TEMP.bin` or `app.bin` file does not match the data recorded in the `<file_size>` tags of the `ota.xml` files.
   * **Solution:** Make sure you used the current firmware packing script, which automatically updates the XML metadata.

2. **The `dt_ota_flasher.py` script raises `BleakError` or drops the connection at 1-2%:**
   * **Cause:** The PC's Bluetooth adapter does not support the DLE frame length extension or drops large MTU buffers.
   * **Solution:** Add a small delay between frame transmissions in the script (increase the `asyncio.sleep` value to `0.01` sec) or use an external USB Bluetooth 5.0+ adapter.
