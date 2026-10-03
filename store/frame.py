"""Frames raw screenshots for the stores in the app's light style.

Drawing is done by frame.swift with CoreText, so every script (Arabic,
Devanagari, CJK) is shaped and wrapped correctly. Titles, subtitles and the
hero checklist live in captions.json.

  store/screenshots/raw/{ios,android}/<lang>/<screen>.png
    -> store/ios/screenshots/<asc-locale>/<n>_<screen>.png      (1320x2868)
    -> store/android/metadata/android/<play-locale>/images/phoneScreenshots/<n>.png (1080x1920)

Usage: python3 store/frame.py [lang ...]
"""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

from listing import LOCALES

ROOT = pathlib.Path(__file__).resolve().parent
CAPTIONS = json.loads((ROOT / "captions.json").read_text())
SCREENS = CAPTIONS["_order"]
ASSETS = ROOT / "screenshots" / "assets"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

TARGETS = {
    # platform: (canvas width, height, output directory builder)
    "ios": (1320, 2868, lambda lang: ROOT / "ios" / "screenshots" / LOCALES[lang][0], "{n}_{screen}.png"),
    "android": (1080, 1920, lambda lang: ROOT / "android" / "metadata" / "android" / LOCALES[lang][1] / "images" / "phoneScreenshots", "{n}.png"),
}


def render_svg(name, size):
    """Renders design/illustrations/<name>.svg to a PNG for the hero frame."""
    svg = ROOT.parent / "design" / "illustrations" / f"{name}.svg"
    out = ASSETS / f"{name}.png"
    if out.exists() and out.stat().st_mtime > svg.stat().st_mtime:
        return out
    ASSETS.mkdir(parents=True, exist_ok=True)
    width, height = size
    html = ASSETS / f"{name}.html"
    html.write_text(f'<html><body style="margin:0;background:transparent">'
                    f'<img src="{svg.as_uri()}" style="width:{width}px;height:{height}px"></body></html>')
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                    f"--window-size={width},{height}", f"--screenshot={out}", html.as_uri()],
                   check=True, capture_output=True)
    html.unlink()
    return out


def main():
    langs = sys.argv[1:] or list(LOCALES)
    mark = render_svg("app_mark", (512, 512))
    student = render_svg("hero_student", (800, 880))
    jobs = []
    for lang in langs:
        text = CAPTIONS[lang if lang in CAPTIONS else lang.split("-")[0]]
        for platform, (w, h, out_dir, pattern) in TARGETS.items():
            directory = out_dir(lang)
            raws = [ROOT / "screenshots" / "raw" / platform / lang / f"{screen}.png" for screen in SCREENS]
            if not all(raw.exists() for raw in raws):
                continue
            shutil.rmtree(directory, ignore_errors=True)
            for n, (screen, raw) in enumerate(zip(SCREENS, raws), start=1):
                jobs.append({
                    "raw": str(raw), "out": str(directory / pattern.format(n=n, screen=screen)),
                    "width": w, "height": h, "rtl": lang == "ar",
                    "title": text["titles"][n - 1], "subtitle": text["subtitles"][n - 1],
                    "style": "hero" if n == 1 else "standard",
                    "bullets": text["bullets"] if n == 1 else None,
                    "mark": str(mark), "illustration": str(student),
                })
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(jobs, f)
    subprocess.run(["swift", str(ROOT / "frame.swift"), f.name], check=True)
    pathlib.Path(f.name).unlink()


if __name__ == "__main__":
    main()
