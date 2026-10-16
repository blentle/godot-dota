"""下载固定版本的经典美术候选，按字节数和 Git blob 摘要校验，禁止执行下载内容。"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "references/downloads/war3-original"


def verify(data, entry):
    """Git blob 摘要同时包含文件长度，不能仅依据后缀信任候选内容。"""
    blob = b"blob " + str(len(data)).encode() + b"\0" + data
    digest = (hashlib.sha1(blob).hexdigest() == entry["git_blob_sha"] if "git_blob_sha" in entry
              else hashlib.sha256(data).hexdigest() == entry["sha256"])
    return len(data) == entry["bytes"] and digest


def fetch(entry):
    relative = Path(entry["path"])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("资源路径越界")
    target = CACHE / relative
    if target.is_file() and verify(target.read_bytes(), entry):
        return str(relative), "缓存已校验"
    if "source_map_sha256" in entry:
        raise ValueError("地图内资源须先运行 tools/classic_art/fetch_heroes.cjs 提取：" + str(relative))
    request = urllib.request.Request(entry["url"], headers={"User-Agent": "godot-dota-art/0.1"})
    with urllib.request.urlopen(request, timeout=90) as response:
        data = response.read(entry["bytes"] + 1)
    if not verify(data, entry):
        raise ValueError("资源大小或摘要不符：" + str(relative))
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".partial")
    temporary.write_bytes(data)
    temporary.replace(target)
    return str(relative), "下载并校验"


def main():
    manifest = json.loads((ROOT / "references/classic-art-sources.json").read_text())
    with ThreadPoolExecutor(max_workers=6) as pool:
        for path, status in pool.map(fetch, manifest["files"]):
            print(status + "：" + path, flush=True)


if __name__ == "__main__":
    main()
