; PageX — Защищенный блокнот с 10 вкладками
; Автор: https://github.com/IgerOK
; Лицензия: MIT
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; === Константы и версия ===
Version := "v1.2"
SALT_CONSTANT := "PageX-V1-Static-Universal-Salt-For-All-Systems-2024-MIT"

; === РАЗМЕРЫ ОКОН ===
PasswordWindowSize := {Width: 270, Height: 480}
MainWindowSize := {Width: 700, Height: 520}
HelpWindowSize := {Width: 300, Height: 0}

; === НАСТРОЙКИ ===
DataFile := A_ScriptDir "\notes.dat"
SettingsFile := A_ScriptDir "\settings.ini"
TabCount := 10
Tabs := []
MasterPassword := ""
Edits := []
tabCtrl := ""
Btn_AlwaysOnTop := ""
Btn_Theme := ""
Btn_Transparency := ""
Btn_Font := ""
FontSize := 10
HelpWindow := ""
CurrentTabIndex := 1
NeedsSave := false

; === НАСТРОЙКА ШРИФТОВ ===
Fonts := ["Segoe UI", "Calibri", "Verdana", "Georgia", "Tahoma"]

; Загружаем настройки
AlwaysOnTop := LoadSetting("AlwaysOnTop", 0)
TransparencyLevel := LoadSetting("TransparencyLevel", 0)
FontSize := LoadSetting("FontSize", 10)
FontName := LoadSetting("FontName", Fonts[1])
ThemeLevel := LoadSetting("ThemeLevel", 0)

if !IsFontInList(FontName) {
    FontName := Fonts[1]
}

; === ЦВЕТА ТЕМ ===
LightTheme := {
    Background: "FFFFFF",
    Text: "000000",
    Control: "F0F0F0",
    Border: "C0C0C0",
    Highlight: "E0E0E0",
    Button: "F0F0F0",
    EditBackground: "FFFFFF",
    EditText: "000000",
    Name: "Светлая",
    Icon: "🔆",
    Arrow: "UP"
}

MediumTheme := {
    Background: "D0D0D0",
    Text: "000000",
    Control: "B0B0B0",
    Border: "808080",
    Highlight: "C0C0C0",
    Button: "B0B0B0",
    EditBackground: "F0F0F0",
    EditText: "000000",
    Name: "Средняя",
    Icon: "💡",
    Arrow: "UP"
}

DarkTheme := {
    Background: "2D2D2D",
    Text: "E0E0E0",
    Control: "404040",
    Border: "606060",
    Highlight: "505050",
    Button: "404040",
    EditBackground: "404040",
    EditText: "A8A8A8",
    Name: "Темная",
    Icon: "🔦",
    Arrow: "UP"
}

Themes := [LightTheme, MediumTheme, DarkTheme]

; === УЛУЧШЕННОЕ ШИФРОВАНИЕ ===
GetSystemSalt() {
    global MasterPassword, SALT_CONSTANT
    
    if MasterPassword {
        combined := MasterPassword . SALT_CONSTANT
        return CreateDeterministicSalt(combined, 64)
    }
    
    return CreateDeterministicSalt(SALT_CONSTANT, 64)
}

CreateDeterministicSalt(input, length) {
    result := Buffer(length, 0)
    
    hash := 0x811C9DC5
    
    inputBuf := Buffer(StrPut(input, "UTF-8") - 1)
    StrPut(input, inputBuf, "UTF-8")
    
    loop inputBuf.Size {
        i := A_Index - 1
        hash := hash ^ NumGet(inputBuf, i, "UChar")
        hash := (hash * 0x01000193) & 0xFFFFFFFF
    }
    
    loop length {
        i := A_Index - 1
        
        hash := (hash * 1103515245 + 12345) & 0xFFFFFFFF
        saltByte := (hash >> 16) & 0xFF
        
        saltByte := saltByte ^ (i & 0xFF)
        
        NumPut("UChar", saltByte, result, i)
    }
    
    return result
}

CreateStrongKey(password, length := 256) {
    passwordBuf := Buffer(StrPut(password, "UTF-8") - 1)
    StrPut(password, passwordBuf, "UTF-8")
    
    result := Buffer(length, 0)
    
    salt := GetSystemSalt()
    
    loop length {
        i := A_Index - 1
        
        passByte := NumGet(passwordBuf, Mod(i, passwordBuf.Size), "UChar")
        
        saltByte := NumGet(salt, Mod(i, salt.Size), "UChar")
        
        lcg := i * 1103515245 + 12345 + saltByte
        
        keyByte := passByte ^ saltByte
        keyByte := keyByte ^ (lcg & 0xFF)
        keyByte := keyByte ^ ((lcg >> 8) & 0xFF)
        keyByte := keyByte ^ ((lcg >> 16) & 0xFF)
        keyByte := keyByte ^ ((lcg >> 24) & 0xFF)
        
        if (i > 0) {
            prevByte := NumGet(result, i - 1, "UChar")
            keyByte := keyByte ^ prevByte
        }
        
        NumPut("UChar", keyByte & 0xFF, result, i)
    }
    
    return result
}

