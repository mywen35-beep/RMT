global CheckedPhysicalKey := ""
global CheckedResult := ""
IsPhysicalKeyPressed(key) {
    global CheckedPhysicalKey := key
    return true
}
IsJoyPovCentered(*) => true
IsJoyPovAt(*) => true
IsJoyAxisCompare(*) => true
MySetGlobalVariable(names, values, *) {
    global CheckedResult := values[1]
}

TestReviewRegressions() {
    global MySoftData, TestCommandData, TriggeredTarget, CheckedPhysicalKey, CheckedResult
    nodes := MergeFixture._ParseMacroItemsToml(A_ScriptDir "\pipeline\MacroFile.toml", "Normal", 1)
    Assert(nodes.Length == 2 && nodes[1].Children[1].Serial == "Normal.Module1.Macro1"
        && nodes[2].Children[1].Serial == "Normal.Module2.Macro1", "merge parser preserves unique source paths across modules")
    names := Map("运行1", "运行Pro2")
    Assert(Compat13_Macro("运行1_备注🚫⭐▶", names) == "运行Pro2_备注🚫⭐▶", "remark markers do not become command flags")
    Assert(Compat13_Macro("🚫运行1_备注🚫", names) == "🚫运行Pro2_备注🚫", "command and remark markers preserved independently")
    Assert(CompatMacro("🚫运行1_备注🚫", &fixed) == "🚫运行1_备注🚫", "older migration stage preserves remark markers")
    Assert(CompatMacro("按键_a_3_100_备注🚫", &fixed) == "按键_a_点击_100_备注🚫", "older syntax conversion does not disable enabled command")

    MySoftData.GetJoyToAhkMap := (*) => Map("JoyHome", "Joy13", "JoyA", "Joy1")
    TestCommandData := {KeyArr: ["Home"], CheckType: 1, StateType: 1, VarName: "test"}
    CheckedPhysicalKey := ""
    OnKeyCheck(0, "按键检测1", 1)
    Assert(CheckedPhysicalKey == "", "keyboard Home does not read physical gamepad")
    OnJoyCheck(0, "手柄检测1", 1)
    Assert(CheckedPhysicalKey == "Joy13" && CheckedResult == 1, "gamepad Home still resolves to gamepad button")
    CheckedPhysicalKey := ""
    TestCommandData.KeyArr := ["A"]
    OnKeyCheck(0, "按键检测1", 1)
    Assert(CheckedPhysicalKey == "", "keyboard A is not interpreted as gamepad A")
    TestCommandData.KeyArr := ["JoyHome"]
    OnKeyCheck(0, "按键检测1", 1)
    Assert(CheckedPhysicalKey == "Joy13", "legacy explicit gamepad names remain supported")

    source := {MacroType: "按键宏", MacroSerial: "Normal.Module1.Macro1", Index: 1, CallType: "触发"}
    missing := {MacroType: "按键宏", MacroSerial: "Normal.Module9.Macro1", Index: 1, CallType: "触发"}
    current := {MacroType: "当前宏", MacroSerial: "", Index: 1, CallType: "触发"}
    forward := {MacroType: "子宏", MacroSerial: "SubMacro.Module1.Macro1", Index: 1}
    parsed := [Map("Data", source), Map("Data", missing), Map("Data", current), Map("Data", forward)]
    targets := Map("Normal.Module1.Macro1", {ID: "Normal.Module2.Macro1", Index: 2},
        "SubMacro.Module1.Macro1", {ID: "SubMacro.Module3.Macro1", Index: 5})
    MergeFixture.RemapMacroTargets(parsed, targets)
    Assert(source.MacroSerial == "Normal.Module2.Macro1" && source.Index == 2, "merge updates both path and index after target allocation")
    Assert(forward.MacroSerial == "SubMacro.Module3.Macro1" && forward.Index == 5, "merge supports forward references across tables")
    Assert(missing.MacroSerial == "" && missing.Index == 0, "unselected target cannot bind to an existing macro")
    Assert(current.Index == 1, "current-macro operation is not remapped")
    table := MySoftData.TableInfo[1]
    TestCommandData := source
    TriggeredTarget := ""
    OnSubMacro(table, "宏操作1", 1)
    Assert(TriggeredTarget == "Normal|Normal.Module2.Macro1", "merged operation executes imported macro rather than existing collision")
    TestCommandData := missing
    TriggeredTarget := ""
    OnSubMacro(table, "宏操作1", 1)
    Assert(TriggeredTarget == "", "missing imported target does not trigger another macro")
    missing.Index := 1
    OnSubMacro(table, "宏操作1", 1)
    Assert(TriggeredTarget == "", "stale index cannot override an unresolved macro ID")
}
