#Requires AutoHotkey v2.0
#Include "CompatTov1-2.ahk"
#Include "Compatv1-3.ahk"

; 配置格式版本独立于 RMPK 容器版本和软件构建版本。
Compat_CurrentVersion() => "1.3"
Compat_VersionFile(dir) => dir "\RmtVersion.toml"

Compat_CompareVersion(left, right) {
    if (!RegExMatch(left, "^\d+\.\d+(?:\.\d+)?$") || !RegExMatch(right, "^\d+\.\d+(?:\.\d+)?$"))
        throw Error("无效的 RMT 配置版本：" left " / " right)
    a := StrSplit(left, "."), b := StrSplit(right, ".")
    loop 3 {
        x := A_Index <= a.Length ? Integer(a[A_Index]) : 0
        y := A_Index <= b.Length ? Integer(b[A_Index]) : 0
        if (x != y)
            return x > y ? 1 : -1
    }
    return 0
}

Compat_ReadVersion(dir) {
    path := Compat_VersionFile(dir)
    if (!FileExist(path))
        return "0.0"
    CfgInvalidate(path)
    version := CfgRead(path, "RMT", "ConfigVersion", "")
    Compat_CompareVersion(version, Compat_CurrentVersion())
    return version
}

Compat_WriteVersion(dir, version) {
    CfgWrite(version, Compat_VersionFile(dir), "RMT", "ConfigVersion")
}

; 新版本新增 CompatvN-M.ahk，并按目标版本顺序登记。
Compat_MigrationSteps() {
    return [{Version: "1.2.2", Run: CompatTo12_UpgradeDir},
        {Version: "1.3", Run: Compat13_UpgradeProfile}]
}

Compat_UpgradeDir(dir) {
    version := Compat_ReadVersion(dir)
    if (Compat_CompareVersion(version, Compat_CurrentVersion()) > 0)
        throw Error("配置版本 " version " 高于当前支持的 " Compat_CurrentVersion())
    loop files, dir "\*.toml" {
        CfgInvalidate(A_LoopFileFullPath)
        TomlUtil_Invalidate(A_LoopFileFullPath)
    }
    ; 仅转换存储格式，不在 INI 转换器中夹带版本语义迁移。
    conv := IniImport_ConvertDir(dir)
    if (conv["Failed"].Count) {
        msg := ""
        for name, err in conv["Failed"]
            msg .= name ": " err "`n"
        throw Error("配置转换失败：" msg)
    }
    changed := conv["Converted"] > 0
    for step in Compat_MigrationSteps() {
        if (Compat_CompareVersion(version, step.Version) >= 0)
            continue
        changed := step.Run.Call(dir) || changed
        ; 本阶段完整成功后才推进版本，失败不能标为已迁移。
        Compat_WriteVersion(dir, step.Version)
        version := step.Version
        changed := true
    }
    ; 路径搬迁不是版本升级：同版本包导入也需要定位包内图片。
    loop files, dir "\*.toml" {
        path := A_LoopFileFullPath
        for key, value in CfgSection(path, IniImport_Section()) {
            data := CompatParseData(value)
            if (IsObject(data) && CompatPath(path, data)) {
                CfgWrite(JSON.stringify(data, 0), path, IniImport_Section(), key)
                changed := true
            }
        }
    }
    return changed
}
