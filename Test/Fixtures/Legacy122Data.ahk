; Frozen constructor fixtures from RMTv1.2.2:Main/DataClass.Ahk.
; Keep legacy fields/defaults to detect accidental reinterpretation in future migrations.
class Legacy122RunData {
    __New() {
        this.SerialStr := ""
        this.Target := ""
        this.Mode := 1
        this.Option := 1
    }
}
class Legacy122FileIOData {
    __New() {
        this.SerialStr := ""
        this.OperType := "读取Excel"    ;1读取Excel 2写入Excel 3读取文本文件 4写入文本文件
        this.Encoding := "UTF-8"        ;文本文件编码格式
        this.FilePath := ""

        ;读取Excel      "单元格", "指定行", "指定列", "指定区域-行", "指定区域-列"
        ;写入Excel      单元格    行号自增  列号自增  指定区域-行    指定区域-列
        ;读取文本文件   读取全部内容, 逐行读取, 指定行
        ;写入文本文件   "覆盖写入", "追加写入", "追加写入-行", "指定行", "行号自增"
        this.OperMode := "单元格"
        this.NameOrSerial := 1
        this.RowVar := 1
        this.ColVar := 1
        this.RowEndVar := 1
        this.ColEndVar := 1

        this.TextRowVar := 1        ;文本文件指令行号

        this.Content := "写入的内容" ;单元格时的写入内容
        this.ArrName := "Arr"       ;写入区域时的数组

        this.SaveType := "变量"     ;保存类型  变量或数组
        this.SaveName := "Data"
    }
}
class Legacy122SearchData {
    __New() {
        this.SerialStr := ""
        this.ConfigName := Format("{}*{}_{}", A_ScreenWidth, A_ScreenHeight, GetLang("全屏"))
        this.SearchType := 1        ;1屏幕图片  2屏幕颜色  3屏幕文本 4窗口图片 5窗口颜色 6窗口文本
        this.WinInfo := ""          ;窗口信息
        this.SearchColor := "FFFFFF"
        this.SearchText := GetLang("检索文本")
        this.SearchImagePath := ""
        this.Similar := 90 ; 图片搜索模糊匹配度100  - 50
        this.OCRType := 1   ;1中文  2英文
        this.SearchImageType := 1 ; 1 opencv 2 rmt
        this.StartPosX := 0
        this.StartPosY := 0
        this.EndPosX := A_ScreenWidth
        this.EndPosY := A_ScreenHeight
        this.SearchCount := 1
        this.SearchInterval := 1000
        this.MouseActionType := 2   ;   1无动作 2移动到目标 3移动到目标点击
        this.Speed := 90
        this.ClickCount := 1
        this.ConfigArr := []    ;配置数组，不同的分辨率
        this.TrueMacro := ""
        this.FalseMacro := ""
        this.ResultToggle := 0
        this.ResultSaveName := GetLang("搜索结果")
        this.TrueValue := 1
        this.FalseValue := 0
        this.CoordToogle := 0
        this.CoordXName := GetLang("坐标X")
        this.CoordYName := GetLang("坐标Y")
    }

}
class Legacy122MMProData {
    __New() {
        this.SerialStr := ""
        this.ConfigName := Format("{}*{}_{}", A_ScreenWidth, A_ScreenHeight, GetLang("全屏"))
        this.ConfigArr := []
        this.PosVarX := 100
        this.PosVarY := 100
        this.ActionType := 1          ;鼠标动作 1移动 2移动点击1次 3移动点击2次
        this.MouseMoveMode := 0      ;鼠标移动模式 0=绝对移动 1=相对移动 2=游戏视角
        this.Speed := 90           ;移动速度
        this.Count := 1
        this.Interval := 1000
    }
}
class Legacy122VariableData {
    __New() {
        this.SerialStr := ""
        this.IsIgnoreExist := 0
        this.ToggleArr := [1, 0, 0, 0]
        this.OperaTypeArr := [1, 1, 1, 1]   ;1赋值 2随机 3字符 4删除
        this.VariableArr := ["Var1", "Var2", "Var3", "Var4"]
        this.CopyVariableArr := ["1", "0", "0", "0"]
        this.MinVariableArr := ["0", "0", "0", "0"]
        this.MaxVariableArr := ["10", "10", "10", "10"]
    }
}
class Legacy122CompareData {
    __New() {
        this.ToggleArr := [1, 0, 0, 0]
        this.NameArr := ["Var1", "Var2", "Var3", "Var4"]
        this.CompareTypeArr := [1, 1, 1, 1]  ;1大于 2大于等于 3等于 4小于等 5小于 6字符包含 7存在变量 8正则匹配
        this.VariableArr := ["Var1", "Var2", "Var3", "Var4"]
        this.TrueControlType := "无"   ;流程控制：1无 2循环-跳过本轮 3循环-跳出 4分支-跳出
        this.FalseControlType := "无"   ;流程控制：1无 2循环-跳过本轮 3循环-跳出 4分支-跳出
        this.TrueMacro := ""
        this.FalseMacro := ""
        this.SaveToggle := 0
        this.SaveName := GetLang("结果")
        this.TrueValue := 1
        this.FalseValue := 0
        this.LogicalType := 1
    }
}
class Legacy122LoopData {
    __New() {
        this.SerialStr := ""
        this.LoopCount := 10    ;循环次数
        this.CondiType := 1     ;条件类型 1：无 2：退出条件 3：继续条件
        this.LogicType := 1     ;逻辑关系  1：且    2：或
        this.ToggleArr := [1, 0, 0, 0]
        this.NameArr := ["Var1", "Var2", "Var3", "Var4"]
        this.CompareTypeArr := [1, 1, 1, 1]  ;1大于 2大于等于 3等于 4小于等 5小于 6字符包含 7存在变量
        this.VariableArr := ["Var1", "Var2", "Var3", "Var4"]
        this.LoopBody := ""     ;循环体
    }

