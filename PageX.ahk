; PageX — Защищенный блокнот с 10 вкладками
; Автор: https://github.com/IgerOK
; Лицензия: MIT
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; === Константы и версия ===
Version := "v1.1"
SALT_CONSTANT := "PageX-V1-Static-Universal-Salt-For-All-Systems-2024-MIT"

; === РАЗМЕРЫ ОКОН ===
; Настройки размеров окон (ширина x высота)
PasswordWindowSize := {Width: 270, Height: 480}      ; Окно ввода пароля
MainWindowSize := {Width: 700, Height: 520}          ; Основное окно программы
HelpWindowSize := {Width: 300, Height: 0}            ; Окно помощи (0 = авто)

; === НАСТРОЙКИ ===
DataFile := A_ScriptDir "\notes.dat"
SettingsFile := A_ScriptDir "\settings.ini"
TabCount := 10  ; 10 вкладок (0-9)
Tabs := []
MasterPassword := ""
Edits := []
tabCtrl := ""
Btn_AlwaysOnTop := ""
Btn_Theme := ""
Btn_Transparency := ""
Btn_Font := ""
FontSize := 10  ; Начальный размер шрифта
HelpWindow := ""  ; Для управления окном справки
CurrentTabIndex := 1  ; Текущая активная вкладка

; === НАСТРОЙКА ШРИФТОВ ===
; === ИЗМЕНИТЕ ЗДЕСЬ ПЕД ЗАПУСКОМ ===
; Убедитесь, что шрифты установлены в вашей системе
; Формат: ["Шрифт1", "Шрифт2", "Шрифт3", ...]
;Fonts := ["Segoe UI", "Arial", "Arial Narrow", "Consolas", "Courier New"]
Fonts := ["Segoe UI", "Calibri", "Verdana", "Georgia", "Tahoma"]

; Загружаем настройки
AlwaysOnTop := LoadSetting("AlwaysOnTop", 0)
TransparencyLevel := LoadSetting("TransparencyLevel", 0)
FontSize := LoadSetting("FontSize", 10)  ; Загружаем размер шрифта
FontName := LoadSetting("FontName", Fonts[1])  ; Загружаем имя текущего шрифта
ThemeLevel := LoadSetting("ThemeLevel", 0)  ; 0=светлая, 1=средняя, 2=темная

; Проверяем, что выбранный шрифт есть в списке
if !IsFontInList(FontName) {
    FontName := Fonts[1]  ; Если шрифт не найден, используем первый из списка
}

; === ЦВЕТА ТЕМ ===
; Светлая тема (0)
LightTheme := {
    Background: "FFFFFF",      ; Белый фон окна
    Text: "000000",           ; Черный текст интерфейса
    Control: "F0F0F0",        ; Светло-серый для контролов
    Border: "C0C0C0",         ; Серые границы
    Highlight: "E0E0E0",      ; Подсветка
    Button: "F0F0F0",         ; Цвет кнопок
    EditBackground: "FFFFFF", ; Белый фон для текстовых полей
    EditText: "000000",       ; Черный текст в полях ввода
    Name: "Светлая",
    Icon: "🔆",               ; Яркая лампочка
    Arrow: "UP"               ; Стрелка вверх текст
}

; Средняя тема (1)
MediumTheme := {
    Background: "D0D0D0",      ; Серый фон окна
    Text: "000000",           ; Черный текст интерфейса
    Control: "B0B0B0",        ; Серый
    Border: "808080",         ; Темные границы
    Highlight: "C0C0C0",      ; Подсветка
    Button: "B0B0B0",         ; Цвет кнопок
    EditBackground: "F0F0F0", ; Светло-серый фон
    EditText: "000000",       ; Черный текст в полях ввода
    Name: "Средняя",
    Icon: "💡",               ; Лампочка
    Arrow: "UP"               ; Стрелка вверх текст
}

