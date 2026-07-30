; l2_strings.ahk - all user-facing UI text (MsgBox/popup/tray messages), in
; Russian and English side by side. #Include'd by the main script and bundled
; straight into the compiled exe by Ahk2Exe - end users only ever see one
; exe, never this file directly.
;
; Language is auto-detected once at startup from the Windows UI language
; (A_Language, a hex LCID - "0419" is Russian) and never asked about
; explicitly: Russian Windows installs get Russian text, everything else
; gets English. Internal implementation details that aren't shown to the
; user (the Gemini prompts that ask the AI to translate chat text) are
; deliberately NOT part of this file - those stay Russian-authored prompts
; regardless of UI language, since prompt wording doesn't need to match the
; reader's language to work correctly.

f_detect_ui_lang() {
    return (A_Language = "0419") ? "ru" : "en"
}

g_ui_lang := f_detect_ui_lang()

; simple {1}/{2}/... placeholder substitution, since AHK has no built-in
; sprintf - only needed for the handful of messages that embed a live value
; (a version number, a folder path, an HTTP status).
f_fmt(s, args*) {
    for i, a in args
        s := StrReplace(s, "{" i "}", a)
    return s
}

g_str := Map()

g_str["end_calib_btn"] := Map("ru", "■ ЗАВЕРШИТЬ КАЛИБРОВКУ", "en", "■ END CALIBRATION")

g_str["exit_menu_item"] := Map("ru", "Выход", "en", "Exit")

g_str["gemini_intro"] := Map(
    "ru", "Gemini - настоящая языковая модель, которая заметно лучше обычного "
        . "Google Translate/Tesseract понимает игровой жаргон, опечатки OCR и "
        . "контекст. Используется для перевода чата и (в окне 'Party') для "
        . "распознавания списка группы через изображение. Это бесплатно и без "
        . "привязки карты, но каждый игрок заводит свой личный ключ.",
    "en", "Gemini is a genuine language model that understands game slang, OCR "
        . "typos and context far better than plain Google Translate/Tesseract. "
        . "It's used for chat translation and (in the 'Party' window) for "
        . "reading the party list straight from a screenshot. It's free and "
        . "needs no credit card, but every player sets up their own key.")

g_str["gemini_how_to"] := Map("ru", "Как получить ключ:", "en", "How to get a key:")

g_str["gemini_step1"] := Map(
    "ru", '1. Зайдите на <a href="https://aistudio.google.com/app/apikey">aistudio.google.com</a> и войдите через Google-аккаунт.',
    "en", '1. Go to <a href="https://aistudio.google.com/app/apikey">aistudio.google.com</a> and sign in with your Google account.')

g_str["gemini_step23"] := Map(
    "ru", "2. Нажмите Get API key -> Create API key (займёт минуту).`n"
        . "3. Скопируйте ключ и вставьте в поле ниже, затем нажмите Сохранить.",
    "en", "2. Click Get API key -> Create API key (takes a minute).`n"
        . "3. Copy the key, paste it in the field below, then click Save.")

g_str["gemini_key_label"] := Map("ru", "Ключ:", "en", "Key:")

g_str["gemini_storage_note"] := Map(
    "ru", "Хранится в реестре Windows (только для вашей учётной записи), а не в файле рядом с "
        . "программой - его нельзя случайно передать вместе с папкой/архивом инструмента.",
    "en", "Stored in the Windows registry (under your account only), not in a file next to "
        . "the program - it can't accidentally end up shared along with the tool's folder/archive.")

g_str["save_btn"] := Map("ru", "Сохранить", "en", "Save")
g_str["cancel_btn"] := Map("ru", "Отмена", "en", "Cancel")

g_str["gemini_saved_msg"] := Map(
    "ru", "Ключ Gemini сохранён - перевод чата и скан пати теперь будут пробовать Gemini в первую очередь.",
    "en", "Gemini key saved - chat translate and party scan will now try Gemini first.")
g_str["gemini_removed_msg"] := Map(
    "ru", "Ключ Gemini удалён - перевод чата и скан пати вернутся к Google Translate/Tesseract.",
    "en", "Gemini key removed - chat translate and party scan will fall back to Google Translate/Tesseract.")