SimpleEncrypt(text, password) {
    if (text = "")
        return ""
    
    enhancedKey := CreateStrongKey(password, 256)
    
    textBufSize := StrPut(text, "UTF-8") - 1
    if (textBufSize <= 0)
        return ""
    
    textBuf := Buffer(textBufSize + 1, 0)
    StrPut(text, textBuf, "UTF-8")
    
    keyLen := enhancedKey.Size
    loop textBufSize {
        i := A_Index - 1
        textByte := NumGet(textBuf, i, "UChar")
        keyByte := NumGet(enhancedKey, Mod(i, keyLen), "UChar")
        NumPut("UChar", textByte ^ keyByte, textBuf, i)
    }
    
    checksum := 0
    loop textBufSize {
        i := A_Index - 1
        checksum := (checksum + NumGet(textBuf, i, "UChar")) & 0xFF
    }
    
    NumPut("UChar", checksum, textBuf, textBufSize)
    
    hexResult := ""
    loop textBufSize + 1 {
        i := A_Index - 1
        hexResult .= Format("{:02X}", NumGet(textBuf, i, "UChar"))
    }
    
    return hexResult
}

SimpleDecrypt(hexData, password) {
    if (hexData = "")
        return ""
    
    if Mod(StrLen(hexData), 2) != 0
        return ""
    
    enhancedKey := CreateStrongKey(password, 256)
    
    bufSize := StrLen(hexData) // 2
    if bufSize < 2
        return ""
    
    textBuf := Buffer(bufSize, 0)
    
    loop bufSize {
        i := A_Index - 1
        hexByte := SubStr(hexData, i*2 + 1, 2)
        NumPut("UChar", Integer("0x" hexByte), textBuf, i)
    }
    
    expectedChecksum := NumGet(textBuf, bufSize - 1, "UChar")
    actualChecksum := 0
    
    loop bufSize - 1 {
        i := A_Index - 1
        actualChecksum := (actualChecksum + NumGet(textBuf, i, "UChar")) & 0xFF
    }
    
    if (actualChecksum != expectedChecksum) {
        return ""
    }
    
    keyLen := enhancedKey.Size
    loop bufSize - 1 {
        i := A_Index - 1
        textByte := NumGet(textBuf, i, "UChar")
        keyByte := NumGet(enhancedKey, Mod(i, keyLen), "UChar")
        NumPut("UChar", textByte ^ keyByte, textBuf, i)
    }
    
    return StrGet(textBuf, bufSize - 1, "UTF-8")
}

; === Запрос пароля ===
InputBoxPass:
try {
    IB := InputBox(
        "PageX " Version " `n" .
		"───────────────────────────────────────`n" .
        "Защищенный блокнот с 10 вкладками`n" .
		"для не конфиденциальных данных`n" .
        "───────────────────────────────────────`n" .
        "Автор: https://github.com/IgerOK`n" .
        "Лицензия: MIT`n" .
        "───────────────────────────────────────`n" .
        "Горячие клавиши:`n" .
        "• Ctrl+S - Сохранить (без выхода)`n" .
        "• Ctrl+Q - Сохранить и выйти`n" .
        "• Esc - Сохранить и выйти`n" .
        "• F1 - Справка `n" .
        "• Ctrl+0..9 - Переключение вкладок`n" .
        "• Ctrl+Колесо мыши - Размер шрифта`n" .
        "• Клик по шрифту - Сменить шрифт`n" .
        "───────────────────────────────────────`n" .
        "ВВЕСТИ И ЗАПОМНИТЬ ПАРОЛЬ!`n" .
        "• Любые символы в диапазоне 1...100 `n" .
        "• Усиленное шифрование (ключ 256 байт + проверка целостности)`n" .
        "(без пароля данные недоступны)",
        "PageX " Version " - Вход",
        "w" PasswordWindowSize.Width " h" PasswordWindowSize.Height
    )
    
    if IB.Result != "OK"
        ExitApp
    
    password := IB.Value
    if !password
        ExitApp
    
    if (StrLen(password) > 100) {
        MsgBox "Пароль слишком длинный! Максимум 100 символов.", "PageX " Version, "Iconx"
        goto InputBoxPass
    }
    
    if (StrLen(password) < 1) {
        MsgBox "Введите пароль.", "PageX " Version, "Iconx"
        goto InputBoxPass
    }
    
    MasterPassword := password
}
catch {
    ExitApp
}

