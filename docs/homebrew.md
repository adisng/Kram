# Homebrew tap

This repository does not create or manage the `adisng/homebrew-tap` repository. After a KRAM GitHub release exists, add a formula there using the release tarball URL and its published SHA-256 checksum.

## Formula template

Create `Formula/kram.rb` in `adisng/homebrew-tap`:

```ruby
class Kram < Formula
  desc "Fast, zero-dependency macOS file organizer in Swift"
  homepage "https://github.com/adisng/Kram"
  version "2.0.0"
  url "https://github.com/adisng/Kram/releases/download/v#{version}/kram-v#{version}-macos-universal.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_SHA256"

  def install
    bin.install "kram"
    bin.install_symlink "kram" => "kr"
  end

  test do
    assert_match "kram #{version}", shell_output("#{bin}/kram --version")
  end
end
```

## Tap creation steps

1. Create a public GitHub repository named `homebrew-tap` under `adisng`.
2. Add the formula at `Formula/kram.rb`.
3. Replace the placeholder SHA-256 with the value from the release `.sha256` file.
4. Commit and push the formula.
5. Test with:

```bash
brew tap adisng/tap
brew install adisng/tap/kram
kr --version
```
