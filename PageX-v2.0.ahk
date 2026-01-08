; PageX — Блокнот с вкладками
; Автор: https://github.com/IgerOK
; Лицензия: MIT License © 2025
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; === Константы и версия ===
Version := "v2.0"

; === НАСТРОЙКИ ===
SplitPath A_ScriptName, , , &scriptExt, &scriptNameNoExt
ScriptBaseName := scriptNameNoExt
DataFile := A_ScriptDir "\" ScriptBaseName ".ddd"
TabCount := 10

; === РАЗМЕРЫ ОКОН ПО УМОЛЧАНИЮ ===
DEFAULT_MAIN_WIDTH := 565
DEFAULT_MAIN_HEIGHT := 180
DEFAULT_HELP_WIDTH := 300
DEFAULT_HELP_HEIGHT := 550
MIN_MAIN_WIDTH := 565
MIN_MAIN_HEIGHT := 180

; === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
global Tabs := []
global TabContents := []
global TabHeaders := []
global CursorPositions := []
global Btn_AlwaysOnTop := ""
global Btn_Theme := ""
global Btn_Transparency := ""
global Btn_Font := ""
global Btn_FontSize := ""
global Btn_TabSize := ""
global FontSize := 10
global HelpWindow := ""
global CurrentTabIndex := 1
global NeedsSave := false
global SyncTimer := ""
global LineNumbersData := Map()
global VisibleLinesCache := 30
global LastScrollPositions := []
global LastHScrollPositions := []
global lineNumberCtrl := ""
global contentEdit := ""
global MyGui := ""
global LineNumberWidth := 60
global AlwaysOnTop := 0
global TransparencyLevel := 0
global FontName := "Consolas"
global ThemeLevel := 0
global TabSize := 4
global TabSizes := [2, 4, 8]
global Fonts := ["Consolas", "Cascadia Code", "JetBrains Mono", "Fira Code", "Courier New"]

; === ЦВЕТА ТЕМ ===
MediumTheme := {
    Background: "D0D0D0",
    Text: "000000",
    Control: "B0B0B0",
    Button: "B0B0B0",
    EditBackground: "F0F0F0",
    EditText: "000000",
    LineNumberBackground: "E0E0E0",
    LineNumberText: "0000FF",
    LineNumberBorder: "B0B0B0",
    TabActive: "A0C8D0",
    Name: "Средняя",
    Icon: "🔆"
}

DarkTheme := {
    Background: "2D2D2D",
    Text: "E0E0E0",
    Control: "404040",
    Button: "404040",
    EditBackground: "404040",
    EditText: "A8A8A8",
    LineNumberBackground: "303030",
    LineNumberText: "FFFFA0",
    LineNumberBorder: "505050",
    TabActive: "306080",
    Name: "Темная",
    Icon: "💡"
}

global Themes := [MediumTheme, DarkTheme]

; === ФУНКЦИИ ПОЛУЧЕНИЯ ТЕКСТОВ КНОПОК ===
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

GetFontNameButtonText() {
    global FontName
    displayName := FontName
    if (StrLen(FontName) > 12) {
        displayName := SubStr(FontName, 1, 12) . "…"
    }
    return displayName
}

GetFontSizeButtonText() {
    global FontSize
    return FontSize . "pt"
}

GetThemeIcon(level) {
    global Themes
    if (level >= 0 && level < Themes.Length) {
        return Themes[level + 1].Icon
    }
    return Themes[1].Icon
}

GetTabSizeButtonText() {
    global TabSize
    return "TbSz=" . TabSize
}

GetTabSizeToolTip() {
    global TabSize
    return "РАЗМЕР ТАБУЛЯЦИИ`nТекущий размер: " . TabSize . " пробелов`nНажмите для изменения (2/4/8)"
}

