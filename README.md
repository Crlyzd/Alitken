# Alitken Media Converter (Universal Edition)

**Alitken Media Converter** is an interactive, fast, and feature-rich PowerShell-based media conversion utility. It detects hardware acceleration capabilities automatically, handles missing dependencies dynamically with an inline transfer speed progress bar, and integrates with the Windows shell for right-click media conversions.

It is designed to run either as a modular PowerShell script or compiled into a single, standalone executable (`AlitConverter.exe`) using `ps2exe`.

---

## 🌟 Features

*   **⚡ Automated Hardware Acceleration**:
    *   Queries your system's GPU (supports **NVIDIA NVENC**, **AMD AMF**, **Intel QuickSync**).
    *   Configures optimal encoding arguments and falls back to CPU (software) encoding if no compatible GPU is detected.
    *   Supports H.264, H.265/HEVC, and AV1 video codecs.
*   **📦 Smart Dependency Installer**:
    *   Detects if `ffmpeg`, `ffprobe`, or `magick` (ImageMagick) are present in your local `bin/` folder or the system PATH.
    *   Automatically downloads and extracts missing portable dependencies (utilizing `HttpClient` streaming chunks).
    *   Displays a real-time inline console progress bar with current download speed (MB/s), downloaded size, and percentage.
*   **🖱️ Windows Context Menu (SendTo Integration)**:
    *   Includes a built-in installer option to create a "SendTo" shortcut.
    *   Right-click any file or folder -> **Send to** -> **Alitken Converter** for instant conversion.
*   **🛠️ Interactive CLI Config Menus**:
    *   Clean menu system to specify video resolution, bitrate settings, and target codecs.
    *   Optionally resize images or convert files individually or in batches.
*   **🔒 High Performance & Preservation**:
    *   Performs lossless audio copy (`-c:a copy`) during video transcode to preserve audio quality.
    *   Auto-resolves filename conflicts (appending suffixes like `_1`, `_2` if output files exist).

---

## 📁 Repository Structure

```tree
Alitken/
├── AlitConverter.ps1       # Bundled standalone PowerShell script
├── AlitConverter.exe       # Compiled Windows executable
├── build.ps1               # Compiler script (Bundles src/ and runs ps2exe)
├── src/
│   ├── Assets/
│   │   └── icon.ico        # Custom executable icon
│   ├── Processors/
│   │   ├── ImageProcessor.ps1  # Image conversion using ImageMagick
│   │   └── VideoProcessor.ps1  # Video conversion & progress tracking using FFmpeg
│   ├── System/
│   │   ├── DependencyChecker.ps1   # Local and system environment parser
│   │   ├── DependencyInstaller.ps1 # Dynamic chunk downloader with progress bar
│   │   └── GpuDetector.ps1         # GPU encoder mapping (NVENC, AMF, QSV)
│   ├── UI/
│   │   ├── ConfigMenus.ps1      # Dynamic prompt and options state machine
│   │   ├── ConflictResolver.ps1 # Safe file overwriting logic
│   │   └── MenuHelper.ps1       # Standardized console UI options and menus
│   └── AlitConverter.template.ps1 # Main template used for bundling
```

---

## 🚀 Getting Started

### Prerequisites

*   **Operating System**: Windows 10 / 11
*   **PowerShell**: Version 5.1 or higher
*   **Internet Access**: Only required during the first run to automatically fetch portable dependencies if not installed.

### How to Run

1.  **Launch the Interactive Menu**:
    *   Double-click [AlitConverter.exe](file:///d:/VS/Alitken/Alitken/Alitken/AlitConverter.exe) or execute [AlitConverter.ps1](file:///d:/VS/Alitken/Alitken/Alitken/AlitConverter.ps1).
    *   Select **Option 1** to register the tool in your Windows **Send To** context menu.

2.  **Convert Media**:
    *   Select any video/image file or a directory in File Explorer.
    *   Right-click -> **Send to** -> **Alitken Converter**.
    *   Choose your desired codec, output resolution, and bitrate settings in the interactive console menu.

---

## 🔧 Building / Packaging

You can compile the modules from the `src/` directory into the single script/executable by running:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

The script will:
1.  Bundle all modules from `src/` into a single standalone [AlitConverter.ps1](file:///d:/VS/Alitken/Alitken/Alitken/AlitConverter.ps1).
2.  If the `ps2exe` module is installed, compile [AlitConverter.ps1](file:///d:/VS/Alitken/Alitken/Alitken/AlitConverter.ps1) to [AlitConverter.exe](file:///d:/VS/Alitken/Alitken/Alitken/AlitConverter.exe) using the custom icon at `src/Assets/icon.ico`.

---

## 📝 Configuration Options

### Video Codec Selection
*   **H.264** (AVC) - Highly compatible, supported on nearly all devices.
*   **H.265** (HEVC) - Advanced compression, excellent quality-to-size ratio.
*   **AV1** - Next-generation open-source codec with superior efficiency.

### Hardware Acceleration Mappings
*   **NVIDIA**: `h264_nvenc`, `hevc_nvenc`, `av1_nvenc`
*   **AMD**: `h264_amf`, `hevc_amf`, `av1_amf`
*   **Intel**: `h264_qsv`, `hevc_qsv`, `av1_qsv`
*   **CPU (Software Fallback)**: `libx264`, `libx265`, `libaom-av1`

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](file:///d:/VS/Alitken/Alitken/Alitken/LICENSE) file for details.
