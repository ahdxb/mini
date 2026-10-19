#!/bin/bash
# START GUIDE
# Always-on Mac mini: setup, check, and replacement notes.
# Updated 2026-10-19.
# Download:  https://ahdxb.github.io/mini/mac-mini.sh
# Fallback:  https://gist.githubusercontent.com/ahdxb/7dc7377a171872ef677cedc8eff592bc/raw/mac-mini.sh
# Source:    https://github.com/ahdxb/Sonar (private; published to Pages and Gist)
# For a fresh, personally managed Mac mini. No Homebrew/Git prerequisite.
# After creating the admin account: download this file, then run setup.
# Setup installs dependencies and pauses for the manual steps below.
#
# USE
#   bash mac-mini.sh                Show this guide; change nothing.
#   bash mac-mini.sh setup          Ask for a name and confirmation, then configure.
#   bash mac-mini.sh setup-remote   Configure an already prepared Mini over SSH.
#   sudo bash mac-mini.sh check     Read settings and test local service ports.
#   sudo bash mac-mini.sh check --require-screen-sharing
#                                  Also require Screen Sharing to accept TCP.
#
# 1. UNBOX AND CREATE THE ADMINISTRATOR ACCOUNT (MANUAL)
#   Connect power, Ethernet, a display, keyboard and mouse. Keep these available
#   until the final reboot test. Start the Mac and follow Setup Assistant:
#   - Choose your language, country and keyboard layout; connect to the Internet.
#   - Set up as a new Mac; skip migration from another Mac or backup for this
#     clean rebuild. Do not import the old Mini's Tailscale identity.
#   - Create a local administrator with a strong, unique password. Record its
#     SHORT account name and password in your password manager. Use the same
#     short name on a replacement if you want saved SSH destinations to match.
#   - Apple Account/iCloud sign-in is optional for these services. Choose Set Up
#     Later for the minimum setup. Find My requires signing in if wanted later.
#   - Skip optional Siri/Apple Intelligence, Screen Time and analytics choices
#     as offered. They are not required. Leave other preferences at defaults.
#   - If offered FileVault, leave it off for this unattended-boot design; verify
#     its actual state in step 3 even if Setup Assistant never asked about it.
#   Finish at the desktop, signed into the administrator account. Screens and
#   wording vary by macOS version; none of the optional services above is needed.
#
# 2. DOWNLOAD THIS FILE AND START
#   Open Terminal (Applications > Utilities, or Spotlight) and download the
#   latest version from GitHub Pages (no GitHub sign-in needed):
#
#     curl -fsSLo ~/Downloads/mac-mini.sh \
#       https://ahdxb.github.io/mini/mac-mini.sh
#
#   Read its contents before running it (e.g. less ~/Downloads/mac-mini.sh).
#   No Git, GitHub CLI, personal access token or SSH deploy key is needed.
#   Then run:
#
#     /bin/bash ~/Downloads/mac-mini.sh setup
#
#   Do NOT prefix this command with sudo. Setup asks for your administrator
#   password only when needed. To read the whole guide without making changes:
#
#     /bin/bash ~/Downloads/mac-mini.sh
#
#   Setup checks that it is running locally on a Mini, asks for a name and your
#   confirmation, and guides you through steps 3–7. If an update needs a reboot,
#   or you need to stop, rerun the same command afterward. Completed installs are
#   reused. Settings outside this script's scope are not reset on a rerun.
#
# TERMINAL ACCESS OVER SSH (AFTER INITIAL PREPARATION)
#   First complete the administrator account and macOS preparation in steps 1/3,
#   enable native Remote Login for that account in step 5, and install Homebrew
#   and the Homebrew Tailscale system service in step 4. Enroll the Mini in the
#   intended tailnet. Remote setup requires that service to be running and
#   connected, Tailscale SSH off, incoming tailnet connections allowed, and
#   FileVault fully off. It does not bootstrap or migrate Tailscale remotely.
#   Screen Sharing is optional; no desktop login is needed for this workflow.
#
#   From your other computer's terminal, connected to the same tailnet:
#
#     ssh -t ACCOUNT@TAILSCALE_IP
#
#   Substitute the Mini's short account name and Tailscale IP. Verify its SSH
#   host fingerprint against your independently recorded value on first use.
#   A working MagicDNS name or reachable LAN IP can replace TAILSCALE_IP.
#   In the resulting shell ON THE MINI, download and inspect the script:
#
#     curl -fsSLo ~/mac-mini.sh \
#       https://ahdxb.github.io/mini/mac-mini.sh
#     less ~/mac-mini.sh
#     /bin/bash ~/mac-mini.sh setup-remote
#
#   Run setup-remote as the account user, without sudo. It requests sudo for
#   privileged operations, validates prerequisites, displays the current
#   identity, and asks you to type SETUP. It advertises exit-node service and
#   applies the power settings. It preserves the name, tailnet, SSH permissions,
#   DNS, subnet routes and other Tailscale preferences; it never restarts services,
#   reauthenticates, upgrades software, opens GUI apps or requests a reboot.
#   If a prerequisite fails, resolve it with local assistance before retrying.
#
#   Open the printed Tailscale admin URL on YOUR computer for step 6. Keep a
#   second SSH connection open and verify a NEW connection after setup. Working
#   access now cannot guarantee access after a network/power/OS failure.
#   Each run prints a private progress-log path in your home folder. If the
#   connection drops, reconnect and rerun the same command. It rechecks actual
#   settings and skips completed changes; it does not roll back completed work.
#   Do not run multiple setup sessions or edit Tailscale settings concurrently.
#
#   To check without changing configuration (also works over SSH):
#
#     sudo /bin/bash ~/mac-mini.sh check
#
#   Port 22 is required. Port 5900 is informational unless you explicitly run:
#
#     sudo /bin/bash ~/mac-mini.sh check --require-screen-sharing
#
# 3. PREPARE MACOS (SETUP PRINTS THIS CHECKLIST AND PAUSES)
#   Open System Settings. Use its search box if a setting has moved:
#   - General > Software Update: install current stable updates and restart now.
#     Finish any prompts and log back in before proceeding.
#   - General > Date & Time: set time automatically; confirm time/time zone.
#   - General > About > Name: choose a useful computer name, e.g. "Le Mac mini".
#     This is separate from the Tailscale network name requested in step 4.
#   - Privacy & Security > FileVault: OFF; wait for any decryption to finish.
#     This permits unattended cold boots but reduces protection against physical
#     access to stored data. Do not keep sensitive personal data on this server.
#   - Users & Groups: automatic login OFF and Guest User OFF. One administrator
#     is enough for this minimal setup; additional accounts are optional.
#   - Lock Screen: require a password immediately after sleep/screensaver.
#     Let the DISPLAY sleep. Step 4 disables sleep of the COMPUTER itself.
#   - Energy: if "Start up when power is connected" offers "Always", select it
#     for stronger power recovery. Otherwise use restart after power failure,
#     which step 4 also enables. See the Apple power reference below.
#   Keep Ethernet connected. DHCP is sufficient; a static LAN IP is not required.
#   Do not forward SSH/VNC ports on the router. Keep its inbound firewall enabled.
#
# 4. DEPENDENCIES AND CORE SETUP (AUTOMATED, WITH INSTALLER PROMPTS)
#   Enter a unique Tailscale name: "le-mac-mini" for France, a different name
#   for the second Mini. After you type SETUP, follow the prompts in Terminal.
#   Setup first prints step 3 and waits for you to finish those macOS settings.
#
#   If Homebrew is absent, setup downloads and runs its official installer from
#   https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh .
#   It runs as your admin account; the installer requests sudo when needed and
#   handles Command Line Tools installation. Complete any installer prompts.
#   If tool installation fails, run "xcode-select --install", finish its dialog,
#   then rerun setup. The full Xcode app is unnecessary. See https://brew.sh/ .
#   This script uses full tool paths; no shell/PATH customization is required.
#   Do NOT separately install the Tailscale App Store app or Homebrew cask.
#
#   When Tailscale displays a login URL, open it in Safari and sign in to the
#   SAME tailnet as your other devices. Complete device approval/Tailnet Lock
#   signing if your tailnet asks. If the command waits, finish that approval.
#
#   Setup installs Tailscale if missing, registers its ROOT boot service,
#   connects it, sets its Tailscale name, advertises an exit node, turns Tailscale
#   SSH off, permits incoming tailnet connections, disables computer sleep and
#   enables restart after power failure. It does not reboot or configure Sharing.
#   It displays Tailscale status and the IP. Verify the intended account/tailnet.
#   Record the name/IP and local account short name in your password manager.
#   "whoami" in Terminal shows the current account's short name.
#
# 5. ENABLE SSH AND OPTIONAL SCREEN SHARING (LOCAL SETUP PAUSES FOR YOU)
#   In System Settings > General > Sharing:
#   - Remote Login ON. Open its details, choose "Only these users", and add the
#     intended local account. Full-disk access is not required merely to connect;
#     enable it only if later maintenance tasks need it.
#   - Optional: Screen Sharing ON if you want remote desktop access. Otherwise
#     leave it off. Choose "Only these users" and add the intended account.
#     Turn Remote Management OFF first if it is enabled. Use normal Mac-account
#     authentication; leave the separate legacy "VNC password" option off.
#   - If macOS asks about incoming connections for these services, allow them.
#     If its firewall is enabled, do not use "Block all incoming connections"
#     for a machine intended to accept these remote connections.
#   This baseline uses the account password for native SSH and screen sharing.
#   SSH keys can be added later; the script does not install keys or enforce them.
#
# 6. APPROVE THE EXIT NODE (SETUP PAUSES FOR YOU)
#   Open https://login.tailscale.com/admin/machines and find the correct Mini.
#   Complete device approval if required. In its route settings, enable/approve
#   "Use as exit node". In its device menu, disable NODE key expiry for this
#   persistent server. Enrollment auth-key expiry is a different setting.
#   If your tailnet has custom access rules, permit the intended clients to
#   access this Mini's TCP 22 (also 5900 if using Screen Sharing) and use exit
#   nodes (autogroup:internet).
#   Do not replace an existing policy wholesale to make this work.
#   Advertising, approval and client selection are THREE separate steps.
#
# 7. TEST FROM ANOTHER DEVICE, THEN TEST UNATTENDED REBOOT
#   Setup runs the local checker after step 6. To run it again later:
#
#     sudo /bin/bash ~/Downloads/mac-mini.sh check
#
#   Resolve FAIL and UNKNOWN messages. Exit 0 means the automated local checks
#   passed, 1 means a failure, and 2 means an incomplete/unsupported check.
#   Exit-node approval is checked as reported by the local Tailscale daemon.
#   This is not a fresh admin-console query; client permissions and working
#   exit-node traffic still need the tests below.
#   If the Tailscale app is installed, the checker reports that it differs from
#   the intended Homebrew daemon setup. It does not launch, replace or remove it.
#   This does not replace the following end-to-end tests:
#   - On your laptop/phone, install or open its normal Tailscale client and sign
#     into the same tailnet. Use another Internet connection, e.g. a hotspot.
#   - SSH: on a client with SSH, run "ssh ACCOUNT@TAILSCALE_IP", substituting the
#     Mini's short account name and its address from step 4. Verify the server's
#     fingerprint before accepting it, then enter the Mini account's password.
#     To view that fingerprint LOCALLY on the Mini after Remote Login is enabled:
#       sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
#   - If enabled, test Screen Sharing: Finder > Go > Connect to Server, enter
#     "vnc://TAILSCALE_IP", and authenticate with the Mini's account. In Screens,
#     create a Mac connection with that same address and account credentials.
#     A working MagicDNS name may replace the IP in either client.
#   - In the client's Tailscale menu, select THIS Mini as the exit node. Browse
#     HTTPS websites and confirm DNS works. Check the public IP using an IP-check
#     site; it should be the Mini site's Internet egress, not the client's.
#     Restore the client's preferred exit-node selection after the test.
#   - Restart the Mini with local help still available. Leave it at the login
#     window: do NOT log in locally. Repeat SSH, optional screen sharing and exit-node
#     browsing from your other device. If they fail, fix this before deployment.
#   - If it will run without a display, disconnect the display and repeat the
#     remote tests in that actual configuration before leaving the site.
#   - Test power recovery during a planned local maintenance window. Never pull
#     power during an update or active writes. A normal shutdown does not test
#     "restart after power failure". Record which recovery case you tested.
#   The Mini is ready only when those tests pass. Repeat steps 1–7 for the other
#   Mini with its own unique name. Keep account recovery and this file elsewhere.
#
# REPLACEMENT DETAILS
#   Keep this script, account/MFA recovery, and your client SSH keys available
#   independently of the Minis. Enroll a replacement as a NEW Tailscale device;
#   never copy the old Tailscale state. Retire the confirmed failed device in
#   the admin console, reuse its name, and repeat approvals and expiry settings.
#   Its Tailscale IP and SSH host keys may change. Verify the new SSH fingerprint
#   locally before replacing its old known_hosts entry. Reselect the replacement
#   exit node on clients and update saved Screens/SSH destinations as necessary.
#
# UPDATES
#   Update one Mini at a time. Keep the other working and local help available.
#   For a deliberate Tailscale update on a new Apple-silicon Mini:
#     /opt/homebrew/bin/brew update
#     /opt/homebrew/bin/brew upgrade tailscale
#     sudo /opt/homebrew/bin/brew services restart tailscale
#   Then check and repeat remote tests. Intel Homebrew uses /usr/local instead.
#   After macOS updates, also test access after reboot without desktop login.
#
# LIMITS AND ALERTS
#   The root service starts during boot and restarts if tailscaled exits.
#   It needs macOS, an unlocked disk and working networking first.
#   Power recovery covers power failure, not every shutdown, hang or failed OS
#   update. Supported newer Minis also offer Energy > start when power connects
#   > Always: https://support.apple.com/en-au/125517 . Set that in the UI if wanted.
#   Ethernet, a UPS for the Mini/router, and local assistance improve recovery.
#   Native SSH/Screen Sharing may also be reachable on the LAN. Do not forward
#   ports 22/5900 from the Internet. Keep the router's inbound firewall enabled.
#   This uses native macOS SSH, not Tailscale SSH. No custom SSH/firewall policy.
#   Alerts are not installed by this script. If wanted later, the smallest
#   addition is an external missed-heartbeat service, one check per Mini.
#   A local checker cannot prove that remote login or exit routing works.
#
# KEEPING IT SHARED
#   Keep this one file in the private GitHub repository as the master copy.
#   Pushing it to main publishes the script to GitHub Pages through the public
#   ahdxb/mini repository and updates the secret Gist automatically. The workflow
#   also runs when its publishing configuration changes or when started manually.
#   Only mac-mini.sh, the download index and .nojekyll are copied to mini; Sonar's
#   private Git history and other files stay in Sonar. The script is PUBLIC at
#   both download URLs, and mini is discoverable. Keep this file free of secrets.
#   Pages: https://ahdxb.github.io/mini/mac-mini.sh
#   Gist fallback (use if Pages is unavailable):
#     curl -fsSLo ~/mac-mini.sh \
#       https://gist.githubusercontent.com/ahdxb/7dc7377a171872ef677cedc8eff592bc/raw/mac-mini.sh
#   Both destinations serve the latest published copy; allow time for publishing.
#   Pages publishing uses Sonar's MINI_DEPLOY_KEY secret, a dedicated write key
#   for ahdxb/mini only. Gist publishing uses the existing GIST_TOKEN secret.
#   Keep a downloaded copy on your laptop for recovery without GitHub access.
#   Rerun the step 2 curl command for updates; setup does not update itself.
#   No credentials belong in the file or repository. Keep GitHub/MFA recovery
#   accessible independently of either Mini. A download is not automatic sync.
#
# REFERENCES
#   https://docs.github.com/en/repositories/working-with-files/using-files/viewing-and-understanding-files
#   https://support.apple.com/guide/mac-mini/welcome/mac
#   https://docs.brew.sh/Installation
#   https://github.com/tailscale/tailscale/wiki/Tailscaled-on-macOS
#   https://tailscale.com/docs/concepts/macos-variants
#   https://tailscale.com/docs/reference/tailscale-cli
#   https://tailscale.com/docs/features/exit-nodes
#   https://support.apple.com/en-gb/guide/mac-help/mh11848/mac
#   https://support.apple.com/en-gb/guide/mac-help/mchlp1066/mac
#   https://support.apple.com/en-au/125517
# END GUIDE


