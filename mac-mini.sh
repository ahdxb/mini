#!/bin/bash
# START GUIDE
# Mac mini with Tailscale exit node: server and home setup, checks, and recovery.
# Last updated 2026-10-23.
# Download:  https://ahdxb.github.io/mini/mac-mini.sh
# Fallback:  https://gist.githubusercontent.com/ahdxb/7dc7377a171872ef677cedc8eff592bc/raw/mac-mini.sh
# Source:    https://github.com/ahdxb/Sonar (private; published to Pages and Gist)
#
# PROFILES
#   Two profiles are available: home (default), and server.
#   A profile determines which settings setup applies and which checks must pass.
#   Profiles are not saved: repeat the same profile/options on later checks and reruns.
#
#   Both profiles:
#   - use the Homebrew Tailscale system service and advertise the Mini as an exit node;
#   - prevent computer sleep and enable restart after power failure;
#   - keep existing settings for FileVault, accounts, login settings, Screen Sharing
#     or firewall;
#   - have Screen Sharing as optional;
#   - use the same SSH settings and options (see below);
#   - support local and SSH setup.
#
# +--------------------+-------------------------------+-------------------------------+
# | Profile            | home (default)                | server                        |
# +====================+===============================+===============================+
# | Intended use       | Exit node + everyday computer | Dedicated unattended exit     |
# |                    | (e.g. My Mac Mini M4)         | node (e.g. Le Mac Mini)       |
# +====================+===============================+===============================+
# | FileVault          | Keep the current setting;     | Keep the current setting;     |
# |                    | ON is accepted                | Must be OFF to pass           |
# +--------------------+-------------------------------+-------------------------------+
# | Incoming           | Keep the current setting;     | Local setup allows them; SSH  |
# | connections over   | Must be ON to pass            | setup requires them already   |
# | Tailscale          |                               | allowed                       |
# +--------------------+-------------------------------+-------------------------------+
# | Recovery after     | With FileVault ON, requires   | Designed to resume services   |
# | cold boot          | an unlock locally or through  | without a disk unlock,        |
# |                    | a supported, independently    | provided power, macOS and     |
# |                    | reachable SSH-unlock path     | networking recover            |
# +--------------------+-------------------------------+-------------------------------+
#
# COMMAND REFERENCE
#   Read the guide:
#     bash mac-mini.sh | less
#     Pager keys: Space = next page, b = back, / = search, q = quit.
#
#   Set up locally, after completing macOS preparation:
#     bash mac-mini.sh setup --profile PROFILE
#     (PROFILE must be lowercase home or server; defaults to home without --profile)
#
#   Set up over SSH, on an already prepared computer:
#     bash mac-mini.sh setup-remote --profile PROFILE
#     (See "Terminal access over SSH" after step 7)
#
#   Check settings without changing configuration:
#     sudo bash mac-mini.sh check --profile PROFILE
#
# OPTIONAL SETTINGS
#   Options to setup, setup-remote, and check:
#     --ssh native (default): require macOS Remote Login and Tailscale SSH OFF.
#     --ssh tailscale: require Tailscale SSH ON; native Remote Login is optional.
#       Setup never enables/disables either SSH service or changes access rules.
#       Prepare the selected method separately; a mismatch stops setup.
#       Repeat this option on checks and reruns.
#
#   Options to check only:
#     --ssh any: accept either native SSH or Tailscale SSH without requiring a specific
#       method. This never changes settings and cannot verify remote authentication.
#     --require-screen-sharing: require the Screen Sharing service to accept connections.

