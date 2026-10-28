#Requires AutoHotkey v2.0

; Preview reads unsaved editor values and draws only; it never saves or sends input.
BindMouseMovePreview(ui, kind) {
    ui.Update("BtnCmdPreview", "Visibility", "Visible")
    ui.Update("BtnCmdPreview", "ToolTip", GetLang("预览移动路径"))
    ui.OnEvent("BtnCmdPreview", "Click", (*) => PreviewMouseMovement(ui, kind))
}

PreviewMouseMovement(ui, kind) => MouseMovePreview.Toggle(ui, kind)

; Read all editor values in one IPC request. Timer refreshes do not show modal errors
; while the user is in the middle of typing a coordinate.
ReadMousePreview(ui, kind, cx, cy, notify := false) {
    fields := kind == "delta" ? ["DeltaXCon", "DeltaYCon", "CountCon"]
        : (kind == "pro" ? ["MouseMoveModeCombo>SelectedIndex", "ActionTypeCombo>SelectedIndex", "PosVarX", "PosVarY", "EndPosVarX", "EndPosVarY", "RefCombo>SelectedIndex", "WinInfoCon"]
        : ["MouseMoveModeCombo>SelectedIndex", "PosXCon", "PosYCon"])
    state := ui.Query(fields*)
    mode := 1, action := 1, endX := 0, endY := 0, count := 1, wx := 0, wy := 0
    if (kind == "delta") {
        x := state.Get("DeltaXCon", ""), y := state.Get("DeltaYCon", ""), count := state.Get("CountCon", "")
    } else {
        mode := state.Get("MouseMoveModeCombo>SelectedIndex", 0)
        if (kind == "pro") {
            x := state.Get("PosVarX", ""), y := state.Get("PosVarY", "")
            action := state.Get("ActionTypeCombo>SelectedIndex", 0) + 1
            if (action == 4 && mode == 0)
                endX := state.Get("EndPosVarX", ""), endY := state.Get("EndPosVarY", "")
            if (mode == 0 && state.Get("RefCombo>SelectedIndex", 0) == 1) {
                hwnds := GetHwndList(GetLangKey(state.Get("WinInfoCon", "")))
                if (!IsObject(hwnds) || hwnds.Length == 0) {
                    if (notify)
                        MsgBox(GetLang("预览未找到目标窗口。"))
                    return ""
                }
                try WinGetPos(&wx, &wy, , , "ahk_id " hwnds[1])
                catch {
                    if (notify)
                        MsgBox(GetLang("预览未找到目标窗口。"))
                    return ""
                }
            }
        } else {
            x := state.Get("PosXCon", ""), y := state.Get("PosYCon", "")
        }
    }
    for value in [x, y, endX, endY, count] {
        if (!IsNumber(value)) {
            if (notify)
                MsgBox(GetLang("预览需要数值坐标和次数，请先将变量替换为数值。"))
            return ""
        }
    }
    return MousePreviewPoints(kind, x, y, cx, cy, mode, action, endX, endY, count, wx, wy)
}

; Numeric geometry follows the executor: relative moves truncate, absolute moves round.
MousePreviewPoints(kind, x, y, cx, cy, mode := 0, action := 1, endX := 0, endY := 0, count := 1, wx := 0, wy := 0) {
    if (kind == "delta") {
        steps := Max(1, Integer(count)), dx := Integer(x), dy := Integer(y)
        return {X1: cx, Y1: cy, X2: cx + dx*steps, Y2: cy + dy*steps, StepX: dx, StepY: dy, Steps: steps}
    }
    if (mode == 1)
        return {X1: cx, Y1: cy, X2: cx + Integer(x), Y2: cy + Integer(y)}
    if (kind == "pro" && action == 4)
        return {X1: Round(wx + x), Y1: Round(wy + y), X2: Round(wx + endX), Y2: Round(wy + endY)}
    return {X1: cx, Y1: cy, X2: Round(wx + x), Y2: Round(wy + y)}
}

class MouseMovePreview {
    static Overlay := ""
    static Editor := ""
    static Kind := ""
    static OriginX := 0
    static OriginY := 0
    static LastFrame := ""
    static Revision := 0
    static RefreshTimer := ObjBindMethod(MouseMovePreview, "Refresh")

    static Toggle(ui, kind) {
        if (this.Editor == ui) {
            this.Clear()
            return
        }
        this.Clear()
        this.Editor := ui, this.Kind := kind
        CoordMode("Mouse", "Screen")
        MouseGetPos(&cx, &cy)
        this.OriginX := cx, this.OriginY := cy
        if (!this.Refresh(true)) {
            this.Clear()
            return
        }
        SetTimer(this.RefreshTimer, 300)
    }

    static Clear(ui := "") {
        ; A different editor closing must not dismiss the current editor's preview.
        if (IsObject(ui) && this.Editor != ui)
            return
        SetTimer(this.RefreshTimer, 0)
        this.Revision += 1
        if (IsObject(this.Editor))
            this.SetButton(false)
        this.Editor := "", this.Kind := "", this.LastFrame := ""
        this.HideOverlay()
    }

    static HideOverlay() {
        if (IsObject(this.Overlay))
            this.Overlay.Destroy()
        this.Overlay := ""
    }

    static SetButton(enabled) {
        try {
            this.Editor.Update("BtnCmdPreview", "Background", enabled ? "$Theme:ActionBg" : "Transparent")
            this.Editor.Update("BtnCmdPreview", "Foreground", enabled ? "$Theme:ActionText" : "$Theme:TitleBarForeground")
            this.Editor.Update("BtnCmdPreview", "ToolTip", GetLang(enabled ? "关闭指令预览" : "预览移动路径"))
        }
    }

