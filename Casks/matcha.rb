cask "matcha" do
  version "1.5.2"
  sha256 "0c79d08ff7b551383f5e23e7c4a07c367ba47b34228ccd278233d8548c989fff"

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
