"""生成 SolidCraft 中文版双语资源包（可复现）。

用法（仓库根目录）：
    python zh-cn/i18n/build_zh_cn.py

产物：
    zh-cn/i18n/zh-CN.json      合并后的完整中文语言包
    zh-cn/i18n/en-US.json      对应的英文原版
    zh-cn/i18n/对照表.csv       id / 英文 / 中文 对照
    assets/locales/zh.json     正式语言包补译
    crates/ui-text/locales/zh.json  共享语言包补译

说明：源码中形如 "X"/"Y"/"HDR"/"STEP"/"{name} · {value}" 的条目是符号、
占位符或行业专名，中英同文是正确的，不做强行翻译；只补译真正的英文句子。
"""
from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_EN = ROOT / "assets/locales/en.json"
APP_ZH = ROOT / "assets/locales/zh.json"
SHARED_EN = ROOT / "crates/ui-text/locales/en.json"
SHARED_ZH = ROOT / "crates/ui-text/locales/zh.json"
OUT = ROOT / "zh-cn/i18n"

# 按 message id 补译的条目（其余中英同文的是符号/占位符/专名，保持原文）
PATCHES: dict[str, str] = {
    "Board color": "电路板颜色",
    "Board thickness": "电路板厚度",
    "Board thickness must be greater than 0 and at most 1000 mm.": "电路板厚度必须大于 0 且不超过 1000 mm。",
    "Copper (traces, vias, zones, pads)": "铜层（走线、过孔、覆铜区、焊盘）",
    "Import options": "导入选项",
    "Importing KiCad board": "正在导入 KiCad 电路板",
    "Include components": "包含元器件",
    "Include silkscreen": "包含丝印层",
    "Open KiCad PCB": "打开 KiCad PCB",
    "Overlay on the board": "叠加在电路板上",
    "color.hex": "十六进制",
    "help.notice": "注意",
    "prefs.minutes_suffix": " 分钟",
    "ui.drawing_first.tabloid": "小报（Tabloid）",
    "ui.drawing_panel.legal": "法律用纸（Legal）",
    "ui.drawing_panel.letter": "信纸（Letter）",
}


def load(p: Path) -> dict[str, str]:
    return json.loads(p.read_text(encoding="utf-8"))


def dump(p: Path, data: dict[str, str]) -> None:
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def patch_in_place(p: Path, patches: dict[str, str]) -> int:
    """逐行替换，保持源文件原有顺序、缩进与格式（最小 diff）。"""
    lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
    changed = 0
    for i, line in enumerate(lines):
        for key, text in patches.items():
            marker = json.dumps(key, ensure_ascii=False) + ": "
            if line.lstrip().startswith(marker):
                indent = line[: len(line) - len(line.lstrip())]
                tail = "," if line.rstrip().endswith(",") else ""
                nl = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
                lines[i] = f"{indent}{marker}{json.dumps(text, ensure_ascii=False)}{tail}{nl}"
                changed += 1
                break
    p.write_text("".join(lines), encoding="utf-8")
    return changed


def main() -> None:
    app_en, app_zh = load(APP_EN), load(APP_ZH)
    shared_en, shared_zh = load(SHARED_EN), load(SHARED_ZH)

    assert set(app_en) == set(app_zh), "应用语言包 en/zh 键不一致"
    assert set(shared_en) == set(shared_zh), "共享语言包 en/zh 键不一致"
    assert not (set(app_en) & set(shared_en)), "应用与共享语言包不应有重复 id"

    # 只补译「英文原文 = 中文」且确实是句子的条目，按行替换以保持最小 diff
    sentence_patches = {k: v for k, v in PATCHES.items()
                        if k in app_zh and app_zh[k] == app_en[k]}
    changed = patch_in_place(APP_ZH, sentence_patches)
    app_zh = load(APP_ZH)

    en_all = {**app_en, **shared_en}
    zh_all = {**app_zh, **shared_zh}
    assert set(en_all) == set(zh_all) and len(en_all) == len(app_en) + len(shared_en)

    dump(OUT / "en-US.json", en_all)
    dump(OUT / "zh-CN.json", zh_all)
    with (OUT / "对照表.csv").open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["message id", "English (原文)", "简体中文"])
        for k in sorted(en_all):
            w.writerow([k, en_all[k], zh_all[k]])

    same = sum(1 for k in en_all if en_all[k] == zh_all[k])
    print(f"应用语言包: {len(app_en)} 键；共享语言包: {len(shared_en)} 键")
    print(f"补译: {changed} 条；双语资源包: {len(en_all)} 键")
    print(f"中英同文（符号/占位符/专名）: {same} 条")
    print(f"输出: {OUT}")


if __name__ == "__main__":
    main()
