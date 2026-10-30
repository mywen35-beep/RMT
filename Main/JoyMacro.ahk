#Requires AutoHotkey v2.0

class JoyMacro {

    class MacroInfo {
        __New(action, actionUp, processName, originalKey := "") {
            this.actionFunc := action
            this.actionUpFunc := actionUp
            this.processName := processName
            this.originalKey := originalKey
            this.keepOriginal := originalKey != ""
        }

        Action() {
            global MyMouseInfo
            if (this.processName != "") {
                if (!MyMouseInfo.CheckIfMatch(this.processName, true))
                    return
            }

            action := this.actionFunc
            action()
            if (this.keepOriginal)
                JoyMacro.PassThroughKey(this.originalKey, 1)
        }

        ActionUp() {
            if (this.actionUpFunc == "") {
                if (this.keepOriginal)
                    JoyMacro.PassThroughKey(this.originalKey, 0)
                return
            }
            ; 松开时不检查窗口条件（确保松止能停下）
            action := this.actionUpFunc
            action()
            if (this.keepOriginal)
                JoyMacro.PassThroughKey(this.originalKey, 0)
        }
    }

    __New() {
        this.MacroMap := Map()
        this.ComboMacroMap := Map()
        this.interval := 50
        this.joyFloat := 5
        this.axisMaxValue := 100
        this.JoyIndexArr := []
        this.diActive := Map()

        this.timerAction := this.CheckMacro.Bind(this)

        ; 轴分类/区间表（CheckMacro 分发用 joyAxises/joyPOVMap；区间统一走 Xbox 布局 xboxJosAxisMap）
        this.joyAxises := Map("JoyXMin", 0, "JoyXMax", 100, "JoyYMin", 0, "JoyYMax", 100, "JoyZMin", 0, "JoyZMax", 100,
            "JoyRMin", 0, "JoyRMax", 100, "JoyUMin", 0, "JoyUMax", 100, "JoyVMin", 0, "JoyVMax", 100)
        this.joyPOVMap := Map("JoyPOV_0", 0, "JoyPOV_9000", 9000, "JoyPOV_18000", 18000, "JoyPOV_27000", 27000)

        ; 边缘触发状态追踪（0=上次松开，1=上次按下）——统一路径唯一状态表（GameInput/XInput）
        this.prevXboxState := Map()

        this.xboxJoyBtnMap := Map("Joy1", 12, "Joy2", 13, "Joy3", 14, "Joy4", 15, "Joy5", 8, "Joy6", 9, "Joy7", 5,
            "Joy8", 4, "Joy9", 6, "Joy10", 7,
            "JoyPOV_0", 0, "JoyPOV_18000", 1, "JoyPOV_27000", 2, "JoyPOV_9000", 3)
        this.xboxJosAxisMap := Map("JoyXMin", -32768, "JoyXMax", 32767, "JoyYMin", -32768, "JoyYMax", 32767, "JoyZMin",
            255, "JoyZMax", 255, "JoyRMin", -32768, "JoyRMax", 32767, "JoyUMin", -32768, "JoyUMax", 32767, "JoyVMin", -
            32768, "JoyVMax", 32767)

    }

    __Delete() {
        SetTimer this.timerAction, 0
    }

