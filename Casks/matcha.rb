cask "matcha" do
  version "1.5.4"
  sha256 "2222ba9fa7023b61e4ac9248424edef68a79d22a2e77400eeda63caf3bd329f9"

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
