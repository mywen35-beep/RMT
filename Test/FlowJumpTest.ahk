; Loaded by RunFlowJumpTest.py with verbatim production functions/classes.
global MainSoftData := {Lang: "中文", FontType: "Microsoft YaHei UI", IsModalSubGui: false}
global MySoftData := {isWorker: false}
global workIndex := 0
global Records := [], Config := Map(), English := false
global Translations := Map("流程跳转", "FlowJump", "循环-跳过本轮", "Loop-Continue", "循环-跳出", "Loop-Exit", "分支-跳出", "Branch-Exit")
global XAML_TEMPLATE := '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="940" Height="700"><Window.Resources>%resources%</Window.Resources>%app%</Window>'

GetLang(s) => English && Translations.Has(s) ? Translations[s] : s
GetLangKey(s) {
    for key, value in Translations {
        if (s == value)
            return key
    }
    return s
}
GetLangArr(arr) {
    result := []
    for value in arr
        result.Push(GetLang(value))
    return result
}
SplitMacro(s) => s == "" ? [] : StrSplit(s, "⫶")
SplitCommand(s) => StrSplit(s, "_")
GetCmdByParams(parts) {
    s := ""
    for part in parts
        s .= (A_Index == 1 ? "" : "_") part
    return s
}
GetCmdStr(s) => s
GetCmdSymbol(*) => ""
IsMoveCmd(*) => false
GetMacroCMDData(key) => Config[key]
WaitIfPaused(*) {
}
GraphPoolLog(*) {
}
TryGetTabVarValue(&value, table, index, raw, *) {
    value := raw
    return true
}
DoCompare(&value, *) {
    value := true
    return true
}
GetCompareTypeStrMap() => Map()
IsGraphNodeSerial(s) => InStr(s, "图形节点") == 1
ShouldSkipGraphNextDispatch(*) => false
DispatchGraphBranches(table, index, nexts, *) {
    for serial in nexts
        WalkGraphNode(table, serial, index)
}
ExecuteMacroCmdOnce(table, cmd, index, *) {
    if (InStr(cmd, "流程跳转_") == 1)
        OnFlowJump(table, cmd, index)
    else if (InStr(cmd, "循环") == 1)
        OnLoop(table, cmd, index)
    else if (InStr(cmd, "如果Pro") == 1)
        OnComparePro(table, cmd, index)
    else if (InStr(cmd, "如果") == 1)
        OnCompare(table, cmd, index)
    else
        Records.Push(cmd)
}

class XAMLHost {
    __New(xaml, *) {
        this.xaml := xaml
        this.wpfHwnd := A_ScriptHwnd
        this.Selected := 0
    }
    static FontSize() => 15
    static CmdTitleBarHeight() => 30
    static AddCmdTitleBar(main, title, height) => this.AddTitleBar(main, title, height)
    static AddTitleBar(main, title, height, *) {
        return {Title: main.Add("TextBlock").Grid_Row(0).Text(title).Height(height)}
    }
    OnEvent(*) {
    }
    Update(*) {
    }
    Query(*) => this.Selected
}
class XamlWin {
    static Open(*) => true
    static Owner(*) => 0
}
AddCmdOkBtn(parent, *) => parent.Add("Button").Name("BtnOk").Content("确定")
BindCmdEditorChrome(*) {
}
SafeGuiFromHwnd(*) => 0

Assert(value, message) {
    if (!value)
        throw Error(message)
    FileAppend("PASS " message "`n", "*")
}
NewTable() {
    global Records := []
    return {ID: "test", Items: [{ID: "item", Killed: false, VariableMap: Map("循环-跳过本轮", false, "循环-跳出", false, "分支-跳出", false)}]}
}
LoopConfig(body, count := 3) => {LoopCount: count, CondiType: 1, LoopBody: body}
IfConfig(body, legacy := "无") => {LogicalType: 1, ToggleArr: [true], CompareTypeArr: [1], NameArr: ["a"], VariableArr: ["b"], SaveToggle: false, TrueMacro: body, FalseMacro: "", TrueControlType: legacy, FalseControlType: "无"}