    ;用于逻辑树展示
    static GetCondiStr(Data) {
        CommandStr := ""
        symbolStr := Data.LogicType == 1 ? GetLang("且") : GetLang("或")
        CompareTypeStrArr := GetLangArr(["大于", "大于等于", "等于", "小于等于",
            "小于", "字符包含", "变量存在", "正则匹配"])

        loop 4 {
            if (!Data.ToggleArr[A_Index])
                continue

            VariName := GetLang(Data.NameArr[A_Index])
            TypeStr := CompareTypeStrArr[Data.CompareTypeArr[A_Index]]
            Variable := GetLang(Data.VariableArr[A_Index])
            if (Data.CompareTypeArr[A_Index] != 7)
                CommandStr .= VariName " " TypeStr " " Variable " " symbolStr " "
            else
                CommandStr .= VariName " " TypeStr " " symbolStr " "
        }

        CommandStr := Trim(CommandStr, " ")
        CommandStr := Trim(CommandStr, symbolStr)
        CommandStr := Trim(CommandStr, " ")
        return CommandStr
    }
}
class Legacy122OperationData {
    __New() {
        this.SerialStr := ""
        this.ToggleArr := [1, 0, 0, 0]
        this.UpdateNameArr := ["Var1", "Var2", "Var3", "Var4"]
        this.ExpressionArr := ["", "", "", ""]    ;完整表达式字符串（用于支持括号和整体编辑）
    }
}
class Legacy122InputData {
    __New() {
        this.SerialStr := ""
        this.Type := "弹窗"                 ;弹窗 状态 继续 继续&取消
        this.PauseType := "暂停当前宏"      ;交互时：不暂停 暂停当前宏  暂停所有宏
        this.CancelType := "终止当前宏"     ;取消时  终止当前宏  终止所有宏
        this.SaveName := "Data"             ;保存的变量名或数组名
    }
}