    static Palette() {
        colors := MainSoftData.HasProp("ThemeColors") ? MainSoftData.ThemeColors : Map()
        return {Line: Integer("0x" SubStr(AppThemeUtil.ResolveColor(colors, "Theme_Color01"), 2)),
            Outline: Integer("0x" SubStr(AppThemeUtil.ResolveColor(colors, "Theme_Color14"), 2))}
    }

    static Refresh(notify := false) {
        if (!IsObject(this.Editor))
            return false
        revision := this.Revision
        points := ReadMousePreview(this.Editor, this.Kind, this.OriginX, this.OriginY, notify)
        if (revision != this.Revision)
            return false
        if (!IsObject(points)) {
            this.HideOverlay()
            this.LastFrame := ""
            return false
        }
        palette := this.Palette()
        frame := points.X1 "," points.Y1 "," points.X2 "," points.Y2 "," palette.Line "," palette.Outline
        if (points.HasOwnProp("Steps"))
            frame .= "," points.Steps "," points.StepX "," points.StepY
        if (frame != this.LastFrame) {
            this.Show(points, palette)
            this.LastFrame := frame
            this.SetButton(true)
        }
        return true
    }

    static Show(p, palette := "") {
        if (!IsObject(palette))
            palette := this.Palette()
        ; Physical virtual-desktop pixels, including monitors left/above the primary.
        left := SysGet(76), top := SysGet(77), width := SysGet(78), height := SysGet(79)
        token := Gdip_Startup()
        hbm := 0, hdc := 0, old := 0, g := 0, outline := 0, pen := 0, brush := 0
        try {
            hbm := CreateDIBSection(width, height)
            hdc := CreateCompatibleDC()
            old := SelectObject(hdc, hbm)
            g := Gdip_GraphicsFromHDC(hdc)
            Gdip_GraphicsClear(g, 0)
            Gdip_SetSmoothingMode(g, 4)
            outline := Gdip_CreatePen(palette.Outline, 7)
            pen := Gdip_CreatePen(palette.Line, 3)
            brush := Gdip_BrushCreateSolid(palette.Line)
            x1 := p.X1 - left, y1 := p.Y1 - top, x2 := p.X2 - left, y2 := p.Y2 - top
            dx := x2-x1, dy := y2-y1, length := Sqrt(dx*dx + dy*dy)
            if (length > 0) {
                ux := dx/length, uy := dy/length
                arrow := Min(18, length), wing := arrow * 0.5
                ax := x2 - ux*arrow - uy*wing, ay := y2 - uy*arrow + ux*wing
                bx := x2 - ux*arrow + uy*wing, by := y2 - uy*arrow - ux*wing
                for linePen in [outline, pen] {
                    Gdip_DrawLine(g, linePen, x1, y1, x2, y2)
                    Gdip_DrawLine(g, linePen, ax, ay, x2, y2)
                    Gdip_DrawLine(g, linePen, bx, by, x2, y2)
                }
            }
            if (p.HasOwnProp("Steps")) {
                range := MousePreviewVisibleSteps(p, left, top, width, height)
                loop Max(0, range.Last - range.First + 1) {
                    step := range.First + A_Index - 1
                    px := x1 + p.StepX * step, py := y1 + p.StepY * step
                    Gdip_DrawEllipse(g, outline, px-3, py-3, 6, 6)
                    Gdip_FillEllipse(g, brush, px-3, py-3, 6, 6)
                }
            }
            Gdip_DrawEllipse(g, outline, x1-5, y1-5, 10, 10)
            Gdip_FillEllipse(g, brush, x1-5, y1-5, 10, 10)
            ; A ring also marks a zero-length move.
            Gdip_DrawEllipse(g, pen, x2-8, y2-8, 16, 16)
            if (!IsObject(this.Overlay))
                this.Overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020 -DPIScale")
            this.Overlay.Show("NA x" left " y" top " w" width " h" height)
            UpdateLayeredWindow(this.Overlay.Hwnd, hdc, left, top, width, height)
        } finally {
            if (brush)
                Gdip_DeleteBrush(brush)
            if (pen)
                Gdip_DeletePen(pen)
            if (outline)
                Gdip_DeletePen(outline)
            if (g)
                Gdip_DeleteGraphics(g)
            if (old)
                SelectObject(hdc, old)
            if (hbm)
                DeleteObject(hbm)
            if (hdc)
                DeleteDC(hdc)
            Gdip_Shutdown(token)
        }
    }
}

; Skip only off-screen steps; retain every visible step even for very large counts.
MousePreviewVisibleSteps(p, left, top, width, height) {
    first := 1, last := p.Steps
    for axis in [{Origin: p.X1, Delta: p.StepX, Low: left-7, High: left+width+7},
        {Origin: p.Y1, Delta: p.StepY, Low: top-7, High: top+height+7}] {
        if (axis.Delta == 0) {
            if (axis.Origin < axis.Low || axis.Origin > axis.High)
                return {First: 1, Last: 0}
            continue
        }
        a := (axis.Low-axis.Origin)/axis.Delta, b := (axis.High-axis.Origin)/axis.Delta
        first := Max(first, Ceil(Min(a, b)))
        last := Min(last, Floor(Max(a, b)))
    }
    if (p.StepX == 0 && p.StepY == 0)
        last := Min(last, 1) ; coincident points have identical pixels
    return {First: first, Last: last}
}