; Темная тема (2) - УЛУЧШЕННАЯ ВЕРСИЯ
DarkTheme := {
    Background: "2D2D2D",      ; Темный фон окна
    Text: "E0E0E0",           ; Светлый текст интерфейса
    Control: "404040",        ; Темный
    Border: "606060",         ; Темные границы
    Highlight: "505050",      ; Подсветка
    Button: "404040",         ; Цвет кнопок
    EditBackground: "404040", ; Темно-серый фон для текстовых полей
    EditText: "A8A8A8",       ; Холодный серый HEX: A8A8A8 = RGB(168,168,168)
    Name: "Темная",
    Icon: "🔦",               ; Фонарик (темная лампочка)
    Arrow: "UP"               ; Стрелка вверх текст
}

; Все темы в массиве
Themes := [LightTheme, MediumTheme, DarkTheme]

; === УЛУЧШЕННОЕ ШИФРОВАНИЕ (ВСЁ В ОДНОМ) ===

; Создает детерминированную соль на основе пароля и константы
GetSystemSalt() {
    global MasterPassword, SALT_CONSTANT
    
    ; Если пароль уже введен, создаем соль на его основе
    if MasterPassword {
        ; Комбинируем пароль с константой для уникальности
        combined := MasterPassword . SALT_CONSTANT
        return CreateDeterministicSalt(combined, 64)
    }
    
    ; На этапе загрузки используем константу
    return CreateDeterministicSalt(SALT_CONSTANT, 64)
}

; Создает детерминированную соль фиксированной длины
CreateDeterministicSalt(input, length) {
    result := Buffer(length, 0)
    
    ; Простой детерминированный алгоритм на основе FNV-1a
    hash := 0x811C9DC5  ; Начальное значение FNV-1a
    
    ; Преобразуем входную строку в байты
    inputBuf := Buffer(StrPut(input, "UTF-8") - 1)
    StrPut(input, inputBuf, "UTF-8")
    
    ; Хешируем всю строку
    loop inputBuf.Size {
        i := A_Index - 1
        hash := hash ^ NumGet(inputBuf, i, "UChar")
        hash := (hash * 0x01000193) & 0xFFFFFFFF
    }
    
    ; Используем хеш как seed для генерации соли
    loop length {
        i := A_Index - 1
        
        ; Псевдослучайный генератор
        hash := (hash * 1103515245 + 12345) & 0xFFFFFFFF
        saltByte := (hash >> 16) & 0xFF
        
        ; Добавляем позицию для уникальности
        saltByte := saltByte ^ (i & 0xFF)
        
        NumPut("UChar", saltByte, result, i)
    }
    
    return result
}

; Создает усиленный ключ из пароля
CreateStrongKey(password, length := 256) {
    passwordBuf := Buffer(StrPut(password, "UTF-8") - 1)
    StrPut(password, passwordBuf, "UTF-8")
    
    result := Buffer(length, 0)
    
    ; Получаем системную соль
    salt := GetSystemSalt()
    
    ; Генерируем ключ с использованием соли
    loop length {
        i := A_Index - 1
        
        ; Берем байты из пароля циклически
        passByte := NumGet(passwordBuf, Mod(i, passwordBuf.Size), "UChar")
        
        ; Берем байты из соли
        saltByte := NumGet(salt, Mod(i, salt.Size), "UChar")
        
        ; Линейный конгруэнтный генератор для перемешивания
        lcg := i * 1103515245 + 12345 + saltByte
        
        ; Смешиваем все компоненты
        keyByte := passByte ^ saltByte
        keyByte := keyByte ^ (lcg & 0xFF)
        keyByte := keyByte ^ ((lcg >> 8) & 0xFF)
        keyByte := keyByte ^ ((lcg >> 16) & 0xFF)
        keyByte := keyByte ^ ((lcg >> 24) & 0xFF)
        
        ; Добавляем зависимость от предыдущего байта
        if (i > 0) {
            prevByte := NumGet(result, i - 1, "UChar")
            keyByte := keyByte ^ prevByte
        }
        
        NumPut("UChar", keyByte & 0xFF, result, i)
    }
    
    return result
}