    AddMacro(key, action, processName, actionUp := "") {
        keepOriginal := SubStr(key, 1, 1) == "~"
        if (keepOriginal)
            key := LTrim(key, "~")
        key := JoyMacro.NormalizeTriggerKey(key)
        originalKey := keepOriginal ? key : ""
        JoyDebugLog("AddMacro key=" key " mapped=" (MySoftData.JoyXboxToAhkMap.Has(key) ? MySoftData.JoyXboxToAhkMap[key] : "<missing>"), "trigger")
        ; 统一到 GameInput 的 XInput 兼容布局：强制用 Xbox 映射，不再按 JoyType 切换
        ; 到 PS5 布局（JoyXboxToAhkMap 与 JoyPS5ToAhkMap 左侧物理键名相同，
        ; 仅右侧内部目标不同；GameInput 把 DS4 也归一为 XInput，故 Xbox 映射对所有类型都对）。
        joyToAhkMap := MySoftData.JoyXboxToAhkMap

        if (InStr(key, " & ")) {
            keyParts := StrSplit(key, " & ")
            if (keyParts.Length == 2) {
                ahkKey1 := joyToAhkMap[keyParts[1]]
                ahkKey2 := joyToAhkMap[keyParts[2]]

                if (ahkKey1 == "" || ahkKey2 == "") {
                    return
                }

                comboKey := ahkKey1 " & " ahkKey2
                macro := JoyMacro.MacroInfo(action, actionUp, processName, originalKey)
                this.ComboMacroMap.Set(comboKey, macro)
                this.Enable()
                return
            }
        }

        macro := JoyMacro.MacroInfo(action, actionUp, processName, originalKey)
        ahkKey := joyToAhkMap[key]
        this.MacroMap.Set(ahkKey, macro)
        this.Enable()
    }

    ; 兼容旧配置中误保存的短名 A/B/...，统一成 JoyA/JoyB/...。
    static NormalizeTriggerKey(key) {
        if (InStr(key, " & ")) {
            parts := StrSplit(key, " & ")
            return JoyMacro.NormalizeTriggerKey(parts[1]) " & " JoyMacro.NormalizeTriggerKey(parts[2])
        }
        if (InStr(key, "Joy"))
            return key
        try converted := JoyShortToInternal(key)
        catch
            converted := ""
        return converted != "" ? converted : key
    }

    Enable() {
        if (this.MacroMap.Count == 0 && this.ComboMacroMap.Count == 0)
            return
        ; 保留 1.2.2 的 DirectInput 设备枚举：很多手柄不会出现在
        ; GameInput/XInput，但 AHK 的 1Joy1/1Joy2 状态仍然可读。
        this.JoyIndexArr := []
        loop 10 {
            idx := A_Index
            try {
                name := GetKeyState(idx "JoyName")
                if (name != "" && !InStr(name, "ViGEm") && !InStr(name, "vXbox") && !InStr(name, "Nefarius"))
                    this.JoyIndexArr.Push(idx)
            }
        }
        ; 手柄类型由用户通过 GUI 下拉框设置，此处不再自动覆盖。
        ; GameInput/XInput 仍作为 DirectInput 不可用时的补充读取路径。
        try GI_EnsureWrapper()
        catch as e
            JoyDebugLog("JoyMacro.Enable: GameInput 不可用: " e.Message)
        SetTimer this.timerAction, 0
        SetTimer this.timerAction, this.interval
    }

    CheckMacro() {
        if (this.ComboMacroMap.Count > 0) {
            for key, macro in this.ComboMacroMap {
                this.CheckComboMacro(key)
            }
        }

        for key, macro in this.MacroMap {
            isJoyAxis := this.joyAxises.Has(key)
            isJoyPOV := this.joyPOVMap.Has(key)
            isJoyBtn := !isJoyAxis && !isJoyPOV

            if (isJoyBtn) {
                this.CheckBtnMacro(key)
            }
            else if (isJoyPOV) {
                this.CheckPOVMacro(key)
            }
            else {
                this.CheckAxisMacro(key)
            }
        }
    }

