cask "matcha" do
  version "1.5.8"
  sha256 "bf052897282717fcd11e037a82eaec5e60816bd48bb0e1141959d27c91d92df9"

  url "https://github.com/jakeantelis/Matcha/releases/download/v#{version}/Matcha.zip"
  name "Matcha"
  desc "Keep awake for builds, exports, and AI coding agents"
  homepage "https://github.com/jakeantelis/Matcha"

  depends_on :macos

  auto_updates true

  app "Matcha.app"

  zap trash: [
    "~/Library/Application Support/Matcha",
    "~/Library/Preferences/com.matcha.app.plist",
  ]
end