#   Options to local setup only:
#     --hostname NAME: explicitly change the Tailscale name. Otherwise, keep the
#       current name.
#
#   Run setup as your administrator account without sudo; it requests sudo when
#   needed. Run check with sudo, as shown above. Help and check make no changes.
#
# MACHINE SETUP GUIDELINES
# ------------------------
# 1. CREATE OR KEEP THE ADMINISTRATOR ACCOUNT
#   Choose home or server using the explanations above.
#   For a new Mini, connect Ethernet, display, keyboard and mouse and complete
#   Setup Assistant. Create a local administrator and store account recovery
#   independently of this Mini. Do not import another Mini's Tailscale identity.
#   For an existing Mini, keep its accounts and data; no clean rebuild is required.
#
# 2. PREPARE MACOS COMPLETELY BEFORE RUNNING SETUP (MANUAL)
#   Complete these tasks first, including any restarts. For an already prepared
#   Mini, verify what applies; use the SSH workflow below for remote maintenance.
#   For both profiles:
#   - Install current stable macOS updates, restart, and finish any prompts.
#     On a deployed remote Mini, schedule updates separately with a recovery plan.
#   - Verify networking (Ethernet is recommended; DHCP is OK) and automatic date/time.
#   - Keep or choose a Computer Name. This is separate from --hostname, which
#     changes only the Tailscale name.
#   - With --ssh native (default), enable Remote Login for the intended account
#     in System Settings > General > Sharing. Choose permitted users and prepare
#     Mac-account/key authentication. Tailscale SSH must already be OFF. To check:
#       sudo tailscale debug prefs | plutil -extract RunSSH raw -expect bool -o - -
#     must return false (if tailscale is already installed).
#   - With --ssh tailscale, prepare the Homebrew Tailscale system service with
#     Tailscale SSH already ON, and configure/test its network and SSH access
#     rules. Native Remote Login is optional. Do not switch SSH methods through
#     your only working connection; keep another tested access method available.
#     See https://tailscale.com/docs/features/tailscale-ssh for preparation.
#   - Setup preserves SSH settings in both profiles; the script never edits
#     SSH permissions.
#   - Screen Sharing is optional. Enable it only if wanted, restrict permitted
#     users, and use normal Mac-account authentication. Leave the legacy VNC
#     password off. Remote Management must be off to enable Screen Sharing.
#   - If the Mini's macOS firewall is enabled, permit the services you intend
#     to use. Do not enable "Block all incoming connections" for these services.
#   - Setup prevents computer sleep and enables restart after power failure.
#     The display may still sleep. Neither setting changes FileVault.
#   Server only:
#   - FileVault OFF; verify it is fully off before setup. This reduces protection
#     against physical access to data. Keep sensitive personal data off this server.
#     macOS 26 SSH unlock is a separate recovery design; this script still requires
#     FileVault OFF for server. See "FileVault and recovery" below.
#   - Turn automatic login and Guest User off. Require a password immediately
#     after screen lock. Let the display sleep; setup prevents computer sleep.
#   - If Energy offers "Start up when power is connected" > "Always", choose it
#     if desired. Setup also enables restart after power failure.
#   Home:
#   - Keep your existing FileVault, account, login and lock-screen choices.
#     FileVault ON is valid and is not a failed home check. An unattended cold
#     boot requires an unlock before the Tailscale daemon can return. On supported
#     Macs, this may be possible over SSH using a separate network path; see
#     "FileVault and recovery" below.
#   Finish macOS preparation before downloading and launching setup below.
#
# 3. DOWNLOAD AND READ THE SCRIPT
#   Open Terminal on the Mini (or see "Terminal access over SSH" below):
#
#     curl -fsSLo ~/mac-mini.sh https://ahdxb.github.io/mini/mac-mini.sh
#     bash ~/mac-mini.sh | less
#
#   Read the script itself with "less ~/mac-mini.sh" before running setup.
#
# 4. RUN LOCAL SETUP AFTER PREPARATION
#   Choose the intended command; do not prefix setup with sudo:
#
#     bash ~/mac-mini.sh setup --profile server --hostname le-mac-mini
#     bash ~/mac-mini.sh setup --profile home
#
#   Use a unique --hostname for each Mini if renaming. Setup verifies prerequisites,
#   shows the selected profile and changes, and asks you to type SETUP. It does
#   not open a macOS-settings checklist halfway through installation. Account,
#   FileVault and Sharing choices must already be complete in step 2.
#   If Homebrew is missing, local setup runs its official installer from:
#     https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
#   The installer may request sudo and install Command Line Tools. Full Xcode is
#   unnecessary. If installation fails, resolve the installer error and rerun.
#   Package installation runs as your account; the system service is started
#   with sudo. Homebrew takes root ownership of selected service paths and warns
#   that upgrades/reinstalls/uninstalls can require manual cleanup (see UPDATES).
#   Existing formulae are not upgraded.
#   Do not install a second Tailscale app/cask. If one already exists, setup stops
#   without replacing it; resolve installation choice locally first.
#   Setup reuses a healthy running system daemon. If necessary locally, it starts
#   the Homebrew service and runs "tailscale up" to connect/enroll. Open its login
#   URL in a browser and select the intended tailnet. Complete device approval or
#   Tailnet Lock signing if required. Already connected Minis are not reauthenticated.
#   Setup advertises exit-node service, applies only the selected profile/options,
#   and preserves other preferences. It does not reboot or change accounts.
#   If home preferences block incoming connections over Tailscale, review them
#   separately: setup preserves them, and the checker reports the access problem.
#   Record the Tailscale IP/name and account short name ("whoami").
#   On interruption, rerun the same command with the same profile/options.
#   Completed installs and settings are reused. Changes are not rolled back.
#
# 5. APPROVE THE EXIT NODE (SETUP PRINTS THIS CHECKLIST AND PAUSES)
#   Open https://login.tailscale.com/admin/machines on your own computer and find
#   the Mini. Verify the intended tailnet/identity before changing approvals.
#   Complete device approval, enable "Use as exit node" in route settings, and
#   consider disabling NODE key expiry for a persistent server. Enrollment
#   auth-key expiry is a different setting. Respect your existing access policy.
#   If using custom access rules, permit the intended clients to access TCP 22
#   (also 5900 if using Screen Sharing) and use exit nodes (autogroup:internet).
#   Tailscale SSH additionally requires SSH access rules for the intended users.
#   Advertising, approval and client selection are three separate steps.
#   After completing this step, type DONE for setup to run local checks.
#
# 6. RUN CHECKS FOR THE SAME PROFILE AND OPTIONS
#   Setup passes its profile and SSH method to the checker.
#   To run it again locally or through SSH:
#
#     sudo bash ~/mac-mini.sh check --profile server
#     sudo bash ~/mac-mini.sh check --profile server --ssh tailscale
#     sudo bash ~/mac-mini.sh check --profile server --ssh any
#     sudo bash ~/mac-mini.sh check --profile home
#
#   Add --require-screen-sharing only if you require that service. Native port
#   22 is required only with --ssh native; port 5900 is informational by default.
#   PASS is green and FAIL red in color-capable terminals, including over SSH.
#   Files and pipes receive plain text. Use NO_COLOR=1 to disable color.
#   Informational update checks compare Homebrew itself with its latest stable
#   GitHub release and Tailscale with the stable Homebrew formula version.
#   These online lookups time out after 8 seconds each. They do not install,
#   upgrade or restart anything. Available updates and lookup failures do not
#   affect the check's exit status. Formula rebuild revisions are not compared.
#   Both profiles require sleep=0 and power recovery=1. Server checks also
#   require FileVault fully off; home reports FileVault as information.
#   Both profiles require the selected SSH method: native requires Tailscale
#   SSH OFF; tailscale requires it ON. Check-only --ssh any accepts either
#   available method.
#   A local Tailscale SSH setting does not prove that a client
#   can authenticate; test a NEW authorized connection from another device.
#   Both profiles check Tailscale connectivity, exit-node advertisement/approval,
#   incoming connections over Tailscale and the Homebrew system service.
#   Launch-file checks cover paths, ownership and Unix write bits only. See
#   UPDATES AND LIMITS for their security limits and maintenance guidance.
#   Exit 0 means local checks passed, 1 means a failure, and 2 means incomplete
#   or unsupported checks. FileVault ON is not a home failure. Computer sleep
#   enabled or restart after power failure disabled fails either profile.
#   The checker recognizes competing Tailscale installations without launching,
#   replacing or removing them. This file supports the Homebrew daemon only.
#   Local ports do not prove authentication. Exit-node approval is the daemon's
#   report, not a fresh admin-console query. Complete the external tests below.
#
# NETWORK AND ROUTER ADVICE (SEPARATE FROM MINI SETUP)
#   This advice depends on your network. The script does not inspect or change
#   router settings and does not require a particular router or firewall.
#   - If your router has a firewall that blocks unsolicited internet connections,
#     keep it enabled. Do not forward public TCP ports 22 (SSH) or 5900 (Screen
#     Sharing) to the Mini. Use its Tailscale address for remote access.
#   - For FileVault SSH unlock from another site, arrange an independent network
#     path to the Mini's LAN address. The locked Mini cannot provide its own
#     Tailscale connection or exit node. Options include:
#     - Another always-on device at that site acting as a Tailscale subnet router.
#     - A suitable VPN on the site's router or another independent VPN gateway.
#
#       Your computer -> separate VPN/subnet router -> Mini's LAN IP -> SSH unlock
#
#     The separate router/gateway and site network must also survive or recover
#     from an outage. See "FileVault and recovery" below for unlock requirements.
#   - Consider a UPS for the Mini and network equipment to improve recovery
#     from power interruptions.
#
# 7. TEST REMOTE ACCESS, EXIT ROUTING AND RECOVERY
#   From another device on the same tailnet, preferably on a different Internet
#   connection (such as a hotspot):
#   - Run "ssh ACCOUNT@TAILSCALE_IP" using the Mini's short account name. Verify
#     the selected method and authentication. With native SSH, verify the host
#     fingerprint against an independently recorded value. Locally:
#       sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
#     Tailscale SSH uses its own host keys and Tailscale identity/access rules;
#     the native sshd fingerprint above does not verify that service.
#   - If Screen Sharing is enabled, test "vnc://TAILSCALE_IP" using the Mini's
#     account credentials. A working MagicDNS name can replace the Tailscale IP.
#   - Select this Mini as your client's exit node. Test HTTPS browsing, DNS and
#     public egress IP. Restore the client's preferred exit-node selection afterward.
#   - Server: restart with local assistance still available, leave at the login
#     window without desktop login, and repeat the remote tests. Disconnect the
#     display and repeat in the actual headless configuration before deployment.
#   - Home: test the recovery behavior you chose. With FileVault on, arrange a
#     disk unlock locally or, on supported Macs, over the separate SSH path
#     described under "FileVault and recovery". Authentication is still needed;
#     test the actual cold-boot/power-recovery case before relying on it.
#     Verify services remain available when the display sleeps.
#   - Test chosen power-recovery behavior in a planned local maintenance window.
#     Never pull power during updates or writes. Normal shutdown does not test
#     restart after power failure. Record the recovery case actually tested.
#   Do not rely on either Mini remotely until its intended operating tests pass.
#
# TERMINAL ACCESS OVER SSH (AFTER INITIAL PREPARATION)
#   Remote setup works with either profile and either selected SSH method.
#   The account, selected SSH method, Homebrew formula and connected Homebrew
#   Tailscale ROOT boot service must already exist. Native (default) requires
#   Remote Login and Tailscale SSH OFF. --ssh tailscale requires Tailscale SSH ON
#   and accepts native Remote Login OFF. Neither choice changes SSH settings.
#   Server additionally requires FileVault fully off; home preserves FileVault.
#   Both require incoming connections over Tailscale already allowed. Remote
#   setup does not bootstrap, migrate or restart Tailscale.
#   A logged-in desktop is unnecessary once macOS and its disk are accessible.
#   This setup command is for an already unlocked Mac. FileVault SSH unlock is
#   a separate startup procedure; see "FileVault and recovery" below.
#   From your other computer (connected to the same tailnet):
#
#     ssh -t ACCOUNT@TAILSCALE_IP
#
#   Verify the selected SSH service's identity. Native SSH can also use a LAN IP;
#   Tailscale SSH requires the Tailscale address. A working MagicDNS name can
#   replace TAILSCALE_IP. In the resulting terminal ON THE MINI:
#
#     curl -fsSLo ~/mac-mini.sh https://ahdxb.github.io/mini/mac-mini.sh
#     less ~/mac-mini.sh
#     bash ~/mac-mini.sh setup-remote --profile server
#     # For an existing Tailscale SSH connection, use instead:
#     bash ~/mac-mini.sh setup-remote --profile server --ssh tailscale
#
#   For the home Mini, use "setup-remote --profile home" instead. Both profiles
#   apply the same power settings. Do not prefix setup-remote with sudo. It verifies
#   prerequisites, shows the identity/profile and asks for SETUP. It preserves
#   name, tailnet, SSH/DNS/routing/access preferences and running services, changing
#   only exit-node advertisement and required power settings. It never opens GUI
#   apps, upgrades software, reauthenticates, restarts services or reboots.
#   Keep a second SSH session open, then verify a NEW connection afterward.
#   Open printed approval URLs on your own computer. Each run prints a private
#   progress log in your home folder. On a dropped connection, reconnect and
#   rerun the same command/options; it rechecks live state and skips completed work.
#   Do not run concurrent setup sessions or change Tailscale settings during setup.
#   Working access now cannot guarantee access after network/power/OS failure.
#
# FILEVAULT AND RECOVERY
#   FileVault protects access to stored data using your credentials. With it ON,
#   startup can wait for an authorized disk unlock. While the data volume is
#   locked, this Mini's Homebrew Tailscale daemon and exit-node service are not
#   available. A Mac can therefore power on and still be unreachable over its
#   own Tailscale connection until someone unlocks it.
#
#   The server profile requires FileVault OFF so this setup can recover without
#   an unlock or an extra recovery device after a cold boot/power loss. Turning
#   it off reduces protection against physical access to stored data. It does
#   not turn on automatic desktop login or remove normal login/SSH authentication.
#   This is the tradeoff of this server design, not a universal requirement for
#   running a Mac server. The script never changes FileVault itself.
#
#   macOS 26 or later: SSH-unlock exception on Apple silicon
#     Apple supports unlocking FileVault over SSH after a restart when Remote
#     Login was enabled beforehand and suitable networking is available. You
#     still authenticate with credentials authorized to unlock FileVault.
#     This native startup SSH service is separate from Tailscale SSH and from
#     running "setup-remote" after the Mac is unlocked.
#
#   From another site, use the independent network path described under
#   "Network and router advice" above. A device already on the same LAN can
#   connect directly if networking permits. The Mini's own Tailscale IP is not
#   a route to its pre-unlock SSH service. After the unlock, macOS can start the
#   normal Tailscale daemon and exit-node service.
#
#   SSH unlock enables remote intervention; it does not make recovery automatic.
#   Verify hardware/OS support, authorized credentials, pre-unlock networking and
#   the actual recovery scenario with local assistance available. This script
#   neither configures nor validates that alternative recovery path. Its server
#   setup and checks still require FileVault fully OFF, including on macOS 26+.
#   Home continues to preserve FileVault; plan and test its unlock path yourself.
#   See the Apple FileVault and Tailscale subnet-router sources in REFERENCES.
#
# REPLACEMENT DETAILS
#   Keep this script and account/MFA recovery independently of both Minis. Use
#   the same profile/options on a replacement and enroll it as a NEW Tailscale
#   device; never copy old Tailscale state. Retire the confirmed failed device,
#   reuse its name if desired, and repeat approvals and expiry choices. IP and
#   SSH host keys can change. Verify the new fingerprint independently before
#   changing known_hosts. Update saved SSH/Screen Sharing/exit-node selections.
#
# UPDATES AND LIMITS
#   Update one Mini at a time with local access or a tested recovery path. The
#   restart can disconnect SSH and exit-node clients; do not begin over your
#   only connection without recovery. Complete upgrade AND restart in the same
#   maintenance session. On Apple Silicon:
#     /opt/homebrew/bin/brew update
#     /opt/homebrew/bin/brew upgrade tailscale
#     sudo /opt/homebrew/bin/brew services restart tailscale
#   Intel Homebrew uses /usr/local. Inspect upgrade errors before continuing:
#   cleanup can fail after installation succeeds, but other failures need repair.
#   Upgrade selects a new, account-owned daemon through the opt link. A crash or
#   reboot can launch it even while a planned restart is deferred. Restart
#   reapplies selected root ownership changes; it need not fix writable modes.
#   "services start" and either setup command leave an already running service
#   alone. setup-remote never upgrades or restarts Tailscale.
#
#   Recheck the same profile/options, a NEW remote connection, and exit-node/DNS
#   tests after restart. If restart fails, use recovery and retain both versions.
#   Upgrade/reinstall/uninstall can leave protected remnants or .reinstall
#   backups. Only after verifying the replacement works, review the exact obsolete
#   Cellar/tailscale/<version> path in the cleanup error and remove that remnant
#   with sudo rm -rf followed by its quoted absolute path. Never remove current
#   versions, opt/linked paths, the whole Cellar/tailscale directory, or a version
#   glob. Do not upgrade as root or chown the live keg to suppress cleanup errors.
#
#   Ownership checks inspect selected files and Unix write bits, not parent
#   directories, ACLs, binary integrity or the running binary version. Homebrew's
#   account-controlled paths prevent these checks from establishing a security
#   boundary against that account or guaranteeing safe future launches.
#   Boot recovery still needs macOS, disk access and networking. See "Network and
#   router advice" for recovery planning. No alerts are installed; local checks
#   cannot prove remote authentication or exit routing.
#
# KEEPING IT SHARED
#   Sonar is the private master. Pushes to main publish only mac-mini.sh, the
#   download index and .nojekyll to public ahdxb/mini, and update the secret Gist.
#   Publishing waits for Linux/macOS tests, including on workflow/template/test
#   changes and manual dispatches. Pull requests run tests without publishing.
#   Private Git history stays in Sonar; this script is public at BOTH destinations.
#   Pages: https://ahdxb.github.io/mini/mac-mini.sh
#   Gist fallback:
#     curl -fsSLo ~/mac-mini.sh \
#       https://gist.githubusercontent.com/ahdxb/7dc7377a171872ef677cedc8eff592bc/raw/mac-mini.sh
#   Allow time for publishing. Pages uses Sonar's MINI_DEPLOY_KEY secret (write
#   access to mini only); Gist uses GIST_TOKEN. Never put credentials in this file.
#   Rerun the download command in step 3 for updates; setup does not update itself.
#
# REFERENCES
#   https://docs.brew.sh/Installation
#   https://github.com/tailscale/tailscale/wiki/Tailscaled-on-macOS
#   https://tailscale.com/docs/concepts/macos-variants
#   https://tailscale.com/docs/reference/tailscale-cli
#   https://tailscale.com/docs/features/exit-nodes
#   https://support.apple.com/guide/mac-help/flvlt001/mac
#   https://support.apple.com/en-ca/guide/security/sec8447f5049/web
#   https://tailscale.com/docs/features/subnet-routers
#   https://www.youtube.com/watch?v=833pTn_3HYI
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