    CheckBtnMacro(joyBtnSymbol) {
        ; 统一单路径：按钮从 GameInput 读（wButtons 位），不再走 DirectInput。
        ; 仅在能映射到 XInput 位时触发（JoyN / DPad 键都已含在 xboxJoyBtnMap）。
        ; Xbox 手柄必须先走 XInput DLL。DirectInput 对 Xbox 经常存在设备名但
        ; 按键状态始终为 0 的情况，先读它会让宏看起来像“完全没有触发”。
        if (this.xboxJoyBtnMap.Has(joyBtnSymbol)) {
            if (this.CheckXboxBtnOrPOVMacro(joyBtnSymbol))
                return
        }
        ; 1.2.2 兼容路径：DirectInput/AHK JoyN 是最直接的物理按键来源。
        ; 先走它，避免 GameInput/XInput 不报告设备时整条触发链失效。
        for idx in this.JoyIndexArr {
            try pressed := GetKeyState(idx joyBtnSymbol, "P")
            catch
                continue
            prevKey := joyBtnSymbol "|DI|" idx
            prev := this.prevXboxState.Has(prevKey) ? this.prevXboxState[prevKey] : 0
            if (pressed && !prev) {
                this.prevXboxState[prevKey] := 1
                this.diActive[joyBtnSymbol] := true
                this.MacroMap.Get(joyBtnSymbol).Action()
                return
            }
            if (pressed && prev)
                this.diActive[joyBtnSymbol] := true
            if (!pressed && prev) {
                this.prevXboxState[prevKey] := 0
                this.diActive[joyBtnSymbol] := false
                this.MacroMap.Get(joyBtnSymbol).ActionUp()
                return
            }
        }
        ; 只有 DirectInput 确认该键正在按下时才抑制 XInput；
        ; 其它情况下继续遍历全部 XInput 0~3 槽位。
        if (this.diActive.Has(joyBtnSymbol) && this.diActive[joyBtnSymbol])
            return
    }

    CheckComboMacro(comboKey) {
        ; 统一单路径：组合键走 GameInput（XInput 布局），不再并行跑 DI 分支。
        ; key1/key2 已由 AddMacro 经 Xbox 映射转成内部键，直接走 XInput 组合判定。
        keyParts := StrSplit(comboKey, " & ")
        if (keyParts.Length != 2)
            return

        key1 := keyParts[1]
        key2 := keyParts[2]

        ; GameInput 不读回 ViGEm 虚拟输出（回环探针已证），无需按虚拟槽位跳过
        loop 4 {
            idx := A_Index - 1
            try State := this.XInputState(idx)
            catch
                continue
            if !IsObject(State) {
                ; 设备暂不可读（未就绪/断连）时也要复位边沿状态，否则该槽位会永远停在「已按下」，
                ; 表现为组合键只生效一次、之后怎么按都没反应。
                prevKey0 := comboKey "|Xbox|" idx
                if (this.prevXboxState.Has(prevKey0) && this.prevXboxState[prevKey0]) {
                    this.prevXboxState[prevKey0] := 0
                    this.ComboMacroMap.Get(comboKey).ActionUp()
                }
                continue
            }

            pressed1 := false
            pressed2 := false

            if (this.xboxJoyBtnMap.Has(key1)) {
                bitSymbol1 := this.xboxJoyBtnMap.Get(key1)
                pressed1 := (State.wButtons >> bitSymbol1) & 1
            }
            else if (this.xboxJosAxisMap.Has(key1)) {
                value1 := this.GetXboxAxisValue(key1, idx)
                valueSection1 := this.GetAxisTriggerSection(key1, true)
                pressed1 := (value1 != 0 && value1 >= valueSection1[1] && value1 <= valueSection1[2])
            }

            if (this.xboxJoyBtnMap.Has(key2)) {
                bitSymbol2 := this.xboxJoyBtnMap.Get(key2)
                pressed2 := (State.wButtons >> bitSymbol2) & 1
            }
            else if (this.xboxJosAxisMap.Has(key2)) {
                value2 := this.GetXboxAxisValue(key2, idx)
                valueSection2 := this.GetAxisTriggerSection(key2, true)
                pressed2 := (value2 != 0 && value2 >= valueSection2[1] && value2 <= valueSection2[2])
            }

            prevKey := comboKey "|Xbox|" idx
            prev := this.prevXboxState.Has(prevKey) ? this.prevXboxState[prevKey] : 0

            if (pressed1 && pressed2) {
                if (!prev) {
                    this.prevXboxState[prevKey] := 1
                    macro := this.ComboMacroMap.Get(comboKey)
                    macro.Action()
                    return
                }
            }
            else if (prev) {
                ; 任一键松开（或本帧未同时按下）必须复位，否则 prev 永远为 1 → 组合键只能用一次
                this.prevXboxState[prevKey] := 0
                macro := this.ComboMacroMap.Get(comboKey)
                macro.ActionUp()
            }
        }
    }

