import Foundation
import KRAMCore

public final class InteractiveMenu {

    public static func showMenu() -> KRAMArguments? {
        print("""
🐭 \(ANSI.bold)KRAM 1.5.0 — Keep. Rearrange. Automate. Manage.\(ANSI.reset)

Select an action:

  1.  📁  Organize        Sort files in a directory
  2.  👁   Preview         Dry-run without changes
  3.  ↩️   Undo            Reverse last operation
  4.  ⚙️   Config          View current settings
  5.  📊  Status          Show last transaction
  6.  ❓  Help            Show all commands

Choose [1-6] or q to quit: 
""", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
            return nil
        }

        var args = KRAMArguments()

        switch input.lowercased() {
        case "1":
            if let dir = DirectoryPicker.pickDirectory() {
                args.targetURL = dir
                args.apply = true
                return args
            }
            return nil
        case "2":
            if let dir = DirectoryPicker.pickDirectory() {
                args.targetURL = dir
                args.dryRun = true
                return args
            }
            return nil
        case "3":
            args.undo = true
            return args
        case "4":
            showConfig()
            return nil
        case "5":
            args.showLast = true
            return args
        case "6":
            args.showHelp = true
            return args
        case "q":
            return nil
        default:
            UI.printError("Invalid choice: \(input)")
            return nil
        }
    }

    private static func showConfig() {
        let config = ConfigurationManager().load()
        print("\n🐭 \(ANSI.bold)KRAM — Configuration\(ANSI.reset)")
        print(UI.divider)
        print("Version:              \(config.version)")
        print("Skip patterns:        \(config.skipPatterns.joined(separator: ", "))")
        print("Disabled categories:  \(config.disabledCategories.isEmpty ? "None" : config.disabledCategories.joined(separator: ", "))")
        print(UI.divider)
        print()
    }
}
