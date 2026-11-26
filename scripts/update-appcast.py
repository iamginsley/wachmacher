#!/usr/bin/env python3
"""Adds (or replaces) a release in site/appcast.xml, the Sparkle update feed.

Usage: scripts/update-appcast.py <version> <build> <dmg-url> <length> <ed-signature> <notes.md>
"""
import html
import re
import sys
from email.utils import formatdate
from pathlib import Path

APPCAST = Path(__file__).resolve().parent.parent / "site" / "appcast.xml"
HEADER = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Wachmacher</title>
    <link>https://iamginsley.github.io/wachmacher/appcast.xml</link>
    <description>Updates für Wachmacher</description>
    <language>de</language>
"""
FOOTER = """  </channel>
</rss>
"""


def notes_to_html(markdown: str) -> str:
    """Bullets become a list, other lines paragraphs. Everything is escaped."""
    parts, items = [], []
    for raw in markdown.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        text = html.escape(line.lstrip("-* ").replace("**", "") if line[:1] in "-*" else line.replace("**", ""))
        if line[:1] in "-*":
            items.append(f"<li>{text}</li>")
        else:
            if items:
                parts.append("<ul>" + "".join(items) + "</ul>")
                items = []
            parts.append(f"<p>{text}</p>")
    if items:
        parts.append("<ul>" + "".join(items) + "</ul>")
    return "".join(parts)


def main() -> None:
    version, build, url, length, signature, notes_path = sys.argv[1:7]
    notes = notes_to_html(Path(notes_path).read_text(encoding="utf-8"))
    item = f"""    <item>
      <title>Version {version}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[{notes}]]></description>
      <enclosure url="{html.escape(url)}" length="{length}" type="application/octet-stream" sparkle:edSignature="{signature}"/>
    </item>
"""
    items = []
    if APPCAST.exists():
        existing = re.findall(r"    <item>.*?</item>\n", APPCAST.read_text(encoding="utf-8"), flags=re.S)
        items = [i for i in existing if f"<sparkle:version>{build}</sparkle:version>" not in i]
    APPCAST.write_text(HEADER + item + "".join(items) + FOOTER, encoding="utf-8")
    print(f"✓ {APPCAST.name}: version {version} (build {build})")


if __name__ == "__main__":
    main()