# Process defaults
# ----------------
set -uo pipefail                # Fail on unset variables or failed pipeline commands.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin${PATH:+:$PATH}"
                                # Prepend standard tool directories while preserving the existing PATH
export LC_ALL=C                 # Use the C locale for predictable behavior
MODE=${1:-help}                 # Set mode from first argument; default to help
die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
                                # Function die() prints an error to stderr and exits with code 2

# Help mode
# ---------
# Remove each comment marker and at most one space, preserving guide indentation.
# Exit successfully before inspecting the machine.
# $0 is the script path; sed selects from START GUIDE through END GUIDE.
if [ "$MODE" = help ] || [ "$MODE" = --help ]; then
  sed -nE '/^# START GUIDE$/,/^# END GUIDE$/{
    /^# START GUIDE$/d
    /^# END GUIDE$/d
    s/^# ?//
    p
  }' "$0" || die "cannot print guide from $0"
  exit 0
fi

# Validate the requested mode
# ---------------------------
# Accept setup, setup-remote, or check with its optional Screen Sharing flag.
# || calls die() only when the preceding test fails.
REQUIRE_SCREEN_SHARING=false
case "$MODE" in
  check)
    if [ $# = 2 ] && [ "$2" = --require-screen-sharing ]; then
      REQUIRE_SCREEN_SHARING=true
    else
      [ $# = 1 ] || die 'Use: sudo bash mac-mini.sh check [--require-screen-sharing]'
    fi ;;
  setup|setup-remote) [ $# = 1 ] || die 'Setup modes do not accept extra arguments.' ;;
  *) die 'Choose help, setup, setup-remote, or check.' ;;
esac
[ "$(uname -s)" = Darwin ] || die 'This script is for macOS.'

# Locate Homebrew
# ---------------
# Support standard Apple Silicon and Intel prefixes. Only local setup installs
# Homebrew; check and remote setup report it missing.
BREW=''
if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew;
elif [ -x /usr/local/bin/brew ]; then BREW=/usr/local/bin/brew; fi

# Print a numbered step from the guide
# ------------------------------------
# awk starts at the requested heading and stops at the next one, or at the
# replacement notes after step 7. It removes comment markers before printing.
# Inside awk, $0 means the input line; outside awk, "$0" is this script's path.
show_step() {
  awk -v n="$1" '
    $0 ~ "^# " n "\\. " { show=1; found=1 }
    show && /^# [0-9]+\. / && $0 !~ "^# " n "\\. " { exit }
    show && /^# REPLACEMENT DETAILS/ { exit }
    show { sub(/^# ?/, ""); print }
    END { if (!found) exit 1 }
  ' "$0" || die "cannot display guide step $1"
}

# Pause for a manual step
# -----------------------
# Print the checklist and wait for DONE. IFS= and read -r preserve literal input
# Any other answer ends normally. Completed changes remain; this does not undo them
manual_step() {
  show_step "$1"
  printf '\nComplete this step, then type DONE (anything else stops setup): '
  IFS= read -r ANSWER
  [ "$ANSWER" = DONE ] || { printf 'Stopped. Rerun setup when ready.\n'; exit 0; }
}

# Read a JSON field with stock macOS tools. Missing fields fail closed.
field() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

# Bound read-only queries, including remote preflight queries. This terminates
# only the CLI process, never the Tailscale daemon.
run_timed() {
  local child timer result
  "$@" & child=$!
  ( sleep 15; kill -TERM "$child" 2>/dev/null;
    sleep 2; kill -KILL "$child" 2>/dev/null ) >/dev/null 2>&1 & timer=$!
  if wait "$child"; then result=0; else result=$?; fi
  kill "$timer" 2>/dev/null || true
  wait "$timer" 2>/dev/null || true
  return "$result"
}

# Refuse common competing installations without attempting a migration.
check_tailscale_installation() {
  local other
  for other in /Applications/Tailscale.app "$HOME/Applications/Tailscale.app" \
    /Library/LaunchDaemons/com.tailscale.tailscaled.plist \
    "$HOME/Library/LaunchAgents/homebrew.mxcl.tailscale.plist"; do
    [ ! -e "$other" ] || die "Another Tailscale installation exists: $other. Resolve migration locally first."
  done
}

# CHECK: require access to system settings
# ----------------------------------------
# Enters check mode.
# Require root and Homebrew, then locate the Tailscale CLI.
# Checks read settings and attempt local TCP connections; they do not repair
# configuration or send alerts. Exit before reaching setup.
if [ "$MODE" = check ]; then
  [ "$(id -u)" = 0 ] || die 'Use: sudo bash mac-mini.sh check'
                                # Require root privileges; otherwise instruct running the check with sudo
  [ -n "$BREW" ] || die 'Homebrew is missing. Run setup first.'
                                # Fail unless Homebrew was found; instruct running setup first
  TS="${BREW%/brew}/tailscale"  # Derive the Tailscale executable path from Homebrew’s executable path
                                # Executable is checked later so the other health checks can still run

  # Protect temporary status files
  # ------------------------------
  # Create a private temporary folder for the checker’s output, then arrange to delete it when finished
  umask 077
  TMP=$(mktemp -d) || die 'Could not create a temporary directory.'
  trap 'rm -rf "$TMP"' EXIT

  # Track and report results
  # ------------------------
  # Keep separate counts for confirmed failures and unknown results. PASS only prints;
  # FAIL and UNKNOWN print a label and increment their corresponding counters.
  BAD=0
  UNKNOWN=0
  pass() { printf 'PASS     %s\n' "$*"; }
  fail() { printf 'FAIL     %s\n' "$*"; BAD=$((BAD+1)); }
  unknown() { printf 'UNKNOWN  %s\n' "$*"; UNKNOWN=$((UNKNOWN+1)); }

  # Compare a field with its expected value
  # ---------------------------------------
  # Arguments are file, key path, expected value and label. A missing or unreadable
  # field is UNKNOWN; a readable but different value is FAIL. value is local here.
  expect() {
    local value
    if value=$(field "$1" "$2"); then
      if [ "$value" = "$3" ]; then pass "$4"; else fail "$4"; fi
    else unknown "$4 (field unavailable)"; fi
  }

  # Limit how long a Tailscale query can wait
  # -----------------------------------------
  # Run the CLI in the background and save its process ID ($!). A separate timer
  # sends TERM after 15 seconds and KILL two seconds later if the CLI has not exited.
  # This stops the CLI query, not tailscaled. Wait for its result, stop and collect
  # the timer, and return the saved result. "$@" preserves each command argument.
  # Expected cleanup errors, such as an already-exited process, are ignored.
  read_tailscale() { run_timed "$TS" "$@"; }

  # Check that Tailscale is connected and has the expected exit-node and SSH settings
  # --------------------------------------------------------------------------------
  # Timestamp the report and require an executable CLI. Save each query in a private temporary file.
  # Failed queries/timeouts are UNKNOWN; inspect returned fields individually.
  # Display the tailnet/name for manual verification.
  # Check saved preferences separately, since a running node can still be configured incorrectly.
  # An older CLI without "get --json" produces UNKNOWN instead of an assumed pass.
  # Keep stderr privately. On failure, append its first nonempty line (up to 240 characters);
  # with no detail, use the generic error message.
  # Signal exit codes alone are not treated as proof of a timeout.
  printf 'Local checks, %s\n' "$(date '+%Y-%m-%d %H:%M %Z')"

  # Check that Homebrew can start. Asking for its version does not install or update software.
  if "$BREW" --version >/dev/null 2>&1; then
    pass 'Homebrew starts successfully'
  else
    fail 'Homebrew exists but could not report its version'
  fi

  # Identify an alternative CLI path without running it. A CLI in another
  # location does not establish that the intended Homebrew daemon is installed.
  OTHER_TS=$(command -v tailscale || true)
  if [ -n "$OTHER_TS" ] && [ "$OTHER_TS" != "$TS" ]; then
    printf 'INFO     Another Tailscale CLI is available at %s\n' "$OTHER_TS"
  fi

  # Recognize the app in its usual installation location instead of calling it
  # missing. Its presence does not prove it is running. The intended setup uses
  # Homebrew tailscaled to start before desktop login. Do not run an app CLI or
  # switch installations here; continue checking the other system settings.
  if [ -d /Applications/Tailscale.app ]; then
    fail 'Tailscale app found at /Applications/Tailscale.app; expected the Homebrew daemon setup'
    printf 'INFO     The intended Homebrew daemon starts before desktop login. The app is a different installation.\n'
    if [ -x "$TS" ]; then
      printf 'INFO     The expected Homebrew CLI also exists; review which installation is in use.\n'
    fi
    printf 'INFO     Tailscale status/preferences queries skipped; no installation was changed.\n'
  elif [ -x "$TS" ]; then          # Query only the expected Homebrew CLI
    if read_tailscale status --json >"$TMP/status" 2>"$TMP/status.err"; then
                                    # Copy Tailscale's status as JSON into a file
      expect "$TMP/status" BackendState Running 'Tailscale running'
                                    # PASS if Tailscale’s backend state is exactly Running
      expect "$TMP/status" Self.Online true 'Tailscale connected to control server'
                                    # PASS if this Mac is currently connected to Tailscale's servers
      expect "$TMP/status" Self.ExitNodeOption true 'Exit node advertised and approved (reported by Tailscale)'
                                    # PASS if Tailscale says this Mac is an approved exit node.
      printf 'Identity: %s / %s\n' "$(field "$TMP/status" CurrentTailnet.Name || printf unknown)" \
        "$(field "$TMP/status" Self.DNSName || printf unknown)"
                                    # Print the tailnet and this Mac's Tailscale name for eyeballing
    else
      DETAIL=$(awk 'NF {print substr($0, 1, 240); exit}' "$TMP/status.err")
      unknown "Cannot read Tailscale status${DETAIL:+: $DETAIL}"
    fi
    if read_tailscale get --json >"$TMP/prefs" 2>"$TMP/prefs.err"; then
                                    # Copy Tailscale's settings as JSON into a file
      expect "$TMP/prefs" advertise-exit-node true 'Exit node advertised'
                                    # PASS if this Mac is set to offer itself as an exit node
      expect "$TMP/prefs" ssh false 'Native SSH baseline (Tailscale SSH off)'
                                    # PASS if Tailscale's built-in SSH server is turned off
      expect "$TMP/prefs" shields-up false 'Incoming tailnet connections allowed'
                                    # PASS if this Mac accepts connections from other tailnet devices
    else
      DETAIL=$(awk 'NF {print substr($0, 1, 240); exit}' "$TMP/prefs.err")
      unknown "Cannot read Tailscale preferences${DETAIL:+: $DETAIL}"
    fi
  else fail "Expected Homebrew Tailscale CLI is missing or not executable: $TS"; fi

  # Check that Tailscale's startup service exists and is running
  # -----------------------------------------------------------
  # Require the plist file and a running service in launchd's system domain.
  # This verifies current state, not that a future reboot will succeed.
  if [ -f /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist ] &&
                                  # True if Tailscale’s boot-time launchd plist file exists
     launchctl print system/homebrew.mxcl.tailscale >"$TMP/service" 2>/dev/null &&
                                  # Dump the root-domain service's live state to a temp file
     grep -q 'state = running' "$TMP/service"; then pass 'Tailscale system boot service running';
                                  # If the dump says "running", report PASS
  else fail 'Expected Homebrew Tailscale startup service is missing or stopped'; fi

  # Check that automatic sleep is off and restart after power failure is on
  # -----------------------------------------------------------------------
  # Read the saved power settings without changing them. Expect sleep=0 and
  # autorestart=1. Each setting must appear, and every reported value must match.
  # Report FAIL if a setting is missing or has a different value.
  if pmset -g custom >"$TMP/power" 2>/dev/null; then
    for setting in sleep:0 autorestart:1; do
      key=${setting%:*}; value=${setting#*:}
      if awk -v k="$key" -v v="$value" '$1==k {n++; if ($2!=v) bad=1} END {exit !(n && !bad)}' "$TMP/power"; then
        pass "Power setting $key=$value"
      else fail "Power setting $key should be $value"; fi
    done
  else unknown 'Cannot read power settings'; fi

  # Check FileVault without changing it
  # -----------------------------------
  # Require the exact fully-off status. Encryption/decryption still in progress
  # must not be mistaken for a completed unattended-boot setup.
  if fdesetup status >"$TMP/filevault" 2>/dev/null; then
    if grep -Fxq 'FileVault is Off.' "$TMP/filevault"; then pass 'FileVault off for unattended cold boot';
    else fail 'FileVault is not fully off; unattended cold boot needs review'; fi
  else unknown 'Cannot read FileVault status'; fi

  # Native SSH is required. Screen Sharing is optional unless requested.
  # Local TCP probes do not test authentication or reachability from a client.
  if nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1; then
    pass 'Local port 22 accepts TCP (SSH)'
  else fail 'Local port 22 unavailable; check Remote Login'; fi
  if nc -z -G 3 127.0.0.1 5900 >/dev/null 2>&1; then
    pass 'Local port 5900 accepts TCP (Screen Sharing)'
  elif [ "$REQUIRE_SCREEN_SHARING" = true ]; then
    fail 'Local port 5900 unavailable; Screen Sharing was explicitly required'
  else printf 'INFO     Screen Sharing unavailable on port 5900 (optional)\n'; fi

  # Summarize and return a result
  # -----------------------------
  # List the tests that still need a person or another device. Confirmed failures
  # return exit 1; otherwise unknown results return exit 2. With neither, explicitly
  # exit 0 after the success message. This means only the local checks passed.
  printf '\nMANUAL: verify the displayed identity, node expiry, client permissions, automatic\n'
  printf 'login off, permitted users, remote SSH, optional Screen Sharing, exit-node browsing and\n'
  printf 'DNS, and access after reboot without a desktop login. Local TCP is not\n'
  printf 'an authentication test. This script sends no alerts and makes no repairs.\n'
  printf '\nResult: %s failed; %s unknown.\n' "$BAD" "$UNKNOWN"
  [ "$BAD" = 0 ] || exit 1
  [ "$UNKNOWN" = 0 ] || exit 2
  printf 'All automated local checks passed; complete the manual checks above.\n'
  exit 0
fi

# REMOTE SETUP: finish a prepared server without changing its access method.
# Require the existing Homebrew system daemon rather than installing, starting
# or migrating networking software through the connection that depends on it.
if [ "$MODE" = setup-remote ]; then
  set -e
  [ -t 0 ] || die 'Use an interactive SSH terminal (ssh -t ACCOUNT@ADDRESS).'
  [ "$(id -u)" != 0 ] || die 'Run setup-remote as your administrator account, without sudo.'
  [ -n "${SSH_CONNECTION:-}" ] || die 'Use setup-remote inside an SSH session; use setup for local preparation.'
  case " $(id -Gn) " in
    *' admin '*) ;;
    *) die 'Remote setup requires a local administrator account.' ;;
  esac
  system_profiler SPHardwareDataType | grep -q 'Model Name: Mac mini' || die 'Setup is restricted to Mac mini hardware.'
  [ -n "$BREW" ] || die 'Homebrew must already be installed. Complete local preparation first.'
  "$BREW" --version >/dev/null || die 'Homebrew cannot start. Resolve locally before remote setup.'
  check_tailscale_installation
  TS="${BREW%/brew}/tailscale"
  [ -x "$TS" ] && "$BREW" list --formula tailscale >/dev/null 2>&1 ||
    die 'The Homebrew Tailscale formula must already be installed. Complete local preparation first.'
  sudo -v

  umask 077
  TMP=$(mktemp -d)
  REMOTE_LOG=''
  remote_cleanup() {
    local result=$?
    trap - EXIT
    rm -rf "$TMP"
    if [ -n "$REMOTE_LOG" ]; then
      printf 'Run ended with exit %s. Progress log: %s\n' "$result" "$REMOTE_LOG" | tee -a "$REMOTE_LOG"
    fi
    exit "$result"
  }
  trap remote_cleanup EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  REMOTE_LOG=$(mktemp "$HOME/mac-mini-remote.XXXXXX")
  remote_progress() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" | tee -a "$REMOTE_LOG"; }
  printf 'Private progress log: %s\n' "$REMOTE_LOG"

  remote_preflight() {
    local value
    check_tailscale_installation
    [ -f /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist ] &&
      sudo launchctl print system/homebrew.mxcl.tailscale >"$TMP/service" 2>/dev/null &&
      grep -q 'state = running' "$TMP/service" ||
      die 'The Homebrew Tailscale system service must already be running. Resolve locally; remote setup will not restart it.'
    run_timed sudo -n "$TS" status --json >"$TMP/status" || die 'Cannot read Tailscale status. No configuration was changed.'
    [ "$(field "$TMP/status" BackendState)" = Running ] &&
      [ "$(field "$TMP/status" Self.Online)" = true ] || die 'Tailscale must already be connected. Resolve enrollment locally.'
    for value in CurrentTailnet.Name Self.DNSName; do
      [ -n "$(field "$TMP/status" "$value")" ] || die "Cannot verify Tailscale identity field $value."
    done
    run_timed sudo -n "$TS" get --json >"$TMP/prefs" || die 'Cannot read Tailscale preferences. No configuration was changed.'
    # Refuse rather than disable Tailscale SSH: the current session may use it.
    [ "$(field "$TMP/prefs" ssh)" = false ] ||
      die 'Tailscale SSH is enabled or unknown. Establish native Remote Login and resolve this locally; remote setup will not change SSH settings.'
    [ "$(field "$TMP/prefs" shields-up)" = false ] ||
      die 'Incoming tailnet connections must already be allowed. Remote setup will not change access settings.'
    value=$(field "$TMP/prefs" advertise-exit-node) || die 'Cannot read exit-node advertisement preference.'
    case "$value" in true|false) ;; *) die 'Unrecognized exit-node advertisement preference.' ;; esac
    nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1 || die 'Native SSH must already listen on port 22. Resolve Remote Login locally.'
    sudo -n fdesetup status >"$TMP/filevault" || die 'Cannot verify FileVault. Complete local preparation first.'
    grep -Fxq 'FileVault is Off.' "$TMP/filevault" || die 'FileVault must be fully off for this unattended-boot design. Resolve locally first.'
    pmset -g custom >"$TMP/power" || die 'Cannot read power settings.'
    # Refuse unreadable/missing values rather than guessing what will change.
    for value in sleep autorestart; do
      awk -v k="$value" '$1==k {n++; if ($2 !~ /^[0-9]+$/) bad=1} END {exit !(n && !bad)}' "$TMP/power" ||
        die "Cannot verify power setting $value."
    done
  }

  remote_preflight
  remote_progress 'Preflight passed; no configuration changed.'
  REMOTE_TAILNET=$(field "$TMP/status" CurrentTailnet.Name)
  REMOTE_NAME=$(field "$TMP/status" Self.DNSName)
  printf 'Existing identity: %s / %s\n' "$REMOTE_TAILNET" "$REMOTE_NAME"
  cat <<'REMOTE_PLAN'
