import Foundation
import Darwin

public enum KeyPress: Equatable {
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
        var firstByte: UInt8 = 0
        let n = read(STDIN_FILENO, &firstByte, 1)
        guard n > 0 else { return .unknown }

        if firstByte == 27 { // ESC
            // When an arrow key or other ANSI escape sequence is pressed, terminals send ESC
            // followed by '[' and a direction code ('A'..'D'). Under latency (e.g. SSH, tmux,
            // or slower terminal emulators), these bytes can arrive across separate read() calls.
            // With VMIN=1 and VTIME=0, a single read() returns immediately upon receiving ESC (27),
            // which would erroneously be treated as a standalone Escape press, exiting the picker.
            //
            // To be escape-sequence-safe, we perform a lookahead: temporarily configure termios
            // with VTIME=1 (100ms timeout) and VMIN=0 (non-blocking if no bytes arrive). If '['
            // followed by an arrow direction byte arrives within the timeout window, we return
            // the corresponding arrow KeyPress. If no additional bytes arrive within the timeout,
            // it is treated as a genuine KeyPress.escape.
            let isTTY = isatty(STDIN_FILENO) != 0
            var raw = termios()
            if isTTY {
                tcgetattr(STDIN_FILENO, &raw)
                var lookaheadTerm = raw
                withUnsafeMutableBytes(of: &lookaheadTerm.c_cc) { ptr in
                    ptr[Int(VMIN)] = 0
                    ptr[Int(VTIME)] = 1 // 100ms timeout
                }
                tcsetattr(STDIN_FILENO, TCSANOW, &lookaheadTerm)
            }
            defer {
                if isTTY {
                    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
                }
            }

            var seq = [UInt8](repeating: 0, count: 2)
            var bytesRead = 0
            while bytesRead < 2 {
                if !isTTY {
                    var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
                    let ready = poll(&pfd, 1, 100)
                    if ready <= 0 { break }
                }
                var b: UInt8 = 0
                let r = read(STDIN_FILENO, &b, 1)
                if r == 1 {
                    seq[bytesRead] = b
                    bytesRead += 1
                } else {
                    break
                }
            }

            if bytesRead == 2 && seq[0] == 91 { // 91 is '[' (0x5B)
                switch seq[1] {
                case 65: return .up    // 'A'
                case 66: return .down  // 'B'
                case 67: return .right // 'C'
                case 68: return .left  // 'D'
                default: return .unknown
                }
            } else if bytesRead == 0 {
                return .escape
            } else {
                return .unknown
            }
        }

        switch firstByte {
        case 10, 13:    return .enter
        case 9:         return .tab
        case 127, 8:    return .backspace
        case 113:       return .quit        // q
        case 106:       return .down        // j
        case 107:       return .up          // k
        case 104:       return .left        // h
        case 108:       return .right       // l
        case 47:        return .slash       // /
        default:
            let scalar = UnicodeScalar(firstByte)
            if scalar.isASCII {
                return .character(Character(scalar))
            }
            return .unknown
        }
    }

    public static func clearScreen() { print("\u{001B}[2J\u{001B}[H", terminator: "") }
    public static func clearLine()   { print("\u{001B}[2K\u{001B}[G", terminator: "") }
    public static func clearToEndOfLine() { print("\u{001B}[K", terminator: "") }
    public static func hideCursor()  { print("\u{001B}[?25l", terminator: "") }
    public static func showCursor()  { print("\u{001B}[?25h", terminator: "") }
    public static func moveTo(row: Int, col: Int) { print("\u{001B}[\(row);\(col)H", terminator: "") }
}
