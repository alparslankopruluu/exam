"""Builds the public legal/support pages from docs/*.md.

Output: backend/hosting/{index,privacy,terms,support}.html — ready for any
static host (GitHub Pages, Vercel, Firebase Hosting).

Operator details come from store/legal/operator.json. The build refuses to
produce pages while any value is still a placeholder, so unfinished legal
text can't be published by accident. Pass --preview to render anyway.
"""
import html
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
# Served by Firebase Hosting (backend/firebase.json -> "public": "hosting").
OUT = REPO / "backend" / "hosting"

PAGE = """<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Examly</title>
<style>
  :root {{ --bg:#F7F9FC; --text:#0F172A; --muted:#64748B; --primary:#3B6CF6; --card:#fff; --border:#E6EAF2; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --bg:#0B1020; --text:#E6EAF2; --muted:#94A3B8; --card:#131A2E; --border:#243049; }} }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--text); font:16px/1.6 -apple-system, "Segoe UI", Roboto, sans-serif; }}
  main {{ max-width: 760px; margin: 0 auto; padding: 32px 16px 64px; }}
  nav {{ display:flex; gap:16px; margin-bottom:24px; font-weight:600; }}
  nav a, a {{ color:var(--primary); text-decoration:none; }}
  h1 {{ font-size: 32px; line-height:1.2; margin: 0 0 8px; }}
  h2 {{ font-size: 20px; margin: 32px 0 8px; }}
  em {{ color: var(--muted); font-style: normal; }}
  .card {{ background:var(--card); border:1px solid var(--border); border-radius:20px; padding:24px; }}
</style></head>
<body><main>
<nav><a href="index.html">Examly</a><a href="privacy.html">Privacy</a><a href="terms.html">Terms</a><a href="support.html">Support</a></nav>
<div class="card">{body}</div>
</main></body></html>
"""

SUPPORT_MD = """# Support

Need help with Examly? Email us at {CONTACT_EMAIL} and we'll get back to you.

## Common questions

- **Restore a subscription:** open Profile & Settings → Restore purchases.
- **Keep progress on a new phone:** open Profile & Settings → Save your progress and sign in with the same Apple, Google or email account on both devices.
- **Cancel a subscription:** manage it in your App Store or Google Play account settings.
- **Delete your account and data:** open Profile & Settings → Delete account, or email us.
"""

INDEX_MD = """# Examly

Adaptive exam prep with a personal daily plan, practice that adapts to you and an AI tutor that explains until it clicks.

- [Privacy Policy](privacy.html)
- [Terms of Use](terms.html)
- [Support](support.html)
"""


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"(?<![\"=>])(https?://[^\s<]+)", r'<a href="\1">\1</a>', text)
    text = re.sub(r"\b_(.+?)_\b", r"<em>\1</em>", text)
    return text


def markdown(md):
    out, in_list = [], False
    for line in md.splitlines():
        if line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        if line.startswith("## "):
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("# "):
            out.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.strip():
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def main():
    preview = "--preview" in sys.argv
    operator = json.loads((HERE / "operator.json").read_text())
    unfilled = [k for k, v in operator.items() if not v or v.startswith("{")]
    if unfilled and not preview:
        sys.exit(f"Fill in store/legal/operator.json first: {', '.join(unfilled)}")

    def fill(text):
        for key, value in operator.items():
            text = text.replace("{" + key + "}", value)
        return text

    pages = {
        "index": ("Examly", INDEX_MD),
        "privacy": ("Privacy Policy", (REPO / "docs" / "PRIVACY_POLICY.md").read_text()),
        "terms": ("Terms of Use", (REPO / "docs" / "TERMS.md").read_text()),
        "support": ("Support", SUPPORT_MD),
    }
    OUT.mkdir(exist_ok=True)
    for name, (title, md) in pages.items():
        (OUT / f"{name}.html").write_text(PAGE.format(title=title, body=markdown(fill(md))))
    print(f"wrote {len(pages)} pages to {OUT}" + (" (preview with placeholders)" if unfilled else ""))


if __name__ == "__main__":
    main()
