global RMT_VERSION := "1.3"
RMTC_SealBuffer(*) {
    throw Error("Encryption is not used by these package tests")
}

TestVersionMigration() {
    Assert(Compat_CompareVersion("1.3", "1.3.0") == 0 && Compat_CompareVersion("1.10", "1.3") > 0,
        "version comparison uses numeric components")
    old := A_ScriptDir "\version-old"
    FolderPackager.UnpackFile(A_ScriptDir "\legacy.rmt", old)
    Assert(Compat_ReadVersion(old) == "0.0", "unversioned package starts before historical fixes")
    IniWrite("按键_a_3_100", old "\MacroFile.ini", "UserSettings", "NormalMacroArr1")
    Assert(RepairFixture().OnRepairSetting(old, true), "unversioned import runs ordered migration chain")
    Assert(CfgRead(old "\MacroFile.toml", "Normal.Module1.Macro1", "Macro") == "按键_a_点击_100",
        "historical command conversion precedes 1.3 layout conversion")
    Assert(Compat_ReadVersion(old) == "1.3" && !Compat_UpgradeDir(old), "successful migration records version and repeat import skips steps")

    v122 := A_ScriptDir "\version-122"
    FolderPackager.UnpackFile(A_ScriptDir "\legacy.rmt", v122)
    ; 历史语法作为探针：带 1.2.2 标记时不能再经过历史指令转换。
    IniWrite("按键_a_3_100", v122 "\MacroFile.ini", "UserSettings", "NormalMacroArr1")
    Compat_WriteVersion(v122, "1.2.2")
    CfgWrite(JSON.stringify({SerialStr: "运行1", Mode: 4, Option: 1}, 0), v122 "\RunFile.toml", "UserSettings", "运行1")
    Compat_UpgradeDir(v122)
    Assert(CfgRead(v122 "\MacroFile.toml", "Normal.Module1.Macro1", "Macro") == "按键_a_3_100", "1.2.2 metadata skips historical conversion")
    Assert(CfgRead(v122 "\RunFile.toml", "UserSettings", "运行Pro1", "") != "", "1.2.2 metadata still runs 1.3 command splitting")

    current := A_ScriptDir "\version-current"
    DirCreate(current)
    Compat_WriteVersion(current, "1.3")
    CfgWrite("keep", current "\MainSettings.toml", "UserSettings", "NewSetting")
    Assert(!Compat_UpgradeDir(current) && CfgRead(current "\MainSettings.toml", "UserSettings", "NewSetting") == "keep",
        "current version does not reapply old settings filter")
    DirCreate(current "\Images")
    FileAppend("image", current "\Images\test.png")
    CfgWrite(JSON.stringify({SearchImagePath: "C:\Old\Images\test.png"}, 0), current "\SearchFile.toml", "UserSettings", "搜索1")
    Compat_UpgradeDir(current)
    imageData := JSON.parse(CfgRead(current "\SearchFile.toml", "UserSettings", "搜索1"), , false)
    Assert(imageData.SearchImagePath == current "\Images\test.png", "same-version import still relocates package images")

    package := A_ScriptDir "\versioned.rmt"
    FolderPackager.PackFolder(old, package)
    unpacked := A_ScriptDir "\version-roundtrip"
    FolderPackager.UnpackFile(package, unpacked)
    Assert(Compat_ReadVersion(unpacked) == "1.3" && CfgRead(Compat_VersionFile(unpacked), "RMT", "AppVersion") == "1.3",
        "real RMPK export roundtrip carries config and application versions")
    Assert(!Compat_UpgradeDir(unpacked), "exported current package skips version migrations")
    FolderPackager.UnpackFile(A_ScriptDir "\legacy.rmt", unpacked)
    Assert(Compat_ReadVersion(unpacked) == "0.0", "unversioned overwrite cannot inherit stale destination version")

    future := A_ScriptDir "\version-future"
    DirCreate(future)
    Compat_WriteVersion(future, "1.4")
    FileAppend("[UserSettings]`nNormalModeArr=1", future "\MacroFile.ini", "UTF-8")
    rejected := false
    try Compat_UpgradeDir(future)
    catch
        rejected := true
    Assert(rejected && FileExist(future "\MacroFile.ini") && Compat_ReadVersion(future) == "1.4",
        "future version rejected before modifying configuration")
    CfgWrite("broken", Compat_VersionFile(future), "RMT", "ConfigVersion")
    rejected := false
    try Compat_UpgradeDir(future)
    catch
        rejected := true
    Assert(rejected && FileExist(future "\MacroFile.ini"), "malformed version is not silently treated as legacy")
    failed := A_ScriptDir "\version-failed"
    DirCreate(failed)
    FileAppend("invalid INI", failed "\MacroFile.ini")
    rejected := false
    try Compat_UpgradeDir(failed)
    catch
        rejected := true
    Assert(rejected && !FileExist(Compat_VersionFile(failed)), "failed conversion does not mark migration complete")
}
