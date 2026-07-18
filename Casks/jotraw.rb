cask "jotraw" do
  version "1.1.0"
  sha256  "0bf76a2bcb4080be2811b83c725d49000753e490e1421504aef601d156639d2b"

  # The artifact should be a notarized, code-signed zip containing JotSync.app
  # and the jotraw binary at the top level:
  #   jotraw-<version>-macos.zip
  #     ├── JotSync.app/
  #     └── jotraw
  url "https://github.com/evorio-io/homebrew-jotraw/releases/download/v#{version}/jotraw-#{version}-macos.zip"
  name "jotraw"
  desc "Command-line companion and iCloud sync agent for the JotRaw iOS app"
  homepage "https://github.com/evorio-io/jotraw"

  depends_on macos: :sequoia

  app "JotSync.app"
  binary "jotraw"

  # Install the launchd plist into the user's LaunchAgents and bootstrap it
  # immediately so iCloud sync starts working without a logout/login cycle.
  #
  # This block runs on both fresh install and `brew upgrade`. On upgrade the
  # old JotSync.app is already running, and simply booting/bootstrapping the
  # launchd job is NOT enough to pick up the new binary:
  #
  #   * The launchd job tracks the `open -W -a JotSync.app` process, not the
  #     app itself — LaunchServices spawns JotSync in its own session, so
  #     `bootout` kills `open` but leaves the old JotSync process alive.
  #   * `bootstrap` then re-runs `open -a JotSync.app`, but LaunchServices sees
  #     an instance already running and just re-attaches to it — the freshly
  #     installed binary never launches until the user logs out.
  #
  # So we explicitly terminate the running app (by its exact executable path,
  # to avoid matching the `open` wrapper) and wait for it to exit before
  # bootstrapping, guaranteeing the new version is the one that comes up.
  postflight do
    plist_src = "#{staged_path}/io.evorio.jotsync.plist"
    plist_dst = "#{Dir.home}/Library/LaunchAgents/io.evorio.jotsync.plist"
    service   = "gui/#{Process.uid}/io.evorio.jotsync"
    domain    = "gui/#{Process.uid}"
    exec_path = "/Applications/JotSync.app/Contents/MacOS/JotSync"

    FileUtils.mkdir_p(File.dirname(plist_dst))
    FileUtils.cp(plist_src, plist_dst)

    # Remove the launchd job first so KeepAlive can't respawn the old app
    # while we're terminating it.
    system_command "/bin/launchctl",
                   args:         ["bootout", service],
                   must_succeed: false,
                   print_stderr: false,
                   print_stdout: false

    # Same again for the pre-io.evorio agent. Upgrading from an eu.helfin
    # build leaves that job registered against the very same JotSync.app, so
    # its KeepAlive would respawn the app moments after the pkill below and
    # the two agents would then race to own the process on every login.
    # Worse, uninstall only knows the new label, so the stale agent would
    # outlive the cask and keep relaunching an app that is no longer there.
    # Boot it out and delete its plist before terminating anything.
    legacy_service = "gui/#{Process.uid}/eu.helfin.jotsync"
    legacy_plist   = "#{Dir.home}/Library/LaunchAgents/eu.helfin.jotsync.plist"

    system_command "/bin/launchctl",
                   args:         ["bootout", legacy_service],
                   must_succeed: false,
                   print_stderr: false,
                   print_stdout: false
    begin
      File.delete(legacy_plist)
    rescue Errno::ENOENT
      nil
    end

    # Ask the running (old) instance to quit, then wait up to ~10s for it to
    # actually exit so the new binary isn't racing a shutdown of the old one.
    system_command "/usr/bin/pkill",
                   args:         ["-f", exec_path],
                   must_succeed: false,
                   print_stderr: false,
                   print_stdout: false
    20.times do
      still_running = system_command "/usr/bin/pgrep",
                                     args:         ["-f", exec_path],
                                     must_succeed: false,
                                     print_stderr: false,
                                     print_stdout: false
      break unless still_running.success?

      sleep 0.5
    end

    system_command "/bin/launchctl",
                   args:         ["bootstrap", domain, plist_dst],
                   must_succeed: true
  end

  uninstall_preflight do
    service = "gui/#{Process.uid}/io.evorio.jotsync"

    system_command "/bin/launchctl",
                   args:         ["bootout", service],
                   must_succeed: false,
                   print_stderr: false,
                   print_stdout: false
    plist_dst = "#{Dir.home}/Library/LaunchAgents/io.evorio.jotsync.plist"
    begin
      File.delete(plist_dst)
    rescue Errno::ENOENT
      nil
    end
  end

  zap trash: [
    "/tmp/jotsync.err.log",
    "/tmp/jotsync.out.log",
    "~/Library/Containers/io.evorio.jotsync",
    "~/Library/Group Containers/group.io.evorio.jotraw",
    "~/Library/LaunchAgents/io.evorio.jotsync.plist",
    # Pre-io.evorio leftovers, so a zap after an upgrade-in-place is complete.
    "~/Library/Containers/eu.helfin.jotsync",
    "~/Library/Group Containers/group.eu.helfin.Jot",
    "~/Library/LaunchAgents/eu.helfin.jotsync.plist",
  ]
end
