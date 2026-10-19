#!/bin/bash
# START GUIDE
# Mac mini with Tailscale exit node: server and home setup, checks, and recovery.
# Last updated 2026-10-19.
# Download:  https://ahdxb.github.io/mini/mac-mini.sh
# Fallback:  https://gist.githubusercontent.com/ahdxb/7dc7377a171872ef677cedc8eff592bc/raw/mac-mini.sh
# Source:    https://github.com/ahdxb/Sonar (private; published to Pages and Gist)
#
# USE
#   bash mac-mini.sh | less                 Read this guide (Space, b, /, q).
#   bash mac-mini.sh setup --profile home   Local setup; preserve home settings.
#   bash mac-mini.sh setup --profile server Local setup for an unattended server.
#   bash mac-mini.sh setup-remote --profile home
#   bash mac-mini.sh setup-remote --profile server
#                                          Configure an already prepared Mini over SSH.
#   sudo bash mac-mini.sh check --profile home
#   sudo bash mac-mini.sh check --profile server
#
#   Without --profile, all modes default to home. Profiles are not saved; specify
#   the same profile and options on later checks/reruns. Changing to home does
#   not undo previous server changes. Help and check make no configuration changes.
#   Options for setup, setup-remote and check:
#     --always-on                   Set/require computer sleep=0 (display may sleep).
#     --restart-after-power-failure Set/require power-failure restart=1.
#   Server includes both power options. Home preserves them unless requested.
#   Check also accepts --require-screen-sharing. Screen Sharing is optional otherwise.
#   Local setup alone accepts --hostname NAME to explicitly change the Tailscale
#   name. Without it, the existing name is kept. SSH setup never renames the Mini.
#
# 1. CHOOSE THE PROFILE AND CREATE THE ACCOUNT
#   For a new Mini, connect Ethernet, display, keyboard and mouse and complete
#   Setup Assistant. Create a local administrator and store account recovery
#   independently of this Mini. Do not import another Mini's Tailscale identity.
#   For an existing Mini, keep its accounts and data; no clean rebuild is required.
#   - server: dedicated unattended Mini, such as France. Requires FileVault OFF
#     for this cold-boot design, prevents computer sleep and enables power recovery.
#   - home: a Mini also used for everyday work. Preserves FileVault, accounts,
#     Computer Name, sleep and power recovery settings. A display does not decide
#     the profile: a home Mini may also run continuously using --always-on.
#   Both profiles install/configure the same Homebrew Tailscale system daemon and
#   advertise exit-node service. Home preserves existing Tailscale SSH and other
#   access preferences. Local server setup explicitly selects native SSH and
#   allows incoming tailnet connections. Remote setup never changes access settings.
#   Neither profile changes FileVault, account permissions, login settings,
#   Screen Sharing or the firewall automatically. These remain manual choices.
#
# 2. PREPARE MACOS COMPLETELY BEFORE RUNNING SETUP (MANUAL)
#   Complete these tasks first, including any restarts. For an already prepared
#   Mini, verify what applies; use the SSH workflow below for remote maintenance.
#   For both profiles:
#   - Install current stable macOS updates, restart, and finish any prompts.
#     On a deployed remote Mini, schedule updates separately with a recovery plan.
#   - Verify networking and automatic date/time. Ethernet is recommended; DHCP
#     is sufficient. Keep router inbound protection; do not forward ports 22/5900.
#   - Keep or choose a Computer Name. This is separate from --hostname, which
#     changes only the Tailscale name.
#   - Enable native Remote Login for the intended account in System Settings >
#     General > Sharing. Choose permitted users. Full-disk access is unnecessary
#     merely to connect. The script checks port 22 but never edits SSH permissions.
#   - Screen Sharing is optional. Enable it only if wanted, restrict permitted
#     users, and use normal Mac-account authentication. Leave the legacy VNC
#     password off. Remote Management must be off to enable Screen Sharing.
#   - If a firewall is enabled, permit the services you intend to use. Do not
#     enable "Block all incoming connections" for these remote services.
#   Server only:
#   - FileVault OFF; verify it is fully off before setup. This reduces protection
#     against physical access to data. Keep sensitive personal data off this server.
#   - Turn automatic login and Guest User off. Require a password immediately
#     after screen lock. Let the display sleep; setup prevents computer sleep.
#   - If Energy offers "Start up when power is connected" > "Always", choose it
#     if desired. Setup also enables restart after power failure.
#   Home:
#   - Keep your existing FileVault, account, login, lock-screen and power choices.
#     FileVault ON is valid and is not a failed home check. An unattended cold
#     boot may require someone to unlock the disk before remote services return.
#   - An exit node is unavailable while the computer sleeps. Choose --always-on
#     only if continuous availability is wanted. Power recovery is a separate
#     opt-in: --restart-after-power-failure. Neither option changes FileVault.
#   Finish macOS preparation before downloading and launching setup below.
#
# 3. DOWNLOAD AND READ THE SCRIPT
#   Open Terminal on the Mini (or see "Terminal access over SSH" below):
#
#     curl -fsSLo ~/mac-mini.sh https://ahdxb.github.io/mini/mac-mini.sh
#     bash ~/mac-mini.sh | less
#
#   Read the script itself with "less ~/mac-mini.sh" before running setup.
#   No Git, GitHub CLI or access token is needed. Keep a downloaded recovery copy.
#
# 4. RUN LOCAL SETUP AFTER PREPARATION
#   Choose the intended command; do not prefix setup with sudo:
#
#     bash ~/mac-mini.sh setup --profile server --hostname le-mac-mini
#     bash ~/mac-mini.sh setup --profile home
#
#   Optional home power changes, chosen explicitly:
#
#     bash ~/mac-mini.sh setup --profile home --always-on --restart-after-power-failure
#
#   Use a unique --hostname for each Mini if renaming. Setup verifies prerequisites,
#   shows the selected profile and changes, and asks you to type SETUP. It does
#   not open a macOS-settings checklist halfway through installation. Account,
#   FileVault and Sharing choices must already be complete in step 2.
#   If Homebrew is missing, local setup runs its official installer from:
#     https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
#   The installer may request sudo and install Command Line Tools. Full Xcode is
#   unnecessary. If installation fails, resolve the installer error and rerun.
#   Homebrew runs as your account, not root. Existing formulae are not upgraded.
#   Do not install a second Tailscale app/cask. If one already exists, setup stops
#   without replacing it; resolve installation choice locally first.
#   Setup reuses a healthy running system daemon. If necessary locally, it starts
#   the Homebrew service and runs "tailscale up" to connect/enroll. Open its login
#   URL in a browser and select the intended tailnet. Complete device approval or
#   Tailnet Lock signing if required. Already connected Minis are not reauthenticated.
#   Setup advertises exit-node service, applies only the selected profile/options,
#   and preserves other preferences. It does not reboot or change accounts.
#   If existing home preferences block incoming tailnet connections, review them
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
#   Advertising, approval and client selection are three separate steps.
#   After completing this step, type DONE for setup to run local checks.
#
# 6. RUN CHECKS FOR THE SAME PROFILE AND OPTIONS
#   Setup passes its profile/power options to the checker automatically.
#   To run it again locally or through SSH:
#
#     sudo bash ~/mac-mini.sh check --profile server
#     sudo bash ~/mac-mini.sh check --profile home
#     sudo bash ~/mac-mini.sh check --profile home --always-on --restart-after-power-failure
#
#   Add --require-screen-sharing only if you require that service. Port 22 is
#   required for both profiles; port 5900 is informational by default.
#   Server checks require FileVault fully off, sleep=0, power recovery=1 and
#   Tailscale SSH off. Home reports FileVault and unselected power settings as
#   information; it checks only explicitly selected power requirements. Home
#   also reports the existing Tailscale SSH choice without requiring it off.
#   Both profiles check Tailscale connectivity, exit-node advertisement/approval,
#   incoming tailnet connections and the Homebrew system service.
#   Exit 0 means local checks passed, 1 means a failure, and 2 means incomplete
#   or unsupported checks. FileVault ON or ordinary sleep is not a home failure
#   unless you explicitly require always-on power settings that are not met.
#   The checker recognizes competing Tailscale installations without launching,
#   replacing or removing them. This file supports the Homebrew daemon only.
#   Local ports do not prove authentication. Exit-node approval is the daemon's
#   report, not a fresh admin-console query. Complete the external tests below.
#
# 7. TEST REMOTE ACCESS, EXIT ROUTING AND RECOVERY
#   From another device on the same tailnet, preferably on a different Internet
#   connection (such as a hotspot):
#   - Run "ssh ACCOUNT@TAILSCALE_IP" using the Mini's short account name. Verify
#     the host fingerprint against an independently recorded value. Locally:
#       sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
#   - If Screen Sharing is enabled, test "vnc://TAILSCALE_IP" using the Mini's
#     account credentials. A working MagicDNS name can replace the Tailscale IP.
#   - Select this Mini as your client's exit node. Test HTTPS browsing, DNS and
#     public egress IP. Restore the client's preferred exit-node selection afterward.
#   - Server: restart with local assistance still available, leave at the login
#     window without desktop login, and repeat the remote tests. Disconnect the
#     display and repeat in the actual headless configuration before deployment.
#   - Home: test the recovery behavior you chose. With FileVault on, arrange a
#     disk unlock after cold boot; do not expect unattended remote recovery.
#     If sleep is allowed, verify and accept that services are unavailable asleep.
#   - Test chosen power-recovery behavior in a planned local maintenance window.
#     Never pull power during updates or writes. Normal shutdown does not test
#     restart after power failure. Record the recovery case actually tested.
#   Do not rely on either Mini remotely until its intended operating tests pass.
#
# TERMINAL ACCESS OVER SSH (AFTER INITIAL PREPARATION)
#   Remote setup works with either profile. The account, native Remote Login,
#   Homebrew formula and connected Homebrew Tailscale ROOT boot service must
#   already exist. Server additionally requires FileVault fully off and Tailscale
#   SSH off. Home preserves both choices. Both require incoming tailnet connections
#   already allowed. Remote setup does not bootstrap, migrate or restart Tailscale.
#   A logged-in desktop is unnecessary once macOS and its disk are accessible.
#   From your other computer (connected to the same tailnet):
#
#     ssh -t ACCOUNT@TAILSCALE_IP
#
#   Verify the SSH fingerprint. A reachable LAN IP or working MagicDNS name can
#   replace TAILSCALE_IP. In the resulting terminal ON THE MINI:
#
#     curl -fsSLo ~/mac-mini.sh https://ahdxb.github.io/mini/mac-mini.sh
#     less ~/mac-mini.sh
#     bash ~/mac-mini.sh setup-remote --profile server
#
#   For the home Mini, use "setup-remote --profile home" instead; add either home
#   power option only if wanted. Do not prefix setup-remote with sudo. It verifies
#   prerequisites, shows the identity/profile and asks for SETUP. It preserves
#   name, tailnet, SSH/DNS/routing/access preferences and running services, changing
#   only exit-node advertisement and selected power settings. It never opens GUI
#   apps, upgrades software, reauthenticates, restarts services or reboots.
#   Keep a second SSH session open, then verify a NEW connection afterward.
#   Open printed approval URLs on your own computer. Each run prints a private
#   progress log in your home folder. On a dropped connection, reconnect and
#   rerun the same command/options; it rechecks live state and skips completed work.
#   Do not run concurrent setup sessions or change Tailscale settings during setup.
#   Working access now cannot guarantee access after network/power/OS failure.
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
#   Update one Mini at a time with a recovery plan. On Apple Silicon:
#     /opt/homebrew/bin/brew update
#     /opt/homebrew/bin/brew upgrade tailscale
#     sudo /opt/homebrew/bin/brew services restart tailscale
#   Intel Homebrew uses /usr/local instead. Service restarts may interrupt access;
#   do not perform these over your only connection without a recovery path.
#   Recheck the same profile/options and repeat external tests after updates.
#   The root daemon starts at boot, but needs macOS, disk access and networking.
#   Power recovery does not cover every shutdown, hang or failed update. Ethernet,
#   a UPS for the Mini/router and local assistance improve recovery. This script
#   installs no alerts. A local checker cannot prove remote access or exit routing.
#
# KEEPING IT SHARED
#   Sonar is the private master. Pushes to main publish only mac-mini.sh, the
#   download index and .nojekyll to public ahdxb/mini, and update the secret Gist.
#   Publishing also runs for workflow/template changes and manual dispatches.
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