    ; 将触发手柄的原始状态复制到 RMT 的虚拟手柄。这样即使触发宏，
    ; 游戏仍能看到该按键本来的按下/松开行为。
    static PassThroughKey(key, state) {
        key := RegExReplace(key, "^~", "")
        if (InStr(key, " & ")) {
            for part in StrSplit(key, " & ")
                JoyMacro.PassThroughKey(part, state)
            return
        }
        name := SubStr(key, 4)
        static xboxMap := Map("A", "A", "B", "B", "X", "X", "Y", "Y", "LB", "LB", "RB", "RB",
            "LS", "LS", "RS", "RS", "Back", "Back", "Start", "Start", "Home", "Xbox", "Pad", "A")
        static ds4Map := Map("A", "Cross", "B", "Circle", "X", "Square", "Y", "Triangle", "LB", "L1", "RB", "R1",
            "LS", "LS", "RS", "RS", "Back", "Share", "Start", "Options", "Home", "Ps", "Pad", "TouchPad")
        btnMap := MainSoftData.JoyType == "DS4" ? ds4Map : xboxMap
        static dpadMap := Map("DpadUp", "Up", "DpadRight", "Right", "DpadDown", "Down", "DpadLeft", "Left")
        if (dpadMap.Has(name))
            MyViGJoySetState("Dpad", state ? dpadMap[name] : "None", 0)
        else if (btnMap.Has(name))
            MyViGJoySetState("Btn", btnMap[name], state)
        else if (name == "LT" || name == "RT")
            MyViGJoySetState("Axis", name, state ? 255 : 0)
        else if (RegExMatch(name, "^Axis(LX|LY|RX|RY)(Min|Max)$", &m)) {
            axis := m[1]
            target := state ? (m[2] == "Min" ? 0 : 100) : 50
            MyViGJoySetState("Axis", axis, target)
        }
    }

    CheckPOVMacro(joyPOVSymbol) {
        ; 统一单路径：DPad 从 GameInput 读（wButtons 位），不再走 DirectInput POV。
        if (this.xboxJoyBtnMap.Has(joyPOVSymbol))
            this.CheckXboxBtnOrPOVMacro(joyPOVSymbol)
    }

    CheckAxisMacro(joyAxisSymbol) {
        ; 统一单路径：轴从 GameInput 读（真实摇杆/扳机值），不再走 DirectInput。
        if (this.xboxJosAxisMap.Has(joyAxisSymbol))
            this.CheckXboxAxisMacro(joyAxisSymbol)
    }

    CheckXboxBtnOrPOVMacro(joySymbol) {
        isXboxHasBtn := this.xboxJoyBtnMap.Has(joySymbol)
        if (!isXboxHasBtn)
            return false

        ; 反回环已下移到读取源头(GI_CollectStates 过滤 PID=0x028E 的 ViGEm 设备)：
        ; ViGEm 永不进入本读取数组，JoyMacro 读到的只有物理手柄 → 此处直接按边沿触发即可。
        ; (曾用的因果位掩码 IsViGEmOutputtingBit/__ViGEmOutButtons 已删除——它在 ViGEm 输出
        ;  同键位时会误伤物理手柄的同键按下。)
        found := false
        loop 4 {
            idx := A_Index - 1
            try state := this.XInputState(idx)
            catch
                continue
            if IsObject(state) {
                found := true
                bitSymbol := this.xboxJoyBtnMap.Get(joySymbol)
                pressed := (state.wButtons >> bitSymbol) & 1
                prevKey := joySymbol "|Xbox|" idx
                prev := this.prevXboxState.Has(prevKey) ? this.prevXboxState[prevKey] : 0

                if (pressed && !prev) {
                    this.prevXboxState[prevKey] := 1
                    this.MacroMap.Get(joySymbol).Action()
                    return true
                }
                if (!pressed && prev) {
                    this.prevXboxState[prevKey] := 0
                    this.MacroMap.Get(joySymbol).ActionUp()
                }
            } else {
                prevKey := joySymbol "|Xbox|" idx
                if (this.prevXboxState.Has(prevKey) && this.prevXboxState[prevKey]) {
                    this.prevXboxState[prevKey] := 0
                    this.MacroMap.Get(joySymbol).ActionUp()
                }
            }
        }
        return found
    }