; Улучшенное шифрование с проверкой целостности
SimpleEncrypt(text, password) {
    if (text = "")
        return ""
    
    ; Создаем усиленный ключ (256 байт)
    enhancedKey := CreateStrongKey(password, 256)
    
    ; Преобразуем текст в байты UTF-8
    textBuf := Buffer(StrPut(text, "UTF-8") - 1)
    StrPut(text, textBuf, "UTF-8")
    
    ; XOR шифрование с усиленным ключом
    keyLen := enhancedKey.Size
    loop textBuf.Size {
        i := A_Index - 1
        textByte := NumGet(textBuf, i, "UChar")
        keyByte := NumGet(enhancedKey, Mod(i, keyLen), "UChar")
        NumPut("UChar", textByte ^ keyByte, textBuf, i)
    }
    
    ; Вычисляем контрольную сумму для проверки целостности
    checksum := 0
    loop textBuf.Size {
        i := A_Index - 1
        checksum := (checksum + NumGet(textBuf, i, "UChar")) & 0xFF
    }
    
    ; Добавляем контрольную сумму в конец
    NumPut("UChar", checksum, textBuf, textBuf.Size)
    
    ; HEX кодирование
    hexResult := ""
    loop textBuf.Size + 1 {  ; +1 для контрольной суммы
        i := A_Index - 1
        hexResult .= Format("{:02X}", NumGet(textBuf, i, "UChar"))
    }
    
    return hexResult
}

; Улучшенное дешифрование с проверкой целостности
SimpleDecrypt(hexData, password) {
    if (hexData = "")
        return ""
    
    ; Проверяем HEX формат
    if Mod(StrLen(hexData), 2) != 0
        return ""
    
    ; Создаем тот же усиленный ключ
    enhancedKey := CreateStrongKey(password, 256)
    
    ; Преобразуем HEX в байты
    bufSize := StrLen(hexData) // 2
    if bufSize < 2  ; Минимум: 1 байт данных + контрольная сумма
        return ""
    
    textBuf := Buffer(bufSize, 0)
    
    loop bufSize {
        i := A_Index - 1
        hexByte := SubStr(hexData, i*2 + 1, 2)
        NumPut("UChar", Integer("0x" hexByte), textBuf, i)
    }
    
    ; Проверяем контрольную сумму
    expectedChecksum := NumGet(textBuf, bufSize - 1, "UChar")
    actualChecksum := 0
    
    loop bufSize - 1 {
        i := A_Index - 1
        actualChecksum := (actualChecksum + NumGet(textBuf, i, "UChar")) & 0xFF
    }
    
    if (actualChecksum != expectedChecksum) {
        return ""  ; Ошибка контрольной суммы
    }
    
    ; XOR дешифрование (исключая контрольную сумму)
    keyLen := enhancedKey.Size
    loop bufSize - 1 {
        i := A_Index - 1
        textByte := NumGet(textBuf, i, "UChar")
        keyByte := NumGet(enhancedKey, Mod(i, keyLen), "UChar")
        NumPut("UChar", textByte ^ keyByte, textBuf, i)
    }
    
    ; Возвращаем данные без контрольной суммы
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
    
    ; Проверка длины пароля
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
    Tabs := ["", "", "", "", "", "", "", "", "", ""]  ; 10 пустых вкладок
}

; Гарантируем 10 вкладок
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

; Устанавливаем шрифт для ВСЕХ элементов (фиксированный размер 10)
MyGui.SetFont("s10", "Segoe UI")

MyGui.MarginX := 10
MyGui.MarginY := 10

; === ПАНЕЛЬ НАСТРОЕК ===
; Кнопка "Поверх всех окон" - текстовая
Btn_AlwaysOnTop := MyGui.Add("Button", "x10 y10 w40 h25", GetArrowText(AlwaysOnTop))
Btn_AlwaysOnTop.OnEvent("Click", ToggleAlwaysOnTop)
Btn_AlwaysOnTop.ToolTip := "ОКНО`nПоложение окна: " . (AlwaysOnTop ? "ПОВЕРХ ВСЕХ (ВКЛ)" : "ОБЫЧНОЕ (ВЫКЛ)") . "`nНажмите для переключения"

