import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case russian = "ru"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .german:
            return "Deutsch"
        case .russian:
            return "Русский"
        case .traditionalChinese:
            return "繁體中文"
        }
    }

    fileprivate var translationIndex: Int {
        switch self {
        case .simplifiedChinese: return 0
        case .english: return 1
        case .japanese: return 2
        case .spanish: return 3
        case .french: return 4
        case .german: return 5
        case .russian: return 6
        case .traditionalChinese: return 7
        }
    }
}

enum AppText: String, CaseIterable {
    case appName
    case language
    case alertTitle
    case ok
    case unknownError
    case shortcutGuide
    case voiceCenter
    case importBook
    case organizingBook
    case continueReading
    case myBooks
    case openBookshelfAndImport
    case bookCount
    case viewingHistory
    case selectAll
    case deselectAll
    case deleteSelected
    case done
    case batchManage
    case noHistory
    case historyWillAppear
    case today
    case yesterday
    case dayBeforeYesterday
    case earlier
    case back
    case backHome
    case backBookshelf
    case shelfBookCount
    case emptyShelf
    case importedBooksStayLocal
    case importFirstBook
    case chapter
    case chooseChapter
    case organizingParagraphs
    case noReadableText
    case openReadableBook
    case previousChapterHelp
    case previousPageHelp
    case pauseReadingHelp
    case startReadingHelp
    case returnToSpeech
    case restoreAutoFollow
    case batteryRemaining
    case pluggedIn
    case progressPercent
    case nextPageHelp
    case nextChapterHelp
    case readingSettings
    case readingVoice
    case personalVoice
    case voiceQuality
    case speechRate
    case autoFollow
    case autoFollowOnDetail
    case autoFollowOffDetail
    case stopCondition
    case displayMode
    case eyeCareMode
    case eyeCareDetail
    case fontSize
    case pageBrightness
    case selectionHint
    case collapseSettings
    case expandSettings
    case followSystem
    case lightMode
    case darkMode
    case timerOff
    case tenMinutes
    case twentyMinutes
    case thirtyMinutes
    case sixtyMinutes
    case finishSection
    case finishChapter
    case standardQuality
    case enhancedQuality
    case premiumQuality
    case femaleVoice
    case maleVoice
    case neutralVoice
    case unspecifiedVoice
    case parchmentYellow
    case eyeCareGreen
    case mistBlue
    case softPink
    case palePurple
    case noColor
    case permissionNotDetermined
    case permissionDenied
    case unsupportedDevice
    case authorized
    case removeFromLibrary
    case originalFileKept
    case progress
    case sourceUnavailable
    case openNamedBook
    case deleteHistoryHelp
    case voiceCenterDetail
    case installedVoices
    case currentVoiceDetail
    case chooseReadingVoice
    case enhancedVoices
    case enhancedVoicesDetail
    case openSystemVoiceDownloads
    case personalVoiceStatusDetail
    case recordingAndAuthorization
    case localVoiceLibrary
    case localVoicePrivacy
    case searchVoices
    case wantNaturalVoice
    case downloadVoiceHint
    case openSystemVoiceManager
    case refresh
    case previewVoice
    case removeFavorite
    case addFavorite
    case recordPersonalVoice
    case personalRecordingPrivacy
    case createPersonalVoice
    case createPersonalVoiceDetail
    case allowPersonalVoice
    case allowPersonalVoiceDetail
    case returnRefreshChoose
    case returnRefreshChooseDetail
    case currentStatus
    case personalVoiceCount
    case personalVoiceRequirements
    case personalVoiceReauthorization
    case openPersonalVoiceSettings
    case refreshPersonalVoices
    case allowVoicePage
    case addAnnotation
    case editAnnotation
    case highlightColor
    case underlineSelection
    case note
    case deleteAnnotation
    case save
    case cancel
    case shortcutTitle
    case nextChapter
    case previousChapter
    case playPause
    case previousPage
    case nextPage
    case twoFingerRight
    case twoFingerLeft
    case exitApp
    case naturalScrollHint
    case contextHighlight
    case clearHighlight
    case editNote
    case addNote
    case clearNote
    case underline
    case removeUnderline
    case translate
    case copy
    case openBookCommand
    case readingMenu
    case pause
    case startOrContinue
    case systemDefault
    case fullText
    case statusOpening
    case statusPaused
    case statusReading
    case statusReady
    case translationRequiresNewerSystem
    case missingBookFile
    case missingLibraryBook
    case unavailableVoice
    case personalVoiceNeedsAccess
    case personalVoicePermissionOff
    case personalVoiceUnsupported
    case personalVoiceUnavailable
    case selectedPersonalVoiceMissing
    case unsupportedFormat
    case unknownEncoding
    case invalidEPUB
    case noTextInFile
    case unzipFailed
}

struct AppLocalization {
    static func text(_ key: AppText, language: AppLanguage) -> String {
        guard let values = translations[key],
              values.indices.contains(language.translationIndex) else {
            return key.rawValue
        }
        return values[language.translationIndex]
    }