try {
    table := NewTable()
    Config["循环1"] := LoopConfig("before⫶流程跳转_循环-跳过本轮⫶wrong")
    OnTriggerMacroOnce(table, "循环1⫶after", 1)
    Assert(Records.Length == 4 && Records[3] == "before" && Records[4] == "after", "continue skips rest of each iteration and resumes after loop")

    table := NewTable()
    Config["循环1"] := LoopConfig("before⫶流程跳转_循环-跳出⫶wrong")
    OnTriggerMacroOnce(table, "循环1⫶after", 1)
    Assert(Records.Length == 2 && Records[2] == "after", "break exits loop and executes following command")

    table := NewTable()
    Config["循环2"] := LoopConfig("inner⫶流程跳转_循环-跳出⫶wrong", 5)
    Config["循环1"] := LoopConfig("循环2⫶outer", 2)
    OnTriggerMacroOnce(table, "循环1⫶after", 1)
    Assert(Records.Length == 5 && Records[1] == "inner" && Records[2] == "outer" && Records[5] == "after", "nested break affects only nearest loop")

    table := NewTable()
    Config["如果1"] := IfConfig("branch⫶流程跳转_分支-跳出⫶wrong")
    OnTriggerMacroOnce(table, "如果1⫶outside", 1)
    Assert(Records.Length == 2 && Records[2] == "outside", "branch exit skips branch tail but preserves outer continuation")

    table := NewTable()
    Config["如果1"] := IfConfig("branch⫶流程跳转_循环-跳过本轮⫶wrong")
    Config["循环1"] := LoopConfig("如果1⫶wrong", 2)
    OnTriggerMacroOnce(table, "循环1⫶after", 1)
    Assert(Records.Length == 3 && Records[3] == "after", "continue propagates out of if to enclosing loop")

    table := NewTable()
    Config["如果Pro1"] := {VariNameArr: [["a"]], CompareTypeArr: [[1]], VariableArr: [["b"]], LogicTypeArr: [1], MacroArr: ["hit⫶流程跳转_循环-跳出⫶wrong"], ControlTypeArr: ["无"], DefaultMacro: "wrong", DefaultControlType: "无"}
    Config["循环1"] := LoopConfig("如果Pro1⫶wrong")
    OnTriggerMacroOnce(table, "循环1⫶after", 1)
    Assert(Records.Length == 2 && Records[2] == "after", "jump from ifPro exits enclosing loop")

    table := NewTable()
    Config["如果1"] := IfConfig("legacy", "循环-跳出")
    Config["循环1"] := LoopConfig("如果1⫶wrong")
    OnTriggerMacroOnce(table, "循环1⫶after", 1)
    Assert(Records.Length == 2 && Records[2] == "after", "legacy conditional control still executes without data migration")

    table := NewTable()
    Config["图形节点1"] := {CurCMD: "流程跳转_循环-跳过本轮", NextNodeArr: ["图形节点2"]}
    Config["图形节点2"] := {CurCMD: "wrong", NextNodeArr: []}
    WalkGraphNode(table, "图形节点1", 1)
    Assert(Records.Length == 0 && table.Items[1].VariableMap["循环-跳过本轮"], "graph continue stops successor dispatch and preserves flag for loop")

    invalid := false
    try FlowJumpAction("流程跳转_无")
    catch
        invalid := true
    Assert(invalid, "invalid jump action rejected")
    for action in FlowJumpActions() {
        cmd := "流程跳转_" action
        English := true
        translated := GetLangCmd(cmd, 1)
        Assert(GetLangCmd(translated, 2) == cmd && FlowJumpAction(translated) == action, "language roundtrip " action)
        English := false
        graph := GraphFixture()
        parsed := graph._Parse(cmd)
        Assert(!parsed.temp && graph._BuildCmd(parsed) == cmd, "graph parse/build preserves inline command " action)
    }

    jump := FlowJumpGui()
    jump.ShowGui("")
    FileAppend(jump.ui.xaml, A_Args[1] "\jump.xaml", "UTF-8")
    for i, action in FlowJumpActions() {
        jump.ui.Selected := i - 1
        Assert(jump.GetCommandStr() == "流程跳转_" action, "selector produces unnumbered command " action)
        jump.ShowGui("流程跳转_" action)
        Assert(InStr(jump.ui.xaml, 'SelectedIndex="' (i - 1) '"'), "reopening restores selected action " action)
    }
    simple := CompareGui()
    simple._BuildAndShow()
    FileAppend(simple.ui.xaml, A_Args[1] "\if.xaml", "UTF-8")
    pro := CompareProGui()
    pro._BuildAndShow()
    pro.LVRowArr := [["以上都不是", "", "流程跳转_循环-跳出", "无"]]
    Assert(!InStr(pro._CardXml(1), "ComboBox") && InStr(pro._CardXml(1), "流程跳转_循环-跳出"), "ifPro cards show branch commands without flow selector")
    FileAppend(pro.ui.xaml, A_Args[1] "\ifpro.xaml", "UTF-8")
    branch := CompareProEditItemGui()
    branch._BuildAndShow()
    FileAppend(branch.ui.xaml, A_Args[1] "\branch.xaml", "UTF-8")
    ExitApp(0)
} catch as e {
    FileAppend("FAIL " e.Message " @ " e.Line "`n" e.Stack, "*")
    ExitApp(1)
}