; === Загрузка данных ===
if FileExist(DataFile)
{
    try {
        encrypted := FileRead(DataFile, "UTF-8")
        
        if (encrypted != "" && encrypted != "`n" && encrypted != "`r`n")
        {
            decrypted := SimpleDecrypt(encrypted, MasterPassword)
            if (decrypted = "")
                throw Error("Ошибка расшифровки")
                
            Tabs := StrSplit(decrypted, "`n--PageX-TAB--`n", "`r")
        }
    }
    catch {
        MsgBox "Ошибка загрузки!`nПроверьте пароль.", "PageX " Version, "Iconx"
        goto InputBoxPass
    }
}
else {
    Tabs := ["", "", "", "", "", "", "", "", "", ""]
}

while Tabs.Length < TabCount
    Tabs.Push("")

; === MIT лицензия для вкладки 0 ===
mitLicenseText := 
"--------------------------------------------------`n" .
"MIT License`n" .
"`n" .
"Copyright (c) 2024 IgerOK`n" .
"`n" .
"Permission is hereby granted, free of charge, to any person obtaining a copy`n" .
"of this software and associated documentation files (the 'Software'), to deal`n" .
"in the Software without restriction, including without limitation the rights`n" .
"to use, copy, modify, merge, publish, distribute, sublicense, and/or sell`n" .
"copies of the Software, and to permit persons to whom the Software is`n" .
"furnished to do so, subject to the following conditions:`n" .
"`n" .
"The above copyright notice and this permission notice shall be included in all`n" .
"copies or substantial portions of the Software.`n" .
"`n" .
"THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR`n" .
"IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,`n" .
"FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE`n" .
"AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER`n" .
"LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,`n" .
"OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE`n" .
"SOFTWARE.`n" .
"--------------------------------------------------"

; === Информация для вкладки 0 ===
if (Tabs[1] = "") {
    Tabs[1] := "▌ ВАЖНО: Содержимое этой вкладки можно полностью очистить!`n" .
               "▌ Просто выделите текст и удалите его.`n`n" .
               "Начните вводить свои заметки здесь...`n`n" .
               mitLicenseText
}

; === Информация для вкладки 1 ===
if (Tabs[2] = "") {
    Tabs[2] := 
    "PageX " Version " — Защищенный блокнот с 10 вкладками`n" .
    "═══════════════════════════════════════════════════════`n" .
    "`n" .
    "▌ ВАЖНО: Содержимое этой вкладки можно полностью очистить!`n" .
    "▌ Просто выделите текст и удалите его.`n" .
    "`n" .
    "🔄 ОСНОВНОЕ УПРАВЛЕНИЕ`n" .
    "───────────────────────────────────────────────────────`n" .
    "• Ctrl+0..9 - Быстрое переключение между вкладками`n" .
    "• Ctrl+S    - Сохранить данные (без выхода)`n" .
    "• Ctrl+Q    - Сохранить и выйти`n" .
    "• Esc       - Сохранить и выйти`n" .
    "• F1        - Быстрая справка (окно поверх всех)`n" .
    "`n" .
    "✏️ РЕДАКТИРОВАНИЕ ТЕКСТА`n" .
    "───────────────────────────────────────────────────────`n" .
    "• Ctrl+Колесо мыши вверх - Увеличить шрифт`n" .
    "• Ctrl+Колесо мыши вниз  - Уменьшить шрифт`n" .
    "• Клик по кнопке шрифта - Сменить шрифт`n" .
    "• Текущий размер шрифта: " FontSize "pt (диапазон: 8-24)`n" .
    "• Доступные шрифты: " Fonts.Length " шт.`n" .
    "`n" .
    "⚙️ НАСТРОЙКИ ОКНА`n" .
    "───────────────────────────────────────────────────────`n" .
    "• UP/DWN - Положение окна (ОКНО)`n" .
    "• 🔆/💡/🔦 - Переключение тем (ТЕМА)`n" .
    "• 0%/25%/50% - Прозрачность окна (ПРОЗРАЧНОСТЬ)`n" .
    "• Название шрифта - Смена шрифта (ШРИФТ)`n" .
    "• Размер окна - Изменяется перетаскиванием краев`n" .
    "`n" .
    "🔒 УЛУЧШЕННАЯ БЕЗОПАСНОСТЬ`n" .
    "───────────────────────────────────────────────────────`n" .
    "• 10 независимых вкладок (0-9) с шифрованием`n" .
    "• Усиленное шифрование (ключ 256 байт + системная соль)`n" .
    "• Контрольная сумма для проверки целостности данных`n" .
    "• Все данные шифруются вашим паролем`n" .
    "• Без пароля восстановить данные невозможно`n" .
    "• Переносимость между компьютерами (один файл .dat)`n" .
    "• Данные хранятся локально, не передаются в интернет`n" .
    "`n" .
    "💾 ФАЙЛЫ ПРОГРАММЫ`n" .
    "───────────────────────────────────────────────────────`n" .
    "• notes.dat     - Зашифрованные данные (не удалять!)`n" .
    "• settings.ini  - Настройки программы (опционально)`n" .
    "`n" .
    "📝 ПОДСКАЗКИ`n" .
    "───────────────────────────────────────────────────────`n" .
    "• Используйте Ctrl+0..9 для быстрой навигации`n" .
    "• Настройте размер и тип шрифта под себя`n" .
    "• Регулярно сохраняйтесь (Ctrl+S)`n" .
    "• Для очистки вкладки просто удалите весь текст`n" .
    "• Для переноса на другой компьютер скопируйте notes.dat`n" .
    "`n" .
    "ℹ️ ИНФОРМАЦИЯ`n" .
    "───────────────────────────────────────────────────────`n" .
    "Версия: " Version "`n" .
    "Автор: https://github.com/IgerOK`n" .
    "Лицензия: MIT`n" .
    "`n" .
    "⚠️  ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ:`n" .
    "• Не забывайте свой пароль! Без него данные будут потеряны.`n" .
    "• Храните пароль в безопасном месте.`n" .
    "• Для переноса данных на другой компьютер:`n" .
    "  1. Скопируйте файл notes.dat`n" .
    "  2. Запустите PageX на новом компьютере`n" .
    "  3. Введите тот же пароль`n" .
    "  4. Данные будут расшифрованы и доступны"
}