    CheckXboxAxisMacro(joyAxisSymbol) {
        valueSection := this.GetAxisTriggerSection(joyAxisSymbol, true)

        ; GameInput 不读回 ViGEm 虚拟输出，无需按虚拟槽位跳过
        loop 4 {
            idx := A_Index - 1
            value := this.GetXboxAxisValue(joyAxisSymbol, idx)
            if (value == 0) {
                prevKey := joyAxisSymbol "|Xbox|" idx
                if (this.prevXboxState.Has(prevKey) && this.prevXboxState[prevKey]) {
                    this.prevXboxState[prevKey] := 0
                    this.MacroMap.Get(joyAxisSymbol).ActionUp()
                }
                continue
            }

            pressed := (value >= valueSection[1] && value <= valueSection[2])
            prevKey := joyAxisSymbol "|Xbox|" idx
            prev := this.prevXboxState.Has(prevKey) ? this.prevXboxState[prevKey] : 0

            if (pressed && !prev) {
                this.prevXboxState[prevKey] := 1
                this.MacroMap.Get(joyAxisSymbol).Action()
                return
            }
            if (!pressed && prev) {
                this.prevXboxState[prevKey] := 0
                this.MacroMap.Get(joyAxisSymbol).ActionUp()
            }
        }
    }

    ;数据获取函数
    GetAxisTriggerSection(axisKey, isXbox) {
        value := this.joyAxises.Get(axisKey)
        floatValue := this.axisMaxValue * (this.joyFloat / 100)
        if (isXbox) {
            value := this.xboxJosAxisMap.Get(axisKey)
            floatValue := Abs(value) * (this.joyFloat / 100)
        }
        if (value <= 0) {
            return [value, value + floatValue]
        }
        else {
            return [value - floatValue, value]
        }
    }

    GetXboxAxisValue(joyAxisSymbol, userIndex := 0) {
        joyAxisName := SubStr(joyAxisSymbol, 1, 4)
        ; GameInput 读取失败(未就绪/异常)按无轴值处理，避免异常冒泡打断轴触发循环
        try State := this.XInputState(userIndex)
        catch
            return 0
        if !IsObject(State)
            return 0

        if (joyAxisSymbol == "JoyZMin") {
            return State.bLeftTrigger
        }
        else if (joyAxisSymbol == "JoyZMax") {
            return State.bRightTrigger
        }

        if (joyAxisName == "JoyX") {
            return State.sThumbLX
        }
        else if (joyAxisName == "JoyY") {
            return State.sThumbLY
        }
        else if (joyAxisName == "JoyR") {
            return State.sThumbRY
        }
        else if (joyAxisName == "JoyU") {
            return State.sThumbRX
        }
        else if (joyAxisName == "JoyV") {
            ; XInput/GameInput 只有双摇杆(X/Y) + 右摇杆(R/U) + 双扳机(Z)，无第 6 轴 JoyV。
            ; 旧实现返回 sThumbRY 会与 JoyR 撞（误读右摇杆 Y），统一路径下 JoyV 无合法数据源，
            ; 强制 return 0 使其永不触发（Xbox 映射也不含 JoyV 键，仅防御）。
            return 0
        }

        return 0
    }

