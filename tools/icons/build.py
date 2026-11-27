"""Genera las texturas de Media/ a partir de los SVG de esta carpeta: python tools/icons/build.py

Los iconos de las pestañas son blancos sobre transparente (64 × 64): el addon los tiñe con SetVertexColor.
El logo (128 × 128) va en color. WoW lee TGA de 32 bits sin comprimir con lados potencia de dos.
Necesita cairosvg y Pillow (pip install cairosvg pillow).
"""
import io
import pathlib

import cairosvg
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
MEDIA = HERE.parent.parent / "Media"
TAB_ICONS = ["clicks", "frames", "appearance", "auras", "debuffs", "buffs", "styles", "profiles"]


def render(svg, size, target):
    png = cairosvg.svg2png(url=str(svg), output_width=size, output_height=size)
    image = Image.open(io.BytesIO(png)).convert("RGBA")
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, format="TGA", compression=None)
    return image


def main():
    for name in TAB_ICONS:
        render(HERE / f"{name}.svg", 64, MEDIA / "Icons" / f"{name}.tga")
    render(HERE / "logo.svg", 128, MEDIA / "Logo.tga")
    print("Media/Icons: %d iconos, Media/Logo.tga" % len(TAB_ICONS))


if __name__ == "__main__":
    main()