; === Создание основного GUI ===
MyGui := Gui(, "PageX " Version " - Защищённый блокнот ")
MyGui.Opt("+Resize +MinSize700x500")
MyGui.SetFont("s10", "Segoe UI")
MyGui.MarginX := 10
MyGui.MarginY := 10

; === ПАНЕЛЬ НАСТРОЕК ===
Btn_AlwaysOnTop := MyGui.Add("Button", "x10 y10 w40 h25", GetArrowText(AlwaysOnTop))
Btn_AlwaysOnTop.OnEvent("Click", ToggleAlwaysOnTop)
Btn_AlwaysOnTop.ToolTip := "ОКНО`nПоложение окна: " . (AlwaysOnTop ? "ПОВЕРХ ВСЕХ (ВКЛ)" : "ОБЫЧНОЕ (ВЫКЛ)") . "`nНажмите для переключения"

Btn_Theme := MyGui.Add("Button", "x60 y10 w25 h25", GetThemeIcon(ThemeLevel))
Btn_Theme.OnEvent("Click", CycleTheme)
Btn_Theme.ToolTip := "ТЕМА`nТекущая тема: " . GetCurrentTheme().Name . "`nНажмите для переключения"

Btn_Transparency := MyGui.Add("Button", "x95 y10 w40 h25", GetTransparencyText(TransparencyLevel))
Btn_Transparency.OnEvent("Click", CycleTransparency)
Btn_Transparency.ToolTip := "ПРОЗРАЧНОСТЬ`nТекущий уровень: " . GetTransparencyPercent(TransparencyLevel) . "`nНажмите для переключения"

Btn_Font := MyGui.Add("Button", "x145 y10 w120 h25", GetFontButtonText())
Btn_Font.OnEvent("Click", CycleFont)
Btn_Font.ToolTip := "ШРИФТ`nТекущий шрифт: " . FontName . " " . FontSize . "pt`nНажмите для смены шрифта`nCtrl+Колесо мыши - изменить размер"

helpButton := MyGui.Add("Button", "x680 y10 w100 h25", "Помощь F1")
helpButton.OnEvent("Click", ToggleHelp)
helpButton.ToolTip := "Открыть справку`nГорячая клавиша: F1"

sepLine := MyGui.Add("Text", "x10 y45 w780 0x10")

; === ВКЛАДКИ ===
tabNames := ["0"]
loop 9
    tabNames.Push(A_Index)

tabCtrl := MyGui.Add("Tab3", "x10 y60 w780 h380 Choose" CurrentTabIndex, tabNames)
tabCtrl.OnEvent("Change", TabChangeHandler)

; Создаём поля ввода и привязываем обработчик изменений
loop TabCount
{
    tabCtrl.UseTab(A_Index)
    content := Tabs.Length >= A_Index ? Tabs[A_Index] : ""
    editCtrl := MyGui.Add("Edit", "x20 y90 w760 h330 +Multi +Wrap +VScroll", content)
    editCtrl.SetFont("s" FontSize, FontName)
    editCtrl.OnEvent("Change", OnEditChange)
    Edits.Push(editCtrl)
}
tabCtrl.UseTab(1)

