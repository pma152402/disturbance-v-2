"""Split the six 4x4 graffiti sheets into 96 standalone RGBA textures."""

from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT_ROOT / "assets" / "graffiti_sheets"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "graffiti_individual"

SHEETS = {
    "tags": "graffiti_sheet_tags.png",
    "characters": "graffiti_sheet_characters.png",
    "symbols": "graffiti_sheet_symbols.png",
    "handstyles": "graffiti_sheet_handstyles.png",
    "throwups": "graffiti_sheet_throwups.png",
    "wildstyle": "graffiti_sheet_wildstyle.png",
}


def split_sheet(slug: str, filename: str) -> int:
    source_path = SOURCE_DIR / filename
    output_path = OUTPUT_DIR / slug
    output_path.mkdir(parents=True, exist_ok=True)
    image = Image.open(source_path).convert("RGBA")
    width, height = image.size

    written = 0
    for row in range(4):
        top = round(row * height / 4)
        bottom = round((row + 1) * height / 4)
        for column in range(4):
            left = round(column * width / 4)
            right = round((column + 1) * width / 4)
            index = row * 4 + column + 1
            crop = image.crop((left, top, right, bottom))
            crop.save(output_path / f"{slug}_{index:02d}.png", optimize=True)
            written += 1
    return written


def main() -> None:
    total = sum(split_sheet(slug, filename) for slug, filename in SHEETS.items())
    print(f"Created {total} standalone graffiti textures in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