This will advertise this Mini as an exit node, disable computer sleep, and enable
restart after power failure. Completed settings are skipped on reruns. It keeps
the existing name, tailnet, SSH/DNS/routing/access preferences and running services.
No installs, upgrades, GUI apps, service restarts or reboots are requested.
Verify the identity above. Keep a second SSH session open. Afterward, open the
printed admin URL on your own computer, then test a NEW SSH connection.
REMOTE_PLAN
  printf 'Type SETUP to apply these changes: '
  IFS= read -r CONFIRM
  [ "$CONFIRM" = SETUP ] || { remote_progress 'Cancelled; no configuration changed.'; exit 0; }
  # Refresh sudo and recheck live state after the user has reviewed the plan.
  sudo -v
  remote_preflight
  [ "$(field "$TMP/status" CurrentTailnet.Name)" = "$REMOTE_TAILNET" ] &&
    [ "$(field "$TMP/status" Self.DNSName)" = "$REMOTE_NAME" ] ||
    die 'Tailscale identity changed while awaiting confirmation. Rerun and review the current identity.'
  if [ "$(field "$TMP/prefs" advertise-exit-node)" = true ]; then
    remote_progress 'Exit-node advertisement already enabled; skipped.'
  else
    remote_progress 'Enabling exit-node advertisement.'
    sudo -n "$TS" set --advertise-exit-node=true
    remote_progress 'Exit-node advertisement enabled.'
  fi
  for setting in sleep:0 autorestart:1; do
    key=${setting%:*}; value=${setting#*:}
    if awk -v k="$key" -v v="$value" '$1==k {n++; if ($2!=v) bad=1} END {exit !(n && !bad)}' "$TMP/power"; then
      remote_progress "Power setting $key=$value already applied; skipped."
    else
      remote_progress "Applying power setting $key=$value."
      sudo -n pmset -a "$key" "$value"
      remote_progress "Power setting $key=$value applied."
    fi
  done
  remote_progress 'Configuration applied. Exit-node approval and external tests remain.'
  # Show the existing admin checklist without opening a browser on the server.
  manual_step 6
  RESULT=0
  sudo /bin/bash "$0" check || RESULT=$?
  show_step 7
  remote_progress "Local checks returned $RESULT; verify a new SSH connection and complete the external tests."
  exit "$RESULT"
fi

# SETUP: check the operating conditions
# -------------------------------------
# Stop on unhandled errors (set -e). Require an interactive Terminal, a normal
# user account and Mac mini hardware. Reject sessions identified as SSH sessions.
# The SSH guard cannot detect every remote-control tool; retain local access.
# Privileged commands will request sudo individually, so Homebrew runs as the user.
if [ "$MODE" = setup ]; then
  set -e
  [ -t 0 ] || die 'Run setup in an interactive Terminal window.'
  [ "$(id -u)" != 0 ] || die 'Run setup as your local administrator, without sudo.'
  [ -z "${SSH_CONNECTION:-}${SSH_TTY:-}" ] || die 'Use setup at the Mini, not through SSH.'
  system_profiler SPHardwareDataType | grep -q 'Model Name: Mac mini' || die 'Setup is restricted to Mac mini hardware.'

  # Refuse common competing Tailscale installations
  #
  # Check the GUI app, standalone daemon and user LaunchAgent paths. Stop rather
  # than replace them. These paths do not cover every possible custom installation.
  check_tailscale_installation

  # Choose the Tailscale name
  #
  # Read a name without saving a separate profile. Require a DNS label of 1–63
  # characters: lower-case letters/digits at each end, with internal hyphens allowed.
  printf 'Unique name for this Mini (France: le-mac-mini): '
  IFS= read -r NAME
  [[ "$NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] && [ ${#NAME} -le 63 ] || die 'Use 1–63 lower-case letters, digits and internal hyphens.'

  # Show the changes and request confirmation
  #
  # The quoted PLAN delimiter prints the text literally, without shell expansion.
  # Nothing is installed or configured unless the user enters SETUP.
  cat <<'PLAN'
This will install Homebrew and its required tools if missing, using the official
interactive installer, then install the Tailscale formula and start it at boot,
connect it to your tailnet, set its Tailscale name, advertise an exit node,
disable Tailscale SSH, prevent system sleep, and enable power-failure restart.
It leaves macOS accounts, Computer Name, FileVault, automatic login and Sharing
settings for you to configure at the guided pauses. It finishes with local checks.
Existing Tailscale SSH sessions may disconnect. Keep local access available.
PLAN
  printf 'Type SETUP to apply these changes: '
  IFS= read -r CONFIRM
  [ "$CONFIRM" = SETUP ] || { printf 'Cancelled.\n'; exit 0; }

  # Complete macOS settings first
  #
  # Open Settings and pause at guide step 3. Then validate/cache sudo authorization;
  # sudo may ask for the local administrator password.
  open -a 'System Settings'
  manual_step 3
  sudo -v

  # Install Homebrew only when missing
  #
  # Create a private temporary directory and arrange its removal on shell exit.
  # Download the official installer over HTTPS, allowing HTTPS redirects only.
  # Reject HTTP errors; allow 15 seconds to connect and 120 seconds for the download.
  # Run it as the current user with normal prompts. Then remove the temporary files,
  # clear the cleanup trap, and verify Homebrew exists at a supported default path.
  # An unhandled download/installer failure stops setup before it can continue.
  if [ -z "$BREW" ]; then
    INSTALLER_DIR=$(mktemp -d)
    trap 'rm -rf "$INSTALLER_DIR"' EXIT
    curl --proto '=https' --proto-redir '=https' --fail --location --show-error \
      --connect-timeout 15 --max-time 120 \
      https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
      -o "$INSTALLER_DIR/homebrew-install.sh"
    /bin/bash "$INSTALLER_DIR/homebrew-install.sh"
    rm -rf "$INSTALLER_DIR"
    trap - EXIT
    if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew;
    elif [ -x /usr/local/bin/brew ]; then BREW=/usr/local/bin/brew;
    else die 'Homebrew installation did not finish. Resolve its error, then rerun setup.'; fi
  fi

  # Install the Tailscale formula if needed
  #
  # Derive the CLI path by replacing the final /brew with /tailscale. Probe for the
  # installed formula, suppressing probe output. ! reverses the probe's exit status,
  # so installation runs only when the probe fails. Existing formulas are not upgraded.
  TS="${BREW%/brew}/tailscale"
  if ! "$BREW" list --formula tailscale >/dev/null 2>&1; then
    "$BREW" install --formula tailscale
  fi

  # Start and configure Tailscale, then set power recovery
  #
  # sudo registers the service in launchd's system domain so it starts at boot.
  # Bare "up" preserves saved preferences and offers browser login when needed.
  # "set" changes the name, advertises exit service, disables Tailscale SSH in favor
  # of macOS SSH, and permits incoming connections subject to tailnet access rules.
  # pmset applies no system sleep and power-failure restart to all power profiles.
  # Finally, display status and the Tailscale IPv4 address for the user to verify.
  sudo "$BREW" services start tailscale
  sudo "$TS" up
  sudo "$TS" set --hostname="$NAME" --advertise-exit-node=true --ssh=false --shields-up=false
  sudo pmset -a sleep 0 autorestart 1
  sudo "$TS" status
  sudo "$TS" ip -4

  # Complete the remaining manual settings
  #
  # Pause for SSH/Screen Sharing permissions, open Tailscale's device console,
  # and pause for exit-node approval, node expiry and access-rule checks.
  manual_step 5
  open https://login.tailscale.com/admin/machines
  manual_step 6

  # Check locally and show the external tests
  #
  # Run this same file in check mode with sudo. Capture any failure code instead
  # of stopping, so guide step 7 is still displayed. Return the checker's exit code.
  RESULT=0
  sudo /bin/bash "$0" check || RESULT=$?
  show_step 7
  printf 'No reboot was requested. No existing formula was upgraded.\n'
  exit "$RESULT"
fi