# Parse explicit profile/options. Default to home, which accepts FileVault ON.
case "$MODE" in setup|setup-remote|check) ;; *) die 'Choose help, setup, setup-remote, or check.' ;; esac
shift
PROFILE=home
SSH_MODE=native
REQUIRE_SCREEN_SHARING=false
NAME=''
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      [ $# -ge 2 ] || die '--profile requires home or server.'
      PROFILE=$2; shift 2 ;;
    --ssh)
      [ $# -ge 2 ] || die '--ssh requires native, tailscale, or any (check only).'
      SSH_MODE=$2; shift 2 ;;
    --require-screen-sharing)
      [ "$MODE" = check ] || die '--require-screen-sharing is a check option.'
      REQUIRE_SCREEN_SHARING=true; shift ;;
    --hostname)
      [ "$MODE" = setup ] || die '--hostname is supported only in local setup; remote setup preserves the name.'
      [ $# -ge 2 ] || die '--hostname requires a DNS name.'
      NAME=$2
      [[ "$NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] && [ ${#NAME} -le 63 ] || die 'Use 1–63 lower-case letters, digits and internal hyphens.'
      shift 2 ;;
    *) die "Unknown option: $1" ;;
  esac
done
case "$PROFILE" in
  home|server) ;;
  *) die '--profile must be home or server.' ;;
