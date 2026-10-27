cask "matcha" do
  version "1.5.1"
  sha256 "876fe65675524c1680f5a9d59d2455f4e6bbef342db83c1d9dfd454131b0fd95"

  url "https://github.com/jakeantelis/Matcha/releases/download/v#{version}/Matcha.zip"
  name "Matcha"
  desc "Keep awake for builds, exports, and AI coding agents"
  homepage "https://github.com/jakeantelis/Matcha"

  depends_on :macos

  app "Matcha.app"

  zap trash: [
    "~/Library/Application Support/Matcha",
    "~/Library/Preferences/com.matcha.app.plist",
  ]
end
