"""Exit 0 if the screenshot is blank (a flat, unrendered frame), else 1."""
import sys

from PIL import Image, ImageStat

im = Image.open(sys.argv[1]).convert("L")
body = im.crop((0, im.height // 6, im.width, im.height * 5 // 6))
sys.exit(0 if ImageStat.Stat(body).stddev[0] < 1 else 1)
