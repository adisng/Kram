import Foundation

/// Generates shell completion scripts for KRAM.
public final class Completion {

    /// Returns the completion script text for the given shell.
    /// Supported values: "zsh", "bash", "fish".
    public static func generate(shell: String) -> String {
        switch shell.lowercased() {
        case "bash":
            return generateBash()
        case "fish":
            return generateFish()
        default:
            return generateZsh()
        }
    }

    // MARK: - Zsh

    private static func generateZsh() -> String {
        return """
        #compdef kr kram
        # KRAM shell completion for zsh
        # Install: eval "$(kr completion zsh)" in your .zshrc

        _kr() {
            local -a commands flags
            commands=(
                'dl:Organize ~/Downloads'
                'desk:Organize ~/Desktop'
                'docs:Organize ~/Documents'
                'here:Organize current directory'
                'undo:Reverse the last organize'
                'last:Show the last transaction'
                'stats:Show lifetime stats'
                'help:Show help'
                'version:Show version'
                'watch:Watch a directory for changes'
                'completion:Generate shell completion script'
            )
            flags=(
                '--apply[Apply changes]'
                '--recursive[Include subdirectories]'
                '--undo[Undo last transaction]'
                '--verbose[Show skipped files]'
                '--dry-run[Preview only, no changes]'
                '--yes[Skip confirmation prompt]'
                '--help[Show help]'
                '--version[Show version]'
            )

            if (( CURRENT == 2 )); then
                _alternative \\
                    'commands:command:compadd -a commands' \\
                    'flags:flag:compadd -a flags' \\
                    'files:directory:_files -/'
            else
                _alternative \\
                    'flags:flag:compadd -a flags' \\
                    'files:directory:_files -/'
            fi
        }

        compdef _kr kr kram
        """
    }

    // MARK: - Bash

    private static func generateBash() -> String {
        return """
        # KRAM shell completion for bash
        # Install: eval "$(kr completion bash)" in your .bash_profile

        _kr_completions() {
            local cur commands flags
            cur="${COMP_WORDS[COMP_CWORD]}"
            commands="dl desk docs here undo last stats help version watch completion"
            flags="--apply --recursive --undo --verbose --dry-run --yes --help --version"

            if [[ ${COMP_CWORD} -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "${commands} ${flags}" -- "${cur}") )
                COMPREPLY+=( $(compgen -d -- "${cur}") )
            else
                COMPREPLY=( $(compgen -W "${flags}" -- "${cur}") )
                COMPREPLY+=( $(compgen -d -- "${cur}") )
            fi
        }

        complete -F _kr_completions kr kram
        """
    }

    // MARK: - Fish

    private static func generateFish() -> String {
        return """
        # KRAM shell completion for fish
        # Install: kr completion fish | source
        # Or: kr completion fish > ~/.config/fish/completions/kr.fish

        # Disable file completion by default, re-enable for path arguments
        complete -c kr -f
        complete -c kram -f

        # Commands
        complete -c kr -n '__fish_use_subcommand' -a 'dl' -d 'Organize ~/Downloads'
        complete -c kr -n '__fish_use_subcommand' -a 'desk' -d 'Organize ~/Desktop'
        complete -c kr -n '__fish_use_subcommand' -a 'docs' -d 'Organize ~/Documents'
        complete -c kr -n '__fish_use_subcommand' -a 'here' -d 'Organize current directory'
        complete -c kr -n '__fish_use_subcommand' -a 'undo' -d 'Reverse the last organize'
        complete -c kr -n '__fish_use_subcommand' -a 'last' -d 'Show the last transaction'
        complete -c kr -n '__fish_use_subcommand' -a 'stats' -d 'Show lifetime stats'
        complete -c kr -n '__fish_use_subcommand' -a 'help' -d 'Show help'
        complete -c kr -n '__fish_use_subcommand' -a 'version' -d 'Show version'
        complete -c kr -n '__fish_use_subcommand' -a 'watch' -d 'Watch a directory'
        complete -c kr -n '__fish_use_subcommand' -a 'completion' -d 'Generate completions'

        # Long flags
        complete -c kr -l apply -d 'Apply changes'
        complete -c kr -l recursive -d 'Include subdirectories'
        complete -c kr -l undo -d 'Undo last transaction'
        complete -c kr -l verbose -d 'Show skipped files'
        complete -c kr -l dry-run -d 'Preview only'
        complete -c kr -l yes -d 'Skip confirmation'
        complete -c kr -l help -d 'Show help'
        complete -c kr -l version -d 'Show version'

        # Allow directory completion for path arguments
        complete -c kr -n '__fish_use_subcommand' -F

        # Copy all completions for kram alias
        complete -c kram -w kr
        """
    }
}
