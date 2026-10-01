"""Reproduce approved iOS resources with fonttools==4.60.2; never edit sources."""
import hashlib
from pathlib import Path
import shutil
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

root = Path(__file__).resolve().parents[1]
source = root / "fonts"
output = root / "App" / "Fonts"
expected = {
    "Manrope-VariableFont_wght.ttf": "2b7a1ebc80c79246faa1b6e7093c7b91de2a4ceedb9b9a2b2fa05cf9bf8c77cd",
    "PapernotesRegular.woff": "8a0e6f141ec32b126003348f4f96bb2d909e2785327635a511cc19075f063157",
    "Hello Baby.otf": "e8487716783c7a0510f8f2437d79a7d0097601d4e044236cf71443c42f186dca",
}
for name, checksum in expected.items():
    assert hashlib.sha256((source / name).read_bytes()).hexdigest() == checksum, name
    font = TTFont(source / name)
    print(name, "family=", font["name"].getDebugName(1), "PostScript=", font["name"].getDebugName(6))

for role, weight in [("Regular", 400), ("Medium", 500), ("SemiBold", 600)]:
    font = instantiateVariableFont(TTFont(source / "Manrope-VariableFont_wght.ttf"),
                                   {"wght": weight}, updateFontNames=True)
    path = output / f"Manrope-{role}.ttf"
    font.save(path)
    assert TTFont(path)["name"].getDebugName(6) == f"Manrope-{role}"
font = TTFont(source / "PapernotesRegular.woff")
assert font.sfntVersion == "OTTO"
font.flavor = None
font.save(output / "PapernotesRegular.otf")
assert TTFont(output / "PapernotesRegular.otf")["name"].getDebugName(6) == "PapernotesRegular"
shutil.copyfile(source / "Hello Baby.otf", output / "Hello Baby.otf")
