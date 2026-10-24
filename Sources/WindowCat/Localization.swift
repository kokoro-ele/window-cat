import AppKit
import CatCore

enum L10n {
    static var language: AppLanguage = {
        if let index = CommandLine.arguments.firstIndex(of: "--language"), CommandLine.arguments.count > index + 1,
           let language = AppLanguage(rawValue: CommandLine.arguments[index + 1]) { return language }
        if let saved = UserDefaults.standard.string(forKey: "interfaceLanguage"), let language = AppLanguage(rawValue: saved) { return language }
        return .preferred(from: Locale.preferredLanguages)
    }()
    static func set(_ language: AppLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: "interfaceLanguage")
    }
    static func catName(_ skin: Int) -> String { text(.cat1) }
    static func text(_ key: TextKey) -> String { LocalizationCatalog.text(key, language: language) }
    static func status(_ world: CatWorld) -> String {
        switch world.mode {
        case .roam: return text(world.action == .idle ? .looking : .walking)
        case .nap: return text(world.action == .sleeping ? .sleeping : .findingNap)
        case .ball: return text(.playingBall)
        case .wand: return text(.playingWand)
        }
    }
}

func tr(_ key: TextKey) -> String { L10n.text(key) }