    ; 手柄状态读取：优先走 GameInput（同进程复用 RecordJoyUtil 的 wrapper），
    ; 对不产生 GameInput reading 的 XInput 手柄回退到系统 XInput DLL。
    ; UserIndex 在 GameInput 下无槽位概念，单手柄取 device[0]，多手柄按设备序映射。
    ; 两种读取源都失败时按“读不到即不触发”处理。
    XInputState(UserIndex) {
        ; Xbox 手柄以系统 XInput DLL 为首选来源。GameInput 在部分驱动上
        ; 不产生 reading，不能让它的空结果阻断 XInput 0~3 槽位读取。
        try {
            xi := JoyXInputEx(UserIndex)
            if IsObject(xi)
                return {
                    dwPacketNumber: 0,
                    wButtons: xi.wButtons,
                    bLeftTrigger: xi.lt,
                    bRightTrigger: xi.rt,
                    sThumbLX: Round(xi.lx * 327.67),
                    sThumbLY: Round(xi.ly * 327.67),
                    sThumbRX: Round(xi.rx * 327.67),
                    sThumbRY: Round(xi.ry * 327.67)
                }
        }
        catch {
        }
        states := []
        try {
            GI_EnsureWrapper()   ; 幂等懒加载 GameInput wrapper；触发首次读取即自初始化
            states := GI_CollectStates()
        } catch {
            ; GameInput 不可用时直接使用下面的 XInput 回退。
        }
        if (states.Length == 0) {
            ; 部分 XInput 手柄不会产生 GameInput reading（日志表现为
            ; Snapshot GI end n=0），但仍可通过系统 XInput 接口读取。
            ; 这里保留 XInput 兼容回退，确保基础按键触发可用。
            try {
                ahk := this.AhkState(UserIndex)
                if IsObject(ahk)
                    return ahk
            }
            catch
                return 0
        }
        ; 越界槽位(UerIndex>=设备数)直接返回 0，不再回退读 device[0]——
        ; 否则多手柄/槽位循环时第 2+ 台会重复读到第 1 台，造成重复计数/误触发
        if (UserIndex >= states.Length)
            return 0
        st := states[UserIndex + 1]
        return {
            dwPacketNumber: 0,
            wButtons:       st.wButtons,
            bLeftTrigger:   st.bLeftTrigger,
            bRightTrigger:  st.bRightTrigger,
            sThumbLX:       st.sThumbLX,
            sThumbLY:       st.sThumbLY,
            sThumbRX:       st.sThumbRX,
            sThumbRY:       st.sThumbRY
        }
    }

    ; DirectInput/AHK 回退：部分手柄只在 AHK 的 JoyN 设备枚举中可见。
    AhkState(UserIndex) {
        idx := UserIndex + 1
        try name := GetKeyState(idx "JoyName")
        catch
            return 0
        ; 某些 DirectInput 设备 JoyName 为空，但 Joy1/Joy2 状态仍可读；
        ; 只有明确识别为虚拟手柄时才过滤，不能因名称为空丢弃整台设备。
        if (InStr(name, "ViGEm") || InStr(name, "vXbox") || InStr(name, "Nefarius"))
            return 0
        static logged := Map()
        if (!logged.Has(idx)) {
            logged[idx] := true
            JoyDebugLog("AHK fallback device idx=" idx " name=" name, "trigger")
        }
        bits := 0
        static btnBits := Map("Joy1", 12, "Joy2", 13, "Joy3", 14, "Joy4", 15, "Joy5", 8, "Joy6", 9,
            "Joy7", 5, "Joy8", 4, "Joy9", 6, "Joy10", 7, "Joy13", 10, "Joy14", 5)
        for key, bit in btnBits {
            try {
                if (GetKeyState(idx key))
                    bits |= (1 << bit)
            }
        }
        try pov := Integer(GetKeyState(idx "JoyPOV"))
        catch
            pov := 65535
        static povBits := Map(0, 0, 9000, 3, 18000, 1, 27000, 2)
        if (povBits.Has(pov))
            bits |= (1 << povBits[pov])
        return {
            dwPacketNumber: 0,
            wButtons: bits,
            bLeftTrigger: 0,
            bRightTrigger: 0,
            sThumbLX: 0,
            sThumbLY: 0,
            sThumbRX: 0,
            sThumbRY: 0
        }
    }

}
