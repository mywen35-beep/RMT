; Loaded by RunMouseMoveProTest.py with production functions and editor class.
global MainSoftData := {FontType: "Microsoft YaHei UI", CoordXFloat: 0, CoordYFloat: 0}
global MySoftData := {}
global Records := [], Backend := true, FailMove := false, Missing := false
global XAML_TEMPLATE := '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="940" Height="700">%resources%%app%</Window>'
GetLang(s) => s
GetLangKey(s) => s
GetLangArr(arr) => arr
GetMacroKeyMode(*) => 1
TryGetTabVarValue(&value, table, index, raw) {
    if (raw == "missing")
        return false
    value := raw == "{end}" ? 300 : raw
    return true
}
GetFloatValue(value, *) => value
ResolveBindWindow(table, index, s) => s
GetHwndList(*) => Missing ? [] : [A_ScriptHwnd]
EnsureMouseBackend(*) => Backend
InitLogitechGHubNew() => true
MouseMoveAbsByKeyMode(k, x, y, speed, human) {
    Records.Push("abs:" k ":" x ":" y)
    if (FailMove)
        throw Error("simulated movement failure")
    return true
}
MouseMoveRelByKeyMode(k, x, y, *) {
    Records.Push("rel:" k ":" x ":" y)
    if (FailMove)
        throw Error("simulated movement failure")
    return true
}
MouseMoveByStrategy(k, mode, x, y, speed, clicks, human) => Records.Push("move:" clicks)
MouseMoveGameViewByKeyMode(*) => Records.Push("legacy")
; Intercept input calls so tests never move or press the real mouse.
Click(s) => Records.Push(s)
IbClick(s) => Records.Push("ib:" s)
AhiMouseDown(*) => Records.Push("ahi:Down")
AhiMouseUp(*) => Records.Push("ahi:Up")
class XAMLHost {
    __New(xaml, *) {
        this.xaml := xaml
        this.Values := Map()
    }
    static FontSize() => 15
    static CmdTitleBarHeight() => 30
    static AddCmdTitleBar(main, title, h) => main.Add("TextBlock").Text(title)
    OnEvent(*) {
    }
    Update(name, prop, value) => this.Values[name ">" prop] := value
    Query(names*) {
        if (names.Length == 1)
            return this.Values.Get(names[1], "")
        values := Map()
        for name in names
            values[name] := this.Values.Get(name, "")
        return values
    }
}
AddCmdOkBtn(parent) => parent.Add("Button").Name("BtnOk")
SaveMacroCMDData(data) {
    global Saved := data
}
BindCmdEditorChrome(*) {
}
Assert(value, msg) {
    if (!value)
        throw Error(msg)
}
try {
    DetectHiddenWindows(true)
    d := {PosVarX: 10, PosVarY: 20, EndPosVarX: "{end}", EndPosVarY: 400, ActionType: 4, MouseMoveMode: 0, Speed: 90}
    OnMMProOnce({}, 1, d)
    Assert(Records[1] == "abs:1:10:20" && Records[2] == "Down" && Records[3] == "abs:1:300:400" && Records[4] == "Up", "absolute start/end and variable resolution")
    Records := []
    d.RefMode := 1, d.WinInfo := "test"
    WinGetPos(&wx, &wy, , , "ahk_id " A_ScriptHwnd)
    OnMMProOnce({}, 1, d)
    Assert(Records[1] == "abs:1:" (wx+10) ":" (wy+20) && Records[3] == "abs:1:" (wx+300) ":" (wy+400), "window offset on both endpoints")
    Records := [], Missing := true
    OnMMProOnce({}, 1, d)
    Assert(Records.Length == 0, "missing window sends no input")
    Missing := false, d.RefMode := 0, d.EndPosVarY := "missing"
    OnMMProOnce({}, 1, d)
    Assert(Records.Length == 0, "missing end variable sends no input")
    d.MouseMoveMode := 1
    OnMMProOnce({}, 1, d)
    Assert(Records[1] == "Down" && Records[2] == "rel:1:10:20" && Records[3] == "Up", "relative drag ignores absolute end fields")
    for k in [1, 3, 4] {
        Records := [], FailMove := true
        try MouseDragByStrategy(k, 1, 10, 20, 0, 0)
        catch {
        }
        prefix := k == 3 ? "ib:" : (k == 4 ? "ahi:" : "")
        Assert(Records[1] == prefix "Down" && Records[3] == prefix "Up", "release on failure for backend " k)
    }
    FailMove := false, Backend := false, Records := []
    Assert(!MouseDragByStrategy(1, 0, 1, 2, 3, 4) && Records.Length == 0, "backend failure sends no input")
    Backend := true
    for action in [1, 2, 3] {
        Records := [], d.ActionType := action
        OnMMProOnce({}, 1, d)
        Assert(Records[1] == "move:" (action-1), "existing action " action)
    }
    Records := [], d.MouseMoveMode := 2
    OnMMProOnce({}, 1, d)
    Assert(Records[1] == "legacy", "legacy game-view dispatch")
    editor := MMProGui()
    editor._BuildAndShow()
    FileAppend(editor.ui.xaml, A_Args[1] "\movepro.xaml", "UTF-8")
    editor.ui.Values["ActionTypeCombo>SelectedIndex"] := 3
    editor.ui.Values["MouseMoveModeCombo>SelectedIndex"] := 0
    editor.OnTypeChange()
    Assert(editor.ui.Values["EndPosRow>Visibility"] == "Visible" && editor.ui.Values["PosXLabel>Text"] == "起始点", "absolute drag labels")
    Assert(editor.ui.Values["PosYLabel>Text"] == "", "drag Y label removed")
    editor.ui.Values["MouseMoveModeCombo>SelectedIndex"] := 1
    editor.OnTypeChange()
    Assert(editor.ui.Values["EndPosRow>Visibility"] == "Collapsed" && editor.ui.Values["PosXLabel>Text"] == "坐标偏移X:", "relative labels")
    editor._posTarget := "EndPosVar"
    editor.OnSureTarget(500, 600, "")
    Assert(editor.ui.Values["EndPosVarX>Text"] == 500 && editor.ui.Values["EndPosVarY>Text"] == 600, "targeter fills end coordinates")
    graph := GraphFixture()
    graph.ui := ""
    graph.Data := {ActionType: 4, PosVarX: 1, PosVarY: 2}
    for action in [1, 2, 3, 4]
        Assert(graph._MMProActionIndex(action) == action-1, "graph action index " action)
    Assert(graph._MMProActionFromText("拖拽") == 4 && graph._MMProActionFromText("移动后单击") == 2 && graph._MMProActionFromText("移动后双击") == 3, "graph action texts")
    Assert(graph._MMProActionFromState("MPAction", Map(), 4) == 4, "graph drag selection")
    graph._FlushMMProInline("n", Map("MPEndX_n", "{end}", "MPEndY_n", 600))
    Assert(graph.Data.ActionType == 4 && graph.Data.EndPosVarX == "{end}" && graph.Data.EndPosVarY == 600, "graph inline save preserves drag and end coordinates")
    editor.ui.Values["PosVarX"] := 10, editor.ui.Values["PosVarY"] := 20
    editor.ui.Values["EndPosVarX"] := "{end}", editor.ui.Values["EndPosVarY"] := 600
    editor.ui.Values["MouseMoveModeCombo>SelectedIndex"] := 0
    editor.Data := {}
    editor.SaveMMProData()
    Assert(Saved.ActionType == 4 && Saved.EndPosVarX == "{end}" && Saved.EndPosVarY == 600, "editor persists drag and end coordinates")
    Assert(editor.ui.Values["BtnCmdPreview>Visibility"] == "Visible", "Pro preview visible")
    for cls in [MouseMoveGui, DeltaMoveGui] {
        other := cls()
        other._BuildAndShow()
        Assert(other.ui.Values["BtnCmdPreview>Visibility"] == "Visible", "movement preview visible")
    }
    p := MousePreviewPoints("move", 100, 200, -50, 30)
    Assert(p.X1 == -50 && p.Y1 == 30 && p.X2 == 100 && p.Y2 == 200, "absolute preview")
    p := MousePreviewPoints("move", -10.8, 20.8, 100, 200, 1)
    Assert(p.X2 == 90 && p.Y2 == 220, "relative preview truncates like executor")
    p := MousePreviewPoints("pro", 10, 20, 900, 800, 0, 4, 300, 400, 1, -500, 100)
    Assert(p.X1 == -490 && p.Y1 == 120 && p.X2 == -200 && p.Y2 == 500, "window drag preview includes both offsets")
    p := MousePreviewPoints("pro", 10, 20, 100, 200, 1, 4, 900, 800)
    Assert(p.X1 == 100 && p.X2 == 110 && p.Y2 == 220, "relative drag preview ignores absolute endpoints")
    p := MousePreviewPoints("delta", 3, -5, 100, 200, 1, 1, 0, 0, 10)
    Assert(p.X2 == 130 && p.Y2 == 150, "incremental total displacement")
    MouseMovePreview.Show({X1: 100, Y1: 100, X2: 300, Y2: 200})
    Assert(IsObject(MouseMovePreview.Overlay), "native overlay created")
    style := WinGetExStyle("ahk_id " MouseMovePreview.Overlay.Hwnd)
    Assert((style & 0x08080020) == 0x08080020, "overlay is layered, click-through and nonactivating")
    MouseMovePreview.Clear()
    Assert(!IsObject(MouseMovePreview.Overlay), "overlay cleared")
    MouseMovePreview.Show({X1: 150, Y1: 150, X2: 150, Y2: 150})
    MouseMovePreview.Clear()
    Assert(p.Steps == 10 && p.StepX == 3 && p.StepY == -5, "incremental preview retains every step")
    range := MousePreviewVisibleSteps(p, 0, 0, 1920, 1080)
    Assert(range.First == 1 && range.Last == 10, "all visible steps retained")
    p := MousePreviewPoints("delta", -100, 0, 50, 50, 1, 1, 0, 0, 1000000)
    range := MousePreviewVisibleSteps(p, -200, 0, 400, 100)
    Assert(range.First == 1 && range.Last == 2, "negative steps skip only offscreen positions")
    p := MousePreviewPoints("delta", 0, 0, 50, 50, 1, 1, 0, 0, 1000000)
    range := MousePreviewVisibleSteps(p, 0, 0, 100, 100)
    Assert(range.First == 1 && range.Last == 1, "coincident steps share one marker")
    MainSoftData.ThemeColors := Map("Theme_Color01", "#FFFF8C00", "Theme_Color14", "#FF5C3317")
    palette := MouseMovePreview.Palette()
    Assert(palette.Line == 0xFFFF8C00 && palette.Outline == 0xFF5C3317, "preview uses current theme slots")
    toggleUi := XAMLHost("")
    toggleUi.Values := Map("DeltaXCon", 20, "DeltaYCon", 10, "CountCon", 5)
    MouseMovePreview.Toggle(toggleUi, "delta")
    Assert(MouseMovePreview.Editor == toggleUi && IsObject(MouseMovePreview.Overlay), "preview toggles on")
    Assert(toggleUi.Values["BtnCmdPreview>Background"] == "$Theme:ActionBg", "preview button shows selected theme state")
    hwnd := MouseMovePreview.Overlay.Hwnd
    Sleep(2700)
    Assert(IsObject(MouseMovePreview.Overlay) && MouseMovePreview.Overlay.Hwnd == hwnd, "preview persists beyond previous timeout without recreating window")
    frame := MouseMovePreview.LastFrame
    toggleUi.Values["DeltaXCon"] := 30
    MouseMovePreview.Refresh()
    Assert(MouseMovePreview.LastFrame != frame && MouseMovePreview.Overlay.Hwnd == hwnd, "parameter changes refresh existing overlay")
    frame := MouseMovePreview.LastFrame
    MainSoftData.ThemeColors["Theme_Color01"] := "#FF7050C0"
    MouseMovePreview.Refresh()
    Assert(MouseMovePreview.LastFrame != frame, "theme changes refresh preview")
    MouseMovePreview.Clear(XAMLHost(""))
    Assert(MouseMovePreview.Editor == toggleUi, "another editor cannot close active preview")
    MouseMovePreview.Toggle(toggleUi, "delta")
    Assert(!IsObject(MouseMovePreview.Editor) && !IsObject(MouseMovePreview.Overlay), "second click switches preview off")
    Assert(toggleUi.Values["BtnCmdPreview>Background"] == "Transparent", "button returns to unselected state")
    for cls in [MouseMoveGui, MMProGui, DeltaMoveGui] {
        closing := cls()
        closing.ui := toggleUi
        MouseMovePreview.Toggle(toggleUi, "delta")
        closing._CloseWindow()
        Assert(!IsObject(MouseMovePreview.Editor) && !IsObject(MouseMovePreview.Overlay), "editor close turns preview off")
    }
    FileAppend("PASS persistent toggle, theme colors, live refresh, incremental markers and editor cleanup`n", "*")
    FileAppend("PASS preview geometry, title button bindings and native overlay lifecycle`n", "*")
    FileAppend("PASS movement execution, driver release on failure, legacy actions, editor state and targeter" , "*")
    ExitApp(0)
}
catch as e {
    FileAppend(e.Message " at " e.Line "\n" e.Stack, "*")
    ExitApp(1)
}
