import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument(
    "--source",
    type=Path,
    default=ROOT / "tmp" / "docx_qa" / "rule_optimizer_explainer_v1",
)
args = parser.parse_args()

SOURCE = args.source.resolve()
DEST = SOURCE / "contact_sheets"
DEST.mkdir(parents=True, exist_ok=True)

pages = sorted(SOURCE.glob("page-*.png"))
font_path = Path(r"C:\Windows\Fonts\calibrib.ttf")
font = ImageFont.truetype(str(font_path), 28)

for index in range(0, len(pages), 2):
    batch = pages[index:index + 2]
    opened = [Image.open(page).convert("RGB") for page in batch]
    page_width = max(image.width for image in opened)
    page_height = max(image.height for image in opened)
    gutter = 28
    label_height = 52
    canvas = Image.new(
        "RGB",
        (page_width * len(opened) + gutter * (len(opened) - 1), page_height + label_height),
        "white",
    )
    draw = ImageDraw.Draw(canvas)
    x = 0
    for page, image in zip(batch, opened):
        label = page.stem.replace("page-", "Page ")
        draw.text((x + 18, 10), label, font=font, fill="#12314A")
        canvas.paste(image, (x, label_height))
        x += page_width + gutter
    first = index + 1
    last = index + len(batch)
    canvas.save(DEST / f"pages-{first:02d}-{last:02d}.png", quality=94)

print(f"Created {len(list(DEST.glob('pages-*.png')))} contact sheets in {DEST}")