    static func format(
        _ key: AppText,
        language: AppLanguage,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, language: language),
            locale: Locale(identifier: language.rawValue),
            arguments: arguments
        )
    }

    static var isComplete: Bool {
        AppText.allCases.allSatisfy {
            (translations[$0]?.count ?? 0) >= AppLanguage.allCases.count
        }
    }

    // Translation order:
    // Simplified Chinese, English, Japanese, Spanish, French, German,
    // Russian, Traditional Chinese.
    private static let translations: [AppText: [String]] = [
        .appName: [
            "声页", "VoicePage", "声页", "VoicePage", "VoicePage",
            "VoicePage", "VoicePage", "聲頁", "VoicePage"
        ],
        .language: [
            "界面语言", "Language", "表示言語", "Idioma", "Langue",
            "Sprache", "Язык", "介面語言", "لغة الواجهة"
        ],
        .alertTitle: [
            "声页提示", "VoicePage", "声页からのお知らせ", "VoicePage",
            "VoicePage", "VoicePage", "VoicePage", "聲頁提示", "VoicePage"
        ],
        .ok: [
            "好", "OK", "OK", "Aceptar", "OK", "OK", "ОК", "好", "موافق"
        ],
        .unknownError: [
            "发生未知错误。", "An unknown error occurred.", "不明なエラーが発生しました。",
            "Se produjo un error desconocido.", "Une erreur inconnue s’est produite.",
            "Ein unbekannter Fehler ist aufgetreten.", "Произошла неизвестная ошибка.",
            "發生未知錯誤。", "حدث خطأ غير معروف."
        ],
        .shortcutGuide: [
            "操作指南", "Shortcuts", "操作ガイド", "Guía", "Guide",
            "Kurzanleitung", "Подсказки", "操作指南", "دليل الاستخدام"
        ],
        .voiceCenter: [
            "音色中心", "Voice Center", "音声センター", "Centro de voces",
            "Centre vocal", "Stimmen-Center", "Центр голосов", "音色中心",
            "مركز الأصوات"
        ],
        .importBook: [
            "导入图书", "Import Book", "本を読み込む", "Importar libro",
            "Importer un livre", "Buch importieren", "Импортировать книгу",
            "匯入圖書", "استيراد كتاب"
        ],
        .organizingBook: [
            "正在整理章节和正文…", "Preparing chapters and text…", "章と本文を準備中…",
            "Preparando capítulos y texto…", "Préparation des chapitres et du texte…",
            "Kapitel und Text werden vorbereitet…", "Подготовка глав и текста…",
            "正在整理章節和正文…", "جارٍ تجهيز الفصول والنص…"
        ],
        .continueReading: [
            "继续上次阅读", "Continue Reading", "前回の続き", "Continuar leyendo",
            "Continuer la lecture", "Weiterlesen", "Продолжить чтение",
            "繼續上次閱讀", "متابعة القراءة"
        ],
        .myBooks: [
            "我的图书", "My Books", "マイブック", "Mis libros", "Mes livres",
            "Meine Bücher", "Мои книги", "我的圖書", "كتبي"
        ],
        .openBookshelfAndImport: [
            "打开书架并导入图书", "Open the bookshelf and import a book",
            "本棚を開いて本を読み込む", "Abre la biblioteca e importa un libro",
            "Ouvrez la bibliothèque et importez un livre",
            "Bücherregal öffnen und ein Buch importieren",
            "Откройте полку и импортируйте книгу", "開啟書架並匯入圖書",
            "افتح المكتبة واستورد كتابًا"
        ],
        .bookCount: [
            "%d 本图书", "Books: %d", "%d冊", "Libros: %d", "Livres : %d",
            "Bücher: %d", "Книг: %d", "%d 本圖書", "%d كتب"
        ],
        .viewingHistory: [
            "观看历史", "Reading History", "閲覧履歴", "Historial de lectura",
            "Historique de lecture", "Leseverlauf", "История чтения",
            "觀看歷史", "سجل القراءة"
        ],
        .selectAll: [
            "全选", "Select All", "すべて選択", "Seleccionar todo",
            "Tout sélectionner", "Alle auswählen", "Выбрать всё",
            "全選", "تحديد الكل"
        ],
        .deselectAll: [
            "取消全选", "Deselect All", "選択を解除", "Anular selección",
            "Tout désélectionner", "Auswahl aufheben", "Снять выделение",
            "取消全選", "إلغاء تحديد الكل"
        ],
        .deleteSelected: [
            "删除选中", "Delete Selected", "選択項目を削除", "Eliminar selección",
            "Supprimer la sélection", "Auswahl löschen", "Удалить выбранное",
            "刪除所選", "حذف المحدد"
        ],
        .done: [
            "完成", "Done", "完了", "Listo", "Terminé", "Fertig", "Готово",
            "完成", "تم"
        ],
        .batchManage: [
            "批量管理", "Manage", "一括管理", "Gestionar", "Gérer",
            "Verwalten", "Управление", "批次管理", "إدارة"
        ],
        .noHistory: [
            "暂无观看历史", "No reading history", "閲覧履歴はありません",
            "No hay historial de lectura", "Aucun historique de lecture",
            "Noch kein Leseverlauf", "История чтения пуста",
            "暫無觀看歷史", "لا يوجد سجل قراءة"
        ],
        .historyWillAppear: [
            "开始阅读后会自动记录最近位置。", "Your latest position is saved when you start reading.",
            "読書を始めると、最新の位置が自動保存されます。",
            "La última posición se guarda al empezar a leer.",
            "La dernière position est enregistrée dès que vous commencez à lire.",
            "Beim Lesen wird die letzte Position automatisch gespeichert.",
            "Последняя позиция сохраняется при начале чтения.",
            "開始閱讀後會自動記錄最近位置。",
            "سيتم حفظ آخر موضع تلقائيًا عند بدء القراءة."
        ],
        .today: [
            "今日", "Today", "今日", "Hoy", "Aujourd’hui", "Heute",
            "Сегодня", "今日", "اليوم"
        ],
        .yesterday: [
            "昨日", "Yesterday", "昨日", "Ayer", "Hier", "Gestern",
            "Вчера", "昨日", "أمس"
        ],
        .dayBeforeYesterday: [
            "前天", "Two Days Ago", "一昨日", "Anteayer", "Avant-hier",
            "Vorgestern", "Позавчера", "前天", "أول أمس"
        ],
        .earlier: [
            "更早", "Earlier", "それ以前", "Anteriores", "Plus ancien",
            "Früher", "Ранее", "更早", "أقدم"
        ],
        .back: [
            "返回", "Back", "戻る", "Atrás", "Retour", "Zurück",
            "Назад", "返回", "رجوع"
        ],
        .backHome: [
            "返回主页", "Back to Home", "ホームに戻る", "Volver al inicio",
            "Retour à l’accueil", "Zur Startseite", "На главную",
            "返回主頁", "العودة إلى الرئيسية"
        ],
        .backBookshelf: [
            "返回书架", "Back to Bookshelf", "本棚に戻る", "Volver a la biblioteca",
            "Retour à la bibliothèque", "Zurück zum Bücherregal",
            "На книжную полку", "返回書架", "العودة إلى المكتبة"
        ],
        .shelfBookCount: [
            "%d 本", "Books: %d", "%d冊", "Libros: %d", "Livres : %d",
            "Bücher: %d", "Книг: %d", "%d 本", "%d كتب"
        ],
        .emptyShelf: [
            "书架还是空的", "Your bookshelf is empty", "本棚は空です",
            "Tu biblioteca está vacía", "Votre bibliothèque est vide",
            "Ihr Bücherregal ist leer", "Книжная полка пуста",
            "書架還是空的", "مكتبتك فارغة"
        ],
        .importedBooksStayLocal: [
            "导入 EPUB 或 TXT 后，图书会保留在这台 Mac 上。",
            "Imported EPUB and TXT books stay on this Mac.",
            "読み込んだEPUB／TXTはこのMacに保存されます。",
            "Los EPUB y TXT importados permanecen en este Mac.",
            "Les EPUB et TXT importés restent sur ce Mac.",
            "Importierte EPUB- und TXT-Bücher bleiben auf diesem Mac.",
            "Импортированные EPUB и TXT остаются на этом Mac.",
            "匯入 EPUB 或 TXT 後，圖書會保留在這台 Mac 上。",
            "تبقى كتب EPUB وTXT المستوردة على هذا الـ Mac."
        ],
        .importFirstBook: [
            "导入第一本图书", "Import Your First Book", "最初の本を読み込む",
            "Importa tu primer libro", "Importer votre premier livre",
            "Erstes Buch importieren", "Импортировать первую книгу",
            "匯入第一本圖書", "استيراد كتابك الأول"
        ],
        .chapter: [
            "章节", "Chapter", "章", "Capítulo", "Chapitre", "Kapitel",
            "Глава", "章節", "الفصل"
        ],
        .chooseChapter: [
            "选择章节并跳转到该章开头", "Choose a chapter and jump to its beginning",
            "章を選んで先頭へ移動", "Elige un capítulo y ve al inicio",
            "Choisissez un chapitre et allez à son début",
            "Kapitel wählen und zum Anfang springen",
            "Выберите главу и перейдите к её началу",
            "選擇章節並跳到該章開頭", "اختر فصلًا وانتقل إلى بدايته"
        ],
        .organizingParagraphs: [
            "正在整理章节和自然段…", "Preparing chapters and paragraphs…",
            "章と段落を準備中…", "Preparando capítulos y párrafos…",
            "Préparation des chapitres et paragraphes…",
            "Kapitel und Absätze werden vorbereitet…",
            "Подготовка глав и абзацев…", "正在整理章節和自然段…",
            "جارٍ تجهيز الفصول والفقرات…"
        ],
        .noReadableText: [
            "没有可显示的文字", "No readable text", "表示できるテキストがありません",
            "No hay texto para mostrar", "Aucun texte à afficher",
            "Kein anzeigbarer Text", "Нет текста для отображения",
            "沒有可顯示的文字", "لا يوجد نص قابل للعرض"
        ],
        .openReadableBook: [
            "请返回并打开一本 EPUB 或 TXT 书籍。",
            "Go back and open an EPUB or TXT book.",
            "戻ってEPUBまたはTXTを開いてください。",
            "Vuelve y abre un libro EPUB o TXT.",
            "Revenez et ouvrez un livre EPUB ou TXT.",
            "Gehen Sie zurück und öffnen Sie ein EPUB- oder TXT-Buch.",
            "Вернитесь и откройте книгу EPUB или TXT.",
            "請返回並開啟一本 EPUB 或 TXT 圖書。",
            "ارجع وافتح كتاب EPUB أو TXT."
        ],
        .previousChapterHelp: [
            "上一章（⇧⌘←）", "Previous chapter (⇧⌘←)", "前の章（⇧⌘←）",
            "Capítulo anterior (⇧⌘←)", "Chapitre précédent (⇧⌘←)",
            "Vorheriges Kapitel (⇧⌘←)", "Предыдущая глава (⇧⌘←)",
            "上一章（⇧⌘←）", "الفصل السابق (⇧⌘←)"
        ],
        .previousPageHelp: [
            "上一页（⌘←）", "Previous page (⌘←)", "前のページ（⌘←）",
            "Página anterior (⌘←)", "Page précédente (⌘←)",
            "Vorherige Seite (⌘←)", "Предыдущая страница (⌘←)",
            "上一頁（⌘←）", "الصفحة السابقة (⌘←)"
        ],
        .pauseReadingHelp: [
            "暂停朗读（空格）", "Pause reading (Space)", "読み上げを一時停止（Space）",
            "Pausar lectura (Espacio)", "Suspendre la lecture (Espace)",
            "Vorlesen pausieren (Leertaste)", "Приостановить чтение (Пробел)",
            "暫停朗讀（空白鍵）", "إيقاف القراءة مؤقتًا (مسافة)"
        ],
        .startReadingHelp: [
            "从当前页开始朗读（空格）", "Read from this page (Space)",
            "現在のページから読み上げ（Space）", "Leer desde esta página (Espacio)",
            "Lire depuis cette page (Espace)", "Ab dieser Seite vorlesen (Leertaste)",
            "Читать с текущей страницы (Пробел)", "從目前頁開始朗讀（空白鍵）",
            "القراءة من الصفحة الحالية (مسافة)"
        ],
        .returnToSpeech: [
            "返回朗读位置", "Return to Reading", "読み上げ位置に戻る",
            "Volver a la lectura", "Retour à la lecture", "Zur Leseposition",
            "Вернуться к чтению", "返回朗讀位置", "العودة إلى موضع القراءة"
        ],
        .restoreAutoFollow: [
            "回到当前正在朗读的页面并恢复自动翻页",
            "Return to the spoken page and resume automatic following",
            "読み上げ中のページに戻り、自動追従を再開",
            "Vuelve a la página leída y reanuda el seguimiento automático",
            "Revenir à la page lue et reprendre le suivi automatique",
            "Zur gesprochenen Seite zurückkehren und automatisches Folgen fortsetzen",
            "Вернуться к озвучиваемой странице и возобновить автослежение",
            "回到目前正在朗讀的頁面並恢復自動翻頁",
            "العودة إلى الصفحة المقروءة واستئناف المتابعة التلقائية"
        ],
        .batteryRemaining: [
            "剩余电量 %@", "Battery %@", "バッテリー %@", "Batería %@",
            "Batterie %@", "Akku %@", "Батарея %@", "剩餘電量 %@", "البطارية %@"
        ],
        .pluggedIn: [
            "外接电源", "Power Adapter", "電源アダプタ", "Adaptador de corriente",
            "Adaptateur secteur", "Netzteil", "Питание от сети",
            "外接電源", "محول الطاقة"
        ],
        .progressPercent: [
            "进度 %d%%", "Progress %d%%", "進捗 %d%%", "Progreso %d%%",
            "Progression %d%%", "Fortschritt %d%%", "Прогресс %d%%",
            "進度 %d%%", "التقدم %d%%"
        ],
        .nextPageHelp: [
            "下一页（⌘→）", "Next page (⌘→)", "次のページ（⌘→）",
            "Página siguiente (⌘→)", "Page suivante (⌘→)",
            "Nächste Seite (⌘→)", "Следующая страница (⌘→)",
            "下一頁（⌘→）", "الصفحة التالية (⌘→)"
        ],
        .nextChapterHelp: [
            "下一章（⇧⌘→）", "Next chapter (⇧⌘→)", "次の章（⇧⌘→）",
            "Capítulo siguiente (⇧⌘→)", "Chapitre suivant (⇧⌘→)",
            "Nächstes Kapitel (⇧⌘→)", "Следующая глава (⇧⌘→)",
            "下一章（⇧⌘→）", "الفصل التالي (⇧⌘→)"
        ],
        .readingSettings: [
            "阅读设置", "Reading Settings", "読書設定", "Ajustes de lectura",
            "Réglages de lecture", "Leseeinstellungen", "Настройки чтения",
            "閱讀設定", "إعدادات القراءة"
        ],
        .readingVoice: [
            "朗读声音", "Reading Voice", "読み上げ音声", "Voz de lectura",
            "Voix de lecture", "Lesestimme", "Голос чтения",
            "朗讀聲音", "صوت القراءة"
        ],
        .personalVoice: [
            "个人声音", "Personal Voice", "パーソナルボイス", "Voz personal",
            "Voix personnelle", "Eigene Stimme", "Личный голос",
            "個人聲音", "الصوت الشخصي"
        ],
        .voiceQuality: [
            "%@品质", "%@ quality", "%@品質", "Calidad %@",
            "Qualité %@", "%@ Qualität", "Качество: %@",
            "%@品質", "جودة %@"
        ],
        .speechRate: [
            "语速", "Speed", "速度", "Velocidad", "Vitesse", "Tempo",
            "Скорость", "語速", "السرعة"
        ],
        .autoFollow: [
            "跟随朗读自动翻页", "Follow Reading Automatically",
            "読み上げを自動追従", "Seguir la lectura automáticamente",
            "Suivre automatiquement la lecture", "Vorlesen automatisch folgen",
            "Автоматически следовать за чтением", "跟隨朗讀自動翻頁",
            "متابعة القراءة تلقائيًا"
        ],
        .autoFollowOnDetail: [
            "朗读进入下一页时自动跟随", "Follow when reading moves to the next page",
            "次のページへ進むと自動追従", "Seguir al pasar a la página siguiente",
            "Suivre lors du passage à la page suivante",
            "Beim Wechsel zur nächsten Seite folgen",
            "Следовать при переходе на следующую страницу",
            "朗讀進入下一頁時自動跟隨", "المتابعة عند الانتقال إلى الصفحة التالية"
        ],
        .autoFollowOffDetail: [
            "朗读时保持当前浏览页面", "Keep the page you are browsing",
            "閲覧中のページを維持", "Mantener la página actual",
            "Conserver la page consultée", "Aktuelle Seite beibehalten",
            "Оставаться на текущей странице", "朗讀時保持目前瀏覽頁面",
            "البقاء في الصفحة الحالية"
        ],
        .stopCondition: [
            "停止条件", "Stop Condition", "停止条件", "Condición de parada",
            "Condition d’arrêt", "Stoppbedingung", "Условие остановки",
            "停止條件", "شرط الإيقاف"
        ],
        .displayMode: [
            "显示模式", "Appearance", "表示モード", "Apariencia", "Apparence",
            "Darstellung", "Оформление", "顯示模式", "المظهر"
        ],
        .eyeCareMode: [
            "护眼模式", "Eye Care", "アイケア", "Modo descanso visual",
            "Mode confort visuel", "Augenschonmodus", "Режим защиты глаз",
            "護眼模式", "وضع راحة العين"
        ],
        .eyeCareDetail: [
            "低饱和暖绿阅读背景", "Low-saturation warm green background",
            "低彩度の暖色グリーン背景", "Fondo verde cálido de baja saturación",
            "Fond vert chaud peu saturé", "Warmer, entsättigter grüner Hintergrund",
            "Тёплый зелёный фон низкой насыщенности",
            "低飽和暖綠閱讀背景", "خلفية خضراء دافئة منخفضة التشبع"
        ],
        .fontSize: [
            "字体大小", "Font Size", "文字サイズ", "Tamaño de letra",
            "Taille du texte", "Schriftgröße", "Размер шрифта",
            "字體大小", "حجم الخط"
        ],
        .pageBrightness: [
            "页面亮度", "Page Brightness", "ページの明るさ", "Brillo de página",
            "Luminosité de la page", "Seitenhelligkeit", "Яркость страницы",
            "頁面亮度", "سطوع الصفحة"
        ],
        .selectionHint: [
            "拖动选择文字后右键，可高亮、批注、下划线、翻译或拷贝",
            "Select text and right-click to highlight, annotate, underline, translate, or copy",
            "テキストを選択して右クリックすると、ハイライト、注釈、下線、翻訳、コピーができます",
            "Selecciona texto y haz clic derecho para resaltar, anotar, subrayar, traducir o copiar",
            "Sélectionnez du texte puis faites un clic droit pour surligner, annoter, souligner, traduire ou copier",
            "Text markieren und rechtsklicken, um hervorzuheben, zu kommentieren, zu unterstreichen, zu übersetzen oder zu kopieren",
            "Выделите текст и щёлкните правой кнопкой для выделения, заметки, подчёркивания, перевода или копирования",
            "拖曳選取文字後按右鍵，可醒目提示、批註、加底線、翻譯或複製",
            "حدد النص وانقر بزر الماوس الأيمن للتمييز أو التعليق أو التسطير أو الترجمة أو النسخ"
        ],
        .collapseSettings: [
            "收起阅读设置", "Collapse Reading Settings", "読書設定を閉じる",
            "Ocultar ajustes", "Réduire les réglages", "Leseeinstellungen schließen",
            "Свернуть настройки", "收起閱讀設定", "طي إعدادات القراءة"
        ],
        .expandSettings: [
            "展开阅读设置", "Open Reading Settings", "読書設定を開く",
            "Abrir ajustes", "Ouvrir les réglages", "Leseeinstellungen öffnen",
            "Открыть настройки", "展開閱讀設定", "فتح إعدادات القراءة"
        ],
        .followSystem: [
            "跟随系统", "System", "システム", "Sistema", "Système",
            "System", "Системная", "跟隨系統", "النظام"
        ],
        .lightMode: [
            "白天", "Light", "ライト", "Claro", "Clair", "Hell", "Светлая",
            "白天", "فاتح"
        ],
        .darkMode: [
            "黑夜", "Dark", "ダーク", "Oscuro", "Sombre", "Dunkel", "Тёмная",
            "黑夜", "داكن"
        ],
        .timerOff: [
            "关闭定时", "Off", "オフ", "Desactivado", "Désactivé", "Aus",
            "Выкл.", "關閉定時", "إيقاف"
        ],
        .tenMinutes: [
            "10 分钟", "10 minutes", "10分", "10 minutos", "10 minutes",
            "10 Minuten", "10 минут", "10 分鐘", "10 دقائق"
        ],
        .twentyMinutes: [
            "20 分钟", "20 minutes", "20分", "20 minutos", "20 minutes",
            "20 Minuten", "20 минут", "20 分鐘", "20 دقيقة"
        ],
        .thirtyMinutes: [
            "30 分钟", "30 minutes", "30分", "30 minutos", "30 minutes",
            "30 Minuten", "30 минут", "30 分鐘", "30 دقيقة"
        ],
        .sixtyMinutes: [
            "60 分钟", "60 minutes", "60分", "60 minutos", "60 minutes",
            "60 Minuten", "60 минут", "60 分鐘", "60 دقيقة"
        ],
        .finishSection: [
            "读完本小节", "End of Section", "この節の終わり", "Fin de la sección",
            "Fin de la section", "Abschnittsende", "До конца раздела",
            "讀完本小節", "نهاية القسم"
        ],
        .finishChapter: [
            "读完本章", "End of Chapter", "この章の終わり", "Fin del capítulo",
            "Fin du chapitre", "Kapitelende", "До конца главы",
            "讀完本章", "نهاية الفصل"
        ],
        .standardQuality: [
            "标准", "Standard", "標準", "Estándar", "Standard", "Standard",
            "Стандарт", "標準", "قياسي"
        ],
        .enhancedQuality: [
            "增强", "Enhanced", "拡張", "Mejorada", "Améliorée", "Erweitert",
            "Улучшенный", "增強", "محسّن"
        ],
        .premiumQuality: [
            "高级", "Premium", "プレミアム", "Premium", "Premium", "Premium",
            "Премиум", "高級", "متميز"
        ],
        .femaleVoice: [
            "女声", "Female", "女性", "Femenina", "Féminine", "Weiblich",
            "Женский", "女聲", "أنثى"
        ],
        .maleVoice: [
            "男声", "Male", "男性", "Masculina", "Masculine", "Männlich",
            "Мужской", "男聲", "ذكر"
        ],
        .neutralVoice: [
            "中性", "Neutral", "ニュートラル", "Neutra", "Neutre", "Neutral",
            "Нейтральный", "中性", "محايد"
        ],
        .unspecifiedVoice: [
            "未标注", "Unspecified", "指定なし", "Sin especificar",
            "Non indiqué", "Nicht angegeben", "Не указан",
            "未標註", "غير محدد"
        ],
        .parchmentYellow: [
            "书卷黄", "Parchment", "パーチメント", "Pergamino", "Parchemin",
            "Pergament", "Пергамент", "書卷黃", "ورقي"
        ],
        .eyeCareGreen: [
            "护眼绿", "Soft Green", "アイケアグリーン", "Verde suave",
            "Vert doux", "Sanftes Grün", "Мягкий зелёный",
            "護眼綠", "أخضر هادئ"
        ],
        .mistBlue: [
            "雾霾蓝", "Mist Blue", "ミストブルー", "Azul niebla",
            "Bleu brume", "Nebelblau", "Дымчато-синий",
            "霧霾藍", "أزرق ضبابي"
        ],
        .softPink: [
            "浅粉", "Soft Pink", "ソフトピンク", "Rosa suave",
            "Rose doux", "Zartrosa", "Нежно-розовый",
            "淺粉", "وردي هادئ"
        ],
        .palePurple: [
            "淡紫", "Pale Purple", "ペールパープル", "Morado claro",
            "Violet pâle", "Blasslila", "Светло-фиолетовый",
            "淡紫", "بنفسجي فاتح"
        ],
        .noColor: [
            "无", "None", "なし", "Ninguno", "Aucun", "Keine", "Нет",
            "無", "بلا"
        ],
        .permissionNotDetermined: [
            "尚未授权", "Not Yet Authorized", "未承認", "Sin autorizar",
            "Non autorisée", "Noch nicht autorisiert", "Не авторизовано",
            "尚未授權", "لم يُصرح بعد"
        ],
        .permissionDenied: [
            "未获授权", "Permission Denied", "許可されていません", "Permiso denegado",
            "Autorisation refusée", "Zugriff verweigert", "Доступ запрещён",
            "未獲授權", "تم رفض الإذن"
        ],
        .unsupportedDevice: [
            "此设备不支持", "Not Supported", "このデバイスでは非対応",
            "No compatible", "Non pris en charge", "Nicht unterstützt",
            "Не поддерживается", "此裝置不支援", "غير مدعوم"
        ],
        .authorized: [
            "已授权", "Authorized", "承認済み", "Autorizado", "Autorisée",
            "Autorisiert", "Авторизовано", "已授權", "مصرح"
        ],
        .removeFromLibrary: [
            "从我的图书移除", "Remove from My Books", "マイブックから削除",
            "Quitar de Mis libros", "Retirer de Mes livres",
            "Aus „Meine Bücher“ entfernen", "Удалить из «Моих книг»",
            "從我的圖書移除", "إزالة من كتبي"
        ],
        .originalFileKept: [
            "不会删除原始文件", "The original file will not be deleted",
            "元のファイルは削除されません", "El archivo original no se eliminará",
            "Le fichier d’origine ne sera pas supprimé",
            "Die Originaldatei wird nicht gelöscht",
            "Исходный файл не будет удалён", "不會刪除原始檔案",
            "لن يتم حذف الملف الأصلي"
        ],
        .progress: [
            "进度 %d%%", "Progress %d%%", "進捗 %d%%", "Progreso %d%%",
            "Progression %d%%", "Fortschritt %d%%", "Прогресс %d%%",
            "進度 %d%%", "التقدم %d%%"
        ],
        .sourceUnavailable: [
            "原文件不可用", "Source file unavailable", "元のファイルを利用できません",
            "Archivo original no disponible", "Fichier d’origine indisponible",
            "Originaldatei nicht verfügbar", "Исходный файл недоступен",
            "原始檔案無法使用", "الملف الأصلي غير متاح"
        ],
        .openNamedBook: [
            "打开《%@》", "Open “%@”", "『%@』を開く", "Abrir «%@»",
            "Ouvrir « %@ »", "„%@“ öffnen", "Открыть «%@»",
            "開啟《%@》", "فتح «%@»"
        ],
        .deleteHistoryHelp: [
            "删除这条观看历史，不会移除图书",
            "Delete this history entry without removing the book",
            "履歴のみ削除し、本は残します",
            "Eliminar esta entrada sin quitar el libro",
            "Supprimer cette entrée sans retirer le livre",
            "Diesen Verlaufseintrag löschen, ohne das Buch zu entfernen",
            "Удалить запись, не удаляя книгу",
            "刪除這筆觀看歷史，不會移除圖書",
            "حذف سجل القراءة دون إزالة الكتاب"
        ],
        .voiceCenterDetail: [
            "集中管理已安装音色、系统音色下载和个人声音。",
            "Manage installed voices, system voice downloads, and Personal Voice.",
            "インストール済み音声、システム音声のダウンロード、パーソナルボイスを管理します。",
            "Gestiona voces instaladas, descargas del sistema y Voz personal.",
            "Gérez les voix installées, les téléchargements système et la Voix personnelle.",
            "Installierte Stimmen, Systemdownloads und Eigene Stimme verwalten.",
            "Управляйте установленными голосами, загрузками и личным голосом.",
            "集中管理已安裝音色、系統音色下載和個人聲音。",
            "إدارة الأصوات المثبتة وتنزيلات النظام والصوت الشخصي."
        ],
        .installedVoices: [
            "已安装音色", "Installed Voices", "インストール済み音声",
            "Voces instaladas", "Voix installées", "Installierte Stimmen",
            "Установленные голоса", "已安裝音色", "الأصوات المثبتة"
        ],
        .currentVoiceDetail: [
            "当前：%@\n可试听、搜索和收藏本机音色。",
            "Current: %@\nPreview, search, and favorite voices on this Mac.",
            "現在：%@\nこのMacの音声を試聴、検索、お気に入り登録できます。",
            "Actual: %@\nPrueba, busca y guarda voces de este Mac.",
            "Actuelle : %@\nÉcoutez, recherchez et ajoutez des voix aux favoris.",
            "Aktuell: %@\nStimmen auf diesem Mac anhören, suchen und favorisieren.",
            "Текущий: %@\nПрослушивайте, ищите и добавляйте голоса в избранное.",
            "目前：%@\n可試聽、搜尋和收藏本機音色。",
            "الحالي: %@\nاستمع وابحث وأضف أصوات هذا الـ Mac إلى المفضلة."
        ],
        .chooseReadingVoice: [
            "选择朗读音色", "Choose Reading Voice", "読み上げ音声を選ぶ",
            "Elegir voz", "Choisir la voix", "Lesestimme wählen",
            "Выбрать голос", "選擇朗讀音色", "اختيار صوت القراءة"
        ],
        .enhancedVoices: [
            "增强／高级音色", "Enhanced / Premium Voices", "拡張／プレミアム音声",
            "Voces mejoradas / Premium", "Voix améliorées / Premium",
            "Erweiterte / Premium-Stimmen", "Улучшенные / премиум-голоса",
            "增強／高級音色", "أصوات محسنة / متميزة"
        ],
        .enhancedVoicesDetail: [
            "由 macOS 下载并保存在本机，可获得更自然的朗读效果。",
            "Downloaded by macOS and stored locally for more natural reading.",
            "macOSがダウンロードしてローカルに保存し、より自然に読み上げます。",
            "macOS las descarga y guarda localmente para una lectura más natural.",
            "Téléchargées par macOS et stockées localement pour une lecture plus naturelle.",
            "Von macOS geladen und lokal gespeichert, für natürlicheres Vorlesen.",
            "Загружаются macOS и хранятся локально для более естественного чтения.",
            "由 macOS 下載並保存在本機，可獲得更自然的朗讀效果。",
            "ينزلها macOS ويحفظها محليًا لقراءة أكثر طبيعية."
        ],
        .openSystemVoiceDownloads: [
            "打开系统音色下载", "Open System Voice Downloads",
            "システム音声のダウンロードを開く", "Abrir descargas de voces",
            "Ouvrir les téléchargements de voix", "System-Stimmendownloads öffnen",
            "Открыть загрузку голосов", "開啟系統音色下載",
            "فتح تنزيلات أصوات النظام"
        ],
        .personalVoiceStatusDetail: [
            "状态：%@\n已发现 %d 个个人声音。",
            "Status: %@\n%d Personal Voice voices found.",
            "状態：%@\nパーソナルボイスが%d個見つかりました。",
            "Estado: %@\nSe encontraron %d voces personales.",
            "État : %@\n%d voix personnelles trouvées.",
            "Status: %@\n%d eigene Stimmen gefunden.",
            "Статус: %@\nНайдено личных голосов: %d.",
            "狀態：%@\n已找到 %d 個個人聲音。",
            "الحالة: %@\nتم العثور على %d من الأصوات الشخصية."
        ],
        .recordingAndAuthorization: [
            "录制与授权说明", "Recording & Permission", "録音と許可の説明",
            "Grabación y permisos", "Enregistrement et autorisation",
            "Aufnahme und Berechtigung", "Запись и разрешение",
            "錄製與授權說明", "التسجيل والأذونات"
        ],
        .localVoiceLibrary: [
            "本地音色库", "Local Voice Library", "ローカル音声ライブラリ",
            "Biblioteca de voces local", "Bibliothèque vocale locale",
            "Lokale Stimmenbibliothek", "Локальная библиотека голосов",
            "本地音色庫", "مكتبة الأصوات المحلية"
        ],
        .localVoicePrivacy: [
            "选择已下载到这台 Mac 的系统音色，朗读过程不会上传书籍内容。",
            "Choose a system voice downloaded to this Mac. Book content is never uploaded.",
            "このMacにダウンロード済みの音声を選べます。本の内容はアップロードされません。",
            "Elige una voz descargada en este Mac. El contenido del libro no se sube.",
            "Choisissez une voix téléchargée sur ce Mac. Le contenu du livre n’est jamais envoyé.",
            "Wählen Sie eine auf diesen Mac geladene Stimme. Buchinhalte werden nie hochgeladen.",
            "Выберите голос, загруженный на Mac. Текст книги не отправляется.",
            "選擇已下載到這台 Mac 的系統音色，朗讀過程不會上傳圖書內容。",
            "اختر صوت نظام منزلاً على هذا الـ Mac. لا يتم رفع محتوى الكتاب."
        ],
        .searchVoices: [
            "搜索音色、语言或性别", "Search voice, language, or gender",
            "音声、言語、性別を検索", "Buscar voz, idioma o género",
            "Rechercher une voix, une langue ou un genre",
            "Stimme, Sprache oder Geschlecht suchen",
            "Поиск по голосу, языку или полу",
            "搜尋音色、語言或性別", "البحث عن صوت أو لغة أو جنس"
        ],
        .wantNaturalVoice: [
            "想要更自然的增强或高级音色？", "Want a more natural enhanced or premium voice?",
            "より自然な拡張／プレミアム音声を使いますか？",
            "¿Quieres una voz mejorada o Premium más natural?",
            "Vous voulez une voix améliorée ou Premium plus naturelle ?",
            "Eine natürlichere erweiterte oder Premium-Stimme?",
            "Нужен более естественный улучшенный или премиум-голос?",
            "想要更自然的增強或高級音色？", "هل تريد صوتًا محسنًا أو متميزًا أكثر طبيعية؟"
        ],
        .downloadVoiceHint: [
            "在系统设置中下载音色，返回声页后点“刷新”即可使用。",
            "Download voices in System Settings, then return and click Refresh.",
            "システム設定で音声をダウンロードし、声页に戻って「更新」をクリックしてください。",
            "Descarga voces en Ajustes del Sistema, vuelve y pulsa Actualizar.",
            "Téléchargez les voix dans Réglages Système, puis revenez et actualisez.",
            "Stimmen in den Systemeinstellungen laden, zurückkehren und Aktualisieren wählen.",
            "Загрузите голоса в настройках системы, затем вернитесь и обновите список.",
            "在系統設定中下載音色，返回聲頁後點「重新整理」即可使用。",
            "نزّل الأصوات من إعدادات النظام، ثم ارجع واضغط تحديث."
        ],
        .openSystemVoiceManager: [
            "打开系统音色管理", "Open System Voice Settings", "システム音声設定を開く",
            "Abrir ajustes de voces", "Ouvrir les réglages des voix",
            "System-Stimmeneinstellungen öffnen", "Открыть настройки голосов",
            "開啟系統音色管理", "فتح إعدادات أصوات النظام"
        ],
        .refresh: [
            "刷新", "Refresh", "更新", "Actualizar", "Actualiser", "Aktualisieren",
            "Обновить", "重新整理", "تحديث"
        ],
        .previewVoice: [
            "试听音色", "Preview Voice", "音声を試聴", "Probar voz",
            "Écouter la voix", "Stimme anhören", "Прослушать голос",
            "試聽音色", "معاينة الصوت"
        ],
        .removeFavorite: [
            "取消收藏", "Remove Favorite", "お気に入りを解除", "Quitar favorito",
            "Retirer des favoris", "Favorit entfernen", "Убрать из избранного",
            "取消收藏", "إزالة من المفضلة"
        ],
        .addFavorite: [
            "收藏音色", "Favorite Voice", "お気に入りに追加", "Guardar favorita",
            "Ajouter aux favoris", "Als Favorit markieren", "Добавить в избранное",
            "收藏音色", "إضافة إلى المفضلة"
        ],
        .recordPersonalVoice: [
            "录制并使用个人声音", "Record and Use Personal Voice",
            "パーソナルボイスを録音して使用", "Grabar y usar Voz personal",
            "Enregistrer et utiliser la Voix personnelle",
            "Eigene Stimme aufnehmen und verwenden",
            "Записать и использовать личный голос",
            "錄製並使用個人聲音", "تسجيل الصوت الشخصي واستخدامه"
        ],
        .personalRecordingPrivacy: [
            "录音和声音生成由 macOS 在本机完成，声页不会读取原始录音。",
            "Recording and voice generation happen locally in macOS. VoicePage never reads the recordings.",
            "録音と音声生成はmacOS上で行われ、声页が元の録音を読み取ることはありません。",
            "La grabación y generación se realizan localmente en macOS. VoicePage no lee las grabaciones.",
            "L’enregistrement et la génération sont effectués localement par macOS. VoicePage ne lit pas les enregistrements.",
            "Aufnahme und Stimmerzeugung erfolgen lokal in macOS. VoicePage liest die Aufnahmen nicht.",
            "Запись и создание голоса выполняются локально в macOS. VoicePage не читает записи.",
            "錄音和聲音生成由 macOS 在本機完成，聲頁不會讀取原始錄音。",
            "يتم التسجيل وإنشاء الصوت محليًا في macOS، ولا يقرأ VoicePage التسجيلات."
        ],
        .createPersonalVoice: [
            "在系统设置中创建个人声音", "Create Personal Voice in System Settings",
            "システム設定でパーソナルボイスを作成", "Crear Voz personal en Ajustes",
            "Créer une Voix personnelle dans Réglages",
            "Eigene Stimme in den Systemeinstellungen erstellen",
            "Создать личный голос в настройках системы",
            "在系統設定中建立個人聲音", "إنشاء صوت شخصي في إعدادات النظام"
        ],
        .createPersonalVoiceDetail: [
            "按照系统提示朗读句子，等待 Mac 在本机完成声音生成。",
            "Read the prompted phrases and wait for the Mac to generate the voice locally.",
            "表示された文を読み、Macがローカルで音声を生成するのを待ちます。",
            "Lee las frases indicadas y espera a que el Mac genere la voz localmente.",
            "Lisez les phrases demandées et attendez que le Mac génère la voix localement.",
            "Vorgegebene Sätze lesen und warten, bis der Mac die Stimme lokal erzeugt.",
            "Прочитайте предложенные фразы и дождитесь локального создания голоса.",
            "按照系統提示朗讀句子，等待 Mac 在本機完成聲音生成。",
            "اقرأ العبارات المطلوبة وانتظر حتى ينشئ Mac الصوت محليًا."
        ],
        .allowPersonalVoice: [
            "允许声页使用个人声音", "Allow VoicePage to Use Personal Voice",
            "声页にパーソナルボイスの使用を許可", "Permitir a VoicePage usar Voz personal",
            "Autoriser VoicePage à utiliser la Voix personnelle",
            "VoicePage die Eigene Stimme erlauben",
            "Разрешить VoicePage использовать личный голос",
            "允許聲頁使用個人聲音", "السماح لـ VoicePage باستخدام الصوت الشخصي"
        ],
        .allowPersonalVoiceDetail: [
            "系统会显示一次授权提示；授权后个人声音才会出现在音色库。",
            "macOS asks once for permission; Personal Voice appears after authorization.",
            "macOSが一度許可を求めます。承認後に音声ライブラリへ表示されます。",
            "macOS pedirá permiso una vez; la Voz personal aparecerá después.",
            "macOS demande l’autorisation une fois ; la Voix personnelle apparaît ensuite.",
            "macOS fragt einmal nach der Berechtigung; danach erscheint die Eigene Stimme.",
            "macOS запросит разрешение; после этого личный голос появится в библиотеке.",
            "系統會顯示一次授權提示；授權後個人聲音才會出現在音色庫。",
            "سيطلب macOS الإذن مرة واحدة، ثم يظهر الصوت الشخصي في المكتبة."
        ],
        .returnRefreshChoose: [
            "返回声页刷新并选择", "Return, Refresh, and Choose",
            "声页に戻り、更新して選択", "Volver, actualizar y elegir",
            "Revenir, actualiser et choisir", "Zurückkehren, aktualisieren und wählen",
            "Вернуться, обновить и выбрать", "返回聲頁重新整理並選擇",
            "العودة والتحديث والاختيار"
        ],
        .returnRefreshChooseDetail: [
            "个人声音会带有“个人声音”标记，可像其他音色一样试听和使用。",
            "Personal Voice is labeled and can be previewed and used like other voices.",
            "パーソナルボイスにはラベルが付き、他の音声と同様に試聴・使用できます。",
            "La Voz personal aparece etiquetada y se puede probar y usar como las demás.",
            "La Voix personnelle est étiquetée et peut être écoutée et utilisée comme les autres.",
            "Eigene Stimmen sind markiert und können wie andere Stimmen angehört und verwendet werden.",
            "Личный голос отмечен и доступен для прослушивания и использования.",
            "個人聲音會帶有「個人聲音」標記，可像其他音色一樣試聽和使用。",
            "يظهر الصوت الشخصي بعلامة ويمكن معاينته واستخدامه كغيره."
        ],
        .currentStatus: [
            "当前状态：%@", "Current status: %@", "現在の状態：%@",
            "Estado actual: %@", "État actuel : %@", "Aktueller Status: %@",
            "Текущий статус: %@", "目前狀態：%@", "الحالة الحالية: %@"
        ],
        .personalVoiceCount: [
            "已发现 %d 个个人声音", "%d Personal Voice voices found",
            "パーソナルボイスが%d個見つかりました", "Se encontraron %d voces personales",
            "%d voix personnelles trouvées", "%d eigene Stimmen gefunden",
            "Найдено личных голосов: %d", "已找到 %d 個個人聲音",
            "تم العثور على %d من الأصوات الشخصية"
        ],
        .personalVoiceRequirements: [
            "要求：Apple 芯片 Mac、受支持的系统语言及 macOS 14 或更高版本。Apple 规定个人声音仅限本人创建，并用于个人非商业用途。",
            "Requires an Apple silicon Mac, a supported system language, and macOS 14 or later. Apple limits Personal Voice to voices you create for personal, non-commercial use.",
            "Appleシリコン搭載Mac、対応言語、macOS 14以降が必要です。パーソナルボイスは本人が作成し、個人的・非商用目的でのみ使用できます。",
            "Requiere un Mac con Apple silicon, idioma compatible y macOS 14 o posterior. Apple limita Voz personal al uso personal y no comercial.",
            "Nécessite un Mac Apple silicon, une langue compatible et macOS 14 ou ultérieur. Apple réserve la Voix personnelle à un usage personnel non commercial.",
            "Erfordert einen Mac mit Apple-Chip, eine unterstützte Systemsprache und macOS 14 oder neuer. Eigene Stimme ist nur für persönlichen, nicht kommerziellen Gebrauch bestimmt.",
            "Требуется Mac с Apple silicon, поддерживаемый язык и macOS 14 или новее. Личный голос предназначен только для личного некоммерческого использования.",
            "要求：Apple 晶片 Mac、受支援的系統語言及 macOS 14 或更新版本。Apple 規定個人聲音僅限本人建立，並用於個人非商業用途。",
            "يتطلب Mac بمعالج Apple ولغة نظام مدعومة وmacOS 14 أو أحدث. يقتصر الصوت الشخصي على الاستخدام الشخصي غير التجاري."
        ],
        .personalVoiceReauthorization: [
            "更新版本后若一直显示“尚未授权”，请打开个人声音设置，在应用列表中选中并移除旧的“声页”，再返回此处重新允许。",
            "If “Not Yet Authorized” remains after an update, open Personal Voice settings, remove the old VoicePage entry, then return and allow access again.",
            "更新後も「未承認」の場合は、パーソナルボイス設定で古い声页を削除し、戻って再度許可してください。",
            "Si sigue apareciendo “Sin autorizar” tras actualizar, elimina la entrada antigua de VoicePage en los ajustes y vuelve a autorizar.",
            "Si « Non autorisée » persiste après une mise à jour, supprimez l’ancienne entrée VoicePage dans les réglages puis autorisez à nouveau.",
            "Bleibt nach einem Update „Noch nicht autorisiert“, entfernen Sie den alten VoicePage-Eintrag in den Einstellungen und erlauben Sie den Zugriff erneut.",
            "Если после обновления остаётся «Не авторизовано», удалите старую запись VoicePage в настройках и разрешите доступ снова.",
            "更新版本後若一直顯示「尚未授權」，請開啟個人聲音設定，移除舊的「聲頁」，再返回此處重新允許。",
            "إذا استمرت حالة «لم يُصرح بعد» بعد التحديث، فاحذف إدخال VoicePage القديم من الإعدادات ثم اسمح بالوصول مجددًا."
        ],
        .openPersonalVoiceSettings: [
            "打开个人声音设置", "Open Personal Voice Settings",
            "パーソナルボイス設定を開く", "Abrir ajustes de Voz personal",
            "Ouvrir les réglages de Voix personnelle",
            "Einstellungen für Eigene Stimme öffnen",
            "Открыть настройки личного голоса", "開啟個人聲音設定",
            "فتح إعدادات الصوت الشخصي"
        ],
        .refreshPersonalVoices: [
            "刷新个人声音", "Refresh Personal Voices", "パーソナルボイスを更新",
            "Actualizar voces personales", "Actualiser les voix personnelles",
            "Eigene Stimmen aktualisieren", "Обновить личные голоса",
            "重新整理個人聲音", "تحديث الأصوات الشخصية"
        ],
        .allowVoicePage: [
            "允许声页使用", "Allow VoicePage", "声页を許可", "Permitir VoicePage",
            "Autoriser VoicePage", "VoicePage erlauben", "Разрешить VoicePage",
            "允許聲頁使用", "السماح لـ VoicePage"
        ],
        .addAnnotation: [
            "添加文字批注", "Add Annotation", "注釈を追加", "Añadir anotación",
            "Ajouter une annotation", "Anmerkung hinzufügen", "Добавить заметку",
            "新增文字批註", "إضافة تعليق"
        ],
        .editAnnotation: [
            "编辑文字批注", "Edit Annotation", "注釈を編集", "Editar anotación",
            "Modifier l’annotation", "Anmerkung bearbeiten", "Изменить заметку",
            "編輯文字批註", "تعديل التعليق"
        ],
        .highlightColor: [
            "高亮颜色", "Highlight Color", "ハイライト色", "Color de resaltado",
            "Couleur de surbrillance", "Hervorhebungsfarbe", "Цвет выделения",
            "醒目提示顏色", "لون التمييز"
        ],
        .underlineSelection: [
            "为所选文字添加下划线", "Underline selected text", "選択テキストに下線を付ける",
            "Subrayar texto seleccionado", "Souligner le texte sélectionné",
            "Ausgewählten Text unterstreichen", "Подчеркнуть выделенный текст",
            "為所選文字加上底線", "تسطير النص المحدد"
        ],
        .note: [
            "注释", "Note", "メモ", "Nota", "Note", "Notiz", "Заметка",
            "註解", "ملاحظة"
        ],
        .deleteAnnotation: [
            "删除批注", "Delete Annotation", "注釈を削除", "Eliminar anotación",
            "Supprimer l’annotation", "Anmerkung löschen", "Удалить заметку",
            "刪除批註", "حذف التعليق"
        ],
        .save: [
            "保存", "Save", "保存", "Guardar", "Enregistrer", "Sichern",
            "Сохранить", "儲存", "حفظ"
        ],
        .cancel: [
            "取消", "Cancel", "キャンセル", "Cancelar", "Annuler", "Abbrechen",
            "Отмена", "取消", "إلغاء"
        ],
        .shortcutTitle: [
            "快捷操作指南", "Keyboard & Trackpad Shortcuts", "ショートカットガイド",
            "Atajos de teclado y trackpad", "Raccourcis clavier et trackpad",
            "Tastatur- und Trackpad-Kürzel", "Клавиатура и трекпад",
            "快捷操作指南", "اختصارات لوحة المفاتيح ولوحة التعقب"
        ],
        .nextChapter: [
            "下一章", "Next Chapter", "次の章", "Capítulo siguiente",
            "Chapitre suivant", "Nächstes Kapitel", "Следующая глава",
            "下一章", "الفصل التالي"
        ],
        .previousChapter: [
            "上一章", "Previous Chapter", "前の章", "Capítulo anterior",
            "Chapitre précédent", "Vorheriges Kapitel", "Предыдущая глава",
            "上一章", "الفصل السابق"
        ],
        .playPause: [
            "播放 / 暂停", "Play / Pause", "再生／一時停止", "Reproducir / Pausar",
            "Lecture / Pause", "Wiedergabe / Pause", "Воспроизведение / Пауза",
            "播放 / 暫停", "تشغيل / إيقاف مؤقت"
        ],
        .previousPage: [
            "上一页", "Previous Page", "前のページ", "Página anterior",
            "Page précédente", "Vorherige Seite", "Предыдущая страница",
            "上一頁", "الصفحة السابقة"
        ],
        .nextPage: [
            "下一页", "Next Page", "次のページ", "Página siguiente",
            "Page suivante", "Nächste Seite", "Следующая страница",
            "下一頁", "الصفحة التالية"
        ],
        .twoFingerRight: [
            "两指右滑", "Two-finger swipe right", "2本指で右へスワイプ",
            "Deslizar dos dedos a la derecha", "Balayer à droite avec deux doigts",
            "Mit zwei Fingern nach rechts wischen", "Смахнуть двумя пальцами вправо",
            "兩指向右滑", "السحب بإصبعين إلى اليمين"
        ],
        .twoFingerLeft: [
            "两指左滑", "Two-finger swipe left", "2本指で左へスワイプ",
            "Deslizar dos dedos a la izquierda", "Balayer à gauche avec deux doigts",
            "Mit zwei Fingern nach links wischen", "Смахнуть двумя пальцами влево",
            "兩指向左滑", "السحب بإصبعين إلى اليسار"
        ],
        .exitApp: [
            "退出应用", "Quit App", "アプリを終了", "Salir de la app",
            "Quitter l’app", "App beenden", "Выйти из приложения",
            "退出應用程式", "إنهاء التطبيق"
        ],
        .naturalScrollHint: [
            "若鼠标设置中开启了“自然滚动”，触控板双指翻页方向可能与上方描述相反。",
            "If Natural Scrolling is enabled in Mouse settings, trackpad directions may be reversed.",
            "マウス設定で「ナチュラルなスクロール」が有効な場合、トラックパッドの方向が逆になることがあります。",
            "Si el desplazamiento natural está activado en Ratón, la dirección del trackpad puede invertirse.",
            "Si le défilement naturel est activé pour la souris, le sens du trackpad peut être inversé.",
            "Ist „Natürliche Scrollrichtung“ für die Maus aktiv, können die Trackpad-Richtungen umgekehrt sein.",
            "Если включена естественная прокрутка мыши, направления трекпада могут быть обратными.",
            "若滑鼠設定中開啟了「自然捲動」，觸控板雙指翻頁方向可能與上方描述相反。",
            "إذا كان التمرير الطبيعي مفعلاً في إعدادات الماوس فقد تنعكس اتجاهات لوحة التعقب."
        ],
        .contextHighlight: [
            "高亮颜色", "Highlight Color", "ハイライト色", "Color de resaltado",
            "Couleur de surbrillance", "Hervorhebungsfarbe", "Цвет выделения",
            "醒目提示顏色", "لون التمييز"
        ],
        .clearHighlight: [
            "取消高亮", "Remove Highlight", "ハイライトを解除", "Quitar resaltado",
            "Supprimer la surbrillance", "Hervorhebung entfernen",
            "Убрать выделение", "取消醒目提示", "إزالة التمييز"
        ],
        .editNote: [
            "编辑注释", "Edit Note", "メモを編集", "Editar nota",
            "Modifier la note", "Notiz bearbeiten", "Изменить заметку",
            "編輯註解", "تعديل الملاحظة"
        ],
        .addNote: [
            "添加注释", "Add Note", "メモを追加", "Añadir nota",
            "Ajouter une note", "Notiz hinzufügen", "Добавить заметку",
            "新增註解", "إضافة ملاحظة"
        ],
        .clearNote: [
            "清除注释", "Clear Note", "メモを消去", "Borrar nota",
            "Effacer la note", "Notiz leeren", "Очистить заметку",
            "清除註解", "مسح الملاحظة"
        ],
        .underline: [
            "下划线", "Underline", "下線", "Subrayar", "Souligner",
            "Unterstreichen", "Подчеркнуть", "加底線", "تسطير"
        ],
        .removeUnderline: [
            "取消下划线", "Remove Underline", "下線を解除", "Quitar subrayado",
            "Supprimer le soulignement", "Unterstreichung entfernen",
            "Убрать подчёркивание", "取消底線", "إزالة التسطير"
        ],
        .translate: [
            "翻译", "Translate", "翻訳", "Traducir", "Traduire", "Übersetzen",
            "Перевести", "翻譯", "ترجمة"
        ],
        .copy: [
            "拷贝", "Copy", "コピー", "Copiar", "Copier", "Kopieren",
            "Копировать", "複製", "نسخ"
        ],
        .openBookCommand: [
            "打开书籍…", "Open Book…", "本を開く…", "Abrir libro…",
            "Ouvrir un livre…", "Buch öffnen…", "Открыть книгу…",
            "開啟書籍…", "فتح كتاب…"
        ],
        .readingMenu: [
            "朗读", "Reading", "読み上げ", "Lectura", "Lecture", "Vorlesen",
            "Чтение", "朗讀", "القراءة"
        ],
        .pause: [
            "暂停", "Pause", "一時停止", "Pausar", "Pause", "Pause",
            "Пауза", "暫停", "إيقاف مؤقت"
        ],
        .startOrContinue: [
            "开始或继续", "Start or Resume", "開始／再開", "Iniciar o continuar",
            "Démarrer ou reprendre", "Starten oder fortsetzen",
            "Начать или продолжить", "開始或繼續", "بدء أو متابعة"
        ],
        .systemDefault: [
            "系统默认", "System Default", "システム標準", "Predeterminada",
            "Voix système", "Systemstandard", "Системный голос",
            "系統預設", "افتراضي النظام"
        ],
        .fullText: [
            "全文", "Full Text", "全文", "Texto completo", "Texte intégral",
            "Gesamter Text", "Весь текст", "全文", "النص الكامل"
        ],
        .statusOpening: [
            "正在打开书籍…", "Opening book…", "本を開いています…",
            "Abriendo libro…", "Ouverture du livre…", "Buch wird geöffnet…",
            "Открытие книги…", "正在開啟書籍…", "جارٍ فتح الكتاب…"
        ],
        .statusPaused: [
            "已暂停", "Paused", "一時停止中", "En pausa", "En pause",
            "Pausiert", "Приостановлено", "已暫停", "متوقف مؤقتًا"
        ],
        .statusReading: [
            "正在朗读", "Reading", "読み上げ中", "Leyendo", "Lecture en cours",
            "Wird vorgelesen", "Чтение", "正在朗讀", "جارٍ القراءة"
        ],
        .statusReady: [
            "准备就绪", "Ready", "準備完了", "Listo", "Prêt", "Bereit",
            "Готово", "準備就緒", "جاهز"
        ],
        .translationRequiresNewerSystem: [
            "系统翻译功能需要 macOS 14.4 或更高版本。",
            "System translation requires macOS 14.4 or later.",
            "システム翻訳にはmacOS 14.4以降が必要です。",
            "La traducción del sistema requiere macOS 14.4 o posterior.",
            "La traduction système nécessite macOS 14.4 ou ultérieur.",
            "Die Systemübersetzung erfordert macOS 14.4 oder neuer.",
            "Для системного перевода требуется macOS 14.4 или новее.",
            "系統翻譯功能需要 macOS 14.4 或更新版本。",
            "تتطلب ترجمة النظام macOS 14.4 أو أحدث."
        ],
        .missingBookFile: [
            "找不到《%@》的原文件。文件可能已被移动或删除，请重新导入。",
            "The original file for “%@” was not found. It may have been moved or deleted; please import it again.",
            "『%@』の元ファイルが見つかりません。移動または削除された可能性があります。再度読み込んでください。",
            "No se encontró el archivo original de «%@». Puede haberse movido o eliminado; impórtalo de nuevo.",
            "Le fichier d’origine de « %@ » est introuvable. Il a peut-être été déplacé ou supprimé ; importez-le à nouveau.",
            "Die Originaldatei von „%@“ wurde nicht gefunden. Sie wurde möglicherweise verschoben oder gelöscht; bitte erneut importieren.",
            "Исходный файл «%@» не найден. Возможно, он перемещён или удалён; импортируйте его снова.",
            "找不到《%@》的原始檔案。檔案可能已被移動或刪除，請重新匯入。",
            "لم يتم العثور على الملف الأصلي لـ «%@». ربما تم نقله أو حذفه؛ يرجى استيراده مجددًا."
        ],
        .missingLibraryBook: [
            "这本书已不在“我的图书”中，请重新导入。",
            "This book is no longer in My Books. Please import it again.",
            "この本はマイブックにありません。再度読み込んでください。",
            "Este libro ya no está en Mis libros. Impórtalo de nuevo.",
            "Ce livre n’est plus dans Mes livres. Importez-le à nouveau.",
            "Dieses Buch ist nicht mehr in „Meine Bücher“. Bitte erneut importieren.",
            "Этой книги больше нет в «Моих книгах». Импортируйте её снова.",
            "這本書已不在「我的圖書」中，請重新匯入。",
            "لم يعد هذا الكتاب موجودًا في كتبي. يرجى استيراده مجددًا."
        ],
        .unavailableVoice: [
            "该音色已不可用，请刷新音色列表。",
            "This voice is unavailable. Refresh the voice list.",
            "この音声は利用できません。音声一覧を更新してください。",
            "Esta voz no está disponible. Actualiza la lista.",
            "Cette voix est indisponible. Actualisez la liste.",
            "Diese Stimme ist nicht verfügbar. Aktualisieren Sie die Liste.",
            "Этот голос недоступен. Обновите список.",
            "該音色已無法使用，請重新整理音色列表。",
            "هذا الصوت غير متاح. حدّث قائمة الأصوات."
        ],
        .personalVoiceNeedsAccess: [
            "使用个人声音前，请在首页打开“录制／使用个人声音”，并允许声页访问。",
            "Before using Personal Voice, open its guide from Home and allow VoicePage access.",
            "パーソナルボイスを使う前に、ホームからガイドを開き、声页のアクセスを許可してください。",
            "Antes de usar Voz personal, abre la guía desde Inicio y permite el acceso.",
            "Avant d’utiliser la Voix personnelle, ouvrez son guide depuis l’accueil et autorisez l’accès.",
            "Öffnen Sie vor der Nutzung der Eigenen Stimme die Anleitung auf der Startseite und erlauben Sie den Zugriff.",
            "Перед использованием личного голоса откройте руководство на главной странице и разрешите доступ.",
            "使用個人聲音前，請在首頁開啟相關指南，並允許聲頁存取。",
            "قبل استخدام الصوت الشخصي افتح دليله من الرئيسية واسمح لـ VoicePage بالوصول."
        ],
        .personalVoicePermissionOff: [
            "个人声音权限未开启。请在系统设置中允许声页使用个人声音。",
            "Personal Voice permission is off. Allow VoicePage in System Settings.",
            "パーソナルボイスの許可がオフです。システム設定で声页を許可してください。",
            "El permiso de Voz personal está desactivado. Permite VoicePage en Ajustes.",
            "L’autorisation de Voix personnelle est désactivée. Autorisez VoicePage dans Réglages.",
            "Die Berechtigung für Eigene Stimme ist deaktiviert. Erlauben Sie VoicePage in den Systemeinstellungen.",
            "Разрешение на личный голос отключено. Разрешите VoicePage в настройках системы.",
            "個人聲音權限未開啟。請在系統設定中允許聲頁使用個人聲音。",
            "إذن الصوت الشخصي معطل. اسمح لـ VoicePage من إعدادات النظام."
        ],
        .personalVoiceUnsupported: [
            "这台 Mac 或当前系统不支持个人声音。",
            "This Mac or system does not support Personal Voice.",
            "このMacまたはシステムはパーソナルボイスに対応していません。",
            "Este Mac o sistema no admite Voz personal.",
            "Ce Mac ou ce système ne prend pas en charge la Voix personnelle.",
            "Dieser Mac oder das System unterstützt Eigene Stimme nicht.",
            "Этот Mac или система не поддерживает личный голос.",
            "這台 Mac 或目前系統不支援個人聲音。",
            "هذا الـ Mac أو النظام لا يدعم الصوت الشخصي."
        ],
        .personalVoiceUnavailable: [
            "个人声音当前不可用，请检查系统设置后重试。",
            "Personal Voice is currently unavailable. Check System Settings and try again.",
            "パーソナルボイスは現在利用できません。システム設定を確認して再試行してください。",
            "Voz personal no está disponible. Revisa Ajustes e inténtalo de nuevo.",
            "La Voix personnelle est indisponible. Vérifiez Réglages puis réessayez.",
            "Eigene Stimme ist derzeit nicht verfügbar. Prüfen Sie die Systemeinstellungen.",
            "Личный голос сейчас недоступен. Проверьте настройки системы.",
            "個人聲音目前無法使用，請檢查系統設定後重試。",
            "الصوت الشخصي غير متاح حاليًا. تحقق من إعدادات النظام وحاول مجددًا."
        ],
        .selectedPersonalVoiceMissing: [
            "没有找到所选个人声音。请确认声音已生成完成，然后刷新音色。",
            "The selected Personal Voice was not found. Make sure it finished generating, then refresh.",
            "選択したパーソナルボイスが見つかりません。生成完了を確認して更新してください。",
            "No se encontró la Voz personal. Confirma que terminó de generarse y actualiza.",
            "La Voix personnelle sélectionnée est introuvable. Vérifiez sa génération puis actualisez.",
            "Die gewählte Eigene Stimme wurde nicht gefunden. Prüfen Sie die Erstellung und aktualisieren Sie.",
            "Выбранный личный голос не найден. Дождитесь его создания и обновите список.",
            "找不到所選個人聲音。請確認聲音已生成完成，然後重新整理音色。",
            "لم يتم العثور على الصوت الشخصي المحدد. تأكد من اكتمال إنشائه ثم حدّث."
        ],
        .unsupportedFormat: [
            "暂不支持这种文件格式。请选择 EPUB 或 TXT 文件。",
            "This file format is not supported. Choose an EPUB or TXT file.",
            "このファイル形式には対応していません。EPUBまたはTXTを選んでください。",
            "Este formato no es compatible. Elige un archivo EPUB o TXT.",
            "Ce format n’est pas pris en charge. Choisissez un fichier EPUB ou TXT.",
            "Dieses Dateiformat wird nicht unterstützt. Wählen Sie EPUB oder TXT.",
            "Этот формат не поддерживается. Выберите EPUB или TXT.",
            "暫不支援這種檔案格式。請選擇 EPUB 或 TXT 檔案。",
            "تنسيق الملف غير مدعوم. اختر ملف EPUB أو TXT."
        ],
        .unknownEncoding: [
            "无法识别文本编码。建议将文件保存为 UTF-8 后重试。",
            "The text encoding could not be recognized. Save the file as UTF-8 and try again.",
            "文字エンコーディングを認識できません。UTF-8で保存して再試行してください。",
            "No se reconoce la codificación. Guarda el archivo como UTF-8 e inténtalo de nuevo.",
            "L’encodage est inconnu. Enregistrez le fichier en UTF-8 puis réessayez.",
            "Die Textkodierung wurde nicht erkannt. Speichern Sie als UTF-8 und versuchen Sie es erneut.",
            "Кодировка текста не распознана. Сохраните файл в UTF-8 и повторите.",
            "無法識別文字編碼。建議將檔案儲存為 UTF-8 後重試。",
            "تعذر التعرف على ترميز النص. احفظ الملف بصيغة UTF-8 وحاول مجددًا."
        ],
        .invalidEPUB: [
            "EPUB 文件结构不完整，无法找到书籍正文。",
            "The EPUB structure is incomplete and its text could not be found.",
            "EPUBの構造が不完全で、本文を見つけられません。",
            "La estructura EPUB está incompleta y no se encontró el texto.",
            "La structure EPUB est incomplète et le texte est introuvable.",
            "Die EPUB-Struktur ist unvollständig; der Text wurde nicht gefunden.",
            "Структура EPUB неполна, текст книги не найден.",
            "EPUB 檔案結構不完整，無法找到圖書正文。",
            "بنية EPUB غير مكتملة ولم يتم العثور على نص الكتاب."
        ],
        .noTextInFile: [
            "文件中没有找到可朗读的文字。",
            "No readable text was found in the file.",
            "ファイルに読み上げ可能なテキストがありません。",
            "No se encontró texto legible en el archivo.",
            "Aucun texte lisible n’a été trouvé dans le fichier.",
            "In der Datei wurde kein lesbarer Text gefunden.",
            "В файле не найден текст для чтения.",
            "檔案中沒有找到可朗讀的文字。",
            "لم يتم العثور على نص قابل للقراءة في الملف."
        ],
        .unzipFailed: [
            "无法解压 EPUB 文件。%@", "The EPUB could not be extracted. %@",
            "EPUBを展開できません。%@", "No se pudo extraer el EPUB. %@",
            "Impossible d’extraire l’EPUB. %@", "Die EPUB-Datei konnte nicht entpackt werden. %@",
            "Не удалось распаковать EPUB. %@", "無法解壓縮 EPUB 檔案。%@",
            "تعذر فك ضغط EPUB. %@"
        ]
    ]
}
