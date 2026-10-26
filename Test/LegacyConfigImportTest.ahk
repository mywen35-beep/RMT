; Body loaded by RunLegacyConfigImportTest.py with verbatim production dependencies.
global SettingSection := "UserSettings"
global MySoftData := {SpecialKeyMap: Map(), TableInfo: []}
global RMT_LV_ERROR := 3
global TestCommandData := ""
global TriggeredTarget := ""
GetMacroCMDData(*) => TestCommandData
MyTriggerSubMacro(tableID, itemID) {
    global TriggeredTarget := tableID "|" itemID
}
GetLang(value) => value
GetLangKey(value) => value
GetTableIndexByID(*) => 1
RMTLogSys(*) {
}
RMTLogSysInfo(*) {
}
BuildSortIndex(*) {
}
Assert(ok, message) {
    if (!ok)
        throw Error(message)
    FileAppend("PASS " message "`n", "*", "UTF-8")
}
try {
    dir := A_ScriptDir "\imported"
    FolderPackager.UnpackFile(A_ScriptDir "\legacy.rmt", dir)
    result := IniImport_ConvertDir(dir)
    Assert(result["Failed"].Count == 0 && result["Converted"] == 2, "1.2.2 RMPK unpack + UTF-16 INI conversion")
    CfgBatchBegin()
    try CompatCMD(dir "\MacroFile.toml")
    finally CfgBatchEnd()
    Assert(CfgRead(dir "\MacroFile.toml", SettingSection, "NormalHoldTimeArr") == "500π500", "migration independent of active profile tables")
    Assert(IniImport_ExpandFlatMacroFile(dir), "flat arrays expand into table/module/macro paths")
    CfgInvalidate()
    macroPath := dir "\MacroFile.toml"
    Assert(CfgRead(macroPath, "Normal.Module2", "Remark") == "模块二", "module names retained")
    Assert(CfgRead(macroPath, "Normal.Module2", "ForbidState") == "1", "module disabled state retained")
    Assert(CfgRead(macroPath, "Normal.Module1.Macro1", "TK") == "F1", "hotkey retained")
    Assert(InStr(CfgRead(macroPath, "Normal.Module1.Macro1", "Macro"), "间隔_10"), "macro commands retained")
    Assert(CfgRead(macroPath, "SubMacro.Module1.Macro1", "Macro") == "间隔_20", "macro without hotkey or fold retained")
    data := JSON.parse(CfgRead(dir "\SubMacroFile.toml", SettingSection, "宏操作1"), , false)
    Assert(data.MacroSerial == "Normal.Module2.Macro1" && data.Index == 2, "old serial wins over stale index and becomes path ID")
    Assert(CompatMacroTypeSymbol(data.MacroType) == "Normal", "legacy Chinese macro type resolves to runtime table")
    TestCommandData := data
    runtimeTable := TableItem()
    runtimeTable.ID := "Normal"
    runtimeTable.Symbol := "Normal"
    for id in ["Normal.Module1.Macro1", "Normal.Module2.Macro1"] {
        runtimeItem := MacroItem()
        runtimeItem.ID := id
        runtimeTable.Items.Push(runtimeItem)
    }
    MySoftData.TableInfo := [runtimeTable]
    OnSubMacro(runtimeTable, "宏操作1", 1)
    Assert(TriggeredTarget == "Normal|Normal.Module2.Macro1", "actual executor triggers migrated target")
    Assert(CompatMacroTypeSymbol("当前宏") == "当前宏" && CompatMacroTypeSymbol("UI") == "UI", "current macro and symbolic types unchanged")
    before := FileRead(macroPath, "UTF-8")
    Assert(!IniImport_ExpandFlatMacroFile(dir) && FileRead(macroPath, "UTF-8") == before, "repeat migration does not rewrite current layout")
    imageData := {SearchImagePath: "C:\Old\Setting\OldName\Images\test.png"}
    Assert(CompatPath(dir "\SearchProFile.toml", imageData) && imageData.SearchImagePath == dir "\Images\test.png", "image resolves in actual imported temporary directory")
    Assert(!CompatPath(dir "\SearchProFile.toml", imageData), "image migration is idempotent")
    ; A standalone old macro with neither FoldInfo nor TKArr must trigger migration.
    solo := A_ScriptDir "\solo"
    DirCreate(solo)
    FileAppend("[UserSettings]`nSubMacroModeArr=1`nSubMacroMacroArr1=间隔_30", solo "\MacroFile.ini", "UTF-8")
    soloResult := IniImport_ConvertDir(solo)
    for name, err in soloResult["Failed"]
        FileAppend(name " " err "`n", "*", "UTF-8")
    Assert(IniImport_ExpandFlatMacroFile(solo), "mode-only legacy profile detected")
    bad := A_ScriptDir "\bad"
    DirCreate(bad)
    FileAppend("broken configuration", bad "\MacroFile.ini", "UTF-8")
    rejected := false
    try RepairFixture().OnRepairSetting(bad, true)
    catch
        rejected := true
    Assert(rejected && FileExist(bad "\MacroFile.ini"), "strict import rejects failed conversion and retains source INI")
    clean := A_ScriptDir "\pipeline"
    FolderPackager.UnpackFile(A_ScriptDir "\legacy.rmt", clean)
    Assert(RepairFixture().OnRepairSetting(clean, true), "complete production repair pipeline succeeds")
    ref := JSON.parse(CfgRead(clean "\SubMacroFile.toml", SettingSection, "宏操作1"), , false)
    Assert(ref.MacroSerial == "Normal.Module2.Macro1", "full pipeline persists migrated macro reference")
    TestLegacyCommands()
    TestReviewRegressions()
    TestVersionMigration()
    ExitApp(0)
} catch as e {
    FileAppend("FAIL " e.Message " @ " e.Line "`n" e.Stack, "*", "UTF-8")
    ExitApp(1)
}