# Parse explicit profile/options. Default to home so bare commands do not
# silently impose unattended-server requirements on an everyday Mac.
case "$MODE" in setup|setup-remote|check) ;; *) die 'Choose help, setup, setup-remote, or check.' ;; esac
shift
PROFILE=home
ALWAYS_ON=false
POWER_RECOVERY=false
REQUIRE_SCREEN_SHARING=false
NAME=''
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      [ $# -ge 2 ] || die '--profile requires home or server.'
      PROFILE=$2; shift 2 ;;
    --always-on) ALWAYS_ON=true; shift ;;
    --restart-after-power-failure) POWER_RECOVERY=true; shift ;;
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
  server) ALWAYS_ON=true; POWER_RECOVERY=true ;;
  home) ;;
  *) die '--profile must be home or server.' ;;
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
# SSH reference after step 7. It removes comment markers before printing.
# Inside awk, $0 means the input line; outside awk, "$0" is this script's path.
show_step() {
  awk -v n="$1" '
    $0 ~ "^# " n "\\. " { show=1; found=1 }
    show && /^# [0-9]+\. / && $0 !~ "^# " n "\\. " { exit }
    show && /^# (TERMINAL ACCESS OVER SSH|REPLACEMENT DETAILS)/ { exit }
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

# Profile choices affect only these power requirements; unselected values are
# never written. Used by local setup, SSH setup, and the read-only checker.
power_selected() {
  case "$1" in
    sleep) [ "$ALWAYS_ON" = true ] ;;
    autorestart) [ "$POWER_RECOVERY" = true ] ;;
  esac
}
validate_selected_power() {
  local key
  for key in sleep autorestart; do
    if power_selected "$key"; then
      awk -v k="$key" '$1==k {n++; if ($2 !~ /^[0-9]+$/) bad=1} END {exit !(n && !bad)}' "$1" ||
        die "Cannot verify selected power setting $key."
    fi
  done
}
setup_progress() { printf '%s\n' "$*"; }
apply_power_settings() {
  local setting key value
  for setting in sleep:0 autorestart:1; do
    key=${setting%:*}; value=${setting#*:}
    if power_selected "$key"; then
      if awk -v k="$key" -v v="$value" '$1==k {n++; if ($2!=v) bad=1} END {exit !(n && !bad)}' "$1"; then
        setup_progress "Power setting $key=$value already applied; skipped."
      else
        setup_progress "Applying power setting $key=$value."
        sudo -n pmset -a "$key" "$value"
        setup_progress "Power setting $key=$value applied."
      fi
    fi
  done
}
show_profile_plan() {
  printf 'Profile: %s\n' "$PROFILE"
  if [ "$PROFILE" = server ]; then
    printf 'FileVault must already be OFF; accounts and security settings remain manual.\n'
  else
    printf 'Preserve FileVault, accounts, login, lock-screen and unselected power settings.\n'
  fi
  if [ "$ALWAYS_ON" = true ]; then
    printf 'Selected: prevent computer sleep (sleep=0).\n'
  else
    printf 'Preserve computer sleep; exit-node availability follows its sleep schedule.\n'
  fi
  if [ "$POWER_RECOVERY" = true ]; then
    printf 'Selected: enable restart after power failure (autorestart=1).\n'
  else
    printf 'Preserve restart-after-power-failure setting.\n'
  fi
}
# Pass exactly the selected requirements to the child checker. Profiles are
# explicit per invocation, so this does not depend on sudo preserving variables.
finish_setup() {
  local result=0
  local check_args=(check --profile "$PROFILE")
  if [ "$ALWAYS_ON" = true ]; then check_args+=(--always-on); fi
  if [ "$POWER_RECOVERY" = true ]; then check_args+=(--restart-after-power-failure); fi
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
  printf 'Local checks, %s (profile: %s)\n' "$(date '+%Y-%m-%d %H:%M %Z')" "$PROFILE"

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
      if [ "$PROFILE" = server ]; then
        expect "$TMP/prefs" ssh false 'Server native SSH baseline (Tailscale SSH off)'
      else
        SSH_PREF=$(field "$TMP/prefs" ssh || true)
        case "$SSH_PREF" in
          true|false) printf 'INFO     Tailscale SSH=%s (home choice preserved)\n' "$SSH_PREF" ;;
          *) unknown 'Cannot read Tailscale SSH preference' ;;
        esac
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
  if [ -f /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist ] &&
                                  # True if Tailscale’s boot-time launchd plist file exists
     launchctl print system/homebrew.mxcl.tailscale >"$TMP/service" 2>/dev/null &&
                                  # Dump the root-domain service's live state to a temp file
     grep -q 'state = running' "$TMP/service"; then pass 'Tailscale system boot service running';
                                  # If the dump says "running", report PASS
  else fail 'Expected Homebrew Tailscale startup service is missing or stopped'; fi

  # Check only power settings selected by the profile/options. Unselected home
  # settings and FileVault are informational, including when they are unreadable.
  if pmset -g custom >"$TMP/power" 2>/dev/null; then
    for setting in sleep:0 autorestart:1; do
      key=${setting%:*}; value=${setting#*:}
      if power_selected "$key"; then
        if awk -v k="$key" -v v="$value" '$1==k {n++; if ($2!=v) bad=1} END {exit !(n && !bad)}' "$TMP/power"; then
          pass "Power setting $key=$value"
        else fail "Selected power setting $key should be $value"; fi
      else
        VALUES=$(awk -v k="$key" '$1==k {print $2}' "$TMP/power")
        printf 'INFO     Power setting %s=%s (home choice preserved)\n' "$key" "${VALUES:-unknown}"
      fi
    done
  elif [ "$ALWAYS_ON" = true ] || [ "$POWER_RECOVERY" = true ]; then
    unknown 'Cannot read selected power settings'
  else printf 'INFO     Cannot read power settings (home choices preserved)\n'; fi

  if fdesetup status >"$TMP/filevault" 2>/dev/null; then
    if [ "$PROFILE" = server ]; then
      if grep -Fxq 'FileVault is Off.' "$TMP/filevault"; then pass 'FileVault off for server unattended cold boot';
      else fail 'Server profile requires FileVault fully off'; fi
    else
      printf 'INFO     %s (home choice preserved; unlock may be needed after cold boot)\n' "$(head -n 1 "$TMP/filevault")"
    fi
  elif [ "$PROFILE" = server ]; then unknown 'Cannot read FileVault status';
  else printf 'INFO     Cannot read FileVault status (home choice preserved)\n'; fi

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
  printf '\nMANUAL: verify identity, node expiry, client permissions, remote SSH, optional\n'
  printf 'Screen Sharing, exit-node browsing and DNS. Follow step 7 for profile %s.\n' "$PROFILE"
  printf 'Local TCP is not an authentication test. Home sleep/FileVault choices can\n'
  printf 'limit availability and cold-boot recovery. No alerts or repairs are made.\n'
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
    run_timed sudo -n "$TS" get --json >"$TMP/prefs" || die 'Cannot read Tailscale preferences. No configuration was changed.'
    # Never disable Tailscale SSH through a session that may depend on it.
    # Server requires native SSH already selected; home preserves either choice.
    value=$(field "$TMP/prefs" ssh) || die 'Cannot verify Tailscale SSH preference.'
    case "$value" in true|false) ;; *) die 'Unrecognized Tailscale SSH preference.' ;; esac
    if [ "$PROFILE" = server ] && [ "$value" != false ]; then
      die 'Server profile requires native SSH already selected. Resolve locally; remote setup will not disable Tailscale SSH.'
    fi
    [ "$(field "$TMP/prefs" shields-up)" = false ] ||
      die 'Incoming tailnet connections must already be allowed. Remote setup will not change access settings.'
    value=$(field "$TMP/prefs" advertise-exit-node) || die 'Cannot read exit-node advertisement preference.'
    case "$value" in true|false) ;; *) die 'Unrecognized exit-node advertisement preference.' ;; esac
    nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1 || die 'Native SSH must already listen on port 22. Resolve Remote Login locally.'
    if [ "$PROFILE" = server ]; then
      sudo -n fdesetup status >"$TMP/filevault" || die 'Cannot verify FileVault. Complete local preparation first.'
      grep -Fxq 'FileVault is Off.' "$TMP/filevault" || die 'Server profile requires FileVault fully off. Resolve locally first.'
    fi
    if [ "$ALWAYS_ON" = true ] || [ "$POWER_RECOVERY" = true ]; then
      pmset -g custom >"$TMP/power" || die 'Cannot read selected power settings.'
      validate_selected_power "$TMP/power"
    fi
  }

  remote_preflight
  setup_progress 'Preflight passed; no configuration changed.'
  REMOTE_TAILNET=$(field "$TMP/status" CurrentTailnet.Name)
  REMOTE_NAME=$(field "$TMP/status" Self.DNSName)
  printf 'Existing identity: %s / %s\n' "$REMOTE_TAILNET" "$REMOTE_NAME"
  show_profile_plan
  cat <<'REMOTE_PLAN'
