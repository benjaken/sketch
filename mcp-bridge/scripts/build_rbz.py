import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLUGIN = ROOT / "sketchup_plugin"
DIST = ROOT / "dist"
FILES = ["su_mcp_bridge.rb", "extension.json", "su_mcp_bridge/main.rb"]

def main() -> None:
    DIST.mkdir(exist_ok=True)
    out = DIST / "su_mcp_bridge.rbz"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in FILES:
            z.write(PLUGIN / rel, rel)
    print(f"built {out}")

if __name__ == "__main__":
    main()