; Кнопка темы (лампочка) - квадратная
Btn_Theme := MyGui.Add("Button", "x60 y10 w25 h25", GetThemeIcon(ThemeLevel))
Btn_Theme.OnEvent("Click", CycleTheme)
Btn_Theme.ToolTip := "ТЕМА`nТекущая тема: " . GetCurrentTheme().Name . "`nНажмите для переключения"

; Кнопка прозрачности
Btn_Transparency := MyGui.Add("Button", "x95 y10 w40 h25", GetTransparencyText(TransparencyLevel))
Btn_Transparency.OnEvent("Click", CycleTransparency)
Btn_Transparency.ToolTip := "ПРОЗРАЧНОСТЬ`nТекущий уровень: " . GetTransparencyPercent(TransparencyLevel) . "`nНажмите для переключения"

; Кнопка шрифта (вместо текстового индикатора)
Btn_Font := MyGui.Add("Button", "x145 y10 w120 h25", GetFontButtonText())
Btn_Font.OnEvent("Click", CycleFont)
Btn_Font.ToolTip := "ШРИФТ`nТекущий шрифт: " . FontName . " " . FontSize . "pt`nНажмите для смены шрифта`nCtrl+Колесо мыши - изменить размер"

; Кнопка помощи - привязана к правому краю окна
helpButton := MyGui.Add("Button", "x680 y10 w100 h25", "Помощь F1")
helpButton.OnEvent("Click", ToggleHelp)
helpButton.ToolTip := "Открыть справку`nГорячая клавиша: F1"

; Разделительная линия
sepLine := MyGui.Add("Text", "x10 y45 w780 0x10")

; === ВКЛАДКИ (10 штук) ===
tabNames := ["0"]
loop 9
    tabNames.Push(A_Index)  ; ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

tabCtrl := MyGui.Add("Tab3", "x10 y60 w780 h380 Choose" CurrentTabIndex, tabNames)

; Сохраняем обработчик изменения вкладки
tabCtrl.OnEvent("Change", TabChangeHandler)

; Создаём поля ввода для 10 вкладок
loop TabCount
{
    tabCtrl.UseTab(A_Index)
    content := Tabs.Length >= A_Index ? Tabs[A_Index] : ""
    editCtrl := MyGui.Add("Edit", "x20 y90 w760 h330 +Multi +Wrap +VScroll", content)
    editCtrl.SetFont("s" FontSize, FontName)  ; Применяем текущий шрифт (изменяемый)
    Edits.Push(editCtrl)
}
tabCtrl.UseTab(1)

; Обработчики
MyGui.OnEvent("Close", SaveAndExit)
MyGui.OnEvent("Size", GuiSize)

; Регистрируем обработчик сообщения колеса мыши только для изменения размера шрифта
OnMessage(0x20A, FontSizeWheelHandler)  ; WM_MOUSEWHEEL = 0x20A

; Применяем начальные настройки (кроме прозрачности)
ApplyWindowSettings()

; Показываем окно
MyGui.Show("w" MainWindowSize.Width " h" MainWindowSize.Height)

; ТЕПЕРЬ можно применить прозрачность, т.к. окно создано
ApplyTransparency()

; Фокус на первую вкладку
Edits[1].Focus()

; === ФУНКЦИИ ===

; Получить текст для кнопки "Поверх всех окон"
GetArrowText(isOnTop) {
    return isOnTop ? "UP" : "DWN"
}

; Получить текст прозрачности
GetTransparencyText(level) {
    switch level {
        case 1: return "25%"
        case 2: return "50%"
        default: return "0%"
    }
}

; Получить процент прозрачности
GetTransparencyPercent(level) {
    switch level {
        case 1: return "25%"
        case 2: return "50%"
        default: return "0% (нет)"
    }
}

