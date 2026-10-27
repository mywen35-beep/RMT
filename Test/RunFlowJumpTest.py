"""Isolated flow-jump regression tests using production executors and XAML builders.
Does not start RMT or read/write user settings. Run: python Test/RunFlowJumpTest.py
"""
import pathlib
import re
import subprocess
import tempfile
import sys
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding="utf-8")

ROOT = pathlib.Path(__file__).resolve().parents[1]


def definitions(file, names):
    source = (ROOT / file).read_text(encoding="utf-8-sig")
    result = []
    for name in names.split():
        match = re.search(r"(?m)^" + re.escape(name) + r"\([^\n]*[\s\S]*?^}", source)
        if not match:
            raise RuntimeError("Missing function: " + name)
        result.append(match.group())
    return "\n".join(result)


with tempfile.TemporaryDirectory(prefix="rmt-flow-test-") as tmp:
    script = '#Requires AutoHotkey v2.0\n#SingleInstance Off\n#Warn All, Off\nFileEncoding("UTF-8")\n'
    script += f'#Include {ROOT / "Plugins/AHK-XAML/lib/XAML_Generator.ahk"}\n'
    script += definitions("Main/Util/MacroUtil.ahk", "FlowJumpActions FlowJumpAction OnFlowJump OnTriggerMacroOnce OnLoop GetLoopState OnCompare OnComparePro TryInterceptBranch")
    script += "\n" + definitions("Main/AssetUtil.ahk", "HandleControlType")
    script += "\n" + definitions("Main/Util/LangUtil.ahk", "GetLangCmd")
    script += "\n" + definitions("Main/Util/GraphMacroUtil.ahk", "WalkGraphNode")
    # Load actual classes without their unrelated application includes.
    for file in ["Gui/FlowJumpGui.ahk", "Gui/CompareGui.ahk", "Gui/CompareProGui.ahk", "Gui/CompareProEditItemGui.ahk"]:
        source = (ROOT / file).read_text(encoding="utf-8-sig")
        script += "\n" + re.sub(r"(?mi)^#.*$", "", source)
    graph_source = (ROOT / 'Gui/MacroGraph/MacroGraphData.ahk').read_text(encoding='utf-8-sig')
    script += '\n' + re.search(r'(?m)^class MGParseObjBase [\s\S]*?^}', graph_source).group()
    script += '\nclass GraphFixture {\n'
    for name in ['_Parse', '_BuildCmd']:
        script += re.search(r'(?m)^    ' + name + r'\([^\n]*[\s\S]*?^    }', graph_source).group() + '\n'
    script += '}\n'
    script += (ROOT / 'Test/FlowJumpTest.ahk').read_text(encoding='utf-8-sig')
    target = pathlib.Path(tmp) / "test.ahk"
    target.write_text(script, encoding="utf-8-sig")
    result = subprocess.run([r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe", "/ErrorStdOut=UTF-8", str(target), tmp], capture_output=True, timeout=30)
    print(result.stdout.decode("utf-8-sig", errors="replace"))
    print(result.stderr.decode("utf-8-sig", errors="replace"))
    if result.returncode:
        raise SystemExit(result.returncode)
    ns = {"w": "http://schemas.microsoft.com/winfx/2006/xaml/presentation"}
    for name in ["jump", "if", "ifpro", "branch"]:
        root = ET.parse(pathlib.Path(tmp) / (name + ".xaml")).getroot()
        controls = {el.get("Name") for el in root.iter() if el.get("Name")}
        assert not controls.intersection({"TrueControlCon", "FalseControlCon", "ControlTypeCon"})
        if name == "jump":
            assert len(root.findall(".//w:ComboBox", ns)) == 1
            assert len(root.findall(".//w:ComboBoxItem", ns)) == 3
            assert not root.findall(".//w:TextBox", ns)
    print("PASS XAML: all four editors parse; jump has one selector; conditional editors have no flow controls")
