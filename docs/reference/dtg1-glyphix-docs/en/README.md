Source repository: https://github.com/purrrock/dtg1-glyphix-docs (MIT). This is an unofficial translation.

# DT G1 Glyphix OS Documentation & RE Deltas (`dtg1-glyphix-docs`)

A repository containing extended, translated and structured documentation for the **Glyphix OS** framework, as well as reverse engineering artifacts of the **DT NO.1** smartwatch firmware (hardware platform **Actions Semiconductor ATS3085S**, Zephyr RTOS).

The project solves the task of translating the documentation and generating an aggregated context for loading into neural network models (LLMs).

---

## 🎯 Project goals

1. **Upstream synchronization:** Safe downloading and cleaning of the original documentation from the repository [`glyphix-os/web-docs`](https://github.com/glyphix-os/web-docs).
2. **Localization:** Full translation of the documentation into English (`EN`) and Russian (`RU`).
3. **Recording reverse engineering facts:** Maintaining an independent catalog `src/re_deltas/` with factual data about the hardware limitations of the ATS3085S, undocumented C++ API calls, the structure of `.pkg` containers and the VFS configuration.
4. **LLM context build pipeline:** Automatic compilation of scattered Markdown files into 7 structured monoliths for each language with `FILE_PATH:` separators.

---

## 📂 Repository structure

```text
dtg1-glyphix-docs/
├── .gitignore
├── README.md
├── ai_context/                  # Ready aggregated files for LLMs
│   ├── EN/                      # English context (01_..._EN.md - 07_..._EN.md)
│   ├── RU/                      # Russian context (01_..._RU.md - 07_..._RU.md)
│   └── ZH/                      # Chinese context (01_..._ZH.md - 07_..._ZH.md)
├── scripts/                     # Automation tools
│   ├── build_ai_context.py      # Script that builds the aggregated context
│   └── sync_upstream.py         # Script for safely updating the sources from GitHub
└── src/                         # Source materials
    ├── original_docs/           # Cleaned snapshot of the original documentation (ZH)
    ├── re_deltas/               # Reverse engineering data (ATS3085S / DT G1)
    └── transl/                  # Localization files
        ├── EN/                  # English translation
        └── RU/                  # Russian translation
```

---

## 🛠️ Usage instructions

### 1. Safe update of the Chinese sources (Upstream Sync)

The script `scripts/sync_upstream.py` downloads the current archive from GitHub, validates the structure, removes web junk (`.vuepress`, `i18n`, `package.json`) and atomically updates the `src/original_docs/` directory.

Run:
```bash
python scripts/sync_upstream.py
```

*Note: If the network connection is interrupted or the archive turns out to be damaged, the local sources in `src/original_docs/` will not be affected.*

### 2. Generating context files for AI

The script `scripts/build_ai_context.py` scans the files from `original_docs/`, `transl/` and `re_deltas/`, places system separators and produces the final files in the `ai_context/` directory.

Run:
```bash
python scripts/build_ai_context.py
```

Structure of the generated files in `ai_context/<LANG>/`:
* `01_glyphix_framework_core_<LANG>.md` - Framework core, manifests, lifecycle.
* `02_glyphix_ui_components_<LANG>.md` - UI components, Flexbox, styles, animations.
* `03_glyphix_system_api_<LANG>.md` - `@system.*` modules and system calls.
* `04_glyphix_CxxDev_<LANG>.md` - Guide to native C++ development.
* `05_glyphix_tutorials_<LANG>.md` - Tutorials and examples.
* `06_glyphix_hardware_deltas_and_undoc_funcs_<LANG>.md` - ATS3085S hardware limits, API dump, differences between facts and documentation.
* `07_glyphix_toolchain_pkg_<LANG>.md` - Specification of the `gx build` builder and the `.pkg` structure.

---

## ⚠️ Rules for recording reverse engineering (`src/re_deltas/`)

All results of analyzing the firmware binaries, disassembler work, analysis of RAM/Flash dumps and Bluetooth protocols are placed in the `src/re_deltas/` folder. 

Data from `src/re_deltas/` is automatically injected into the file `06_glyphix_hardware_deltas_and_undoc_funcs_*.md` for **all** language branches (`EN`, `RU`, `ZH`). This guarantees that the LLM will be informed about the hardware limitations of the real watch regardless of the chosen conversation language.

---

## ⚖️ License and Attribution

* The original documentation of the Glyphix framework belongs to **XFaith Tech / Glyphix OS**.
* Original repository: [`glyphix-os/web-docs`](https://github.com/glyphix-os/web-docs)
* This repository is a modified fork intended solely for research purposes, software compatibility and reverse engineering of wearable electronics.
