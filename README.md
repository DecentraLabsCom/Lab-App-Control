---
description: Automatically open and close Windows lab apps based on user sessions.
---

# Lab App Control

[![Tests](https://github.com/DecentraLabsCom/Lab-App-Control/actions/workflows/tests.yml/badge.svg)](https://github.com/DecentraLabsCom/Lab-App-Control/actions/workflows/tests.yml)
[![Security Scan](https://github.com/DecentraLabsCom/Lab-App-Control/actions/workflows/codeql.yml/badge.svg)](https://github.com/DecentraLabsCom/Lab-App-Control/actions/workflows/codeql.yml)
[![Release](https://github.com/DecentraLabsCom/Lab-App-Control/actions/workflows/release.yml/badge.svg)](https://github.com/DecentraLabsCom/Lab-App-Control/actions/workflows/release.yml)

**dLabAppControl** is an AutoHotKey script designed to auto-control the lab app lifecycle based on user session events (RDP) in the DecentraLabs lab provider machine.

This single-instance AHK v2 script launches your lab Windows desktop control app on connect, keeps it foregrounded, and closes it automatically when the user session changes (e.g., disconnects).

> **Single Application Mode:**\
> `dLabAppControl.exe "WindowClass" "C:\path\to\app.exe"`\
> `dLabAppControl.exe "Chrome_WidgetWin_1" "C:\Program Files\Google\Chrome\Application\chrome.exe"`\
> (Browsers auto-add `--kiosk --incognito` in single mode)\
> `dLabAppControl.exe "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --app=http://127.0.0.1:8000"`
>
> **Dual Application Mode (Tabbed Container):**\
> `dLabAppControl.exe @dual "Class1" "C:\path\to\app1.exe" "Class2" "C:\path\to\app2.exe"`\
> `dLabAppControl.exe @dual "Class1" "app1.exe" "Class2" "app2.exe" @tab1="Camera" @tab2="Viewer"`\
> `dLabAppControl.exe @dual "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --app=http://127.0.0.1:8000" "MozillaWindowClass" "\"C:\Program Files\Mozilla Firefox\firefox.exe\" --private-window"`\
> (Note: Browser auto-kiosk disabled in dual mode)
>
> **Advanced usage with custom close:**\
> `dLabAppControl.exe "WindowClass" "app.exe" @close-button="Button2"`\
> `dLabAppControl.exe "LVWindow" "myVI.exe" @close-coords="330,484"`
>
> **Test mode (for debugging custom close methods):**\
> `dLabAppControl.exe "LVWindow" "myVI.exe" @close-coords="330,484" @test`\
> `dLabAppControl.exe "Notepad" "notepad.exe" @close-button="Button2" @test`

***

### 🚀 Features

* **Single & Dual Application Modes**\
  Run a single app or two apps side-by-side in a tabbed container with customizable tab titles.
* **Command-Line Parameter Support**\
  Launch applications with full command-line parameters (e.g., Chrome with --app, --incognito flags). Automatically detects simple paths vs. full commands.
* **Single instance & CLI args**\
  Runs as a single instance and takes window class and app executable path arguments.
* **Smart auto-startup**\
  If the target window isn't found, it launches the lab control app and waits (up to 6 s) for the window.
* **Window management & hardening**\
  Activates and maximizes the window; removes minimize and close buttons to prevent user-initiated closure.
* **Session-aware auto-shutdown**\
  Automatically closes apps when RDP session changes are detected using **WTS Session Notifications** (primary method) with event log polling as fallback.
* **Dual app container**\
  Embed two applications in a single maximized window with tabs for easy switching between them.
* **Customizable tab titles**\
  Set custom names for tabs in dual mode (e.g., "Camera" and "Viewer" instead of default "Application 1" and "Application 2").
* **Hybrid detection system**\
  Primary: Real-time WTS session notifications for instant response. Fallback: Event log monitoring via native `wevtutil` for compatibility.
* **Custom close methods**\
  Supports graceful app closure via ClassNN controls or X,Y coordinates for LabVIEW/custom apps.
* **Smart coordinate handling**\
  Automatically converts WindowSpy CLIENT coordinates to screen coordinates with robust fallbacks.
* **Enhanced logging**\
  Detailed logs saved to script directory with configurable verbosity for debugging.
* **Modular architecture**\
  Code organized in separate library modules for maintainability and reusability.
* **Lightweight integration**\
  No changes to the lab application; acts as a wrapper on the provider's Windows machine. Optional compile to EXE.

***

### 🔧 Installation and Use

#### **Option 1: Using the executable**

1. Download `dLabAppControl.exe`.
2.  Run with:

    ```batch
    REM Single app - Basic usage
    dLabAppControl.exe "YourWindowClass" "C:\Path\To\LabControl.exe"

    REM Single app - Browser (auto-kiosk)
    dLabAppControl.exe "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --app=http://127.0.0.1:8000"
    REM (Automatically adds --kiosk --incognito)

    REM Single app - With custom close button (ClassNN)
    dLabAppControl.exe "Notepad" "C:\Windows\System32\notepad.exe" @close-button="Button2"

    REM Single app - With custom close coordinates (LabVIEW/custom apps)
    dLabAppControl.exe "LVWindow" "C:\Path\To\myVI.exe" @close-coords="330,484"
    
    REM Dual app - Two apps in tabbed container
    dLabAppControl.exe @dual "Class1" "C:\Path\To\app1.exe" "Class2" "C:\Path\To\app2.exe"
    
    REM Dual app - With parameters and custom tab titles
    dLabAppControl.exe @dual "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --app=http://127.0.0.1:8000" "MozillaWindowClass" "\"C:\Program Files\Mozilla Firefox\firefox.exe\" --private-window" @tab1="Web App" @tab2="Private Browser"
    ```

#### **Option 2: Download and compile script**

1. Install AutoHotKey v2.
2. Place `dLabAppControl.ahk` and the `lib/` folder on the provider machine.
3.  (Optional) Compile:

    ```batch
    "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in "dLabAppControl.ahk" /out "dLabAppControl_v2.exe"
    ```
4.  Run with:

    ```batch
    REM Single app mode
    "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" dLabAppControl.ahk "YourWindowClass" "C:\Path\To\LabControl.exe"
    
    REM Dual app mode
    "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" dLabAppControl.ahk @dual "Class1" "app1.exe" "Class2" "app2.exe"
    ```

#### **Command-Line Options**

| Option | Description | Required | Example |
|--------|-------------|----------|---------|
| `@dual` | Enable dual app mode (tabbed container) | **Yes** (for dual mode) | `@dual` |
| `@tab1="Title"` | Custom title for first tab (dual mode only) | No | `@tab1="Camera"` |
| `@tab2="Title"` | Custom title for second tab (dual mode only) | No | `@tab2="Viewer"` |
| `@close-button="ClassNN"` | Custom close button control (single mode only) | No | `@close-button="Button2"` |
| `@close-coords="X,Y"` | Custom close coordinates in CLIENT space (single mode only) | No | `@close-coords="330,484"` |
| `@test` | Test custom close method after 5 seconds (single mode only) | No | `@test` |

**Notes:**
- Cannot use both `@close-button` and `@close-coords` at the same time
- Custom close options only apply to single application mode
- Use `@` prefix to distinguish dLabAppControl options from application parameters

#### **Command-Line Parameter Support**

The script automatically detects whether you're providing a simple executable path or a full command with parameters.

**Simple Path (paths with spaces MUST be quoted):**
```batch
REM Path without spaces - quotes optional but recommended
dLabAppControl.exe "Notepad" "C:\Windows\System32\notepad.exe"

REM Path WITH spaces - quotes REQUIRED
dLabAppControl.exe "Chrome_WidgetWin_1" "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

**Full Command with Parameters:**
```batch
REM CMD/Batch syntax - use backslash to escape inner quotes
dLabAppControl.exe "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --app=http://127.0.0.1:8000 --incognito"

REM Firefox with private window
dLabAppControl.exe "MozillaWindowClass" "\"C:\Program Files\Mozilla Firefox\firefox.exe\" --private-window"
```

**Automatic Browser Kiosk Mode:**

dLabAppControl automatically detects when you're launching a browser (Chrome, Edge, Firefox) and adds kiosk and private browsing flags **if they're not already present**. This simplifies deployment - you don't need to manually specify these flags in most cases.

**Supported Browsers:**
- **Chrome** (`chrome.exe`): Automatically adds `--kiosk --incognito`
- **Edge** (`msedge.exe`): Automatically adds `--kiosk --inprivate`
- **Firefox** (`firefox.exe`): Automatically adds `-kiosk -private-window`

**Examples:**
```batch
REM This simple command...
dLabAppControl.exe "Chrome_WidgetWin_1" "C:\Program Files\Google\Chrome\Application\chrome.exe"

REM ...automatically becomes:
REM dLabAppControl.exe "Chrome_WidgetWin_1" "C:\Program Files\Google\Chrome\Application\chrome.exe --kiosk --incognito"

REM If you specify custom parameters, kiosk flags are still added (unless already present):
dLabAppControl.exe "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" http://127.0.0.1:8000"
REM Becomes: chrome.exe --kiosk --incognito http://127.0.0.1:8000

REM If you already have kiosk flags, they won't be duplicated:
dLabAppControl.exe "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --kiosk http://127.0.0.1:8000"
REM Stays unchanged (--kiosk already present)
```

**To disable automatic browser enhancement:**
Edit `lib\Config.ahk` and set:
```ahk
global AUTO_BROWSER_KIOSK := false
```

**How it works:**
- **Detection**: The script checks if the argument contains spaces and quotes to determine if it's a full command
- **Browser Enhancement**: If enabled, browsers are detected by executable name and kiosk flags are automatically added
- **Validation**: Only the executable path is validated for existence; parameters are passed through unchanged
- **Execution**: The full command string is passed to AutoHotkey's `Run()` function
- **Compatibility**: Simple paths work exactly as before - no breaking changes

**Important Rules:**
1. **Paths with spaces MUST be quoted** - Windows will split unquoted paths at spaces
2. **Commands with parameters need inner quotes** around the executable path
3. **CMD/Batch**: Use `\"` (backslash-quote) to escape inner quotes
4. **Guacamole Remote App**: Use regular quotes, no escaping needed
   - Example: `Chrome_WidgetWin_1 "C:\Program Files\Google\Chrome\Application\chrome.exe" --app=http://127.0.0.1:8000 --incognito`

***

### ⚙️ Configuration

The script includes several configuration constants that can be modified in `lib\Config.ahk`:

#### **Core Settings**

* **`POLL_INTERVAL_MS`**: Fallback monitoring interval in milliseconds (default: **5000** = 5 seconds)
* **`STARTUP_TIMEOUT`**: How long to wait for app window to appear (default: **6** seconds)
* **`ACTIVATION_RETRIES`**: Number of retries for window activation when Groupy temporarily hides window (default: **5**)
* **`CloseOnEventIds`**: RDP event IDs that trigger app closure (default: `[23, 24, 39, 40]`)
  * `23`: Logoff, `24`: Disconnect, `39`: Session disconnect, `40`: Reconnect

#### **Browser Auto-Configuration**

* **`AUTO_BROWSER_KIOSK`**: Automatically add kiosk and incognito flags to browsers (default: `true`)
* **`BROWSER_KIOSK_FLAGS`**: Map of browser executables to their default kiosk flags
  * Chrome: `--kiosk --incognito`
  * Edge: `--kiosk --inprivate`
  * Firefox: `-kiosk -private-window`

#### **Debugging & Testing**

* **`VERBOSE_LOGGING`**: Enable detailed polling logs (default: `true` for debugging, `false` for production)
* **`SILENT_ERRORS`**: Suppress error MsgBox popups - log only (default: `false`)
* **`TEST_MODE`**: Activated via command-line parameter `@test` - test custom close after 5 seconds

#### **Custom Close Methods**

The script supports three ways to close applications gracefully:

1. **Standard cascade**: `WinClose` → `WM_SYSCOMMAND` → `WM_CLOSE` → `ProcessClose`
2.  **ClassNN control**: For Win32 apps with accessible controls

    ```powershell
    dLabAppControl.exe "Notepad" "notepad.exe" @close-button="Button2"
    ```
3.  **Client coordinates**: For LabVIEW/custom apps (use WindowSpy CLIENT coordinates)

    ```powershell
    dLabAppControl.exe "LVWindow" "myVI.exe" @close-coords="330,484"
    ```

**Important:** Cannot use both `@close-button` and `@close-coords` at the same time.

#### **Dual Application Mode**

Run two applications side-by-side in a tabbed container window. **Requires** the `@dual` flag to be explicitly specified.

**Features:**
- 📊 **Tabbed interface**: Switch between apps with modern flat tabs
- 🎯 **Custom titles**: Name tabs meaningfully (e.g., "Camera", "Control Panel")
- 🔄 **Synchronized lifecycle**: Both apps close together when session ends
- 🪟 **Single window**: Container maximizes to full screen, apps embedded inside
- 🚫 **Protected apps**: Alt+F4 blocked on embedded applications

**Use Cases:**
- Camera control + Live viewer
- Instrument control + Data visualization
- Configuration tool + Monitoring dashboard
- Any two related lab applications

**Example:**
```batch
REM Basic dual mode (@dual flag required)
dLabAppControl.exe @dual "CameraClass" "camera.exe" "ViewerClass" "viewer.exe"

REM With custom tab titles
dLabAppControl.exe @dual "DobotLab" "DobotLab.exe" "MozillaWindowClass" "firefox.exe" @tab1="Robot Control" @tab2="Web Interface"
```

#### **TEST MODE Usage**

Test your custom close coordinates/controls before deployment:

```batch
REM Test coordinate-based close
dLabAppControl.exe "LVWindow" "myVI.exe" @close-coords="330,484" @test

REM Test control-based close  
dLabAppControl.exe "Notepad" "notepad.exe" @close-button="Button2" @test
```

When `@test` flag is used:
- ✅ App launches normally
- ⏱️ After 5 seconds, custom close method is tested
- ✅ Success: App closes gracefully (check log for confirmation)
- ❌ Failure: App remains open (check log and adjust coordinates/control)

#### **Finding Window Information**

Use the included **WindowSpy.exe** tool to identify:

* **Window Class** (`ahk_class`): Used as first parameter
* **ClassNN** controls: For control-based closing
* **CLIENT coordinates**: Most reliable for custom apps (not Screen or Window coordinates)

> **Note**: WindowSpy is a utility from the [AutoHotkey project](https://github.com/AutoHotkey/AutoHotkey). The executable is included here for convenience only.

#### **Log Files**

* Location: Same directory as script/exe (`dLabAppControl.log`)
* Contains: Startup info, activation retries, coordinate calculations, event detection, close attempts
* Enable `VERBOSE_LOGGING` for detailed polling information

***

### 🌐 Integration with DecentraLabs

Run this script **when a user session starts** (e.g., on Guacamole/RDP connect).\
It will keep the lab app active and **will close it on the next RDP session event** (typically the disconnect at the end of the session).

#### **Recommended Setup: Guacamole + Windows Remote App**

For optimal security and user experience, use this script in combination with:

* **Apache Guacamole** for web-based remote access
* **Windows Remote App connections** to expose individual applications
* **Controlled lab environment** where users access only specific tools

This setup provides:

* ✅ **Application isolation**: Users see only the lab app, not the full desktop
* ✅ **Automatic lifecycle management**: Apps start/stop with user sessions
* ✅ **Enhanced security**: No access to underlying Windows system
* ✅ **Seamless integration**: Works transparently with Guacamole's session management

#### **Guacamole Remote App Configuration**

When configuring dLabAppControl in Guacamole Remote App connections, use this syntax:

**Remote Application Program:**
```
C:\Path\To\dLabAppControl.exe
```

**Remote Application Parameters (simple path):**
```
Chrome_WidgetWin_1 "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

**Remote Application Parameters (with command-line arguments):**
```
Chrome_WidgetWin_1 "C:\Program Files\Google\Chrome\Application\chrome.exe" --app=http://127.0.0.1:8000 --incognito
```

**Important Notes for Guacamole:**
- ✅ **Quote paths with spaces** - use regular double quotes
- ❌ **Do NOT escape inner quotes** - Guacamole passes arguments directly without shell interpretation
- ✅ **Parameters are space-separated** - each argument naturally separated
- ✅ **Works with both single and dual mode** - use `@dual` flag as first parameter for dual mode

**Example Guacamole Configurations:**

*Single App - Chrome (auto-kiosk):*
- **Program**: `C:\LabApps\dLabAppControl.exe`
- **Parameters**: `Chrome_WidgetWin_1 "C:\Program Files\Google\Chrome\Application\chrome.exe" --app=http://lab.example.com`
- (Automatically adds `--kiosk --incognito` in single mode)

*Dual App - Camera + Viewer:*
- **Program**: `C:\LabApps\dLabAppControl.exe`
- **Parameters**: `@dual CameraClass "C:\LabApps\camera.exe" ViewerClass "C:\LabApps\viewer.exe" @tab1="Camera Control" @tab2="Live View"`

***

### 📦 Architecture

The script is organized into focused modules in the `lib/` directory:

```
Lab App Control/
├── dLabAppControl.ahk              # Main entry point
├── lib/                            # Library modules
│   ├── Config.ahk                  # Configuration and constants
│   ├── Utils.ahk                   # Utility functions
│   ├── WindowClosing.ahk           # Window closing logic
│   ├── RdpMonitoring.ahk           # RDP event monitoring
│   ├── SingleAppMode.ahk           # Single app implementation
│   ├── DualAppMode.ahk             # Dual app container
│   └── README.md                   # Module documentation
└── tests/
  ├── FakeApp.ahk                 # Lightweight GUI stub used in smoke tests
  └── SmokeTest_DualAppMode.ahk   # Minimal DualAppMode smoke test harness
```

See `lib/README.md` for detailed module documentation.

### ✅ Smoke Tests

The `tests/` folder contains a lightweight smoke test that launches **DualAppMode** with two simulated applications and verifies key log markers. Run it with AutoHotkey v2 (64-bit recommended):

```powershell
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" tests\SmokeTest_DualAppMode.ahk
```

The harness:

- Launches two `FakeApp.ahk` instances with predictable window classes.
- Starts `CreateDualAppContainer` with those apps and waits ~8 seconds.
- Checks `tests\dLabAppControl.log` for the expected lifecycle messages.
- Returns exit code **0** on success (non-zero otherwise) so you can wire it into CI or scripted regression checks.
