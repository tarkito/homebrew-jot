cask "jotraw" do
  version "1.0.0"
  sha256 : e22f636010e61f2412dc14586bc233c28fa09eda04ac908801398d3a88307908

  # TODO: replace with the real release URL once published.
  # The artifact should be a notarized, code-signed zip containing JotSync.app
  # and the jotraw binary at the top level:
  #   jotraw-<version>-macos.zip
  #     ├── JotSync.app/
  #     └── jotraw
  url "https://github.com/tarkito/Jot/releases/download/v#{version}/jotraw-#{version}-macos.zip"
  name "jotraw"
  desc "Command-line companion and iCloud sync agent for the JotRaw iOS app"
  homepage "https://github.com/tarkito/Jot"

  depends_on macos: ">= :sequoia"

  app "JotSync.app"
  binary "jotraw"

  # Install the launchd plist into the user's LaunchAgents and bootstrap it
  # immediately so iCloud sync starts working without a logout/login cycle.
  postflight do
    plist_src = "#{staged_path}/eu.helfin.jotsync.plist"
    plist_dst = "#{Dir.home}/Library/LaunchAgents/eu.helfin.jotsync.plist"

    FileUtils.mkdir_p(File.dirname(plist_dst))
    FileUtils.cp(plist_src, plist_dst)

    system "/bin/launchctl", "bootout", "gui/#{Process.uid}/eu.helfin.jotsync"
    system "/bin/launchctl", "bootstrap", "gui/#{Process.uid}", plist_dst
  end

  uninstall_preflight do
    system "/bin/launchctl", "bootout", "gui/#{Process.uid}/eu.helfin.jotsync"
    FileUtils.rm_f("#{Dir.home}/Library/LaunchAgents/eu.helfin.jotsync.plist")
  end

  zap trash: [
    "~/Library/Group Containers/group.eu.helfin.Jot",
    "~/Library/Containers/eu.helfin.JotSync",
    "~/Library/LaunchAgents/eu.helfin.jotsync.plist",
    "/tmp/jotsync.out.log",
    "/tmp/jotsync.err.log",
  ]
end
