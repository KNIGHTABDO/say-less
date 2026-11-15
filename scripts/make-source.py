#!/usr/bin/env python3
"""Writes the SideStore source (apps.json) for a release from the built app bundle.

SideStore refuses an install whose privacy prompts aren't declared by the source, so they are
read from the bundle instead of kept by hand.

usage: make-source.py <Payload/SayLess.app> <SayLess.ipa> <tag> <notes-file> <out.json>
"""
import datetime, json, os, plistlib, re, sys

REPO = "KNIGHTABDO/say-less"
PRIVACY_KEY = re.compile(r"^NS\w+UsageDescription$")

app, ipa, tag, notes_file, out = sys.argv[1:6]
with open(os.path.join(app, "Info.plist"), "rb") as f:
    main = plistlib.load(f)
privacy = {k: v for k, v in main.items() if PRIVACY_KEY.match(k)}

notes = open(notes_file).read().strip() or f"Say Less {tag}"
base = f"https://github.com/{REPO}"
icon = f"https://raw.githubusercontent.com/{REPO}/main/SayLess/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
version = {
    "version": main["CFBundleShortVersionString"],
    "buildVersion": str(main["CFBundleVersion"]),
    "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "localizedDescription": notes,
    "downloadURL": f"{base}/releases/download/{tag}/{os.path.basename(ipa)}",
    "size": os.path.getsize(ipa),
    "minOSVersion": main.get("MinimumOSVersion", "26.0"),
}
source = {
    "name": "Say Less",
    "subtitle": "Live translation that never leaves your phone.",
    "sourceURL": f"{base}/releases/latest/download/apps.json",
    "iconURL": icon,
    "tintColor": "D64034",
    "apps": [{
        "name": "Say Less",
        "bundleIdentifier": main["CFBundleIdentifier"],
        "developerName": "KNIGHTABDO",
        "subtitle": "Live translation that never leaves your phone.",
        "localizedDescription": "Face-to-face translation for travel. Speech recognition, translation and voice all run on your iPhone, offline.",
        "iconURL": icon,
        "tintColor": "D64034",
        "category": "utilities",
        "versions": [version],
        "appPermissions": {"entitlements": [], "privacy": privacy},
    }],
    "news": [],
}
with open(out, "w") as f:
    json.dump(source, f, indent=2)
print(f"source: {version['version']} ({version['buildVersion']}), {version['size']} bytes, privacy {sorted(privacy)}")