; Обработчики
MyGui.OnEvent("Close", SaveAndExit)
MyGui.OnEvent("Size", GuiSize)
OnMessage(0x20A, FontSizeWheelHandler)

ApplyWindowSettings()
MyGui.Show("w" MainWindowSize.Width " h" MainWindowSize.Height)
ApplyTransparency()
Edits[1].Focus()

; === ФУНКЦИИ ===

; Обработчик изменения текста в поле ввода
OnEditChange(*) {
    global NeedsSave
    NeedsSave := true
}

GetArrowText(isOnTop) {
    return isOnTop ? "UP" : "DWN"
}

GetTransparencyText(level) {
    switch level {
        case 1: return "25%"
        case 2: return "50%"
        default: return "0%"
    }
}

GetTransparencyPercent(level) {
    switch level {
        case 1: return "25%"
        case 2: return "50%"
        default: return "0% (нет)"
    }
}

GetFontButtonText() {
    global FontName, FontSize
    displayName := FontName
    if (StrLen(FontName) > 12) {
        displayName := SubStr(FontName, 1, 12) . "…"
    }
    return displayName . " " . FontSize . "pt"
}

GetThemeIcon(level) {
    global Themes
    if (level >= 0 && level < Themes.Length) {
        return Themes[level + 1].Icon
    }
    return Themes[1].Icon
}

TabChangeHandler(*) {
    global CurrentTabIndex, tabCtrl, Edits
    CurrentTabIndex := tabCtrl.Value
    if (CurrentTabIndex >= 1 && CurrentTabIndex <= 10) {
        Edits[CurrentTabIndex].Focus()
    }
}

GetCurrentTheme() {
    global ThemeLevel, Themes
    
    if ThemeLevel >= 0 && ThemeLevel < Themes.Length
        return Themes[ThemeLevel + 1]
    else
        return Themes[1]
}

ToggleAlwaysOnTop(*) {
    global AlwaysOnTop, Btn_AlwaysOnTop, MyGui
    
    AlwaysOnTop := !AlwaysOnTop
    
    if AlwaysOnTop {
        MyGui.Opt("+AlwaysOnTop")
        Btn_AlwaysOnTop.Text := "UP"
        Btn_AlwaysOnTop.ToolTip := "ОКНО`nПоложение окна: ПОВЕРХ ВСЕХ (ВКЛ)`nНажмите для переключения"
    } else {
        MyGui.Opt("-AlwaysOnTop")
        Btn_AlwaysOnTop.Text := "DWN"
        Btn_AlwaysOnTop.ToolTip := "ОКНО`nПоложение окна: ОБЫЧНОЕ (ВЫКЛ)`nНажмите для переключения"
    }
    
    SaveSettings()
}

CycleTransparency(*) {
    global TransparencyLevel, Btn_Transparency
    
    TransparencyLevel := Mod(TransparencyLevel + 1, 3)
    ApplyTransparency()
    
    Btn_Transparency.Text := GetTransparencyText(TransparencyLevel)
    Btn_Transparency.ToolTip := "ПРОЗРАЧНОСТЬ`nТекущий уровень: " . GetTransparencyPercent(TransparencyLevel) . "`nНажмите для переключения"
    
    SaveSettings()
}

ApplyTransparency() {
    global TransparencyLevel, Version
    
    if !WinExist("PageX " Version " - Защищённый блокнот ")
        return
    
    switch TransparencyLevel {
        case 1: WinSetTransparent 192, "PageX " Version " - Защищённый блокнот "
        case 2: WinSetTransparent 128, "PageX " Version " - Защищённый блокнот "
        default: WinSetTransparent 255, "PageX " Version " - Защищённый блокнот "
    }
}

ApplyTheme() {
    global MyGui, Btn_AlwaysOnTop, Btn_Theme, Btn_Transparency, Btn_Font, helpButton, sepLine
    global Edits, FontSize, FontName, tabCtrl, ThemeLevel, CurrentTabIndex, AlwaysOnTop, TransparencyLevel
    
    theme := GetCurrentTheme()
    
    Btn_AlwaysOnTop.Text := GetArrowText(AlwaysOnTop)
    Btn_Transparency.Text := GetTransparencyText(TransparencyLevel)
    Btn_Font.Text := GetFontButtonText()
    
    ApplySimpleTheme(theme)
}

