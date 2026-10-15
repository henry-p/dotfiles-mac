"""Install the Mail sender-search files and its per-user keyboard binding."""

import argparse
import datetime
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


SOURCE = Path(__file__).resolve().parent
SERVICE = "Find Emails From Sender (Mail).workflow"
SHORTCUT = "Find Emails From Sender"
SERVICE_KEY = (
    "local.mail.findemailsfromsender - Find Emails From Sender (Mail)"
    " - runWorkflowAsService"
)


def replace_file(source, destination):
    """Keep changed local files as backups; identical reruns make no backups."""
    if destination.is_file() and source.read_bytes() == destination.read_bytes():
        print(f"Unchanged: {destination}")
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = destination.with_name(
            f"{destination.name}.backup-{stamp}-{uuid.uuid4().hex[:6]}"
        )
        destination.rename(backup)
        print(f"Backed up: {backup}")
    staged = destination.with_name(f".{destination.name}.{uuid.uuid4().hex}")
    try:
        shutil.copyfile(source, staged)
        staged.chmod(0o644)
        os.replace(staged, destination)
    finally:
        staged.unlink(missing_ok=True)
    print(f"Installed: {destination}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Preview without changes")
    parser.add_argument(
        "--no-open", action="store_true", help="Do not open a missing Shortcut for import"
    )
    args = parser.parse_args()
    home = Path.home()
    compiled = home / "Library/Scripts/Mail/FindEmailsFromSender.scpt"
    workflow = home / "Library/Services" / SERVICE
    export = SOURCE / "shortcuts" / f"{SHORTCUT}.shortcut"

    if args.dry_run:
        print(f"Compile {SOURCE / 'FindEmailsFromSender.applescript'} -> {compiled}")
        print(f"Install {SOURCE / SERVICE} -> {workflow}")
        print("Register Mail-only Control+Option+A; preserve other service settings.")
        print(f"If absent from Shortcuts, open {export} for confirmation.")
        print("Leave Automation, Accessibility, and script permissions unchanged.")
        return

    if not export.is_file():
        raise SystemExit(f"Missing Shortcut export: {export}")

    # Compile before changing the live installation. The binary is built locally
    # rather than tracked, so it uses this Mac's AppleScript/Mail dictionaries.
    with tempfile.TemporaryDirectory(prefix="mail-sender-setup-") as temporary:
        built = Path(temporary) / "FindEmailsFromSender.scpt"
        subprocess.run(
            ["/usr/bin/osacompile", "-o", str(built),
             str(SOURCE / "FindEmailsFromSender.applescript")],
            check=True,
        )
        replace_file(built, compiled)
    for relative in ("Contents/Info.plist", "Contents/document.wflow"):
        replace_file(SOURCE / SERVICE / relative, workflow / relative)

    # Quote the dictionary key for defaults' property-list parser. -dict-add
    # replaces only this service's record, preserving every other service.
    status = (
        '{key_equivalent = "~^a"; enabled_context_menu = 1; '
        'enabled_services_menu = 1; presentation_modes = '
        '{ContextMenu = 1; ServicesMenu = 1;};}'
    )
    subprocess.run(
        ["/usr/bin/defaults", "write", "pbs", "NSServicesStatus", "-dict-add",
         f'"{SERVICE_KEY}"', status],
        check=True,
    )
    subprocess.run(["/System/Library/CoreServices/pbs", "-update"], check=True)

    # Do not replace an existing/iCloud-synced Shortcut or edit its private DB.
    try:
        result = subprocess.run(
            ["/usr/bin/shortcuts", "list"], capture_output=True, text=True,
            check=True, timeout=20,
        )
        installed = SHORTCUT in result.stdout.splitlines()
    except (subprocess.SubprocessError, OSError) as error:
        print(f"Could not check the Shortcuts library: {error}")
        print(f"If {SHORTCUT!r} is absent, open {export} and add it.")
        installed = None
    if installed is False:
        print(f"Add {SHORTCUT!r} in the Shortcuts import window.")
        if not args.no_open:
            subprocess.run(["/usr/bin/open", str(export)], check=True)
        else:
            print(f"Open this file to import it: {export}")
    elif installed:
        print(f"Kept existing Shortcut: {SHORTCUT}")

    print("Installed Mail service and Control+Option+A binding.")
    print("On a new Mac: allow scripts in Shortcuts Settings > Advanced;")
    print("allow Shortcuts in Privacy & Security > Accessibility, and approve")
    print("Mail/System Events Automation prompts when first running it.")
    print("Restart Mail if its Services menu has not refreshed. See README.md.")


if __name__ == "__main__":
    main()
