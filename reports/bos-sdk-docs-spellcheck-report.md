# BOS SDK Docs Spellcheck Report

Scope:
- Scanned `81` text files under `C:\bos\bos-sdk\docs` (`.md` and `.json`)
- Ignored the binary image file (`.png`) because it is not spell-checkable as text
- Used `cspell` for the initial pass and then manually filtered out obvious product names, acronyms, API names, and other domain-specific false positives

Artifacts:
- Raw tool output: [bos-sdk-cspell-raw.txt](C:/Agents/user_experience_tester/reports/bos-sdk-cspell-raw.txt)
- Source tree reviewed: [docs](C:/bos/bos-sdk/docs)

Summary:
- Raw `cspell` findings: `1403`
- High-confidence spelling items worth correcting: `34` grouped findings
- I did **not** modify the source files in this pass

## High-Confidence Candidates

| File | Line(s) | Current spelling | Suggested correction | Notes |
|---|---:|---|---|---|
| [04_SDK Contents/05_BOS_Middleware/index.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/05_BOS_Middleware/index.md) | 6 | `tentsotrrent` | `Tenstorrent` | Same line also contains `APis`, which likely should be `APIs`. |
| [04_SDK Contents/11_Tools/L1_buffer_visualizer_intro.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/11_Tools/L1_buffer_visualizer_intro.md) | 9, 34, 38, 75, 79 | `heigth` | `height` | Appears in repeated `<img>` attributes. |
| [04_SDK Contents/11_Tools/tracy.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/11_Tools/tracy.md) | 14, 34, 97, 110, 124 | `heigth` | `height` | Same typo repeated in image markup. |
| [04_SDK Contents/Compiler/Stage1.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/Compiler/Stage1.md) | 95, 99 | `Sofware` | `Software` | High-confidence typo. |
| [04_SDK Contents/Compiler/Stage1.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/Compiler/Stage1.md) | 100 | `Opensource` | `Open Source` or `Open-Source` | Needs style choice. |
| [04_SDK Contents/Compiler/Stage1.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/Compiler/Stage1.md) | 393 | `cmpiler` | `compiler` | Flagged directly by `cspell`. |
| [04_SDK Contents/Drivers/UMD.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/Drivers/UMD.md) | 48 | `separatelly` | `separately` | The full sentence may also want `build` -> `built`, but that is grammar rather than spelling. |
| [04_SDK Contents/Manual_model_development/index.md](C:/bos/bos-sdk/docs/04_SDK%20Contents/Manual_model_development/index.md) | 8 | `worflow` | `workflow` | Image asset path typo. |
| [04_SDK Contents/Manual_model_devlopment/_category_.json](C:/bos/bos-sdk/docs/04_SDK%20Contents/Manual_model_devlopment/_category_.json) | 6 | `devlopment` | `development` | Path/id typo; worth checking whether the directory name should also be aligned. |
| [06_Practical_examples/NPU programming guide.md](C:/bos/bos-sdk/docs/06_Practical_examples/NPU%20programming%20guide.md) | 2158 | `insalled` | `installed` | High-confidence typo. |
| [06_Practical_examples/NPU programming guide.md](C:/bos/bos-sdk/docs/06_Practical_examples/NPU%20programming%20guide.md) | 2360 | `implementaiton` | `implementation` | High-confidence typo. |
| [06_Practical_examples/NPU programming guide.md](C:/bos/bos-sdk/docs/06_Practical_examples/NPU%20programming%20guide.md) | 2435 | `excution` | `execution` | High-confidence typo. |
| [06_Practical_examples/NPU programming guide.md](C:/bos/bos-sdk/docs/06_Practical_examples/NPU%20programming%20guide.md) | 3923, 4274 | `subraction` | `subtraction` | Repeated typo. |
| [06_Supported_Models/02_Vision/FastOFT.md](C:/bos/bos-sdk/docs/06_Supported_Models/02_Vision/FastOFT.md) | 78 | `scenairos`, `avaliable` | `scenarios`, `available` | Both appear in the same comment line. |
| [06_Supported_Models/02_Vision/SSR.md](C:/bos/bos-sdk/docs/06_Supported_Models/02_Vision/SSR.md) | 7, 24 | `Envinronment` | `Environment` | Repeated typo in section text. |
| [12_Downloads.md](C:/bos/bos-sdk/docs/12_Downloads.md) | 20 | `enviroment` | `environment` | High-confidence typo. |
| [Getting_Started/_Standalone_SoC/index.md](C:/bos/bos-sdk/docs/Getting_Started/_Standalone_SoC/index.md) | 34 | `upgrated` | `upgraded` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Host_side_setup/Bare-metal.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/Bare-metal.md) | 10 | `confguration` | `configuration` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Host_side_setup/Docker-based(x86).md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/Docker-based(x86).md) | 8 | `enviroment` | `environment` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Host_side_setup/Docker-based(x86).md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/Docker-based(x86).md) | 38 | `dockr` | `docker` | Appears in a command example. |
| [Getting_Started/NN_Accelerator/Host_side_setup/index.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/index.md) | 21 | `neverthe less` | `nevertheless` | Looks like a split-word typo. |
| [Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md) | 8 | `recepis` | `recipes` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md) | 70, 230 | `Therfore` | `Therefore` | Repeated typo. |
| [Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md) | 76, 236 | `neccessary` | `necessary` | Repeated typo. |
| [Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Host_side_setup/Yocto_based(ARM).md) | 138, 298 | `roofts` | likely `rootfs` | Needs a quick human check, but `rootfs` looks most plausible in context. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/01_Evaluation_Board_Overview.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/01_Evaluation_Board_Overview.md) | 46, 52, 70, 81, 108 | `heigth` | `height` | Repeated in image markup. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/02_How_to_Setup_Board.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/02_How_to_Setup_Board.md) | 15, 65 | `heigth` | `height` | Repeated in image markup. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/02_How_to_Setup_Board.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/02_How_to_Setup_Board.md) | 132 | `promt` | `prompt` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 19, 90, 106, 182, 196 | `heigth` | `height` | Repeated in image markup. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 23 | `dowloaded` | `downloaded` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 156 | `EABLE`, `Faastboot` | likely `EAGLE`, `Fastboot` | `EAGLE` is inferred from nearby board naming. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 160 | `anroid` | `android` | Appears in file name `51-anroid.rules`. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 192 | `DONW` | likely `DOWN` | Ambiguous in isolation, but `DOWN` looks most likely. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 251 | `Faastboot` | `Fastboot` | Same typo appears earlier in the file. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 262 | `serieal` | `serial` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/03_How_to_Fuse_New_Image.md) | 274 | `devict` | `device` | High-confidence typo. |
| [Getting_Started/NN_Accelerator/Target_Device_setup/index.md](C:/bos/bos-sdk/docs/Getting_Started/NN_Accelerator/Target_Device_setup/index.md) | 3 | `Traget` | `Target` | Typo is inside the page slug. |
| [Supported_NPU_SoCs/Eagle_N.md](C:/bos/bos-sdk/docs/Supported_NPU_SoCs/Eagle_N.md) | 12 | `adelivering` | `delivering` | Reads like a missing space or extra `a`. |

## Notes

- I intentionally excluded many `cspell` hits such as `TTNN`, `TTIR`, `ONNX`, `Qwen`, `Tensix`, `Fastboot`, `Yocto`, `LPDDR`, and similar technical or brand terms because they look valid in this documentation context.
- If you want, the next pass can turn this report into a patch set and apply only the high-confidence corrections while leaving the ambiguous items (`roofts`, `DONW`, and `Opensource` style choice) for review.