esac
case "$SSH_MODE" in
  native) SSH_ENABLED=false ;;
  tailscale) SSH_ENABLED=true ;;
  any)
    [ "$MODE" = check ] || die '--ssh any is supported only in check mode.'
    SSH_ENABLED='' ;;
  *) die '--ssh must be native, tailscale, or any (check only).' ;;
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
# network advice after step 6 or SSH reference after step 7. It removes comment
# markers before printing.
# Inside awk, $0 means the input line; outside awk, "$0" is this script's path.
show_step() {
  awk -v n="$1" '
    $0 ~ "^# " n "\\. " { show=1; found=1 }
    show && /^# [0-9]+\. / && $0 !~ "^# " n "\\. " { exit }
    show && /^# (NETWORK AND ROUTER ADVICE|TERMINAL ACCESS OVER SSH|REPLACEMENT DETAILS)/ { exit }
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

# Read preferences on both newer CLIs and releases without "get" (e.g. 1.98.8).
# Normalize only the three fields used below. Missing or unexpected debug fields
# stay absent, so checks remain UNKNOWN and remote preflight refuses to proceed.
read_preferences() {
  local output=$1 pair value count index route v4=false v6=false valid=true advertised=''
  shift
  if run_timed "$@" get --json >"$output" 2>"$output.get.err"; then return 0; fi
  if ! grep -Fq 'unknown subcommand: get' "$output.get.err"; then
    cat "$output.get.err" >&2
    return 1
  fi
  run_timed "$@" debug prefs >"$output.debug" || return 1
  printf '{' >"$output"
  for pair in ssh:RunSSH shields-up:ShieldsUp; do
    if value=$(plutil -extract "${pair#*:}" raw -expect bool -o - "$output.debug" 2>/dev/null); then
      case "$value" in
        true|false) printf '"%s":%s,' "${pair%:*}" "$value" >>"$output" ;;
      esac
    fi
  done
  if count=$(plutil -extract AdvertiseRoutes raw -expect array -o - "$output.debug" 2>/dev/null); then
    for ((index=0; index<count; index++)); do
      if route=$(plutil -extract "AdvertiseRoutes.$index" raw -expect string -o - "$output.debug" 2>/dev/null); then
        case "$route" in 0.0.0.0/0) v4=true ;; ::/0) v6=true ;; esac
      else valid=false; fi
    done
    if [ "$valid" = true ]; then
      advertised=false
      if [ "$v4" = true ] && [ "$v6" = true ]; then advertised=true; fi
    fi
  elif [ "$(plutil -type AdvertiseRoutes "$output.debug" 2>/dev/null)" = '(any)' ]; then
    # plutil reports JSON null as (any); a null Go route slice advertises nothing.
    advertised=false
  fi
  if [ -n "$advertised" ]; then printf '"advertise-exit-node":%s,' "$advertised" >>"$output"; fi
  # A sentinel avoids trailing commas without copying unrelated debug data.
  printf '"_normalized":true}\n' >>"$output"
}

# Verify the chosen SSH preference without changing either access method.
require_selected_ssh() {
  local value
  value=$(plutil -extract ssh raw -expect bool -o - "$1" 2>/dev/null) || die 'Cannot verify Tailscale SSH preference. No SSH settings were changed.'
  case "$value" in true|false) ;; *) die 'Unrecognized Tailscale SSH preference. No SSH settings were changed.' ;; esac
  [ "$value" = "$SSH_ENABLED" ] ||
    die "Selected --ssh $SSH_MODE requires Tailscale SSH=$SSH_ENABLED. Setup preserves SSH settings; prepare the selected method separately or choose the method already in use."
}

