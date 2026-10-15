# Mail sender search

Select an email in Apple Mail and press Control+Option+A. Mail searches All
Inboxes across accounts using the sender's email address and focuses the results list.
Review the matches, then use Command+A and Delete yourself. The automation
never deletes or moves messages.

## Install or restore on another Mac

Run as your normal macOS user from a checkout of this repository:

```sh
bash macos/mail/setup.sh
```

`setup-all.sh` also runs this installer. If that script is run through sudo,
the Mail installer switches back to `SUDO_USER` for this user's Library and
preferences. Running as root without `SUDO_USER` is refused.

The installer:

1. Compiles `FindEmailsFromSender.applescript` into
   `~/Library/Scripts/Mail/FindEmailsFromSender.scpt`.
2. Copies the tracked Quick Action into
   `~/Library/Services/Find Emails From Sender (Mail).workflow`.
3. Enables this Mail-only service and assigns Control+Option+A. It updates
   only this service's record in the `pbs` preferences.
4. Checks for a Shortcut named `Find Emails From Sender`. If absent, it opens
   the exported `.shortcut` file. Click Add Shortcut to finish the import.
   An existing or iCloud-synced Shortcut is kept, including its edits.

On a new Mac, also complete these macOS approvals:

- In Shortcuts > Settings > Advanced, enable Allow Running Scripts.
- In System Settings > Privacy & Security > Accessibility, add and enable
  Shortcuts (`/System/Applications/Shortcuts.app`).
- Allow Shortcuts to control Mail and System Events when macOS asks. These
  approvals appear under Privacy & Security > Automation.

The installer does not change security permissions or attempt to bypass them.
Restart Mail if its Services menu has not refreshed. To check the setup without
deleting anything, select an already-read email and press Control+Option+A.
Confirm its sender filter and All Inboxes scope. The same command is under
Mail > Services > Find Emails From Sender (Mail).

Preview installation with `--dry-run`. Use `--no-open` for a setup run that
prints import instructions without opening the Shortcuts import window.

## What is tracked

- `FindEmailsFromSender.applescript`: search implementation and error handling.
- `ShortcutsRunner.applescript`: readable source of the action inside Shortcuts.
- `shortcuts/Find Emails From Sender.shortcut`: portable signed Shortcut installer.
- `Find Emails From Sender (Mail).workflow/`: native Quick Action. It invokes
  `/usr/bin/shortcuts run 'Find Emails From Sender'`.
- `setup.sh` and `install.py`: per-user installation and keyboard registration.
- `build-shortcut.py`: rebuilds the signed Shortcut from the readable runner.

The Shortcuts runner loads the compiled file relative to the current user's
Library. There is no hard-coded user name or repository location in the runtime
files. Rerun setup after editing the search source. If editing the Shortcuts
action, update `ShortcutsRunner.applescript`, then run
`python3 macos/mail/build-shortcut.py`. Signing uses Apple's native `shortcuts
sign` command and requires its signing service to be available. Open the file
and inspect its action before committing a rebuilt package. The installer does not overwrite an
existing Shortcut, so update that action manually on other Macs when needed.

Changed live files receive timestamped backups next to the originals. Identical
files are left alone. Compiled scripts and local backups are not tracked here.

## Migration and iCloud

iCloud Sync can carry the Shortcuts library when enabled in Shortcuts settings.
It does not install this setup's files in `~/Library/Scripts` and
`~/Library/Services`, or recreate its per-user service binding. iCloud Drive
syncing Desktop and Documents is not a full Mac system backup. A Time Machine
backup and Migration Assistant are separate migration options.

Commit and push these repository changes, clone the repo on the next Mac,
then run setup and complete the approvals above.

## Search limits

Tested on macOS 26.4.1 with Mail's German interface. English labels are also
supported. Mail UI changes may require updating the source. Multiple selections
use the first message in Mail's selection order. Ambiguous addresses stop the
search. The scope is Mail's unified Inbox, identified through AppleScript even
if its sidebar label was renamed ("Alle" on this Mac). Trash, Junk, Sent,
Archive, and other folders are excluded. An active message-list filter is
turned off so matching read messages are included too. Search completeness
depends on Mail's index and synchronized messages. Review results before
deleting them.

Control+Option+F remains assigned to OmniWM; this automation uses
Control+Option+A to avoid that conflict.