; Получить текст для кнопки шрифта
GetFontButtonText() {
    global FontName, FontSize
    ; Обрезаем длинное название шрифта если нужно
    displayName := FontName
    if (StrLen(FontName) > 12) {
        displayName := SubStr(FontName, 1, 12) . "…"
    }
    return displayName . " " . FontSize . "pt"
}

; Получить иконку для текущей темы
GetThemeIcon(level) {
    global Themes
    if (level >= 0 && level < Themes.Length) {
        return Themes[level + 1].Icon
    }
    return Themes[1].Icon
}

; Обработчик изменения вкладки
TabChangeHandler(*) {
    global CurrentTabIndex, tabCtrl, Edits
    CurrentTabIndex := tabCtrl.Value
    if (CurrentTabIndex >= 1 && CurrentTabIndex <= 10) {
        Edits[CurrentTabIndex].Focus()
    }
}

; Получить текущую тему
GetCurrentTheme() {
    global ThemeLevel, Themes
    
    if ThemeLevel >= 0 && ThemeLevel < Themes.Length
        return Themes[ThemeLevel + 1]
    else
        return Themes[1]
}

; Переключение режима "Поверх всех окон"
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

; Переключение прозрачности
CycleTransparency(*) {
    global TransparencyLevel, Btn_Transparency
    
    ; Циклическое переключение: 0% → 25% → 50% → 0%
    TransparencyLevel := Mod(TransparencyLevel + 1, 3)
    
    ; Применяем прозрачность
    ApplyTransparency()
    
    ; Обновляем кнопку
    Btn_Transparency.Text := GetTransparencyText(TransparencyLevel)
    Btn_Transparency.ToolTip := "ПРОЗРАЧНОСТЬ`nТекущий уровень: " . GetTransparencyPercent(TransparencyLevel) . "`nНажмите для переключения"
    
    SaveSettings()
}

; Применить прозрачность
ApplyTransparency() {
    global TransparencyLevel, Version
    
    ; Проверяем, существует ли окно
    if !WinExist("PageX " Version " - Защищённый блокнот ")
        return
    
    switch TransparencyLevel {
        case 1: WinSetTransparent 192, "PageX " Version " - Защищённый блокнот "
        case 2: WinSetTransparent 128, "PageX " Version " - Защищённый блокнот "
        default: WinSetTransparent 255, "PageX " Version " - Защищённый блокнот "
    }
}

; Применить тему ко всем элементам
ApplyTheme() {
    global MyGui, Btn_AlwaysOnTop, Btn_Theme, Btn_Transparency, Btn_Font, helpButton, sepLine
    global Edits, FontSize, FontName, tabCtrl, ThemeLevel, CurrentTabIndex, AlwaysOnTop, TransparencyLevel
    
    theme := GetCurrentTheme()
    
    ; Обновляем текст на кнопках (сохраняем текущие состояния)
    Btn_AlwaysOnTop.Text := GetArrowText(AlwaysOnTop)
    Btn_Transparency.Text := GetTransparencyText(TransparencyLevel)
    Btn_Font.Text := GetFontButtonText()
    
    ; Применяем тему
    ApplySimpleTheme(theme)
}

; Применить простую тему (меняем только цвета)
ApplySimpleTheme(theme) {
    global MyGui, Btn_AlwaysOnTop, Btn_Theme, Btn_Transparency, Btn_Font, helpButton, sepLine
    global Edits, tabCtrl, FontSize, FontName
    
    ; Фон окна
    try {
        MyGui.BackColor := theme.Background
    }
    
    ; Текстовые элементы
    for ctrl in [sepLine] {
        if IsObject(ctrl) {
            try {
                ctrl.SetFont("c" . theme.Text)
                ctrl.Opt("Background" . theme.Background)
            }
        }
    }
    
    ; Кнопки
    for ctrl in [helpButton, Btn_Theme, Btn_AlwaysOnTop, Btn_Transparency, Btn_Font] {
        if IsObject(ctrl) {
            try {
                ctrl.SetFont("c" . theme.Text)
                ctrl.Opt("Background" . theme.Button)
            }
        }
    }
    
    ; Вкладки
    if IsObject(tabCtrl) {
        try {
            tabCtrl.SetFont("c" . theme.Text)
        }
    }
    
    ; Текстовые поля - все темы используют цвета из своих определений
    loop Edits.Length {
        if IsObject(Edits[A_Index]) {
            try {
                ; Используем цвета из текущей темы
                Edits[A_Index].SetFont("c" . theme.EditText " s" FontSize, FontName)
                Edits[A_Index].Opt("Background" . theme.EditBackground)
            }
        }
    }
}

