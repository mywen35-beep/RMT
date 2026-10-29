#Requires AutoHotkey v2.0

; 选择的图片归配置所有，避免依赖下载目录、临时目录或另一份配置。
; 已在配置 Images 内的文件保持原路径；同名文件另存，绝不覆盖其他指令的图片。
StoreSearchImage(path, settingDir := "") {
    if (settingDir == "")
        settingDir := A_WorkingDir "\Setting\" MySoftData.CurSettingName
    source := SearchImageFullPath(path)
    imagesDir := SearchImageFullPath(settingDir "\Images")
    if (InStr(source, imagesDir "\", false) == 1)
        return source
    SplitPath source, &name, , &ext, &stem
    destDir := imagesDir "\ScreenShot"
    DirCreate(destDir)
    dest := destDir "\" name
    suffix := 1
    while (FileExist(dest)) {
        dest := destDir "\" stem "_" suffix (ext == "" ? "" : "." ext)
        suffix += 1
    }
    FileCopy(source, dest)
    return dest
}

SearchImageFullPath(path) {
    size := DllCall("GetFullPathNameW", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
    if (!size)
        throw OSError()
    buf := Buffer(size * 2)
    if (!DllCall("GetFullPathNameW", "str", path, "uint", size, "ptr", buf, "ptr", 0, "uint"))
        throw OSError()
    return StrGet(buf)
}