ApplySimpleTheme(theme) {
    global MyGui, Btn_AlwaysOnTop, Btn_Theme, Btn_Transparency, Btn_Font, helpButton, sepLine
    global Edits, tabCtrl, FontSize, FontName
    
    try {
        MyGui.BackColor := theme.Background
    }
    
    for ctrl in [sepLine] {
        if IsObject(ctrl) {
            try {
                ctrl.SetFont("c" . theme.Text)
                ctrl.Opt("Background" . theme.Background)
            }
        }
    }
    
    for ctrl in [helpButton, Btn_Theme, Btn_AlwaysOnTop, Btn_Transparency, Btn_Font] {
        if IsObject(ctrl) {
            try {
                ctrl.SetFont("c" . theme.Text)
                ctrl.Opt("Background" . theme.Button)
            }
        }
    }
    
    if IsObject(tabCtrl) {
        try {
            tabCtrl.SetFont("c" . theme.Text)
        }
    }
    
    loop Edits.Length {
        if IsObject(Edits[A_Index]) {
            try {
                Edits[A_Index].SetFont("c" . theme.EditText " s" FontSize, FontName)
                Edits[A_Index].Opt("Background" . theme.EditBackground)
            }
        }
    }
}

CycleTheme(*) {
    global ThemeLevel
    
    ThemeLevel := Mod(ThemeLevel + 1, 3)
    ApplyTheme()
    SaveSettings()
}

IsFontInList(fontName) {
    global Fonts
    
    for index, font in Fonts {
        if font = fontName {
            return true
        }
    }
    return false
}

FontSizeWheelHandler(wParam, lParam, msg, hwnd) {
    global FontSize, FontName, Edits, NeedsSave
    
    if !WinActive("PageX " Version " - Защищённый блокнот ")
        return
    
    if !GetKeyState("Ctrl")
        return
    
    try {
        MouseGetPos(, , &winId, &controlId, 2)
        
        for editCtrl in Edits {
            if (controlId = editCtrl.Hwnd) {
                delta := wParam >> 16
                delta := delta > 0x7FFF ? -(0x10000 - delta) : delta
                
                if (delta > 0) {
                    if (FontSize < 24) {
                        FontSize += 1
                        UpdateFontAndSize()
                        NeedsSave := true
                    }
                }
                else if (delta < 0) {
                    if (FontSize > 8) {
                        FontSize -= 1
                        UpdateFontAndSize()
                        NeedsSave := true
                    }
                }
                return 0
            }
        }
    }
    catch {
    }
}

GuiSize(GuiObj, MinMax, Width, Height) {
    global
    
    if (MinMax = -1)
        return
    
    if (IsObject(tabCtrl)) {
        tabCtrl.Move(, , Width - 20, Height - 100)
    }
    
    loop TabCount {
        if (Edits.Length >= A_Index) {
            Edits[A_Index].Move(, , Width - 40, Height - 140)
        }
    }
    
    if (IsObject(sepLine)) {
        sepLine.Move(, , Width - 20)
    }
    
    if (Btn_Font) {
        Btn_Font.Move(Width - 245)
    }
    
    if (helpButton) {
        helpButton.Move(Width - 120)
    }
}

CycleFont(*) {
    global Fonts, FontName, Btn_Font, NeedsSave
    
    currentIndex := 0
    loop Fonts.Length {
        if (Fonts[A_Index] = FontName) {
            currentIndex := A_Index
            break
        }
    }
    
    if (currentIndex = Fonts.Length) {
        FontName := Fonts[1]
    } else {
        FontName := Fonts[currentIndex + 1]
    }
    
    UpdateFontAndSize()
    NeedsSave := true
}

UpdateFontAndSize() {
    global Btn_Font, FontName, FontSize, Edits, TabCount, CurrentTabIndex
    
    savedTexts := []
    loop Edits.Length {
        savedTexts.Push(Edits[A_Index].Text)
    }
    
    focusedEdit := 0
    loop Edits.Length {
        if Edits[A_Index].Focused {
            focusedEdit := A_Index
            break
        }
    }
    
    Btn_Font.Text := GetFontButtonText()
    Btn_Font.ToolTip := "ШРИФТ`nТекущий шрифт: " . FontName . " " . FontSize . "pt`nНажмите для смены шрифта`nCtrl+Колесо мыши - изменить размер"
    
    loop TabCount {
        if (Edits.Length >= A_Index) {
            try {
                Edits[A_Index].SetFont("s" FontSize, FontName)
                Edits[A_Index].Text := savedTexts[A_Index]
            }
        }
    }
    
    ApplyTheme()
    
    if (focusedEdit > 0 && focusedEdit <= Edits.Length) {
        try {
            Edits[focusedEdit].Focus()
        }
    }
    else if (CurrentTabIndex >= 1 && CurrentTabIndex <= Edits.Length) {
        try {
            Edits[CurrentTabIndex].Focus()
        }
    }
    
    SaveSettings()
}

