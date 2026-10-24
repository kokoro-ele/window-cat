import Foundation

public enum AppLanguage: String, CaseIterable {
    case english = "en", japanese = "ja", chinese = "zh-Hans"
    public var label: String {
        switch self { case .english: return "English"; case .japanese: return "日本語"; case .chinese: return "简体中文" }
    }
    public static func preferred(from languages: [String]) -> Self {
        for code in languages {
            if code.hasPrefix("ja") { return .japanese }
            if code.hasPrefix("zh") { return .chinese }
            if code.hasPrefix("en") { return .english }
        }
        return .english
    }
}

public enum TextKey: String, CaseIterable {
    case appName, tagline, dragHint, catalog, assigned, noCats, chooseCat, placed, dropReady, noWindow
    case permissionDetail, permissionEnable, permissionNeeded, demo, demoTitle, demoBody
    case language, sidebar, quit, remove, allHome, controls, roam, ball, wand, nap, pause, resume
    case autoNaps, speed, slow, normal, fast, hidden, sleeping, findingNap, walking, looking, playingBall, playingWand
    case cat1, cat2, cat3, cat4, cat5, cat6, credits, pinned, dragCancelled, paused, limit
}

public enum LocalizationCatalog {
    // Centralized copy makes live switching independent of process-wide AppleLanguages.
    public static let entries: [TextKey: [String]] = [
        .appName: ["windowcat", "windowcat", "windowcat"],
        .tagline: ["A little company for your windows.", "いつもの窓に、小さな相棒。", "给你的窗口，添一只猫。"],
        .dragHint: ["Drag this menu bar cat onto a window", "メニューバーの猫をウインドウへドラッグ", "按住菜单栏小猫，拖到窗口上"],
        .catalog: ["CHOOSE A CAT", "猫を選ぶ", "选择一只猫"],
        .assigned: ["WINDOW COMPANIONS", "窓の仲間たち", "窗口里的猫"],
        .noCats: ["No cats placed yet", "まだ猫はいません", "还没有放置小猫"],
        .chooseCat: ["Select a companion below", "下から猫を選んでください", "在下方选择要互动的猫"],
        .placed: ["A new home. Meow!", "新しいおうちだにゃ。", "找到新家了，喵！"],
        .dropReady: ["Release to place", "放すとここに住みます", "松手，把猫放在这里"],
        .noWindow: ["Drop onto a visible window", "見えているウインドウに放してください", "请拖到一个可见窗口上"],
        .permissionDetail: ["Enable Accessibility to place cats on other apps. You can try the demo first.", "ほかのアプリに置くにはアクセシビリティの許可が必要です。まずはデモで遊べます。", "开启辅助功能后，可放到其他应用。也可以先在试玩窗口体验。"],
        .permissionEnable: ["Improve tracking (optional)…", "追従を改善（任意）…", "增强窗口跟踪（可选）…"],
        .permissionNeeded: ["Enable window access, then drag again", "アクセスを許可して、もう一度ドラッグ", "请开启窗口访问后再拖一次"],
        .demo: ["Open a demo window", "デモウインドウを開く", "打开试玩窗口"],
        .demoTitle: ["A home for your cat", "猫のおうち", "给小猫一个家"],
        .demoBody: ["Drag a cat here from the sidebar.\nMove or resize this window — your cat stays with it.\nYou can place another cat on another window.", "サイドバーから猫をここへドラッグ。\nウインドウを動かしても、猫はここにいます。\n別のウインドウにも猫を置けます。", "从侧栏把猫拖到这里。\n移动或缩放窗口，小猫会跟着它。\n还可以给其他窗口各放一只猫。"],
        .language: ["Language", "言語", "语言"],
        .sidebar: ["Show cat sidebar", "猫のサイドバーを表示", "显示猫咪侧栏"],
        .quit: ["Quit windowcat", "windowcat を終了", "退出 windowcat"],
        .remove: ["Send this cat home", "この猫をおうちに戻す", "收回这只猫"],
        .allHome: ["Send all cats home", "すべての猫をおうちに戻す", "收回所有小猫"],
        .controls: ["PLAY TOGETHER", "いっしょに遊ぶ", "陪它玩一会儿"],
        .roam: ["Walk", "おさんぽ", "散步"],
        .ball: ["Ball", "ボール", "小球"],
        .wand: ["Teaser", "猫じゃらし", "逗猫棒"],
        .nap: ["Nap", "おひるね", "打盹"],
        .pause: ["Pause all cats", "すべての猫を一時停止", "暂停所有小猫"],
        .resume: ["Resume", "再開", "继续陪伴"],
        .autoNaps: ["Automatic naps", "自動でおひるね", "允许自动打盹"],
        .speed: ["Walking speed", "歩く速さ", "散步速度"],
        .slow: ["Slow", "ゆっくり", "慢悠悠"],
        .normal: ["Normal", "ふつう", "刚刚好"],
        .fast: ["Quick", "はやめ", "小跑起来"],
        .hidden: ["Waiting for its window", "ウインドウを待っています", "等它的窗口回来"],
        .sleeping: ["Shh… sleeping", "すやすや、おひるね中", "嘘，小猫睡着了…"],
        .findingNap: ["Finding a cozy spot", "寝心地のいい場所を探しています", "找个舒服的位置打盹"],
        .walking: ["Exploring the window", "窓のまわりをおさんぽ中", "沿着窗边散步中"],
        .looking: ["Watching the world go by", "のんびり景色を眺めています", "看看风景，甩甩尾巴"],
        .playingBall: ["Chasing a little ball", "ボールを追いかけています", "追上小球，再拨一下"],
        .playingWand: ["Move your mouse to play", "マウスを動かして遊ぼう", "移动鼠标，带着小猫跑"],
        .cat1: ["White cat", "しろねこ", "小白猫"],
        .cat2: ["Shadow", "くろ", "小黑"],
        .cat3: ["Mochi", "もち", "麻薯"],
        .cat4: ["Peach", "もも", "桃子"],
        .cat5: ["Snow", "ゆき", "小雪"],
        .cat6: ["Sesame", "ごま", "芝麻"],
        .credits: ["Cat art: Elthen", "猫の素材：Elthen", "猫咪素材：Elthen"],
        .pinned: ["Stays with this window", "このウインドウに住んでいます", "固定住在这个窗口"],
        .dragCancelled: ["Drag cancelled", "ドラッグをキャンセルしました", "已取消拖放"],
        .paused: ["Cats are paused", "猫たちはおやすみ中", "小猫已暂停"],
        .limit: ["Up to 12 window companions", "猫は12匹まで置けます", "最多可在 12 个窗口放猫"]
    ]

    public static func text(_ key: TextKey, language: AppLanguage) -> String {
        let index: Int
        switch language { case .english: index = 0; case .japanese: index = 1; case .chinese: index = 2 }
        return entries[key]![index]
    }
}
