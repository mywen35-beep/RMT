###  编译OpenCV插件

当前插件接口版本为 API 12。`FindScreenImageEx`、`FindWinImageEx` 通过独立的 `colorMatch`、`adaptive` 参数控制颜色匹配与自适应缩放。默认灰度匹配，相似度达到 95% 不再自动改为彩色。旧导出接口保留调用格式，固定灰度匹配。

修改识别逻辑后需要同时重新编译并分发 `x64/RMT_OpenCV.dll` 和 `x86/RMT_OpenCV.dll`；已运行的软件需重启以加载新 DLL。

窗口抓图优先使用 Windows Graphics Capture（Windows 10 1903 起），读取 GPU 合成画面，覆盖模拟器内部的子窗口渲染。返回图像统一按真实客户区原点裁剪，不将标题栏、菜单栏或窗口阴影计入搜索坐标，也不拉伸画面。系统可能显示窗口捕获边框。不支持该接口、捕获失败或窗口最小化时，继续使用原有 DWM 缩略图路径；模拟器最小化后是否继续提供画面取决于其渲染行为。越界范围返回失败，避免整窗图被误当成局部图。编译需要包含 C++/WinRT 的 Windows SDK。

1. 安装OpenCV Windows版本（推荐4.8.0）

2. 设置环境变量 OpenCV_DIR 指向OpenCV的build目录（例如：C:\opencv\build）

3. 将OpenCV的二进制目录（例如：C:\opencv\build\x64\vc16\bin）添加到系统PATH环境变量

### 编译项目环境设置

1. 创建新项目 搜索dll 选择动态链接库（dll） C++

2. 删除所有的头文件和源文件

3. 源文件 添加 现有项 RMT_OpenCv.cpp | 添加头文件 RMT_OpenCv.h

4. 项目 Debug 改成 Release  | x86 改成 x64
（如果忘记这一步，后续修改这个，下面的配置都需要重新配置）

5. （解决方案 和 RMT_OpenCv.cpp） 属性 C/C++ 预编译头 不使用预编译头

6. 属性 C/C++ 常规 附加包含目录 添加 D:\opencv\build\include（opencv的include目录）

7. 属性 链接器 常规 附加库目录 添加 D:\opencv\build\x64\vc16\lib（opencv的lib目录）

8. 属性 链接器 输入 附加依赖项 添加 opencv_world481.lib

9. 属性 C/C++ 预处理器 预处理器定义 添加 IMAGEFINDER_EXPORTS

10. 编译

### 不用visual studio（IDE）

1. 安装 Build Tools + C++ 桌面开发 (https://visualstudio.microsoft.com/zh-hans/visual-cpp-build-tools/)

2. 安装 「使用 C++ 的桌面开发」和 当前电脑对应的SDK

3. 执行buildDll.bat，完成后在 Plugins\OpenCV\build\Release 目录下会生成 RMT_OpenCv.dll