; ФУНКЦИЯ СОХРАНЕНИЯ ДАННЫХ
SaveData(*) {
    global DataFile, TabCount, Edits, Tabs, MasterPassword, NeedsSave
    
    try {
        ; Обновляем массив Tabs из всех полей ввода
        loop TabCount {
            if (Edits.Length >= A_Index && IsObject(Edits[A_Index])) {
                Tabs[A_Index] := Edits[A_Index].Text
            } else {
                Tabs[A_Index] := ""
            }
        }
        
        ; Формируем строку для шифрования
        text := ""
        loop TabCount {
            if (A_Index > 1) {
                text .= "`n--PageX-TAB--`n"
            }
            text .= Tabs[A_Index]
        }
        
        ; Шифруем данные
        encrypted := SimpleEncrypt(text, MasterPassword)
        
        ; Сохраняем в файл
        if FileExist(DataFile) {
            FileDelete DataFile
        }
        
        file := FileOpen(DataFile, "w")
        if IsObject(file) {
            file.Write(encrypted)
            file.Close()
        }
        
        ; Сохраняем настройки
        SaveSettings()
        
        ; Сбрасываем флаг необходимости сохранения
        NeedsSave := false
        
        return true
        
    } catch as e {
        MsgBox "Ошибка сохранения: " e.Message, "PageX " Version " - Ошибка", "Iconx"
        return false
    }
}

SaveAndExit(*) {
    global
    
    ; Всегда пытаемся сохранить при выходе
    SaveData()
    
    ExitApp
}

ApplyWindowSettings() {
    global AlwaysOnTop, MyGui
    
    if AlwaysOnTop
        MyGui.Opt("+AlwaysOnTop")
    
    ApplyTheme()
}

; ФУНКЦИЯ СОХРАНЕНИЯ НАСТРОЕК
SaveSettings() {
    global SettingsFile, AlwaysOnTop, TransparencyLevel, FontSize, FontName, ThemeLevel
    
    try {
        ; Простое сохранение настроек
        IniWrite(AlwaysOnTop, SettingsFile, "Window", "AlwaysOnTop")
        IniWrite(TransparencyLevel, SettingsFile, "Window", "TransparencyLevel")
        IniWrite(FontSize, SettingsFile, "Font", "Size")
        IniWrite(FontName, SettingsFile, "Font", "Name")
        IniWrite(ThemeLevel, SettingsFile, "Theme", "ThemeLevel")
        
        return true
    } catch {
        return false
    }
}

LoadSetting(Key, Default) {
    global SettingsFile
    
    if FileExist(SettingsFile) {
        try {
            if (Key = "AlwaysOnTop")
                return Integer(IniRead(SettingsFile, "Window", Key, Default))
            else if (Key = "TransparencyLevel")
                return Integer(IniRead(SettingsFile, "Window", Key, Default))
            else if (Key = "FontSize")
                return Integer(IniRead(SettingsFile, "Font", "Size", Default))
            else if (Key = "FontName")
                return IniRead(SettingsFile, "Font", "Name", Default)
            else if (Key = "ThemeLevel")
                return Integer(IniRead(SettingsFile, "Theme", "ThemeLevel", Default))
        }
        catch {
            return Default
        }
    }
    return Default
}

ToggleHelp(*) {
    global HelpWindow
    
    if IsObject(HelpWindow) && HelpWindow.Hwnd && WinExist("ahk_id " HelpWindow.Hwnd) {
        HelpWindow.Destroy()
        HelpWindow := ""
    } else {
        ShowHelp()
    }
}