This advertises this Mini as an exit node and applies only selected power settings.
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
  if [ "$ALWAYS_ON" = true ] || [ "$POWER_RECOVERY" = true ]; then
    apply_power_settings "$TMP/power"
  fi
  setup_progress 'Configuration applied. Exit-node approval and external tests remain.'
  RESULT=0
  finish_setup || RESULT=$?
  exit "$RESULT"
fi

# LOCAL SETUP: macOS/account/Sharing preparation is complete before launch.
# Home preserves existing preferences; server selects its documented baseline.
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
  nc -z -G 3 127.0.0.1 22 >/dev/null 2>&1 || die 'Complete step 2 first: native Remote Login must already listen on port 22.'
  if [ "$PROFILE" = server ]; then
    sudo -n fdesetup status >"$TMP/filevault" || die 'Cannot verify FileVault. Complete macOS preparation first.'
    grep -Fxq 'FileVault is Off.' "$TMP/filevault" || die 'Server profile requires FileVault fully off. Complete step 2 first.'
  fi
  if [ "$ALWAYS_ON" = true ] || [ "$POWER_RECOVERY" = true ]; then
    pmset -g custom >"$TMP/power" || die 'Cannot read selected power settings.'
    validate_selected_power "$TMP/power"
  fi
  show_profile_plan
  cat <<'PLAN'