; Циклическое переключение темы
CycleTheme(*) {
    global ThemeLevel
    
    ; Переключаем на следующую тему (0-2, затем снова 0)
    ThemeLevel := Mod(ThemeLevel + 1, 3)
    
    ; Применяем тему
    ApplyTheme()
    
    ; Сохраняем настройки
    SaveSettings()
}

; Проверка наличия шрифта в списке
IsFontInList(fontName) {
    global Fonts
    
    for index, font in Fonts {
        if font = fontName {
            return true
        }
    }
    return false
}

; Обработчик колеса мыши только для изменения размера шрифта
FontSizeWheelHandler(wParam, lParam, msg, hwnd) {
    global FontSize, FontName, Edits
    
    ; Проверяем, активно ли основное окно
    if !WinActive("PageX " Version " - Защищённый блокнот ")
        return
    
    ; Проверяем, зажат ли Ctrl
    if !GetKeyState("Ctrl")
        return
    
    ; Проверяем, находится ли курсор над текстовым полем
    try {
        MouseGetPos(, , &winId, &controlId, 2)
        
        ; Проверяем все Edit контролы
        for editCtrl in Edits {
            if (controlId = editCtrl.Hwnd) {
                ; Анализируем направление прокрутки
                delta := wParam >> 16
                delta := delta > 0x7FFF ? -(0x10000 - delta) : delta
                
                if (delta > 0) {
                    if (FontSize < 24) {
                        FontSize += 1
                        UpdateFontAndSize()
                    }
                }
                else if (delta < 0) {
                    if (FontSize > 8) {
                        FontSize -= 1
                        UpdateFontAndSize()
                    }
                }
                return 0  ; Блокируем стандартную обработку
            }
        }
    }
    catch {
        ; Игнорируем ошибки
    }
}

; Изменение размера окна
GuiSize(GuiObj, MinMax, Width, Height) {
    global
    
    if (MinMax = -1) ; Минимизировано
        return
    
    ; Изменяем размер вкладок
    if (IsObject(tabCtrl)) {
        tabCtrl.Move(, , Width - 20, Height - 100)
    }
    
    ; Изменяем размер текстовых полей
    loop TabCount {
        if (Edits.Length >= A_Index) {
            Edits[A_Index].Move(, , Width - 40, Height - 140)
        }
    }
    
    ; Растягиваем разделительную линию
    if (IsObject(sepLine)) {
        sepLine.Move(, , Width - 20)
    }
    
    ; Перемещаем кнопки
    if (Btn_Font) {
        Btn_Font.Move(Width - 245)
    }
    
    if (helpButton) {
        helpButton.Move(Width - 120)
    }
}

; Циклическое переключение шрифтов (только по клику)
CycleFont(*) {
    global Fonts, FontName, Btn_Font
    
    ; Находим текущий шрифт в массиве
    currentIndex := 0
    loop Fonts.Length {
        if (Fonts[A_Index] = FontName) {
            currentIndex := A_Index
            break
        }
    }
    
    ; Переключаем на следующий шрифт
    if (currentIndex = Fonts.Length) {
        FontName := Fonts[1]  ; Если последний, переходим к первому
    } else {
        FontName := Fonts[currentIndex + 1]
    }
    
    UpdateFontAndSize()
}

