"""Run isolated AHK migration tests without starting RMT or changing user settings.
Uses verbatim production functions/classes; only GUI/logging services are stubbed.
Usage: python Test/RunLegacyConfigImportTest.py [AutoHotkey.exe]
"""
import pathlib
import re
import subprocess
import sys
import struct
import json
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

def definitions(file, names):
    source = (ROOT / file).read_text(encoding="utf-8-sig")
    result = []
    for name in names.split():
        match = re.search(r"(?m)^(?:class )?" + re.escape(name) + r"(?:\([^\n]*|\s*\{)[\s\S]*?^}", source)
        if not match:
            raise RuntimeError(f"Missing production definition: {name}")
        result.append(match.group())
    return "\n".join(result)

with tempfile.TemporaryDirectory(prefix="rmt-compat-test-") as tmp:
    script = '#Requires AutoHotkey v2.0\n#SingleInstance Off\n#Warn All, Off\n'
    for file in ["Main/Util/ConfigUtil.ahk", "Main/Util/JsonUtil.ahk", "Main/Util/IniImportUtil.ahk", "Main/Util/FixCompatUtil.ahk", "Main/Util/FileIOUtil.ahk", "Main/Util/JoyNameUtil.ahk", "Test/Fixtures/Legacy122Data.ahk"]:
        script += f'#Include {ROOT / file}\n'
    script += definitions("Main/DataClass.Ahk", "MacroItem MacroFold TableItem SearchImageDefaultType SearchData MMProData DeltaMoveData RunData FileIOData CompareData CompareProData LoopData VariableData OperationData InputData OutputData ExVariableData BGMouseData BGKeyData ArrayData WindowManageData KeyCheckData ScreenShotData SubMacroData TextOpsData TimingData CommentData MacroGraphNode MacroGraphStartNode")
    script += '\n' + definitions("Main/AssetUtil.ahk", "CreateDefaultTableDefs IsItemSymbol IsStaticTable EnsureTableHasFold NewModulePath SaveTableItemInfoTomlCore FoldIDBelongs GetSegTail SplitMacro SplitCommand GetCmdByParams GetMacroStrByCmdArr GetCmdStr GetCmdSymbol CmdStripDebug CmdIsDebug CmdDebugMark")
    script += '\n' + definitions("Main/Util/CompatDataUtil.ahk", "CompatEnsureArrLength CompatMacroTypeSymbol CompatEnsureRunData")
    repair = (ROOT / 'Gui/SettingMgrGui.ahk').read_text(encoding='utf-8-sig')
    script += '\nclass RepairFixture {\n' + re.search(r'(?m)^    OnRepairSetting\([^\n]*[\s\S]*?^    }', repair).group() + '\n}\n'
    script += '\n' + definitions("Main/Util/MacroUtil.ahk", "OnSubMacro OnKeyCheck OnJoyCheck ApplyKeyCheckResult IsCheckKeyPressed")
    script += '\n' + definitions("Main/Util/TableLocator.ahk", "GetTableBySymbol")
    merge = (ROOT / 'Main/Util/MergeUtil.ahk').read_text(encoding='utf-8-sig')
    script += '\n' + definitions("Main/Util/MergeUtil.ahk", "MergeTreeNode")
    script += '\nclass MergeFixture {\n'
    for name in ['RemapMacroTargets', '_ParseMacroItemsToml']:
        script += re.search(r'(?m)^    static ' + name + r'\([^\n]*[\s\S]*?^    }', merge).group() + '\n'
    script += '    static ExtractResourceSerials(*) => []\n}\n'
    script += (ROOT / 'Test/LegacyReviewRegressionTest.ahk').read_text(encoding='utf-8-sig') + '\n'
    # Exercise the actual current unpacker, without loading its unrelated upload UI.
    pack = (ROOT / 'Main/FolderPackager.ahk').read_text(encoding='utf-8-sig')
    script += '\nclass FolderPackager {\n' + '\n'.join(re.findall(r'(?m)^    static (?:MAX_\w+|ALLOWED_EXT) :=.*$', pack))
    for name in ['PackFolder', '_GetAllFiles', '_CreateHeader', '_AddFile', 'UnpackFile', '_ParseHeader', '_ParseFile', '_ValidateEntry']:
        script += '\n' + re.search(r'(?m)^    static ' + name + r'\([^\n]*[\s\S]*?^    }', pack).group()
    script += '\n    static _DecryptData(*) => 0\n}\n'
    script += (ROOT / 'Test/VersionMigrationTest.ahk').read_text(encoding='utf-8-sig') + '\n'
    script += (ROOT / 'Test/LegacyCommandMigrationTest.ahk').read_text(encoding='utf-8-sig') + '\n'
    script += (ROOT / 'Test/LegacyConfigImportTest.ahk').read_text(encoding='utf-8-sig')
    # RMTv1.2.2 RMPK v1 layout, UTF-16 INI + embedded image.
    entries = {
        'MacroFile.ini': ('[UserSettings]\nNormalModeArr=1π2\nNormalTKArr=F1πF2\nNormalSerialArr=Item10πItem20\nNormalMacroArr1=按键_A_点击_100⫶间隔_10\nNormalMacroArr2=宏操作1_调用\nNormalFoldInfo=' + json.dumps({'IndexSpanArr': ['1-1', '2-2'], 'RemarkArr': ['模块一', '模块二'], 'ForbidStateArr': [0, 1], 'TKArr': ['F3', 'F4']}, ensure_ascii=False) + '\nSubMacroModeArr=1\nSubMacroMacroArr1=间隔_20\n').encode('utf-16'),
        'SubMacroFile.ini': ('[UserSettings]\n宏操作1=' + json.dumps({'MacroType': '按键宏', 'Index': 1, 'MacroSerial': 'Item20', 'CallType': '触发'}, ensure_ascii=False)).encode('utf-16'),
        'Images\\test.png': b'fixture-image',
    }
    package = b'RMPK' + struct.pack('<QI', 0, 1)
    for name, content in entries.items():
        name = name.encode('utf-8') + b'\0'
        package += struct.pack('<I', len(name)) + name + struct.pack('<Q', len(content)) + content
    (pathlib.Path(tmp) / 'legacy.rmt').write_bytes(package)
    path = pathlib.Path(tmp) / 'test.ahk'
    path.write_text(script, encoding='utf-8-sig')
    ahk = sys.argv[1] if len(sys.argv) > 1 else r'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
    result = subprocess.run([ahk, '/ErrorStdOut=UTF-8', str(path)], capture_output=True, timeout=60)
    print(result.stdout.decode('utf-8-sig', errors='replace'))
    print(result.stderr.decode('utf-8-sig', errors='replace'))
    sys.exit(result.returncode)

