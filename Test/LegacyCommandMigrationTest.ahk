; Invoked by RunLegacyConfigImportTest.py; no external programs or hardware input are executed.
TestLegacyCommands() {
    dir := A_ScriptDir "\commands"
    DirCreate(dir)
    WriteLegacy(stem, key, data) {
        data.SerialStr := key
        IniWrite(JSON.stringify(data, 0), dir "\" stem ".ini", "UserSettings", key)
    }
    run := Legacy122RunData()
    run.Target := "cmd /c echo 运行1"
    run.Mode := 4
    run.Option := 0
    run.StdIn := "输入数据"
    run.Encoding := {In: "UTF-8", Out: "CP0", Err: "UTF-16"}
    run.SaveNameArr := ["返回码", "输出内容", "错误内容"]
    WriteLegacy("RunFile", "运行1", run)
    run.Mode := 1
    run.Option := 1
    WriteLegacy("RunFile", "运行2", run)
    run.Mode := 1
    run.Option := 2
    WriteLegacy("RunFile", "运行3", run)
    for mode in [2, 3] {
        run.Mode := mode
        run.Option := 1
        WriteLegacy("RunFile", "运行" (mode + 2), run)
    }
    excel := Legacy122FileIOData()
    excel.OperType := "写入Excel"
    excel.OperMode := "指定区域-列"
    excel.ArrName := "表格数据"
    excel.FilePath := "C:\资料\原表.xlsx"
    excel.NameOrSerial := "Sheet2"
    excel.RowVar := "{行}"
    WriteLegacy("FileIOFile", "文件读写1", excel)
    excel.OperType := "读取文本文件"
    excel.OperMode := "逐行读取"
    excel.Encoding := "UTF-16"
    WriteLegacy("FileIOFile", "文件读写2", excel)
    ; Existing destination key must survive collision.
    excel.OperType := "读取Excel"
    WriteLegacy("FileIOFile", "Excel1", excel)
    search := Legacy122SearchData()
    search.StartPosX := 17
    search.TrueMacro := "运行1_备注_含下划线,文件读写1_写入"
    search.ConfigName := "legacy_selected"
    alternate := Legacy122SearchData()
    alternate.ConfigName := A_ScreenWidth "*" A_ScreenHeight "_全屏"
    alternate.StartPosX := 999
    search.ConfigArr := [alternate]
    WriteLegacy("SearchProFile", "搜索Pro1", search)
    move := Legacy122MMProData()
    move.MouseMoveMode := 2
    move.PosVarX := "{dx}"
    move.PosVarY := -20
    move.Count := 3
    move.Interval := 75
    WriteLegacy("MMProFile", "移动Pro1", move)
    move.MouseMoveMode := 1
    WriteLegacy("MMProFile", "移动Pro2", move)
    variable := Legacy122VariableData()
    variable.ToggleArr := [1, 1, 1, 1]
    variable.CopyVariableArr[4] := "保留第四项"
    WriteLegacy("VariableFile", "变量1", variable)
    WriteLegacy("InputFile", "输入1", Legacy122InputData())
    loopData := Legacy122LoopData()
    loopData.LoopBody := "运行1,文件读写1,移动Pro1"
    WriteLegacy("LoopFile", "循环1", loopData)
    graph := {CurCMD: "文件读写1_图形", NextNodeArr: ["图形节点2"]}
    WriteLegacy("GraphNodeFile", "图形节点1", graph)
    output := {Text: "运行1,文件读写1", OutputType: "发送内容"}
    WriteLegacy("OutputFile", "输出1", output)
    IniWrite("1", dir "\MacroFile.ini", "UserSettings", "NormalModeArr")
    macro := "🚫运行1_备注_含下划线⫶文件读写1_Excel,按键_JoyA⎖JoyB_点击_120_3_45,按键_a_点击_80,移动Pro1"
    IniWrite(macro, dir "\MacroFile.ini", "UserSettings", "NormalMacroArr1")
    Assert(RepairFixture().OnRepairSetting(dir, true), "real 1.2.2 constructor fixtures migrate through full pipeline")
    ReadData(stem, key) => JSON.parse(CfgRead(dir "\" stem ".toml", "UserSettings", key), , false)
    advanced := ReadData("RunFile", "运行Pro1")
    Assert(advanced.Mode == 4 && advanced.Option == 0 && advanced.StdIn == "输入数据", "advanced run becomes RunPro without changing mode/options/stdin")
    Assert(advanced.SaveNameArr[3] == "错误内容" && advanced.Encoding.Err == "UTF-16", "run pipe outputs and per-stream encodings retained")
    Assert(ReadData("RunFile", "运行2").Mode == 1, "simple default run remains simple")
    Assert(ReadData("RunFile", "运行Pro3").Option == 2, "window option alone requires RunPro editor")
    Assert(ReadData("RunFile", "运行Pro4").SaveNameArr.Length == 1, "wait process retains exit-code slot only")
    Assert(ReadData("RunFile", "运行Pro5").StdIn == "输入数据", "async pipe keeps stdin")
    xl := ReadData("FileIOFile", "Excel2")
    Assert(xl.OperType == "写入Excel" && xl.ArrName == "表格数据" && xl.RowVar == "{行}", "Excel split preserves range/variables and avoids key collision")
    Assert(ReadData("FileIOFile", "Excel1").OperType == "读取Excel", "existing Excel resource not overwritten")
    txt := ReadData("FileIOFile", "文件读写2")
    Assert(txt.OperType == "读取文件" && txt.OperMode == "逐行读取" && txt.Encoding == "UTF-16", "text operation renamed with mode/encoding unchanged")
    sr := ReadData("SearchProFile", "搜索Pro1")
    Assert(!sr.HasOwnProp("ConfigArr") && !sr.HasOwnProp("ConfigName") && sr.StartPosX == 17, "removed window rules do not select another screen preset")
    Assert(sr.SearchTargetArr.Length == 0 && sr.SatisfyCount == -1 && sr.Adaptive == 0, "new search fields use current defaults")
    delta := ReadData("DeltaMoveFile", "增量移动1")
    Assert(delta.DeltaX == "{dx}" && delta.DeltaY == -20 && delta.Count == 3 && delta.Interval == 75, "game-view movement splits into incremental move with repeat parameters")
    regular := ReadData("MMProFile", "鼠标移动Pro2")
    Assert(regular.RefMode == 0 && regular.MouseMoveMode == 1 && !regular.HasOwnProp("ConfigArr"), "regular mouse move preserves coordinate mode and defaults reference frame")
    Assert(ReadData("VariableFile", "变量1").CopyVariableArr[4] == "保留第四项", "old four-row data is not truncated to new one-row default")
    Assert(ReadData("InputFile", "输入1").TimeoutMs == 0, "new input fields filled from defaults")
    Assert(ReadData("GraphNodeFile", "图形节点1").CurCMD == "Excel2_图形", "graph node command references follow resource split")
    Assert(InStr(ReadData("LoopFile", "循环1").LoopBody, "增量移动1"), "loop body references follow resource split")
    Assert(ReadData("OutputFile", "输出1").Text == "运行1,文件读写1", "ordinary user text is never treated as macro references")
    migrated := CfgRead(dir "\MacroFile.toml", "Normal.Module1.Macro1", "Macro")
    Assert(InStr(migrated, "🚫运行Pro1_备注_含下划线"), "disabled marker and full remark retained")
    Assert(InStr(migrated, "手柄_A+B_点击_120_3_45"), "gamepad split preserves hold/repeat/interval fields")
    Assert(InStr(migrated, "按键_a_点击_80"), "keyboard command unchanged")
    Assert(!InStr(migrated, "🚫🚫"), "disabled marker is not duplicated by older compatibility stage")
    Assert(Compat13_Macro("按键_Joy1⎖DpadUp_按下", Map()) == "手柄_A+上_按下", "old recorder generic gamepad names map to split command")
    Assert(Compat13_Macro("按键_JoyAxisLX:75", Map()) == "手柄_LX:75", "analog gamepad value is retained")
    Assert(Compat13_Macro("按键_a⎖JoyA_点击_100", Map()) == "按键_a⎖JoyA_点击_100", "mixed keyboard/gamepad combo keeps simultaneous input semantics")
    Assert(!Compat13_UpgradeDir(dir), "instruction migration is idempotent")
    before := FileRead(dir "\MacroFile.toml", "UTF-8")
    RepairFixture().OnRepairSetting(dir, true)
    Assert(FileRead(dir "\MacroFile.toml", "UTF-8") == before, "repeat full repair preserves migrated references and macro layout")
    numericFile := {OperType: 4, OperMode: "追加写入"}
    Compat13_Normalize(numericFile, "FileIOFile")
    Assert(numericFile.OperType == "写入文件" && numericFile.Encoding == "UTF-8", "numeric legacy operation type converts and new fields default")
    conditions := {ToggleArr: [1, 1, 1, 1], NameArr: ["a"], CompareTypeArr: [3], VariableArr: ["1"]}
    Compat13_Normalize(conditions, "CompareFile")
    Assert(conditions.NameArr.Length == 4 && conditions.CompareTypeArr[1] == 3, "parallel condition arrays fill missing rows without truncation")
    TestLegacySettings()
}

TestLegacySettings() {
    dir := A_ScriptDir "\settings"
    DirCreate(dir)
    old := "[UserSettings]`nHoldFloat=12`nPauseHotkey=!z`nUnknownSetting=99`nUIPanelDefaultPos=8`nTableIndex=5`n"
        . "[ThemeColors]`nAppTheme=Custom`nWheel_NormalFill=#FF0000`n"
    FileAppend(old, dir "\MainSettings.ini", "UTF-16")
    Assert(Compat_UpgradeDir(dir), "legacy software settings conversion succeeds")
    path := dir "\MainSettings.toml"
    Assert(CfgRead(path, "UserSettings", "HoldFloat") == "12" && CfgRead(path, "UserSettings", "PauseHotkey") == "!z", "corresponding settings retain old values")
    Assert(CfgRead(path, "UserSettings", "UnknownSetting", "default") == "default", "unsupported settings use new defaults")
    Assert(CfgRead(path, "UserSettings", "UIPanelDefaultPos", 1) == 1, "removed enum value falls back to current default")
    Assert(CfgRead(path, "UserSettings", "SearchImageType", 1) == 1, "new setting uses current default rather than guessed command preference")
    Assert(!CfgHasSection(path, "ThemeColors"), "obsolete custom palette is not forced into new theme slots")
}
