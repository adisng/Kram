import Foundation
import Darwin

public enum KeyPress {
    case up, down, left, right
    case enter, escape, tab, quit, slash
    case backspace
    case character(Character)
    case unknown
}

public final class Terminal {

    public static func enableRawMode() -> termios {
        var raw = termios()
        guard isatty(STDIN_FILENO) != 0 else { return raw }
        tcgetattr(STDIN_FILENO, &raw)
        var newSettings = raw
        newSettings.c_lflag &= ~tcflag_t(ICANON | ECHO)
        
        withUnsafeMutableBytes(of: &newSettings.c_cc) { ptr in
            ptr[Int(VMIN)] = 1
            ptr[Int(VTIME)] = 0
        }
        
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &newSettings)
        return raw
    }

    public static func restoreMode(_ original: termios) {
        guard isatty(STDIN_FILENO) != 0 else { return }
        var t = original
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &t)
    }

    public static func readKey() -> KeyPress {
        var buffer = [UInt8](repeating: 0, count: 8)
        let n = read(STDIN_FILENO, &buffer, 8)
        guard n > 0 else { return .unknown }

        if n == 1 {
            switch buffer[0] {
            case 10, 13:    return .enter
            case 27:        return .escape
            case 9:         return .tab
            case 127, 8:    return .backspace
            case 113:       return .quit        // q
            case 106:       return .down        // j
            case 107:       return .up          // k
            case 104:       return .left        // h
            case 108:       return .right       // l
            case 47:        return .slash       // /
            default:
                let scalar = UnicodeScalar(buffer[0])
                if scalar.isASCII {
                    return .character(Character(scalar))
                }
                return .unknown
            }
        } else if n == 3 && buffer[0] == 27 && buffer[1] == 91 {
            switch buffer[2] {
            case 65: return .up
            case 66: return .down
            case 67: return .right
            case 68: return .left
            default: return .unknown
            }
        }
        return .unknown
    }

    public static func clearScreen() { print("\u{001B}[2J\u{001B}[H", terminator: "") }
    public static func clearLine()   { print("\u{001B}[2K\u{001B}[G", terminator: "") }
    public static func hideCursor()  { print("\u{001B}[?25l", terminator: "") }
    public static func showCursor()  { print("\u{001B}[?25h", terminator: "") }
    public static func moveTo(row: Int, col: Int) { print("\u{001B}[\(row);\(col)H", terminator: "") }
}
