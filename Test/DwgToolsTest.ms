#NoEnv
#SingleInstance Force
SendMode Input
SetTitleMatchMode, 2

; ============================================================
; Description:
; Magic key for Chrome / YouTube / ChatGPT / Gemini.
; ============================================================

magic_key := "F1"

global chatgpt_exe_path := IniReadValue("Settings", "ChatGPTExePath", "")
global settings_ini_path := A_ScriptDir . "\magic-key.ini"

Hotkey, %magic_key%, MagicKeyHandler

; -- return


; ============================================================
; Description:
; Main dispatcher of magic key behavior.
; ============================================================

function MagicKeyHandler()
{
    hwnd := WinActive("A")

    if (hwnd == 0) then
    (
        return
    )

    WinGetTitle, window_title, ahk_id %hwnd%
    WinGet, process_name, ProcessName, ahk_id %hwnd%

    if (IsChatGptWindow(process_name, window_title)) then
    (
        ActivateGemini()
        return
    )

    if (IsGeminiWindow(window_title)) then
    (
        ActivateChatGpt()
        return
    )

    if (process_name != "chrome.exe") then
    (
        return
    )

    active_url := GetChromeUrl()

    selected_text := GetSelectedText()

    is_youtube := InStr(active_url, "youtube.com")

    if (is_youtube) then
    (
        HandleYoutube(selected_text)
    )
    else
    (
        HandleGoogle(selected_text)
    )

    ; -- return
}


; ============================================================
; Description:
; Detect ChatGPT windows.
; ============================================================

function IsChatGptWindow(process_name, window_title)
{
    if (process_name == "ChatGPT.exe") then
    (
        return true
    )

    if (window_title == "") then
    (
        return false
    )

    if (InStr(window_title, "ChatGPT")) then
    (
        return true
    )

    return false
}


; ============================================================
; Description:
; Detect Gemini browser window.
; ============================================================

function IsGeminiWindow(window_title)
{
    if (InStr(window_title, "Gemini")) then
    (
        return true
    )

    return false
}


; ============================================================
; Description:
; Activate Gemini tab or open Gemini.
; ============================================================

function ActivateGemini()
{
    SetTitleMatchMode, 2

    if WinExist("Gemini") then
    (
        WinActivate
        return
    )

    if WinExist("ahk_exe chrome.exe") then
    (
        WinActivate

        Sleep, 150

        Send, ^t
        Sleep, 100

        SendInput, https://gemini.google.com/app
        Sleep, 50

        Send, {Enter}

        return
    )

    Run, chrome.exe "https://gemini.google.com/app"

    ; -- return
}


; ============================================================
; Description:
; Activate ChatGPT app or browser.
; ============================================================

function ActivateChatGpt()
{
    global chatgpt_exe_path

    if WinExist("ahk_exe ChatGPT.exe") then
    (
        WinActivate
        return
    )

    if (chatgpt_exe_path == "") then
    (
        chatgpt_exe_path := BrowseForChatGptExe()

        if (chatgpt_exe_path == "") then
        (
            return
        )
    )

    if (!FileExist(chatgpt_exe_path)) then
    (
        chatgpt_exe_path := BrowseForChatGptExe()

        if (chatgpt_exe_path == "") then
        (
            return
        )
    )

    Run, % """" . chatgpt_exe_path . """"

    ; -- return
}


; ============================================================
; Description:
; Ask user to browse ChatGPT executable.
; ============================================================

function BrowseForChatGptExe()
{
    global settings_ini_path

    FileSelectFile, selected_file, 3,, Select ChatGPT.exe, Executable (*.exe)

    if (selected_file == "") then
    (
        return ""
    )

    IniWrite, %selected_file%, %settings_ini_path%, Settings, ChatGPTExePath

    return selected_file
}


; ============================================================
; Description:
; Handle behavior outside YouTube.
; ============================================================

function HandleGoogle(selected_text)
{
    if (selected_text != "") then
    (
        encoded_text := UriEncode(selected_text)
        search_url := "https://www.google.com/search?q=" . encoded_text

        OpenChromeNewTab(search_url)
    )
    else
    (
        OpenChromeNewTab("https://www.youtube.com")
    )

    ; -- return
}


; ============================================================
; Description:
; Handle behavior inside YouTube.
; ============================================================

function HandleYoutube(selected_text)
{
    if (selected_text != "") then
    (
        encoded_text := UriEncode(selected_text)
        search_url := "https://www.youtube.com/results?search_query=" . encoded_text

        Send, ^l
        Sleep, 100

        SendInput, %search_url%
        Sleep, 50

        Send, {Enter}
    )
    else
    (
        FocusYoutubeSearch()
    )

    ; -- return
}


; ============================================================
; Description:
; Focus YouTube search field.
; ============================================================

function FocusYoutubeSearch()
{
    Send, /
    ; -- return
}


; ============================================================
; Description:
; Open URL in new Chrome tab.
; ============================================================

function OpenChromeNewTab(url)
{
    Send, ^t
    Sleep, 100

    SendInput, %url%
    Sleep, 50

    Send, {Enter}

    ; -- return
}


; ============================================================
; Description:
; Get selected text from current application.
; ============================================================

function GetSelectedText()
{
    clipboard_backup := ClipboardAll
    Clipboard := ""

    Send, ^c
    ClipWait, 0.3

    selected_text := Clipboard

    Clipboard := clipboard_backup
    VarSetCapacity(clipboard_backup, 0)

    selected_text := Trim(selected_text)

    return selected_text
}


; ============================================================
; Description:
; Get current Chrome URL from address bar.
; ============================================================

function GetChromeUrl()
{
    clipboard_backup := ClipboardAll
    Clipboard := ""

    Send, ^l
    Sleep, 50

    Send, ^c
    ClipWait, 0.3

    active_url := Clipboard

    Send, {Esc}

    Clipboard := clipboard_backup
    VarSetCapacity(clipboard_backup, 0)

    return active_url
}


; ============================================================
; Description:
; Read value from ini file.
; ============================================================

function IniReadValue(section, key, default_value)
{
    global settings_ini_path

    IniRead, output_value, %settings_ini_path%, %section%, %key%, %default_value%

    return output_value
}


; ============================================================
; Description:
; Encode string for URL usage.
; ============================================================

function UriEncode(text)
{
    static chars := "0123456789ABCDEF"

    encoded_text := ""

    Loop, Parse, text
    (
        char := Asc(A_LoopField)

        if ((char >= 0x30 && char <= 0x39)
        ||  (char >= 0x41 && char <= 0x5A)
        ||  (char >= 0x61 && char <= 0x7A))
        then
        (
            encoded_text .= Chr(char)
        )
        else if (char == 0x20) then
        (
            encoded_text .= "+"
        )
        else
        (
            high := Floor(char / 16)
            low := Mod(char, 16)

            encoded_text .= "%"
            encoded_text .= SubStr(chars, high + 1, 1)
            encoded_text .= SubStr(chars, low + 1, 1)
        )
    )

    return encoded_text
}