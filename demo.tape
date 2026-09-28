Output /tmp/kram-demo.gif
Set Shell zsh
Set TypingSpeed 0
Set FontSize 14
Set Width 1000
Set Height 600
Type "demo=$(mktemp -d); touch \"$demo/invoice.pdf\" \"$demo/config.json\" \"$demo/app.dmg\""
Enter
Type "kr \"$demo\" --dry-run"
Enter
Sleep 2s
Type "kr \"$demo\" --yes"
Enter
Sleep 2s
Type "kr undo"
Enter
Sleep 2s
