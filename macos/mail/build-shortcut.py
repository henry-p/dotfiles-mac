"""Rebuild the portable Shortcut from the readable runner, then sign with Apple."""

from pathlib import Path
import plistlib
import subprocess
import tempfile


def main():
    source = Path(__file__).resolve().parent
    output = source / "shortcuts/Find Emails From Sender.shortcut"
    payload = {
        "WFWorkflowName": "Find Emails From Sender",
        "WFWorkflowClientVersion": "4000",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowTypes": [],
        "WFWorkflowInputContentItemClasses": [],
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowImportQuestions": [],
        "WFWorkflowIcon": {
            "WFWorkflowIconStartColor": 4282601983,
            "WFWorkflowIconGlyphNumber": 59446,
        },
        "WFWorkflowActions": [{
            "WFWorkflowActionIdentifier": "is.workflow.actions.runapplescript",
            "WFWorkflowActionParameters": {
                "Script": (source / "ShortcutsRunner.applescript").read_text(),
            },
        }],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mail-shortcut-build-") as temporary:
        unsigned = Path(temporary) / "Find Emails From Sender.shortcut"
        unsigned.write_bytes(plistlib.dumps(payload))
        subprocess.run([
            "/usr/bin/shortcuts", "sign", "--mode", "anyone", "--input",
            str(unsigned), "--output", str(output),
        ], check=True)
    output.chmod(0o644)
    print(f"Signed: {output}")


if __name__ == "__main__":
    main()
