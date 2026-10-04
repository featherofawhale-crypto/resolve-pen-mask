"""Build the single native Pen Mask Inspector-preset effect."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "钢笔蒙版.setting"
LUA_SCRIPT = ROOT / "preset_button.lua"
ARCHIVE = ROOT / "PenMask.drfx"
ENTRY = "Edit/Effects/原生蒙版工具/钢笔蒙版.setting"
BUTTON = re.compile(r'BTNCS_Execute = "(?:\\.|[^"\\])*"')


def build():
    source = SOURCE.read_text(encoding="utf-8")
    script = LUA_SCRIPT.read_text(encoding="utf-8")
    if len(BUTTON.findall(source)) != 1:
        raise ValueError("Expected exactly one fixed preset button")
    source = BUTTON.sub(lambda _: "BTNCS_Execute = " + json.dumps(script, ensure_ascii=False), source)
    for dependency in ("OpenPanel", "RunScript", "MagicMask", "/Users/", "os.execute", "io.popen"):
        if dependency in source:
            raise ValueError(f"Unexpected external dependency: {dependency}")
    SOURCE.write_text(source, encoding="utf-8")
    payload = source.encode("utf-8")
    entry = zipfile.ZipInfo(ENTRY, date_time=(2026, 1, 1, 0, 0, 0))
    entry.compress_type = zipfile.ZIP_DEFLATED
    entry.external_attr = 0o644 << 16
    with zipfile.ZipFile(ARCHIVE, "w") as archive:
        archive.writestr(entry, payload)
    digest = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
    (ROOT / "SHA256SUMS.txt").write_text(f"{digest}  {ARCHIVE.name}\n", encoding="utf-8")
    return digest


if __name__ == "__main__":
    print(f"PenMask.drfx  SHA256 {build()}")
