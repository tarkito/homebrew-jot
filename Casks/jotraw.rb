cask "jotraw" do
  version "1.0.7"
  sha256  "fbe6e05c8f2d93120024ea3ba6015ce5ebc66510ba199d944e684bc1dfc8aa68"

  # TODO: replace with the real release URL once published.
  # The artifact should be a notarized, code-signed zip containing JotSync.app
  # and the jotraw binary at the top level:
  #   jotraw-<version>-macos.zip
  #     ├── JotSync.app/
  #     └── jotraw
  url "https://github.com/tarkito/homebrew-jot/releases/download/v#{version}/jotraw-#{version}-macos.zip"
  name "jotraw"
  desc "Command-line companion and iCloud sync agent for the JotRaw iOS app"
  homepage "https://github.com/tarkito/Jot"

  depends_on macos: :sequoia

  app "JotSync.app"
  binary "jotraw"

  # Install the launchd plist into the user's LaunchAgents and bootstrap it
  # immediately so iCloud sync starts working without a logout/login cycle.
  postflight do
    plist_src = "#{staged_path}/eu.helfin.jotsync.plist"
    plist_dst = "#{Dir.home}/Library/LaunchAgents/eu.helfin.jotsync.plist"
    service   = "gui/#{Process.uid}/eu.helfin.jotsync"
    domain    = "gui/#{Process.uid}"

    FileUtils.mkdir_p(File.dirname(plist_dst))
    FileUtils.cp(plist_src, plist_dst)

    system_command "/bin/launchctl",
                   args:         ["bootout", service],
                   must_succeed: false,
                   print_stderr: false,
                   print_stdout: false
    system_command "/bin/launchctl",
                   args:         ["bootstrap", domain, plist_dst],
                   must_succeed: true
  end

  uninstall_preflight do
    service = "gui/#{Process.uid}/eu.helfin.jotsync"

    system_command "/bin/launchctl",
                   args:         ["bootout", service],
                   must_succeed: false,
                   print_stderr: false,
                   print_stdout: false
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