g_str["tesseract_installing_msg"] := Map(
    "ru", "Устанавливаю Tesseract OCR через winget, это займёт минуту-две...`nОкно продолжит само после завершения установки.",
    "en", "Installing Tesseract OCR via winget, this takes a minute or two...`nThis window will continue on its own once it's done.")

g_str["tesseract_not_found_msg"] := Map(
    "ru", "Tesseract OCR не найден - без него оверлей не сможет распознавать имена целей.`n`n"
        . "Установить его автоматически сейчас (через winget)?`n"
        . "Это займёт минуту-две и не потребует ручных действий.",
    "en", "Tesseract OCR was not found - without it the overlay can't recognize target names.`n`n"
        . "Install it automatically now (via winget)?`n"
        . "This takes a minute or two and needs no manual steps.")
g_str["tesseract_not_found_title"] := Map("ru", "L2 Target Overlay - Tesseract OCR не найден", "en", "L2 Target Overlay - Tesseract OCR not found")

g_str["tesseract_autoinstall_failed_msg"] := Map(
    "ru", "Автоустановка не удалась (например, нет winget или нет интернета).`n`n"
        . "Установите вручную командой в PowerShell:`n"
        . "winget install --id UB-Mannheim.TesseractOCR`n`n"
        . "и перезапустите эту программу.",
    "en", "Automatic install failed (e.g. no winget or no internet).`n`n"
        . "Install it manually with this PowerShell command:`n"
        . "winget install --id UB-Mannheim.TesseractOCR`n`n"
        . "then restart this program.")

g_str["update_available_msg"] := Map(
    "ru", "Доступна новая версия {1} (у вас {2}).`n`nСкачать и распаковать её сейчас?",
    "en", "Version {1} is available (you have {2}).`n`nDownload and extract it now?")
g_str["update_title"] := Map("ru", "L2 Target Overlay - обновление", "en", "L2 Target Overlay - update")

g_str["update_download_failed_msg"] := Map(
    "ru", "Не удалось скачать обновление (HTTP {1}).",
    "en", "Failed to download the update (HTTP {1}).")

g_str["update_ready_msg"] := Map(
    "ru", "Новая версия {1} скачана и распакована в папку:`n{2}`n`n"
        . "Закройте эту программу и скопируйте L2TargetOverlay.exe и "
        . "L2TargetOverlay_source.ahk оттуда поверх текущих файлов (или просто "
        . "запустите exe из новой папки).",
    "en", "Version {1} has been downloaded and extracted to:`n{2}`n`n"
        . "Close this program and copy L2TargetOverlay.exe and "
        . "L2TargetOverlay_source.ahk from there over the current files (or just "
        . "run the exe from the new folder).")
g_str["update_ready_title"] := Map("ru", "L2 Target Overlay - обновление готово", "en", "L2 Target Overlay - update ready")

g_str["update_extract_error_msg"] := Map(
    "ru", "Ошибка при распаковке обновления: {1}",
    "en", "Error while extracting the update: {1}")

g_str["traytip_chat_ready"] := Map("ru", "`nChat translate: готово.", "en", "`nChat translate: ready.")
g_str["traytip_chat_not_ready"] := Map(
    "ru", "`nChat translate: русский языковой пакет не установлен, распознавание кириллицы в чате будет хуже.",
    "en", "`nChat translate: Russian language pack not installed, Cyrillic OCR in chat will be worse.")
g_str["traytip_gemini_on"] := Map(
    "ru", "`nПеревод: Gemini ({1}), жаргон L2 понимает.",
    "en", "`nTranslate: Gemini ({1}), understands L2 slang.")
g_str["traytip_gemini_off"] := Map(
    "ru", "`nПеревод: Google Translate (настройте через меню ☰ -> Gemini API для лучшего качества).",
    "en", "`nTranslate: Google Translate (set up via menu ☰ -> Gemini API for better quality).")

g_str["chat_error_tag"] := Map("ru", " [ошибка: {1}]", "en", " [error: {1}]")

T(key) {
    global g_str, g_ui_lang
    return g_str.Has(key) ? g_str[key][g_ui_lang] : key
}