; Обновление шрифта и размера
UpdateFontAndSize() {
    global Btn_Font, FontName, FontSize, Edits, TabCount, CurrentTabIndex
    
    ; Сохраняем текущий текст
    savedTexts := []
    loop Edits.Length {
        savedTexts.Push(Edits[A_Index].Text)
    }
    
    ; Сохраняем текущий фокус
    focusedEdit := 0
    loop Edits.Length {
        if Edits[A_Index].Focused {
            focusedEdit := A_Index
            break
        }
    }
    
    ; Обновляем текст на кнопке
    Btn_Font.Text := GetFontButtonText()
    Btn_Font.ToolTip := "ШРИФТ`nТекущий шрифт: " . FontName . " " . FontSize . "pt`nНажмите для смены шрифта`nCtrl+Колесо мыши - изменить размер"
    
    ; Обновляем шрифт во всех текстовых полях и сохраняем текст
    loop TabCount {
        if (Edits.Length >= A_Index) {
            try {
                ; Обновляем шрифт
                Edits[A_Index].SetFont("s" FontSize, FontName)
                
                ; Восстанавливаем текст
                Edits[A_Index].Text := savedTexts[A_Index]
            }
        }
    }
    
    ; Применяем текущую тему (обновляем цвета)
    ApplyTheme()
    
    ; Восстанавливаем фокус
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
    
    ; Сохраняем настройки
    SaveSettings()
}

; Сохранение данных (без выхода)
SaveData(*) {
    global
    
    try {
        ; Собираем текст со всех 10 вкладок
        text := ""
        loop TabCount {
            if (A_Index > 1)
                text .= "`n--PageX-TAB--`n"
            text .= Edits[A_Index].Text
        }
        
        ; Шифруем с улучшенным алгоритмом
        encrypted := SimpleEncrypt(text, MasterPassword)
        
        ; Сохраняем в файл
        if FileExist(DataFile) {
            FileDelete DataFile
        }
        
        FileAppend encrypted, DataFile, "UTF-8"
        
        ; Сохраняем настройки
        SaveSettings()
    }
    catch as e {
        ; Тихий сбой - не показываем сообщений об ошибках
    }
}

; Сохранение и выход
SaveAndExit(*) {
    global
    
    ; Сохраняем данные
    SaveData()
    
    ; Выходим
    ExitApp
}

ApplyWindowSettings() {
    global AlwaysOnTop, MyGui
    
    ; "Поверх всех окон"
    if AlwaysOnTop
        MyGui.Opt("+AlwaysOnTop")
    
    ; Применяем тему
    ApplyTheme()
}

SaveSettings() {
    ; Сохраняем все настройки
    try {
        IniWrite(AlwaysOnTop, SettingsFile, "Window", "AlwaysOnTop")
        IniWrite(TransparencyLevel, SettingsFile, "Window", "TransparencyLevel")
        IniWrite(FontSize, SettingsFile, "Font", "Size")
        IniWrite(FontName, SettingsFile, "Font", "Name")
        IniWrite(ThemeLevel, SettingsFile, "Theme", "ThemeLevel")
    }
    catch {
        ; Игнорируем ошибки
    }
}

