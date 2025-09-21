---
description: Automatically open and close Windows lab apps based on user sessions.
---

# Lab Control

**dLabAppControl** is an AutoHotKey script designed to auto-control the lab app lifecycle based on user session events (RDP) in the DecentraLabs lab provider machine.

This single-instance AHK v2 script that launches your lab control app on connect, keeps it foregrounded, and closes it automatically when the user session changes (e.g., disconnects).

> Usage:\
> `dLabAppControl.exe "WindowClass""C:\path\to\app.exe"`
>
> or
>
> `dLabAppControl.ahk "window ahk_class" "C:\path\to\app.exe"`

***

### 🚀 Features

* **Single instance & CLI args**\
  Runs as a single instance and takes two arguments: target window class and app executable path.
* **Smart auto-startup**\
  If the target window isn’t found, it launches the lab control app and waits (up to 5 s) for the window.
* **Window management & hardening**\
  Activates and maximizes the window; removes minimize and close buttons to prevent user-initiated closure.
* **Session-aware auto-shutdown**\
  Automatically closes the app when a **new RDP session event** is detected (e.g., connect/reconnect/disconnect from _Microsoft-Windows-TerminalServices-LocalSessionManager/Operational_, IDs 24/40).
* **Background monitoring (5 s interval)**\
  Runs silently, polling every 5 s via a hidden PowerShell call to the Windows event log.
* **Lightweight integration**\
  No changes to the lab application; acts as a wrapper on the provider’s Windows machine. Optional compile to EXE.

***

### 🔧 Installation and Use

First option (using the executable):

1. Download dLabAppControl.exe.
2.  Run with:

    ```powershell
    dLabAppControl.exe "YourWindowClass" "C:\Path\To\LabControl.exe"
    ```

Second option (download and compile script)

1. Install AutoHotKey v2.
2. Place `dLabAppControl.ahk` on the provider machine.
3.  (Optional) Compile:

    ```powershell
    Ahk2Exe.exe /in dLabAppControl.ahk /out dLabAppControl.exe
    ```
4.  Run with:

    ```powershell
    AutoHotkey.exe dLabAppControl.ahk "YourWindowClass" "C:\Path\To\LabControl.exe"
    ```

***

### ⚙️ Configuration

* **Polling interval**: currently **5,000 ms** (defined in the script’s timer).
  * To change it, edit the script (or add a third CLI arg and wire it to the timer).
* **Target selection**: the script matches by **window class** (`ahk_class`). Use AHK’s _Window Spy_ tool (https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.19; also included in this repo for easiness) to find it.

***

### 🌐 Integration with DecentraLabs

Run this script **when a user session starts** (e.g., on Guacamole/RDP connect).\
It will keep the lab app active and **will close it on the next RDP session event** (typically the disconnect at the end of the session).