# Discover common installation markers, not whether they are running. Both
# setup and check use this list. A dangling marker also needs manual review.
# Under sudo, use the invoking account's home rather than root's HOME. Keep
# global results even when the invoking account's home cannot be resolved.
find_tailscale_installations() {
  local other account_home=$HOME
  for other in /Applications/Tailscale.app \
    /Library/LaunchDaemons/com.tailscale.tailscaled.plist; do
    if [ -e "$other" ] || [ -L "$other" ]; then printf '%s\n' "$other"; fi
  done
  if [ "$(id -u)" = 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
    account_home=$(sudo -n -H -u "$SUDO_USER" printenv HOME 2>/dev/null) || return 1
    case "$account_home" in /*) ;; *) return 1 ;; esac
  fi
  for other in "$account_home/Applications/Tailscale.app" \
    "$account_home/Library/LaunchAgents/homebrew.mxcl.tailscale.plist"; do
    if [ -e "$other" ] || [ -L "$other" ]; then printf '%s\n' "$other"; fi
  done
}
check_tailscale_installation() {
  local other
  other=$(find_tailscale_installations) || die 'Cannot resolve the invoking account home for Tailscale installation checks.'
  [ -z "$other" ] || die "Another Tailscale installation exists: $other. Resolve migration locally first."
}

# Both profiles require these power settings. Used by local setup, SSH setup,
# and the read-only checker.
validate_power_settings() {
  local key
  for key in sleep autorestart; do
    awk -v k="$key" '$1==k {n++; if ($2 !~ /^[0-9]+$/) bad=1} END {exit !(n && !bad)}' "$1" ||
      die "Cannot verify required power setting $key."
  done
}
setup_progress() { printf '%s\n' "$*"; }
apply_power_settings() {
  local setting key value
  for setting in sleep:0 autorestart:1; do
    key=${setting%:*}; value=${setting#*:}
    if awk -v k="$key" -v v="$value" '$1==k {n++; if ($2!=v) bad=1} END {exit !(n && !bad)}' "$1"; then
      setup_progress "Power setting $key=$value already applied; skipped."
    else
      setup_progress "Applying power setting $key=$value."
      sudo -n pmset -a "$key" "$value"
      setup_progress "Power setting $key=$value applied."
    fi
  done
}
show_profile_plan() {
  printf 'Profile: %s\n' "$PROFILE"
  printf 'SSH method: %s. Preserve existing SSH settings; never enable or disable SSH automatically.\n' "$SSH_MODE"
  if [ "$PROFILE" = server ]; then
    printf 'FileVault must already be OFF; accounts and security settings remain manual.\n'
  else
    printf 'Preserve FileVault, accounts, login and lock-screen settings.\n'
  fi
  printf 'Required: prevent computer sleep (sleep=0).\n'
  printf 'Required: enable restart after power failure (autorestart=1).\n'
}
# Pass exactly the selected requirements to the child checker. Profiles are
# explicit per invocation, so this does not depend on sudo preserving variables.
finish_setup() {
  local result=0
  local check_args=(check --profile "$PROFILE" --ssh "$SSH_MODE")
  manual_step 5
  sudo /bin/bash "$0" "${check_args[@]}" || result=$?
  show_step 7
  setup_progress "Local checks returned $result; complete the external tests for profile $PROFILE."
  return "$result"
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
  # Color labels only on a terminal; keep redirected output free of escape codes.
  PASS_COLOR='' FAIL_COLOR='' COLOR_RESET=''
  if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${NO_COLOR:-}" ]; then
    PASS_COLOR=$'\033[32m'
    FAIL_COLOR=$'\033[31m'
    COLOR_RESET=$'\033[0m'
  fi
  pass() { printf '%sPASS%s     %s\n' "$PASS_COLOR" "$COLOR_RESET" "$*"; }
  fail() { printf '%sFAIL%s     %s\n' "$FAIL_COLOR" "$COLOR_RESET" "$*"; BAD=$((BAD+1)); }
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
  # Older CLIs fall back to validated fields from "debug prefs".
  # Keep stderr privately. On failure, append its first nonempty line (up to 240 characters);
  # with no detail, use the generic error message.
  # Signal exit codes alone are not treated as proof of a timeout.
  printf 'Local checks, %s (profile: %s; SSH: %s)\n' "$(date '+%Y-%m-%d %H:%M %Z')" "$PROFILE" "$SSH_MODE"

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

  SSH_PREF=unknown
  TS_SSH_RUNNING=unknown

  # Report all competing markers and continue other diagnostics. Do not query a
  # possibly competing CLI when discovery is incomplete or a marker is present.
  TS_INSTALLATION_OK=true
  COMPETING_TS=$(find_tailscale_installations) || {
    unknown 'Cannot resolve the invoking account home for Tailscale installation checks'
    TS_INSTALLATION_OK=false
  }
  while IFS= read -r other; do
    [ -n "$other" ] || continue
    fail "Another Tailscale installation exists: $other. Resolve migration locally first."
    TS_INSTALLATION_OK=false
  done <<< "$COMPETING_TS"
  if [ "$TS_INSTALLATION_OK" != true ]; then
    printf 'INFO     Tailscale status/preferences queries skipped; no installation was changed.\n'
  elif [ -x "$TS" ]; then          # Query only the expected Homebrew CLI
    if read_tailscale status --json >"$TMP/status" 2>"$TMP/status.err"; then
                                    # Copy Tailscale's status as JSON into a file
      expect "$TMP/status" BackendState Running 'Tailscale running'
                                    # PASS if Tailscale’s backend state is exactly Running
      expect "$TMP/status" Self.Online true 'Tailscale connected to control server'
                                    # PASS if this Mac is currently connected to Tailscale's servers
      expect "$TMP/status" Self.ExitNodeOption true 'Exit node advertised and approved (reported by Tailscale)'
      if [ "$SSH_MODE" = any ]; then
        TS_BACKEND=$(field "$TMP/status" BackendState || true)
        TS_ONLINE=$(field "$TMP/status" Self.Online || true)
        if [ "$TS_BACKEND" = Running ] && [ "$TS_ONLINE" = true ]; then
          TS_SSH_RUNNING=true
        elif [ -n "$TS_BACKEND" ] && { [ "$TS_ONLINE" = true ] || [ "$TS_ONLINE" = false ]; }; then
          TS_SSH_RUNNING=false
        fi
      fi
                                    # PASS if Tailscale says this Mac is an approved exit node.
      printf 'Identity: %s / %s\n' "$(field "$TMP/status" CurrentTailnet.Name || printf unknown)" \
        "$(field "$TMP/status" Self.DNSName || printf unknown)"
                                    # Print the tailnet and this Mac's Tailscale name for eyeballing
    else
      DETAIL=$(awk 'NF {print substr($0, 1, 240); exit}' "$TMP/status.err")
      unknown "Cannot read Tailscale status${DETAIL:+: $DETAIL}"
    fi
    if read_preferences "$TMP/prefs" "$TS" 2>"$TMP/prefs.err"; then
                                    # Copy Tailscale's settings as JSON into a file
      expect "$TMP/prefs" advertise-exit-node true 'Exit node advertised'
                                    # PASS if this Mac is set to offer itself as an exit node
      SSH_PREF=$(plutil -extract ssh raw -expect bool -o - "$TMP/prefs" 2>/dev/null) || SSH_PREF=unknown
      if [ "$SSH_MODE" = any ]; then
        : # Report either available method after probing native SSH below.
      elif [ "$SSH_PREF" = true ] || [ "$SSH_PREF" = false ]; then
        if [ "$SSH_PREF" = "$SSH_ENABLED" ]; then
          pass "Selected SSH method: $SSH_MODE (Tailscale SSH=$SSH_ENABLED)"
        else fail "Selected SSH method: $SSH_MODE requires Tailscale SSH=$SSH_ENABLED"; fi
      else
        unknown 'Cannot read Tailscale SSH preference'
      fi
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
  SERVICE_RUNNING=false
  if [ -f /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist ] &&
                                  # True if Tailscale’s boot-time launchd plist file exists
     launchctl print system/homebrew.mxcl.tailscale >"$TMP/service" 2>/dev/null &&
                                  # Dump the root-domain service's live state to a temp file
     grep -q 'state = running' "$TMP/service"; then
    SERVICE_RUNNING=true
    pass 'Tailscale system boot service running'
                                  # If the dump says "running", report PASS
  else fail 'Expected Homebrew Tailscale startup service is missing or stopped'; fi

  # Inspect files without executing the daemon or changing ownership. stat -L
  # follows symlinks, so these checks inspect the currently linked target.
  # They deliberately do not claim that writable ancestors/ACLs are safe.
  check_root_permissions() {
    local path=$1 label=$2 kind=$3 metadata owner permissions
    if [ ! -e "$path" ]; then
      fail "$label missing or dangling: $path"
    elif { [ "$kind" = file ] && { [ ! -f "$path" ] || [ ! -x "$path" ]; }; } ||
         { [ "$kind" = directory ] && [ ! -d "$path" ]; }; then
      fail "$label has the wrong type or is not executable: $path"
    elif metadata=$(stat -L -f '%u %Lp' "$path" 2>/dev/null) &&
         [[ "$metadata" =~ ^[0-9]+[[:space:]][0-7]{1,4}$ ]]; then
      owner=${metadata%% *}; permissions=${metadata#* }
      if [ "$owner" = 0 ] && [ "$((8#$permissions & 0022))" = 0 ]; then
        pass "$label root-owned; Unix group/other write bits clear (limited check)"
      else
        fail "$label permissions: uid=$owner mode=$permissions; expected root and no group/other write bits"
      fi
    else
      unknown "Cannot read $label ownership/mode: $path"
    fi
  }
  check_boot_plist() {
    local plist=$1 expected=$2 program username
    if [ ! -f "$plist" ]; then
      fail "Tailscale boot plist missing: $plist"
      return
    fi
    # The plist need not be executable, unlike the daemon.
    check_root_permissions "$plist" 'Tailscale boot plist' plist
    if ! plutil -lint "$plist" >/dev/null 2>&1; then
      unknown 'Cannot parse Tailscale boot plist'
      return
    fi
    # launchd gives Program precedence over ProgramArguments[0]. A present but
    # malformed Program must not silently fall back to the argument array.
    if plutil -type Program "$plist" >/dev/null 2>&1; then
      program=$(plutil -extract Program raw -expect string -o - "$plist" 2>/dev/null) || {
        unknown 'Cannot read Tailscale boot plist Program'; return;
      }
    else
      program=$(plutil -extract ProgramArguments.0 raw -expect string -o - "$plist" 2>/dev/null) || {
        unknown 'Cannot read Tailscale boot plist ProgramArguments.0'; return;
      }
    fi
    if [ "$program" = "$expected" ]; then
      pass 'Tailscale boot plist selects the expected Homebrew daemon path'
    else
      fail "Tailscale boot plist selects an unexpected program: $program"
    fi
    if plutil -type UserName "$plist" >/dev/null 2>&1; then
      if username=$(plutil -extract UserName raw -expect string -o - "$plist" 2>/dev/null); then
        [ "$username" = root ] && pass 'Tailscale boot plist selects root' ||
          fail "Tailscale boot plist selects non-root UserName: $username"
      else unknown 'Cannot read Tailscale boot plist UserName'; fi
    else pass 'Tailscale system boot plist uses the default root user'; fi
  }
  EXPECTED_DAEMON="${BREW%/bin/brew}/opt/tailscale/bin/tailscaled"
  printf '\nTailscale launch files (limited read-only checks)\n'
  PERMISSION_FAILURES=$BAD
  check_boot_plist /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist "$EXPECTED_DAEMON"
  if [ "$SERVICE_RUNNING" = true ]; then
    LOADED_PROGRAM=$(sed -n 's/^[[:space:]]*program = //p' "$TMP/service" | head -n 1)
    if [ -z "$LOADED_PROGRAM" ]; then
      unknown 'Cannot read loaded Tailscale program path from launchctl'
    elif [ "$LOADED_PROGRAM" = "$EXPECTED_DAEMON" ]; then
      pass 'Loaded Tailscale service selects the expected Homebrew daemon path'
    else fail "Loaded Tailscale service selects an unexpected program: $LOADED_PROGRAM"; fi
  fi
  printf 'INFO     Linked daemon inspected: %s\n' "$EXPECTED_DAEMON"
  check_root_permissions "$EXPECTED_DAEMON" 'Tailscale linked daemon' file
  check_root_permissions "${EXPECTED_DAEMON%/*}" 'Tailscale linked bin directory' directory
  printf 'INFO     Limited file checks: no parent-directory, ACL, integrity or running-version audit.\n'
  printf 'INFO     The Homebrew account can still replace launch paths; passing does not guarantee safe future launches. See UPDATES AND LIMITS.\n'
  if [ "$BAD" != "$PERMISSION_FAILURES" ]; then
    printf 'MANUAL   Review UPDATES AND LIMITS. After an upgrade, complete the planned service restart with a recovery path, then recheck.\n'
    printf 'INFO     No ownership repairs or service restarts were attempted.\n'
  fi

  # Both profiles require computer sleep off and restart after power failure on.
  if pmset -g custom >"$TMP/power" 2>/dev/null; then
    for setting in sleep:0 autorestart:1; do
      key=${setting%:*}; value=${setting#*:}
      if awk -v k="$key" -v v="$value" '$1==k {n++; if ($2!=v) bad=1} END {exit !(n && !bad)}' "$TMP/power"; then
        pass "Power setting $key=$value"
      else fail "Required power setting $key should be $value"; fi
    done
  else
    unknown 'Cannot read required power settings'
  fi

  if fdesetup status >"$TMP/filevault" 2>/dev/null; then
    if [ "$PROFILE" = server ]; then
      if grep -Fxq 'FileVault is Off.' "$TMP/filevault"; then pass 'FileVault off for server unattended cold boot';
      else fail 'Server profile requires FileVault fully off'; fi
    else
      printf 'INFO     %s (home choice preserved; unlock may be needed after cold boot)\n' "$(head -n 1 "$TMP/filevault")"
    fi
  elif [ "$PROFILE" = server ]; then unknown 'Cannot read FileVault status';
  else printf 'INFO     Cannot read FileVault status (home choice preserved)\n'; fi

  # The selected method determines whether native SSH is required.
  # Local TCP probes do not test authentication or reachability from a client.
  if [ "$SSH_MODE" = any ]; then
    if nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1; then
      pass 'SSH method any: native SSH accepts TCP on localhost port 22'
    elif [ "$SSH_PREF" = true ] && [ "$TS_SSH_RUNNING" = true ]; then
      pass 'SSH method any: Tailscale SSH enabled on a running, connected node'
    elif [ "$SSH_PREF" = unknown ] || { [ "$SSH_PREF" = true ] && [ "$TS_SSH_RUNNING" = unknown ]; }; then
      unknown 'Native SSH unavailable; cannot verify Tailscale SSH availability'
    else fail 'Neither native SSH nor Tailscale SSH is available'; fi
    printf 'MANUAL   Test a new SSH connection from an authorized client; local checks do not verify SSH policy or authentication.\n'
  elif [ "$SSH_MODE" = native ]; then
    if nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1; then
      pass 'Local port 22 accepts TCP (SSH)'
    else fail 'Local port 22 unavailable; check Remote Login'; fi
  else
    printf 'INFO     Native SSH on localhost port 22 is optional with --ssh tailscale.\n'
    printf 'MANUAL   Test a new Tailscale SSH connection from an authorized client; local checks do not verify SSH policy or authentication.\n'
  fi
  if nc -z -G 3 127.0.0.1 5900 >/dev/null 2>&1; then
    pass 'Local port 5900 accepts TCP (Screen Sharing)'
  elif [ "$REQUIRE_SCREEN_SHARING" = true ]; then
    fail 'Local port 5900 unavailable; Screen Sharing was explicitly required'
  else printf 'INFO     Screen Sharing unavailable on port 5900 (optional)\n'; fi

  # Query release metadata directly instead of running brew update/outdated,
  # which can refresh the installation or package caches. Only TMP is written.
  report_update() {
    local label=$1 installed=$2 latest=$3 comparison
    if ! [[ "$installed" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
       ! [[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      printf 'INFO     %s update check unavailable (cannot compare stable release versions)\n' "$label"
      return
    fi
    comparison=$(awk -v current="$installed" -v latest="$latest" 'BEGIN {
      split(current, a, "."); split(latest, b, ".")
      for (i=1; i<=3; i++) {
        if (a[i]+0 < b[i]+0) { print "older"; exit }
        if (a[i]+0 > b[i]+0) { print "newer"; exit }
      }
      print "same"
    }')
    case "$comparison" in
      older) printf 'INFO     %s update available: %s -> %s\n' "$label" "$installed" "$latest" ;;
      same) printf 'INFO     %s up to date: %s\n' "$label" "$installed" ;;
      newer) printf 'INFO     %s installed %s is newer than latest stable %s\n' "$label" "$installed" "$latest" ;;
    esac
  }
  brew_update_version() (
    # Root may not see Homebrew's Git version. Query as the original sudo user,
    # from an accessible directory, without changing the main check's context.
    cd / || return 1
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
      run_timed sudo -n -H -u "$SUDO_USER" env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 "$BREW" --version
    else
      run_timed env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 "$BREW" --version
    fi
  )
  fetch_release() {
    curl -q --fail --silent --show-error --location --proto '=https' \
      --connect-timeout 3 --max-time 8 "$1" -o "$2"
  }
  printf '\nSoftware updates (informational; no changes applied)\n'
  if brew_update_version >"$TMP/brew-version" 2>"$TMP/brew-version.err" &&
     fetch_release https://api.github.com/repos/Homebrew/brew/releases/latest "$TMP/brew-release" 2>"$TMP/brew-release.err"; then
    INSTALLED_VERSION=$(awk 'NR==1 && $1=="Homebrew" {print $2}' "$TMP/brew-version")
    LATEST_VERSION=$(field "$TMP/brew-release" tag_name || true)
    report_update Homebrew "$INSTALLED_VERSION" "${LATEST_VERSION#v}"
  else printf 'INFO     Homebrew update check unavailable (version query or online lookup failed)\n'; fi
  if [ "$TS_INSTALLATION_OK" != true ] || [ ! -x "$TS" ]; then
    printf 'INFO     Tailscale update check skipped (expected Homebrew-only installation unavailable)\n'
  elif read_tailscale version >"$TMP/ts-version" 2>"$TMP/ts-version.err" &&
       fetch_release https://formulae.brew.sh/api/formula/tailscale.json "$TMP/ts-release" 2>"$TMP/ts-release.err"; then
    INSTALLED_VERSION=$(head -n 1 "$TMP/ts-version")
    LATEST_VERSION=$(field "$TMP/ts-release" versions.stable || true)
    report_update 'Tailscale (Homebrew)' "$INSTALLED_VERSION" "$LATEST_VERSION"
  else printf 'INFO     Tailscale update check unavailable (version query or online lookup failed)\n'; fi

  # Summarize and return a result
  # -----------------------------
  # List the tests that still need a person or another device. Confirmed failures
  # return exit 1; otherwise unknown results return exit 2. With neither, explicitly
  # exit 0 after the success message. This means only the local checks passed.
  printf '\nMANUAL: verify identity, node expiry, client permissions, remote SSH, optional\n'
  printf 'Screen Sharing, exit-node browsing and DNS. Follow step 7 for profile %s.\n' "$PROFILE"
  printf 'Local TCP is not an authentication test. Home FileVault settings can\n'
  printf 'limit cold-boot recovery. No alerts or repairs are made.\n'
  printf '\nResult: %s failed; %s unknown.\n' "$BAD" "$UNKNOWN"
  [ "$BAD" = 0 ] || exit 1
  [ "$UNKNOWN" = 0 ] || exit 2
  printf 'All automated local checks passed; complete the manual checks above.\n'
  exit 0
fi

# REMOTE SETUP: finish a prepared Mini without changing its access method.
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
  setup_progress() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" | tee -a "$REMOTE_LOG"; }
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
    read_preferences "$TMP/prefs" sudo -n "$TS" || die 'Cannot read Tailscale preferences. No configuration was changed.'
    # Require the chosen method without changing the connection used for setup.
    require_selected_ssh "$TMP/prefs"
    [ "$(field "$TMP/prefs" shields-up)" = false ] ||
      die 'Incoming tailnet connections must already be allowed. Remote setup will not change access settings.'
    value=$(field "$TMP/prefs" advertise-exit-node) || die 'Cannot read exit-node advertisement preference.'
    case "$value" in true|false) ;; *) die 'Unrecognized exit-node advertisement preference.' ;; esac
    if [ "$SSH_MODE" = native ]; then
      nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1 || die 'Native SSH must already listen on port 22. Resolve Remote Login locally.'
    fi
    if [ "$PROFILE" = server ]; then
      sudo -n fdesetup status >"$TMP/filevault" || die 'Cannot verify FileVault. Complete local preparation first.'
      grep -Fxq 'FileVault is Off.' "$TMP/filevault" || die 'Server profile requires FileVault fully off. Resolve locally first.'
    fi
    pmset -g custom >"$TMP/power" || die 'Cannot read required power settings.'
    validate_power_settings "$TMP/power"
  }

  remote_preflight
  setup_progress 'Preflight passed; no configuration changed.'
  REMOTE_TAILNET=$(field "$TMP/status" CurrentTailnet.Name)
  REMOTE_NAME=$(field "$TMP/status" Self.DNSName)
  printf 'Existing identity: %s / %s\n' "$REMOTE_TAILNET" "$REMOTE_NAME"
  show_profile_plan
  cat <<'REMOTE_PLAN'
This advertises this Mini as an exit node and applies required power settings.
Completed settings are skipped on reruns. It preserves the existing name, tailnet,
SSH/DNS/routing/access preferences and running services. No installs, upgrades,
GUI apps, service restarts or reboots are requested. Verify the identity above.
Keep a second SSH session open, then test a NEW connection afterward. Open the
printed admin URL on your own computer.
REMOTE_PLAN
  printf 'Type SETUP to apply these changes: '
  IFS= read -r CONFIRM
  [ "$CONFIRM" = SETUP ] || { setup_progress 'Cancelled; no configuration changed.'; exit 0; }
  # Refresh sudo and recheck live state after the user has reviewed the plan.
  sudo -v
  remote_preflight
  [ "$(field "$TMP/status" CurrentTailnet.Name)" = "$REMOTE_TAILNET" ] &&
    [ "$(field "$TMP/status" Self.DNSName)" = "$REMOTE_NAME" ] ||
    die 'Tailscale identity changed while awaiting confirmation. Rerun and review the current identity.'
  if [ "$(field "$TMP/prefs" advertise-exit-node)" = true ]; then
    setup_progress 'Exit-node advertisement already enabled; skipped.'
  else
    setup_progress 'Enabling exit-node advertisement.'
    sudo -n "$TS" set --advertise-exit-node=true
    setup_progress 'Exit-node advertisement enabled.'
  fi
  apply_power_settings "$TMP/power"
  setup_progress 'Configuration applied. Exit-node approval and external tests remain.'
  RESULT=0
  finish_setup || RESULT=$?
  exit "$RESULT"
fi

# LOCAL SETUP: macOS/account/Sharing preparation is complete before launch.
# Both profiles preserve SSH settings and require the selected method prepared.
if [ "$MODE" = setup ]; then
  set -e
  [ -t 0 ] || die 'Run setup in an interactive terminal.'
  [ "$(id -u)" != 0 ] || die 'Run setup as your administrator account, without sudo.'
  [ -z "${SSH_CONNECTION:-}${SSH_TTY:-}" ] || die 'Use setup-remote through SSH; local setup can start or enroll Tailscale.'
  case " $(id -Gn) " in *' admin '*) ;; *) die 'Setup requires a local administrator account.' ;; esac
  system_profiler SPHardwareDataType | grep -q 'Model Name: Mac mini' || die 'Setup is restricted to Mac mini hardware.'
  check_tailscale_installation
  sudo -v
  umask 077
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  if [ "$SSH_MODE" = native ]; then
    nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1 || die 'Complete step 2 first: native Remote Login must already listen on port 22.'
  fi
  # Verify an existing installation before any setup changes. Tailscale SSH
  # must be prepared separately; selecting it never bootstraps or switches SSH.
  if [ -n "$BREW" ] && [ -x "${BREW%/brew}/tailscale" ] &&
     [ -f /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist ] &&
     sudo -n launchctl print system/homebrew.mxcl.tailscale >"$TMP/service" 2>/dev/null &&
     grep -q 'state = running' "$TMP/service"; then
    read_preferences "$TMP/prefs" sudo -n "${BREW%/brew}/tailscale" || die 'Cannot verify existing SSH settings. No configuration was changed.'
    require_selected_ssh "$TMP/prefs"
  elif [ "$SSH_MODE" = tailscale ]; then
    die 'Prepare the Homebrew Tailscale installation, running system service and Tailscale SSH first. Setup will not switch SSH methods.'
  fi
  if [ "$PROFILE" = server ]; then
    sudo -n fdesetup status >"$TMP/filevault" || die 'Cannot verify FileVault. Complete macOS preparation first.'
    grep -Fxq 'FileVault is Off.' "$TMP/filevault" || die 'Server profile requires FileVault fully off. Complete step 2 first.'
  fi
  pmset -g custom >"$TMP/power" || die 'Cannot read required power settings.'
  validate_power_settings "$TMP/power"
  show_profile_plan
  cat <<'PLAN'
Complete macOS preparation in step 2 BEFORE proceeding. This installs Homebrew
and the Tailscale formula if missing, reuses or starts the system boot service,
connects/enrolls if needed, and advertises exit-node service. No existing formula
is upgraded. No accounts, FileVault, login, Sharing or firewall settings are changed.
PLAN
  if [ "$PROFILE" = server ]; then
    printf 'Local server setup preserves SSH settings and allows incoming tailnet connections.\n'
  else
    printf 'Home setup preserves existing Tailscale SSH, incoming-access, DNS and routing preferences.\n'
  fi
  if [ -n "$NAME" ]; then printf 'Explicitly selected Tailscale name: %s\n' "$NAME";
  else printf 'Preserve the current Tailscale name.\n'; fi
  printf 'Type SETUP to confirm preparation is complete and apply these changes: '
  IFS= read -r CONFIRM
  [ "$CONFIRM" = SETUP ] || { printf 'Cancelled.\n'; exit 0; }

  # Install only missing dependencies, under the account user. Keep one cleanup
  # trap for all temporary files so an interrupted install can be rerun safely.
  if [ -z "$BREW" ]; then
    curl --proto '=https' --proto-redir '=https' --fail --location --show-error \
      --connect-timeout 15 --max-time 120 \
      https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
      -o "$TMP/homebrew-install.sh"
    /bin/bash "$TMP/homebrew-install.sh"
    if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew;
    elif [ -x /usr/local/bin/brew ]; then BREW=/usr/local/bin/brew;
    else die 'Homebrew installation did not finish. Resolve its error, then rerun setup.'; fi
  fi
  TS="${BREW%/brew}/tailscale"
  if ! "$BREW" list --formula tailscale >/dev/null 2>&1; then "$BREW" install --formula tailscale; fi
  sudo -v
  if [ -f /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist ] &&
    sudo -n launchctl print system/homebrew.mxcl.tailscale >"$TMP/service" 2>/dev/null &&
    grep -q 'state = running' "$TMP/service"; then
    setup_progress 'Tailscale system service already running; no restart requested.'
  else sudo -n "$BREW" services start tailscale; fi
  if run_timed sudo -n "$TS" status --json >"$TMP/status" 2>/dev/null &&
    [ "$(field "$TMP/status" BackendState)" = Running ]; then
    setup_progress 'Tailscale already connected; no enrollment requested.'
  else
    printf 'Open any printed login URL in your browser and verify the intended tailnet.\n'
    sudo "$TS" up
  fi

  read_preferences "$TMP/prefs" sudo -n "$TS" || die 'Cannot verify SSH settings; no SSH settings were changed.'
  require_selected_ssh "$TMP/prefs"

  # A nonempty array is compatible with macOS Bash 3.2 and nounset. Home changes
  # advertisement and an explicit hostname here; power settings follow below.
  TS_ARGS=(set --advertise-exit-node=true)
  if [ "$PROFILE" = server ]; then TS_ARGS+=(--shields-up=false); fi
  if [ -n "$NAME" ]; then TS_ARGS+=(--hostname="$NAME"); fi
  sudo -v
  sudo -n "$TS" "${TS_ARGS[@]}"
  pmset -g custom >"$TMP/power"
  validate_power_settings "$TMP/power"
  apply_power_settings "$TMP/power"
  sudo -n "$TS" status
  sudo -n "$TS" ip -4
  RESULT=0
  finish_setup || RESULT=$?
  printf 'No reboot was requested. No existing formula was upgraded.\n'
  exit "$RESULT"
fi