LoadSetting(Key, Default) {
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

; Функция переключения справки (открыть/закрыть)
ToggleHelp(*) {
    global HelpWindow
    
    ; Если окно помощи существует и видимо
    if IsObject(HelpWindow) && HelpWindow.Hwnd && WinExist("ahk_id " HelpWindow.Hwnd) {
        HelpWindow.Destroy()
        HelpWindow := ""
    } else {
        ; Иначе создаем новое окно
        ShowHelp()
    }
}

; Показать справку
ShowHelp(*) {
    global HelpWindow, HelpWindowSize, Version, ThemeLevel, Themes, AlwaysOnTop, TransparencyLevel, FontName, FontSize
    
    ; Закрываем предыдущее окно справки, если оно существует
    if IsObject(HelpWindow) {
        try {
            HelpWindow.Destroy()
            HelpWindow := ""
        }
        catch {
            HelpWindow := ""
        }
    }
    
    ; Создаём окно справки поверх всех окон
    HelpWindow := Gui("+AlwaysOnTop +ToolWindow", "PageX " Version " - Справка ")
    HelpWindow.SetFont("s10", "Segoe UI")
    HelpWindow.MarginX := 20
    HelpWindow.MarginY := 20
    
    ; Применяем текущую тему к окну справки
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
    
    ; Добавляем текст справки
    helpTextCtrl := HelpWindow.Add("Text", , helpText)
    helpTextCtrl.SetFont("c" . theme.Text)
    helpTextCtrl.Opt("Background" . theme.Background)
    
    ; Добавляем кнопку закрытия
    closeBtn := HelpWindow.Add("Button", "w100 Center", "Закрыть")
    closeBtn.OnEvent("Click", (*) => HelpWindow.Destroy())
    closeBtn.SetFont("c" . theme.Text)
    closeBtn.Opt("Background" . theme.Button)
    
    ; Параметры отображения окна помощи
    if (HelpWindowSize.Width > 0 && HelpWindowSize.Height > 0) {
        HelpWindow.Show("w" HelpWindowSize.Width " h" HelpWindowSize.Height " Center")
    }
    else if (HelpWindowSize.Width > 0) {
        HelpWindow.Show("Center")
    }
    else {
        HelpWindow.Show("Center")
    }
    
    ; Устанавливаем обработчик закрытия окна
    HelpWindow.OnEvent("Close", (*) => HelpWindow := "")
    HelpWindow.OnEvent("Escape", (*) => HelpWindow.Destroy())
}

; === ГОРЯЧИЕ КЛАВИШИ ===
#HotIf WinActive("PageX " Version " - Защищённый блокнот ")
^s::SaveData()      ; Сохранить (без выхода)
^q::SaveAndExit()   ; Сохранить и выйти
Esc::SaveAndExit()  ; Сохранить и выйти
F1::ToggleHelp()    ; Открыть/закрыть справку

; Переключение вкладок Ctrl+0..9
^0::SwitchTab(1)    ; Вкладка 0
^1::SwitchTab(2)    ; Вкладка 1
^2::SwitchTab(3)    ; Вкладка 2
^3::SwitchTab(4)    ; Вкладка 3
^4::SwitchTab(5)    ; Вкладка 4
^5::SwitchTab(6)    ; Вкладка 5
^6::SwitchTab(7)    ; Вкладка 6
^7::SwitchTab(8)    ; Вкладка 7
^8::SwitchTab(9)    ; Вкладка 8
^9::SwitchTab(10)   ; Вкладка 9

; Горячие клавиши для изменения размера шрифта (альтернатива колесу мыши)
^+Up:: {  ; Ctrl+Shift+Up - увеличить шрифт
    if (FontSize < 24) {
        FontSize += 1
        UpdateFontAndSize()
    }
}

^+Down:: {  ; Ctrl+Shift+Down - уменьшить шрифт
    if (FontSize > 8) {
        FontSize -= 1
        UpdateFontAndSize()
    }
}

#HotIf

#HotIf WinActive("PageX " Version " - Справка ")
F1::ToggleHelp()    ; Закрыть окно помощи (F1 в окне помощи)
Esc:: {             ; Esc тоже закрывает окно помощи
    global HelpWindow
    if IsObject(HelpWindow) {
        HelpWindow.Destroy()
        HelpWindow := ""
    }
}
#HotIf

; Функция переключения вкладок
SwitchTab(TabNumber) {
    global tabCtrl, Edits, CurrentTabIndex
    
    if (TabNumber >= 1 && TabNumber <= 10) {
        tabCtrl.Choose(TabNumber)  ; Переключаем вкладку
        CurrentTabIndex := TabNumber
        if (Edits.Length >= TabNumber) {
            Edits[TabNumber].Focus()  ; Фокус на текстовое поле
        }
    }
}

; Обработчик закрытия программы
OnExit(*) {
    SaveData()
}