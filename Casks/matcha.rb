cask "matcha" do
  version "1.5.5"
  sha256 "fac93357fec201f743c53f2ccba38d6614889cc1c2437f8a6f0a7c955d20e729"

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
