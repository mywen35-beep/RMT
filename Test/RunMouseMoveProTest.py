"""Isolated movement regressions; no live mouse input or user settings are touched."""
import pathlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]

def definitions(file, names):
    source = (ROOT / file).read_text(encoding="utf-8-sig")
    return "\n".join(re.search(r"(?m)^" + name + r"\([^\n]*[\s\S]*?^}", source).group() for name in names.split())

with tempfile.TemporaryDirectory(prefix="rmt-mouse-test-") as tmp:
    script = '#Requires AutoHotkey v2.0\n#SingleInstance Off\n#Warn All, Off\n'
    script += f'#Include {ROOT / "Plugins/AHK-XAML/lib/XAML_Generator.ahk"}\n'
    script += definitions("Main/Util/MacroUtil.ahk", "OnMMProOnce") + "\n"
    script += definitions("Main/Util/MouseMoveUtil.ahk", "MouseDragByStrategy MouseDragButtonByKeyMode") + "\n"
    script += f'#Include {ROOT / "Main/Util/ThemeUtil.ahk"}\n'
    script += f'#Include {ROOT / "Main/Util/Gdip_All.ahk"}\n'
    script += f'#Include {ROOT / "Main/Util/MouseMovePreview.ahk"}\n'
    for file in ["Gui/MMProGui.ahk", "Gui/MouseMoveGui.ahk", "Gui/DeltaMoveGui.ahk"]:
        script += re.sub(r"(?mi)^#.*$", "", (ROOT / file).read_text(encoding="utf-8-sig")) + "\n"
    source = (ROOT / "Gui/MacroGraph/MacroGraphHandlers.ahk").read_text(encoding="utf-8-sig")
    script += "\nclass GraphFixture {\n"
    for name in ["_MMProActionIndex", "_MMProActionFromText", "_MMProActionFromState", "_FlushMMProInline"]:
        script += re.search(r"(?m)^    " + name + r"\([^\n]*[\s\S]*?^    }", source).group() + "\n"
    script += """
    _MMProData(*) => this.Data
    _ComboSelectedIndex(name) => InStr(name, "MPAction") ? 3 : 0
    _ComboText(*) => "拖拽"
    _InlineVal(state, name, &value) {
        if (!state.Has(name))
            return false
        value := state[name]
        return true
    }
}
"""
    script += (ROOT / "Test/MouseMoveProTest.ahk").read_text(encoding="utf-8-sig")
    target = pathlib.Path(tmp) / "test.ahk"
    target.write_text(script, encoding="utf-8-sig")
    result = subprocess.run([r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe", "/ErrorStdOut=UTF-8", str(target), tmp], capture_output=True, timeout=30)
    print(result.stdout.decode("utf-8-sig", errors="replace"))
    print(result.stderr.decode("utf-8-sig", errors="replace"))
    if result.returncode:
        raise SystemExit(result.returncode)
    xaml = ET.parse(pathlib.Path(tmp) / "movepro.xaml").getroot()
    ns = {"w": "http://schemas.microsoft.com/winfx/2006/xaml/presentation"}
    controls = {e.get("Name"): e for e in xaml.iter() if e.get("Name")}
    assert [e.get("Content") for e in controls["ActionTypeCombo"].findall("w:ComboBoxItem", ns)] == ["移动", "移动后单击", "移动后双击", "拖拽"]
    assert controls["EndPosRow"].get("Visibility") == "Collapsed"
    end_labels = [e.get("Text") for e in controls["EndPosRow"].findall("w:TextBlock", ns)]
    assert end_labels == ["终止点", ""]
    assert controls["EndPosVarY"].get("Grid.Column") == controls["ActionTypeCombo"].get("Grid.Column")
    assert controls["EndPosVarY"].get("Margin") == controls["ActionTypeCombo"].get("Margin")
    assert {"PosVarX", "PosVarY", "EndPosVarX", "EndPosVarY"} <= controls.keys()
    print("PASS XAML: action options, editable start/end coordinates, collapsed end row")

source = (ROOT / "Gui/MacroEditGui.ahk").read_text(encoding="utf-8-sig")
order = re.search(r'name: "键鼠/手柄".*?cmds: (\[[^\]]+\])', source).group(1)
assert re.findall(r'"([^"\n]+)"', order) == ["按键", "手柄", "移动", "移动Pro", "增量移动", "后台按键", "后台鼠标", "按键检测", "手柄检测"]
assert 'class: MouseMoveGui, name: "移动"' in source
assert 'class: MMProGui, name: "移动Pro"' in source
print("PASS command names and keyboard/mouse/gamepad order")

chrome = (ROOT / "Plugins/AHK-XAML/lib/XAML_Host.ahk").read_text(encoding="utf-8-sig")
assert chrome.index('chrome.Preview :=') < chrome.index('chrome.Play :=')
assert '"BtnCmdPreview", titleHeight, Chr(0xE890), "Collapsed"' in chrome
print("PASS preview icon precedes execution and stays hidden in other editors")
