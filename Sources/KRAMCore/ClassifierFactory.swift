import Foundation

public enum ClassifierFactory {
    private static var didWarn = false

    public static func makeDefault() -> FileClassifier {
        let smart = LayaClassifier()
        guard smart.isUsable else {
            if !didWarn {
                fputs("\(ANSI.yellow)⚠ Local ML classifier unavailable; using extension classification.\(ANSI.reset)\n", stderr)
                didWarn = true
            }
            return ExtensionClassifier()
        }
        return smart
    }
}