ShowHelp(*) {
    global HelpWindow, HelpWindowSize, Version, ThemeLevel, Themes, AlwaysOnTop, TransparencyLevel, FontName, FontSize
    
    if IsObject(HelpWindow) {
        try {
            HelpWindow.Destroy()
            HelpWindow := ""
        }
        catch {
            HelpWindow := ""
        }
    }
    
    HelpWindow := Gui("+AlwaysOnTop +ToolWindow", "PageX " Version " - Справка ")
    HelpWindow.SetFont("s10", "Segoe UI")
    HelpWindow.MarginX := 20
    HelpWindow.MarginY := 20
    
    theme := GetCurrentTheme()
    HelpWindow.BackColor := theme.Background
    
    helpText := 
    "PageX " Version " — Быстрая справка`n" .
    "══════════════════════════════════════════`n" .
    "`n" .
    "📌 ОСНОВНЫЕ КОМАНДЫ:`n" .
    "• Ctrl+S  - Сохранить данные`n" .
    "• Ctrl+Q  - Сохранить и выйти`n" .
    "• Esc     - Сохранить и выйти`n" .
    "• F1      - Эта справка`n" .
    "• Ctrl+0..9 - Переключение вкладок`n" .
    "• Ctrl+Колесо мыши - Изменить размер шрифта`n" .
    "• Клик по кнопке шрифта - Сменить шрифт`n" .
    "`n" .
    "🎨 ТЕМА (3 уровня):`n" .
    "• Текущая тема: " theme.Name " " theme.Icon "`n" .
    "• Нажмите на лампочку для смены темы`n" .
    "• Уровни: Светлая → Средняя → Темная`n" .
    "• Настройки сохраняются автоматически`n" .
    "`n" .
    "📌 КНОПКИ ПАНЕЛИ:`n" .
    "• " . GetArrowText(AlwaysOnTop) . " - ОКНО: " . (AlwaysOnTop ? "ПОВЕРХ ВСЕХ (ВКЛ)" : "ОБЫЧНОЕ (ВЫКЛ)") . "`n" .
    "• " . theme.Icon . " - ТЕМА: " . theme.Name . "`n" .
    "• " . GetTransparencyText(TransparencyLevel) . " - ПРОЗРАЧНОСТЬ: " . GetTransparencyPercent(TransparencyLevel) . "`n" .
    "• " . GetFontButtonText() . " - ШРИФТ: " . FontName . " " . FontSize . "pt`n" .
    "• Помощь F1 - Открыть справку`n" .
    "`n" .
    "🔒 УЛУЧШЕННАЯ БЕЗОПАСНОСТЬ:`n" .
    "• Усиленное шифрование (ключ 256 байт)`n" .
    "• Системная соль для уникальности ключа`n" .
    "• Контрольная сумма для проверки целостности`n" .
    "• Переносимость между компьютерами`n" .
    "• Один файл notes.dat для всех данных`n" .
    "`n" .
    "💡 НАСТРОЙКА ШРИФТОВ:`n" .
    "• Список шрифтов настраивается в коде скрипта`n" .
    "• Ищите строку: Fonts := [...`n" .
    "• Убедитесь, что шрифты установлены в системе`n" .
    "`n" .
    "📦 ПЕРЕНОС ДАННЫХ:`n" .
    "• Скопируйте файл notes.dat на другой компьютер`n" .
    "• Введите тот же пароль`n" .
    "• Все данные будут доступны`n" .
    "`n" .
    "Версия: " Version "`n" .
    "Автор: https://github.com/IgerOK"
    
    helpTextCtrl := HelpWindow.Add("Text", , helpText)
    helpTextCtrl.SetFont("c" . theme.Text)
    helpTextCtrl.Opt("Background" . theme.Background)
    
    closeBtn := HelpWindow.Add("Button", "w100 Center", "Закрыть")
    closeBtn.OnEvent("Click", (*) => HelpWindow.Destroy())
    closeBtn.SetFont("c" . theme.Text)
    closeBtn.Opt("Background" . theme.Button)
    
    if (HelpWindowSize.Width > 0 && HelpWindowSize.Height > 0) {
        HelpWindow.Show("w" HelpWindowSize.Width " h" HelpWindowSize.Height " Center")
    }
    else if (HelpWindowSize.Width > 0) {
        HelpWindow.Show("Center")
    }
    else {
        HelpWindow.Show("Center")
    }
    
    HelpWindow.OnEvent("Close", (*) => HelpWindow := "")
    HelpWindow.OnEvent("Escape", (*) => HelpWindow.Destroy())
}

; === ГОРЯЧИЕ КЛАВИШИ ===
#HotIf WinActive("PageX " Version " - Защищённый блокнот ")
^s::SaveData()
^q::SaveAndExit()
Esc::SaveAndExit()
F1::ToggleHelp()

^0::SwitchTab(1)
^1::SwitchTab(2)
^2::SwitchTab(3)
^3::SwitchTab(4)
^4::SwitchTab(5)
^5::SwitchTab(6)
^6::SwitchTab(7)
^7::SwitchTab(8)
^8::SwitchTab(9)
^9::SwitchTab(10)

^+Up:: {
    global FontSize, NeedsSave
    if (FontSize < 24) {
        FontSize += 1
        UpdateFontAndSize()
        NeedsSave := true
    }
}

^+Down:: {
    global FontSize, NeedsSave
    if (FontSize > 8) {
        FontSize -= 1
        UpdateFontAndSize()
        NeedsSave := true
    }
}
#HotIf

#HotIf WinActive("PageX " Version " - Справка ")
F1::ToggleHelp()
Esc:: {
    global HelpWindow
    if IsObject(HelpWindow) {
        HelpWindow.Destroy()
        HelpWindow := ""
    }
}
#HotIf

SwitchTab(TabNumber) {
    global tabCtrl, Edits, CurrentTabIndex
    
    if (TabNumber >= 1 && TabNumber <= 10) {
        tabCtrl.Choose(TabNumber)
        CurrentTabIndex := TabNumber
        if (Edits.Length >= TabNumber) {
            Edits[TabNumber].Focus()
        }
    }
}

OnExit(*) {
    global NeedsSave
    if (NeedsSave) {
        SaveData()
    }
}