GetCurrentTheme() {
    global ThemeLevel, Themes
    if ThemeLevel >= 0 && ThemeLevel < Themes.Length
        return Themes[ThemeLevel + 1]
    else
        return Themes[1]
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

; === ВСПЛЫВАЮЩЕЕ СООБЩЕНИЕ ===
ShowSaveMessage() {
    global Version, ScriptBaseName
    saveMsg := Gui("+ToolWindow +AlwaysOnTop +Border", "Сохранение")
    saveMsg.SetFont("s10", "Segoe UI")
    saveMsg.MarginX := 20
    saveMsg.MarginY := 15
    theme := GetCurrentTheme()
    saveMsg.BackColor := theme.Background
    msgText := saveMsg.Add("Text", "Center", "✓ Данные сохранены в " . ScriptBaseName . ".ddd")
    msgText.SetFont("c" . theme.Text)
    msgText.Opt("Background" . theme.Background)
    saveMsg.Show("AutoSize Center NoActivate")
    SetTimer(() => CloseSaveMessage(saveMsg), 1500)
}

CloseSaveMessage(msgGui) {
    try {
        if IsObject(msgGui) {
            msgGui.Destroy()
        }
    }
    catch {
        ; Игнорируем ошибки закрытия
    }
}

; === ФУНКЦИЯ ДЛЯ СОХРАНЕНИЯ ТЕКСТА В UTF-8 БЕЗ BOM ===
SaveTextToFileUTF8NoBOM(filePath, text) {
    try {
        folderPath := SubStr(filePath, 1, InStr(filePath, "\", , -1) - 1)
        if (folderPath != "" && !DirExist(folderPath)) {
            DirCreate(folderPath)
        }
        text := StrReplace(text, "`r`r`n", "`r`n")
        text := StrReplace(text, "`n", "`r`n")
        text := StrReplace(text, "`r`r`n", "`r`n")
        file := FileOpen(filePath, "w", "UTF-8-RAW")
        file.Write(text)
        file.Close()
        return true
    }
    catch as e {
        MsgBox "Ошибка сохранения файла " filePath ": " e.Message
        return false
    }
}

; === ЗАГРУЗКА ДАННЫХ ИЗ ФАЙЛА ===
LoadData() {
    global DataFile, TabCount, TabContents, AlwaysOnTop, TransparencyLevel
    global FontSize, FontName, ThemeLevel, TabSize, CursorPositions, Fonts
    
    TabContents := []
    CursorPositions := []
    
    loop TabCount {
        TabContents.Push("")
        CursorPositions.Push(1)
    }
    
    AlwaysOnTop := 0
    TransparencyLevel := 0
    FontSize := 10
    FontName := "Consolas"
    ThemeLevel := 0
    TabSize := 4
    
    if FileExist(DataFile) {
        try {
            content := FileRead(DataFile, "UTF-8")
            if (content != "") {
                sections := StrSplit(content, "`r`n---SECTION---`r`n")
                
                for section in sections {
                    trimmedSection := Trim(section, " `t`r`n")
                    if (trimmedSection = "") {
                        continue
                    }
                    
                    lines := StrSplit(trimmedSection, "`n", "`r")
                    firstLine := lines[1]
                    
                    if (firstLine = "[SETTINGS]") {
                        for line in lines {
                            trimmedLine := Trim(line)
                            if (trimmedLine = "" || SubStr(trimmedLine, 1, 1) = "[" || SubStr(trimmedLine, 1, 1) = ";") {
                                continue
                            }
                            
                            if (InStr(trimmedLine, "=")) {
                                lineParts := StrSplit(trimmedLine, "=", "", 2)
                                key := Trim(lineParts[1])
                                value := Trim(lineParts[2])
                                
                                switch key {
                                    case "AlwaysOnTop": AlwaysOnTop := Integer(value)
                                    case "TransparencyLevel": TransparencyLevel := Integer(value)
                                    case "FontSize": FontSize := Integer(value)
                                    case "FontName": FontName := value
                                    case "ThemeLevel": ThemeLevel := Integer(value)
                                    case "TabSize": TabSize := Integer(value)
                                }
                            }
                        }
                    }
                    else if (firstLine = "[CURSOR_POSITIONS]") {
                        for line in lines {
                            trimmedLine := Trim(line)
                            if (trimmedLine = "" || SubStr(trimmedLine, 1, 1) = "[" || SubStr(trimmedLine, 1, 1) = ";") {
                                continue
                            }
                            
                            if (InStr(trimmedLine, "=")) {
                                lineParts := StrSplit(trimmedLine, "=", "", 2)
                                key := Trim(lineParts[1])
                                value := Trim(lineParts[2])
                                
                                if (SubStr(key, 1, 3) = "Tab") {
                                    tabIndex := Integer(SubStr(key, 4)) + 1
                                    if (tabIndex >= 1 && tabIndex <= TabCount) {
                                        pos := Integer(value)
                                        if (pos > 0) {
                                            CursorPositions[tabIndex] := pos
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else if (firstLine = "[TAB_DATA]") {
                        tabData := SubStr(trimmedSection, StrLen("[TAB_DATA]`r`n") + 1)
                        if (tabData != "") {
                            tabParts := StrSplit(tabData, "`r`n<TAB-")
                            loop tabParts.Length {
                                tabIndex := A_Index
                                part := tabParts[tabIndex]
                                
                                if (tabIndex = 1) {
                                    TabContents[1] := Trim(part, " `t`r`n")
                                } else {
                                    closePos := InStr(part, "<")
                                    if (closePos > 0) {
                                        content := SubStr(part, closePos + 1)
                                        TabContents[tabIndex] := Trim(content, " `t`r`n")
                                    } else {
                                        TabContents[tabIndex] := Trim(part, " `t`r`n")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        catch as e {
            MsgBox "Ошибка загрузки файла данных. Используются значения по умолчанию.`n`n" 
                . "Файл: " DataFile "`n"
                . "Ошибка: " e.Message, "PageX " Version, "Icon!"
        }
    }
    
    if !IsFontInList(FontName) {
        FontName := Fonts[1]
    }
}

; === СОХРАНЕНИЕ ВСЕХ ДАННЫХ ===
SaveData(showMessage := false) {
    global DataFile, TabCount, TabContents, NeedsSave, Version, CurrentTabIndex, contentEdit
    global AlwaysOnTop, TransparencyLevel, FontSize, FontName, ThemeLevel, TabSize, CursorPositions, MyGui
    
    try {
        if (IsObject(contentEdit) && contentEdit.Hwnd) {
            TabContents[CurrentTabIndex] := contentEdit.Value
        }
        
        if (IsObject(contentEdit) && contentEdit.Hwnd) {
            try {
                cursorPos := SendMessage(0x00B0, 0, 0, contentEdit.Hwnd) + 1
                if (cursorPos > 0) {
                    CursorPositions[CurrentTabIndex] := cursorPos
                }
            }
            catch {
                CursorPositions[CurrentTabIndex] := 1
            }
        }
        
        windowWidth := DEFAULT_MAIN_WIDTH
        windowHeight := DEFAULT_MAIN_HEIGHT
        if (IsObject(MyGui)) {
            try {
                MyGui.GetPos(, , &w, &h)
                windowWidth := w
                windowHeight := h
            }
            catch {
                ; Игнорируем ошибки получения размера
            }
        }
        
        content := ""
        content .= "[SETTINGS]`r`n"
        content .= "AlwaysOnTop=" . AlwaysOnTop . "`r`n"
        content .= "TransparencyLevel=" . TransparencyLevel . "`r`n"
        content .= "FontSize=" . FontSize . "`r`n"
        content .= "FontName=" . FontName . "`r`n"
        content .= "ThemeLevel=" . ThemeLevel . "`r`n"
        content .= "TabSize=" . TabSize . "`r`n"
        content .= "---SECTION---`r`n"
        
        content .= "[CURSOR_POSITIONS]`r`n"
        loop TabCount {
            content .= "Tab" . (A_Index - 1) . "=" . CursorPositions[A_Index] . "`r`n"
        }
        content .= "---SECTION---`r`n"
        
        content .= "[WINDOW_SIZE]`r`n"
        content .= "Width=" . windowWidth . "`r`n"
        content .= "Height=" . windowHeight . "`r`n"
        content .= "---SECTION---`r`n"
        
        content .= "[TAB_DATA]`r`n"
        loop TabCount {
            tabIndex := A_Index
            content .= TabContents[tabIndex]
            if (tabIndex < TabCount) {
                content .= "`r`n<TAB-" . tabIndex . "<`r`n"
            }
        }
        content .= "`r`n"
        
        if (!SaveTextToFileUTF8NoBOM(DataFile, content)) {
            throw Error("Не удалось сохранить данные в файл")
        }
        
        NeedsSave := false
        
        if (showMessage) {
            ShowSaveMessage()
        }
        
        return true
        
    } catch as e {
        MsgBox "Ошибка сохранения: " e.Message, "PageX " Version " - Ошибка", "Iconx"
        return false
    }
}

; === ЗАГРУЗКА РАЗМЕРА ОКНА ===
LoadWindowSizeSetting(key, defaultValue) {
    global DataFile
    if FileExist(DataFile) {
        try {
            content := FileRead(DataFile, "UTF-8")
            sections := StrSplit(content, "`r`n---SECTION---`r`n")
            for section in sections {
                trimmedSection := Trim(section, " `t`r`n")
                if (trimmedSection = "") {
                    continue
                }
                lines := StrSplit(trimmedSection, "`n", "`r")
                firstLine := lines[1]
                if (firstLine = "[WINDOW_SIZE]") {
                    for line in lines {
                        trimmedLine := Trim(line)
                        if (trimmedLine = "" || SubStr(trimmedLine, 1, 1) = "[" || SubStr(trimmedLine, 1, 1) = ";") {
                            continue
                        }
                        if (InStr(trimmedLine, "=")) {
                            lineParts := StrSplit(trimmedLine, "=", "", 2)
                            lineKey := Trim(lineParts[1])
                            lineValue := Trim(lineParts[2])
                            if (lineKey = key) {
                                return Integer(lineValue)
                            }
                        }
                    }
                }
            }
        }
        catch {
            ; Игнорируем ошибки загрузки
            return defaultValue
        }
    }
    return defaultValue
}

; === ИНИЦИАЛИЗАЦИЯ МАССИВОВ ===
loop TabCount {
    LastScrollPositions.Push(0)
    LastHScrollPositions.Push(0)
}

; === ОСНОВНОЕ ОКНО ===
CreateMainWindow() {
    global MyGui, Version, Btn_AlwaysOnTop, Btn_Theme, Btn_Transparency, Btn_Font, Btn_FontSize, Btn_TabSize
    global contentEdit, lineNumberCtrl, TabHeaders, helpButton, sepLine, LineNumberWidth
    global AlwaysOnTop, TransparencyLevel, FontSize, FontName, ThemeLevel, TabSize, TabContents, CurrentTabIndex
    
    WindowWidth := LoadWindowSizeSetting("Width", DEFAULT_MAIN_WIDTH)
    WindowHeight := LoadWindowSizeSetting("Height", DEFAULT_MAIN_HEIGHT)
    
    MyGui := Gui(, "PageX " Version " - Блокнот с вкладками")
    MyGui.Opt("+Resize +MinSize" MIN_MAIN_WIDTH "x" MIN_MAIN_HEIGHT)
    MyGui.SetFont("s10", "Segoe UI")
    MyGui.MarginX := 10
    MyGui.MarginY := 10
    
    Btn_AlwaysOnTop := MyGui.Add("Button", "x10 y10 w40 h22", GetArrowText(AlwaysOnTop))
    Btn_AlwaysOnTop.OnEvent("Click", ToggleAlwaysOnTop)
    Btn_AlwaysOnTop.ToolTip := "ОКНО`nПоложение окна: " . (AlwaysOnTop ? "ПОВЕРХ ВСЕХ (ВКЛ)" : "ОБЫЧНОЕ (ВЫКЛ)") . "`nНажмите для переключения"
    
    Btn_Theme := MyGui.Add("Button", "x+10 y10 w25 h22", GetThemeIcon(ThemeLevel))
    Btn_Theme.OnEvent("Click", CycleTheme)
    Btn_Theme.ToolTip := "ТЕМА`nТекущая тема: " . GetCurrentTheme().Name . "`nНажмите для переключения"
    
    Btn_Transparency := MyGui.Add("Button", "x+10 y10 w40 h22", GetTransparencyText(TransparencyLevel))
    Btn_Transparency.OnEvent("Click", CycleTransparency)
    Btn_Transparency.ToolTip := "ПРОЗРАЧНОСТЬ`nТекущий уровень: " . GetTransparencyPercent(TransparencyLevel) . "`nНажмите для переключения"
    
    Btn_Font := MyGui.Add("Button", "x+10 y10 w100 h22", GetFontNameButtonText())
    Btn_Font.OnEvent("Click", CycleFont)
    Btn_Font.ToolTip := "ШРИФТ`nТекущий шрифт: " . FontName . "`nНажмите для смены шрифта"
    
    Btn_FontSize := MyGui.Add("Button", "x+10 y10 w60 h22", GetFontSizeButtonText())
    Btn_FontSize.OnEvent("Click", CycleFontSize)
    Btn_FontSize.ToolTip := "РАЗМЕР ШРИФТА`nТекущий размер: " . FontSize . "pt`nНажмите для изменения (8-24)"
    
    Btn_TabSize := MyGui.Add("Button", "x+10 y10 w60 h22", GetTabSizeButtonText())
    Btn_TabSize.OnEvent("Click", CycleTabSize)
    Btn_TabSize.ToolTip := GetTabSizeToolTip()
    
    helpButton := MyGui.Add("Button", "x+10 y10 w60 h22", "Help F1")
    helpButton.OnEvent("Click", ToggleHelp)
    helpButton.ToolTip := "Открыть справку`nГорячая клавиша: F1"
    
    tabHeaderX := 10
    tabHeaderY := 40
    
    loop TabCount {
        tabNumber := A_Index
        if (A_Index = CurrentTabIndex) {
            btnText := "▶ " . tabNumber . " ◀"
        } else {
            btnText := "  " . tabNumber . "  "
        }
        
        headerBtn := MyGui.Add("Button", 
            Format("x{} y{} w50 h22", tabHeaderX, tabHeaderY),
            btnText)
        
        headerBtn.OnEvent("Click", TabHeader_Click.Bind(A_Index))
        TabHeaders.Push(headerBtn)
        tabHeaderX += 55
    }
    
    sepLine := MyGui.Add("Text", "x10 y68 w" (WindowWidth - 20) " 0x10")
    
    lineNumberCtrl := MyGui.Add("Edit", 
        Format("x{1} y{2} w{3} h{4} +Multi +Right -VScroll +Border -TabStop", 
               10, 75, LineNumberWidth, WindowHeight - 90),
        "")
    lineNumberCtrl.SetFont("s" FontSize, FontName)
    lineNumberCtrl.OnEvent("Change", OnLineNumberChange)
    
    contentEdit := MyGui.Add("Edit", 
        Format("x{1} y{2} w{3} h{4} +Multi +HScroll +VScroll +0x100 +WantTab -Wrap", 
               10 + LineNumberWidth, 75, WindowWidth - 25 - LineNumberWidth, WindowHeight - 90),
        TabContents[CurrentTabIndex])
    contentEdit.SetFont("s" FontSize, FontName)
    contentEdit.OnEvent("Change", OnEditChangeWithLineNumbers)
    
    MyGui.OnEvent("Close", SaveAndExit)
    MyGui.OnEvent("Size", GuiSize)
    
    MyGui.Show("w" WindowWidth " h" WindowHeight)
    ApplyWindowSettings()
}

; === ОБРАБОТКА ТАБУЛЯЦИИ ===
OnTabKey(*) {
    global TabSize
    SendInput "{Space " . TabSize . "}"
    return true
}

; === ГОРИЗОНТАЛЬНАЯ ПРОКРУТКА ===
PerformHorizontalScroll(ctrl, direction) {
    try {
        SendMessage(0x0114, direction > 0 ? 1 : 0, 0, ctrl.Hwnd)
    }
    catch {
        ; Игнорируем ошибки прокрутки
    }
}

; === ОБРАБОТЧИК КОЛЕСА МЫШИ ===
WheelHandler(wParam, lParam, msg, hwnd) {
    global contentEdit
    if (GetKeyState("Ctrl")) {
        delta := wParam >> 16
        delta := delta > 0x7FFF ? -(0x10000 - delta) : delta
        if (IsObject(contentEdit) && contentEdit.Hwnd) {
            if (delta > 0) {
                PerformHorizontalScroll(contentEdit, 1)
            } else {
                PerformHorizontalScroll(contentEdit, -1)
            }
        }
        return 0
    }
}

; === УПРАВЛЕНИЕ НАСТРОЙКАМИ ===
ToggleAlwaysOnTop(*) {
    global AlwaysOnTop, Btn_AlwaysOnTop, Version
    AlwaysOnTop := !AlwaysOnTop
    if AlwaysOnTop {
        WinSetAlwaysOnTop true, "PageX " Version " - Блокнот с вкладками"
        Btn_AlwaysOnTop.Text := "UP"
        Btn_AlwaysOnTop.ToolTip := "ОКНО`nПоложение окна: ПОВЕРХ ВСЕХ (ВКЛ)`nНажмите для переключения"
    } else {
        WinSetAlwaysOnTop false, "PageX " Version " - Блокнот с вкладками"
        Btn_AlwaysOnTop.Text := "DWN"
        Btn_AlwaysOnTop.ToolTip := "ОКНО`nПоложение окна: ОБЫЧНОЕ (ВЫКЛ)`nНажмите для переключения"
    }
    SaveData(false)
}

CycleTransparency(*) {
    global TransparencyLevel, Btn_Transparency
    TransparencyLevel := Mod(TransparencyLevel + 1, 3)
    ApplyTransparency()
    Btn_Transparency.Text := GetTransparencyText(TransparencyLevel)
    Btn_Transparency.ToolTip := "ПРОЗРАЧНОСТЬ`nТекущий уровень: " . GetTransparencyPercent(TransparencyLevel) . "`nНажмите для переключения"
    SaveData(false)
}

ApplyTransparency() {
    global TransparencyLevel, Version
    if !WinExist("PageX " Version " - Блокнот с вкладками")
        return
    switch TransparencyLevel {
        case 1: WinSetTransparent 192, "PageX " Version " - Блокнот с вкладками"
        case 2: WinSetTransparent 128, "PageX " Version " - Блокнот с вкладками"
        default: WinSetTransparent 255, "PageX " Version " - Блокнот с вкладками"
    }
}

CycleTheme(*) {
    global ThemeLevel, Btn_Theme
    ThemeLevel := Mod(ThemeLevel + 1, 2)
    Btn_Theme.Text := GetThemeIcon(ThemeLevel)
    Btn_Theme.ToolTip := "ТЕМА`nТекущая тема: " . GetCurrentTheme().Name . "`nНажмите для переключения"
    ApplyTheme()
    SaveData(false)
}

ApplyTheme() {
    global MyGui, Btn_AlwaysOnTop, Btn_Theme, Btn_Transparency, Btn_Font, Btn_FontSize, helpButton, sepLine
    global contentEdit, FontSize, FontName, ThemeLevel, CurrentTabIndex, AlwaysOnTop, TransparencyLevel
    global lineNumberCtrl, TabHeaders, Btn_TabSize
    theme := GetCurrentTheme()
    Btn_AlwaysOnTop.Text := GetArrowText(AlwaysOnTop)
    Btn_Transparency.Text := GetTransparencyText(TransparencyLevel)
    Btn_Font.Text := GetFontNameButtonText()
    Btn_FontSize.Text := GetFontSizeButtonText()
    Btn_TabSize.Text := GetTabSizeButtonText()
    ApplySimpleTheme()
}

ApplySimpleTheme() {
    global MyGui, Btn_AlwaysOnTop, Btn_Theme, Btn_Transparency, Btn_Font, Btn_FontSize, helpButton, sepLine
    global contentEdit, FontSize, FontName, TabHeaders, lineNumberCtrl, Btn_TabSize
    theme := GetCurrentTheme()
    try {
        MyGui.BackColor := theme.Background
    }
    catch {
        ; Игнорируем ошибки установки цвета
    }
    
    for ctrl in [sepLine] {
        if IsObject(ctrl) {
            try {
                ctrl.SetFont("c" . theme.Text)
                ctrl.Opt("Background" . theme.Background)
            }
            catch {
                ; Игнорируем ошибки установки стилей
            }
        }
    }
    
    for ctrl in [helpButton, Btn_Theme, Btn_AlwaysOnTop, Btn_Transparency, Btn_Font, Btn_FontSize, Btn_TabSize] {
        if IsObject(ctrl) {
            try {
                ctrl.SetFont("c" . theme.Text)
                ctrl.Opt("Background" . theme.Button)
            }
            catch {
                ; Игнорируем ошибки установки стилей
            }
        }
    }
    
    loop TabHeaders.Length {
        headerBtn := TabHeaders[A_Index]
        if (IsObject(headerBtn)) {
            try {
                if (A_Index = CurrentTabIndex) {
                    headerBtn.SetFont("cWhite Bold")
                    headerBtn.Opt("Background" . theme.TabActive)
                } else {
                    headerBtn.SetFont("c" . theme.Text . " Norm")
                    headerBtn.Opt("Background" . theme.Background)
                }
            }
            catch {
                ; Игнорируем ошибки установки стилей
            }
        }
    }
    
    if IsObject(contentEdit) && contentEdit.Hwnd {
        try {
            contentEdit.SetFont("c" . theme.EditText " s" FontSize, FontName)
            contentEdit.Opt("Background" . theme.EditBackground)
        }
        catch {
            ; Игнорируем ошибки установки стилей
        }
    }
    
    if IsObject(lineNumberCtrl) && lineNumberCtrl.Hwnd {
        try {
            lineNumberCtrl.Opt("Background" . theme.LineNumberBackground)
            lineNumberCtrl.SetFont("c" . theme.LineNumberText " s" FontSize, FontName)
        }
        catch {
            ; Игнорируем ошибки установки стилей
        }
    }
}

CycleFont(*) {
    global Fonts, FontName, Btn_Font, contentEdit, CursorPositions, CurrentTabIndex, TabContents
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
    SaveData(false)
}

CycleFontSize(*) {
    global FontSize, Btn_FontSize
    FontSize := FontSize + 1
    if (FontSize > 24) {
        FontSize := 8
    }
    UpdateFontAndSize()
    SaveData(false)
}

CycleTabSize(*) {
    global TabSize, TabSizes, Btn_TabSize
    currentIndex := 0
    loop TabSizes.Length {
        if (TabSizes[A_Index] = TabSize) {
            currentIndex := A_Index
            break
        }
    }
    if (currentIndex = TabSizes.Length) {
        TabSize := TabSizes[1]
    } else {
        TabSize := TabSizes[currentIndex + 1]
    }
    Btn_TabSize.Text := GetTabSizeButtonText()
    Btn_TabSize.ToolTip := GetTabSizeToolTip()
    SaveData(false)
}

UpdateFontAndSize() {
    global Btn_Font, Btn_FontSize, FontName, FontSize, contentEdit, CurrentTabIndex, CursorPositions
    global TabHeaders, lineNumberCtrl, LineNumbersData, VisibleLinesCache, TabContents
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        TabContents[CurrentTabIndex] := contentEdit.Value
    }
    Btn_Font.Text := GetFontNameButtonText()
    Btn_Font.ToolTip := "ШРИФТ`nТекущий шрифт: " . FontName . "`nНажмите для смены шрифта"
    Btn_FontSize.Text := GetFontSizeButtonText()
    Btn_FontSize.ToolTip := "РАЗМЕР ШРИФТА`nТекущий размер: " . FontSize . "pt`nНажмите для изменения (8-24)"
    loop TabHeaders.Length {
        if (IsObject(TabHeaders[A_Index])) {
            try {
                TabHeaders[A_Index].SetFont("s10", FontName)
            }
            catch {
                ; Игнорируем ошибки установки шрифта
            }
        }
    }
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        try {
            contentEdit.SetFont("s" FontSize, FontName)
            contentEdit.Value := TabContents[CurrentTabIndex]
            SetCursorPosition(contentEdit, CursorPositions[CurrentTabIndex])
        }
        catch {
            ; Игнорируем ошибки обновления контента
        }
    }
    VisibleLinesCache := CalculateVisibleLines(CurrentTabIndex)
    if (IsObject(lineNumberCtrl) && lineNumberCtrl.Hwnd) {
        try {
            lineNumberCtrl.SetFont("s" FontSize, FontName)
            if (LineNumbersData.Has(CurrentTabIndex)) {
                LineNumbersData.Delete(CurrentTabIndex)
                UpdateLineNumbersData(CurrentTabIndex, true)
                SyncLineNumbersForTab(CurrentTabIndex, true)
            }
        }
        catch {
            ; Игнорируем ошибки обновления номеров строк
        }
    }
    ApplyTheme()
    SaveData(false)
}

; === ВКЛАДКИ ===
TabHeader_Click(tabIndex, *) {
    global CurrentTabIndex, TabHeaders, contentEdit, TabContents, CursorPositions
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        TabContents[CurrentTabIndex] := contentEdit.Value
    }
    oldTab := CurrentTabIndex
    CurrentTabIndex := tabIndex
    UpdateTabHeaders(oldTab, tabIndex)
    UpdateContent(tabIndex)
    SyncTabChange()
}

UpdateTabHeaders(oldTab, newTab) {
    global TabHeaders
    theme := GetCurrentTheme()
    if (oldTab >= 1 && oldTab <= TabHeaders.Length) {
        tabNumber := oldTab
        TabHeaders[oldTab].Text := "  " . tabNumber . "  "
        try {
            TabHeaders[oldTab].SetFont("Norm")
            TabHeaders[oldTab].Opt("Background" . theme.Background . " c" . theme.Text)
        }
        catch {
            ; Игнорируем ошибки установки стилей
        }
    }
    if (newTab >= 1 && newTab <= TabHeaders.Length) {
        tabNumber := newTab
        TabHeaders[newTab].Text := "▶ " . tabNumber . " ◀"
        try {
            TabHeaders[newTab].SetFont("Bold")
            TabHeaders[newTab].Opt("Background" . theme.TabActive . " cWhite")
        }
        catch {
            ; Игнорируем ошибки установки стилей
        }
    }
}

UpdateContent(tabIndex) {
    global contentEdit, TabContents, CursorPositions
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        try {
            contentEdit.Value := TabContents[tabIndex]
            SetCursorPosition(contentEdit, CursorPositions[tabIndex])
            contentEdit.Focus()
        }
        catch {
            ; Игнорируем ошибки обновления контента
        }
    }
}

; === НОМЕРА СТРОК ===
SetCursorPosition(editCtrl, position) {
    if (IsObject(editCtrl) && position > 0) {
        try {
            SendMessage(0x00B1, position - 1, position - 1, editCtrl.Hwnd)
        }
        catch {
            ; Игнорируем ошибки установки курсора
        }
    }
}

CalculateVisibleLines(tabIndex) {
    global FontSize, VisibleLinesCache, contentEdit
    if (!IsObject(contentEdit) || !contentEdit.Hwnd)
        return VisibleLinesCache
    contentEdit.GetPos(, , , &H)
    lineHeight := FontSize * 1.5
    if (lineHeight > 0) {
        visibleLines := Floor(H / lineHeight)
        visibleLines := Max(20, visibleLines + 5)
        VisibleLinesCache := visibleLines
    }
    return VisibleLinesCache
}

UpdateLineNumbersData(tabIndex, forceUpdate := false) {
    global contentEdit, LineNumbersData, TabContents
    if (!IsObject(contentEdit) || !contentEdit.Hwnd)
        return
    currentText := TabContents[tabIndex]
    if (!forceUpdate && LineNumbersData.Has(tabIndex)) {
        oldText := ""
        try {
            oldText := LineNumbersData[tabIndex].text
        }
        catch {
            oldText := ""
        }
        if (oldText = currentText) {
            return
        }
    }
    lineCount := 1
    if (currentText != "") {
        lines := StrSplit(currentText, "`n", "`r")
        lineCount := lines.Length
        if (SubStr(currentText, -1) = "`n" || SubStr(currentText, -2) = "`r`n") {
            lineCount += 1
        }
    }
    numbers := []
    maxDigits := StrLen(lineCount)
    loop lineCount {
        numberStr := Format("{:d}", A_Index)
        while (StrLen(numberStr) < maxDigits) {
            numberStr := " " . numberStr
        }
        numbers.Push(numberStr)
    }
    LineNumbersData[tabIndex] := {numbers: numbers, text: currentText}
}

SyncLineNumbersForTab(tabIndex, forceSync := false) {
    global contentEdit, lineNumberCtrl, LineNumbersData, VisibleLinesCache, LastScrollPositions
    if (!IsObject(contentEdit) && contentEdit.Hwnd || !IsObject(lineNumberCtrl) || !lineNumberCtrl.Hwnd)
        return
    currentLine := SendMessage(0x00CE, 0, 0, contentEdit.Hwnd)
    if (!forceSync && currentLine = LastScrollPositions[tabIndex])
        return
    LastScrollPositions[tabIndex] := currentLine
    UpdateLineNumbersData(tabIndex)
    numbersData := LineNumbersData[tabIndex]
    if (!numbersData)
        return
    numbers := numbersData.numbers
    if (!numbers.Length)
        return
    startIdx := Max(1, currentLine + 1)
    visibleLines := CalculateVisibleLines(tabIndex)
    newText := ""
    loop visibleLines {
        idx := startIdx + A_Index - 1
        if (idx <= numbers.Length) {
            newText .= numbers[idx] . "`r`n"
        } else {
            newText .= "`r`n"
        }
    }
    lineNumberCtrl.Value := RTrim(newText, "`r`n")
}

SyncAllTabs(forceSync := false) {
    global CurrentTabIndex
    SyncLineNumbersForTab(CurrentTabIndex, forceSync)
}

ActiveSync() {
    SyncAllTabs()
}

OnEditChangeWithLineNumbers(editCtrl, *) {
    global NeedsSave, CurrentTabIndex, TabContents, contentEdit
    NeedsSave := true
    TabContents[CurrentTabIndex] := contentEdit.Value
    UpdateLineNumbersData(CurrentTabIndex, true)
    SetTimer(() => SyncLineNumbersForTab(CurrentTabIndex, true), -50)
}

OnScrollMsg(wParam, lParam, msg, hwnd) {
    global contentEdit, CurrentTabIndex
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        if (hwnd = contentEdit.Hwnd) {
            SyncLineNumbersForTab(CurrentTabIndex)
            SetTimer(SyncAllTabs, -20)
        }
    }
}

SyncTabChange() {
    global CurrentTabIndex, contentEdit, CursorPositions
    UpdateLineNumbersData(CurrentTabIndex, true)
    LastScrollPositions[CurrentTabIndex] := -1
    SyncLineNumbersForTab(CurrentTabIndex, true)
    SetCursorPosition(contentEdit, CursorPositions[CurrentTabIndex])
}

; === ИЗМЕНЕНИЕ РАЗМЕРА ОКНА ===
GuiSize(GuiObj, MinMax, Width, Height) {
    global TabHeaders, contentEdit, sepLine, helpButton, lineNumberCtrl, VisibleLinesCache, CurrentTabIndex, LineNumberWidth
    if (MinMax = -1)
        return
    if (IsObject(sepLine)) {
        try {
            sepLine.Move(, , Width - 20)
        }
        catch {
            ; Игнорируем ошибки перемещения
        }
    }
    if (helpButton) {
        try {
            helpButton.Move(Width - 70, 10, 60)
        }
        catch {
            ; Игнорируем ошибки перемещения
        }
    }
    editHeight := Height - 85
    editWidth := Width - 25 - LineNumberWidth
    if (editWidth < 10)
        editWidth := 10
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        try {
            contentEdit.Move(10 + LineNumberWidth, 75, editWidth, editHeight)
        }
        catch {
            ; Игнорируем ошибки перемещения
        }
    }
    if (IsObject(lineNumberCtrl) && lineNumberCtrl.Hwnd) {
        try {
            lineNumberCtrl.Move(10, 75, LineNumberWidth, editHeight)
        }
        catch {
            ; Игнорируем ошибки перемещения
        }
    }
    VisibleLinesCache := CalculateVisibleLines(CurrentTabIndex)
    SetTimer(() => SyncAllTabs(true), -100)
}

; === ВЫХОД И СОХРАНЕНИЕ ===
SaveAndExit(*) {
    global SyncTimer, MyGui, NeedsSave
    if (SyncTimer) {
        SetTimer(ActiveSync, 0)
        SyncTimer := ""
    }
    if (NeedsSave) {
        SaveData(true)
        Sleep 300
    }
    ExitApp
}

ApplyWindowSettings() {
    global AlwaysOnTop, Version
    if !WinExist("PageX " Version " - Блокнот с вкладками")
        return
    if AlwaysOnTop {
        try {
            WinSetAlwaysOnTop true, "PageX " Version " - Блокнот с вкладками"
        }
        catch {
            ; Игнорируем ошибки установки режима окна
        }
    }
    ApplyTheme()
    ApplyTransparency()
}

; === СПРАВКА ===
ToggleHelp(*) {
    global HelpWindow
    try {
        if IsObject(HelpWindow) && WinExist("ahk_id " HelpWindow.Hwnd) {
            HelpWindow.Destroy()
            HelpWindow := ""
        } else {
            ShowHelp()
        }
    }
    catch {
        HelpWindow := ""
        ShowHelp()
    }
}

ShowHelp(*) {
    global HelpWindow, Version, ThemeLevel, AlwaysOnTop, TransparencyLevel, FontName, FontSize, CurrentTabIndex, TabSize, ScriptBaseName
    global DEFAULT_HELP_WIDTH, DEFAULT_HELP_HEIGHT
    if IsObject(HelpWindow) {
        try {
            if WinExist("ahk_id " HelpWindow.Hwnd) {
                HelpWindow.Show()
                return
            }
        }
        catch {
            HelpWindow := ""
        }
    }
    HelpWindow := Gui("+AlwaysOnTop +ToolWindow -Resize -MaximizeBox -MinimizeBox", "PageX " Version " - Справка")
    HelpWindow.SetFont("s10", "Segoe UI")
    HelpWindow.MarginX := 20
    HelpWindow.MarginY := 20
    theme := GetCurrentTheme()
    HelpWindow.BackColor := theme.Background
    helpText := "PageX " Version "  https://github.com/IgerOK/PageX`n"
    helpText .= "MIT License © 2025`n"
    helpText .= "Без гарантий и обязательств`n"
    helpText .= "----------------------------------------------------`n"
    helpText .= "📌 ОСНОВНЫЕ КОМАНДЫ:`n"
    helpText .= "• Ctrl+S  - Сохранить данные`n"
    helpText .= "• Ctrl+Q  - Сохранить и выйти`n"
    helpText .= "• F1      - Эта справка`n"
    helpText .= "• Ctrl+1..9 - Переключение вкладок 1-9`n"
    helpText .= "• Ctrl+0   - Переключение вкладки 10`n"
    helpText .= "• Клик по кнопке вкладки - Переключить вкладку`n"
    helpText .= "• Tab в текстовом поле - Вставить " TabSize . " пробелов`n"
    helpText .= "• Ctrl+Колесо мыши - Горизонтальная прокрутка`n"
    helpText .= "🎨 ТЕМА (2 уровня):`n"
    helpText .= "• Текущая тема: " theme.Name " " theme.Icon "`n"
    helpText .= "• Нажмите на лампочку для смены темы`n"
    helpText .= "📌 КНОПКИ ПАНЕЛИ:`n"
    helpText .= "• " GetArrowText(AlwaysOnTop) " - ОКНО: " (AlwaysOnTop ? "ПОВЕРХ ВСЕХ" : "ОБЫЧНОЕ") "`n"
    helpText .= "• " theme.Icon " - ТЕМА: " theme.Name "`n"
    helpText .= "• " GetTransparencyText(TransparencyLevel) " - ПРОЗРАЧНОСТЬ`n"
    helpText .= "• " GetFontNameButtonText() " - ШРИФТ (имя)`n"
    helpText .= "• " GetFontSizeButtonText() " - РАЗМЕР ШРИФТА`n"
    helpText .= "• " GetTabSizeButtonText() " - РАЗМЕР ТАБУЛЯЦИИ`n"
    helpText .= "• Help F1 - Открыть справку`n"
    helpText .= "💾 РЕЖИМ СОХРАНЕНИЯ:`n"
    helpText .= "• Все данные сохраняются в один файл *.ddd`n"
    helpText .= "• Сохраняется автоматически при выходе`n"
    helpText .= "📁 ПЕРЕКЛЮЧЕНИЕ ВКЛАДОК:`n"
    helpText .= "• Используйте кнопки 1-10 во втором ряду`n"
    helpText .= "• Или горячие клавиши Ctrl+1..9 и Ctrl+0 для вкладки 10`n"
    helpText .= "• Активная вкладка выделена цветом`n"
    helpText .= "📝 ФОРМАТ ФАЙЛА ДАННЫХ:`n"
    helpText .= "• Данные вкладки 1`n"
    helpText .= "• <TAB-1<`n"
    helpText .= "• Данные вкладки 2`n"
    helpText .= "• <TAB-2<`n"
    helpText .= "• ...и т.д.`n"
    helpText .= "• Разделитель <TAB-X< указывает, что данные вкладки X находятся ВЫШЕ`n"
    helpText .= "`n📋 ДИАГНОСТИКА:`n"
    helpText .= "• Файл данных: " ScriptBaseName ".ddd`n"
    helpText .= "• Файл лога: " ScriptBaseName ".log`n"
    helpText .= "• При проблемах проверьте файл лога`n"
    helpTextCtrl := HelpWindow.Add("Edit", "w" DEFAULT_HELP_WIDTH " h" DEFAULT_HELP_HEIGHT " +Multi +ReadOnly +VScroll", helpText)
    helpTextCtrl.SetFont("c" . theme.Text)
    helpTextCtrl.Opt("Background" . theme.Background)
    HelpWindow.Show("Center")
    HelpWindow.OnEvent("Close", CloseHelpWindow)
}

CloseHelpWindow(*) {
    global HelpWindow
    try {
        if IsObject(HelpWindow) {
            HelpWindow.Destroy()
            HelpWindow := ""
        }
    }
    catch {
        HelpWindow := ""
    }
}

OnLineNumberChange(ctrl, *) {
    SetTimer(() => RestoreLineNumbers(ctrl), -1)
}

RestoreLineNumbers(ctrl) {
    global CurrentTabIndex
    SyncLineNumbersForTab(CurrentTabIndex, true)
}

SendMessage(Msg, wParam, lParam, hwnd) {
    return DllCall("SendMessage", "ptr", hwnd, "uint", Msg, "ptr", wParam, "ptr", lParam, "int")
}

; === ГОРЯЧИЕ КЛАВИШИ ===
#HotIf WinActive("PageX " Version " - Блокнот с вкладками")
^s::SaveData(true)

^q::
{
    SaveData(true)
    Sleep 300
    ExitApp
}

F1::ToggleHelp()

^1::SwitchTab(1)
^2::SwitchTab(2)
^3::SwitchTab(3)
^4::SwitchTab(4)
^5::SwitchTab(5)
^6::SwitchTab(6)
^7::SwitchTab(7)
^8::SwitchTab(8)
^9::SwitchTab(9)
^0::SwitchTab(10)

^+Up::
{
    global FontSize
    if (FontSize < 24) {
        FontSize += 1
        UpdateFontAndSize()
        SaveData(false)
    }
}

^+Down::
{
    global FontSize
    if (FontSize > 8) {
        FontSize -= 1
        UpdateFontAndSize()
        SaveData(false)
    }
}

Tab::
{
    OnTabKey()
    return true
}

^Tab::
{
    OnTabKey()
    return true
}

^WheelUp::
{
    global contentEdit
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        PerformHorizontalScroll(contentEdit, 1)
    }
    return
}

^WheelDown::
{
    global contentEdit
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        PerformHorizontalScroll(contentEdit, -1)
    }
    return
}

#HotIf

#HotIf WinActive("PageX " Version " - Справка")
F1::ToggleHelp()
#HotIf

SwitchTab(TabNumber) {
    global CurrentTabIndex, TabHeaders, contentEdit, CursorPositions, TabContents
    if (TabNumber >= 1 && TabNumber <= 10) {
        if (IsObject(contentEdit) && contentEdit.Hwnd) {
            TabContents[CurrentTabIndex] := contentEdit.Value
        }
        oldTab := CurrentTabIndex
        CurrentTabIndex := TabNumber
        UpdateTabHeaders(oldTab, TabNumber)
        UpdateContent(TabNumber)
        SyncTabChange()
    }
}

; === ОСНОВНОЙ КОД ЗАПУСКА ===
LoadData()
CreateMainWindow()
UpdateLineNumbersData(CurrentTabIndex, true)
SyncLineNumbersForTab(CurrentTabIndex, true)
UpdateTabHeaders(CurrentTabIndex, CurrentTabIndex)
SyncTimer := SetTimer(ActiveSync, 100)
OnMessage(0x0115, OnScrollMsg)
OnMessage(0x0114, OnScrollMsg)
OnMessage(0x020A, WheelHandler)
OnMessage(0x020E, OnScrollMsg)

OnExit(*) {
    global NeedsSave, SyncTimer, contentEdit, TabContents, CurrentTabIndex
    if (SyncTimer) {
        SetTimer(ActiveSync, 0)
        SyncTimer := ""
    }
    if (IsObject(contentEdit) && contentEdit.Hwnd) {
        TabContents[CurrentTabIndex] := contentEdit.Value
    }
    if (NeedsSave) {
        SaveData(true)
    }
}