Complete macOS preparation in step 2 BEFORE proceeding. This installs Homebrew
and the Tailscale formula if missing, reuses or starts the system boot service,
connects/enrolls if needed, and advertises exit-node service. No existing formula
is upgraded. No accounts, FileVault, login, Sharing or firewall settings are changed.
PLAN
  if [ "$PROFILE" = server ]; then
    printf 'Local server setup selects native SSH (Tailscale SSH off) and allows incoming tailnet connections.\n'
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

  # A nonempty array is compatible with macOS Bash 3.2 and nounset. Home changes
  # only advertisement, plus any explicit hostname/power choices.
  TS_ARGS=(set --advertise-exit-node=true)
  if [ "$PROFILE" = server ]; then TS_ARGS+=(--ssh=false --shields-up=false); fi
  if [ -n "$NAME" ]; then TS_ARGS+=(--hostname="$NAME"); fi
  sudo -v
  sudo -n "$TS" "${TS_ARGS[@]}"
  if [ "$ALWAYS_ON" = true ] || [ "$POWER_RECOVERY" = true ]; then
    pmset -g custom >"$TMP/power"
    validate_selected_power "$TMP/power"
    apply_power_settings "$TMP/power"
  fi
  sudo -n "$TS" status
  sudo -n "$TS" ip -4
  RESULT=0
  finish_setup || RESULT=$?
  printf 'No reboot was requested. No existing formula was upgraded.\n'
  exit "$RESULT"
fi
