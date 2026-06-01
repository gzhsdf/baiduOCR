# BaiduOCR

macOS 桌面端 OCR 工具，基于[百度智能云文字识别 API](https://cloud.baidu.com/product/ocr)，支持图片文字识别、批量处理、选区裁剪等功能。

## 功能

- **图片识别** — 拖拽 / 粘贴 / 截图加载图片，一键 OCR 识别
- **批量处理** — 打开文件夹批量导入图片，左侧缩略图切换，一键批量识别
- **选区裁剪** — 在图片上拖拽画框选取识别区域，只识别框内文本
- **多种识别类型** — 通用文字、高精度、手写、数字、身份证、银行卡、营业执照等
- **自动复制 / 剪切** — 识别完成后自动将结果复制或剪切到剪贴板
- **图片操作** — 缩放、旋转、平移等手势操作
- **凭证安全存储** — API Key / Secret Key 存储在系统钥匙串中

## 系统要求

- macOS 15.0+
- Swift 6.0+

## 获取 API 凭证

1. 注册 [百度智能云](https://console.bce.baidu.com/) 账号
2. 在控制台创建「文字识别」应用
3. 获取 **API Key** 和 **Secret Key**

## 构建与运行

### 使用终端

```bash
# 克隆仓库
git clone https://github.com/gzhsdf/baiduOCR.git
cd BaiduOCR

# Debug 运行
swift run

# Release 构建 + 打包 .app
./build.sh
open BaiduOCR.app
```

### 使用 VS Code

安装 [Swift 扩展](https://marketplace.visualstudio.com/items?itemName=sswg.swift-lang) 后直接 F5 运行。

## 使用说明

### 加载图片
- **打开文件** — 点击图片区域选择文件
- **拖拽** — 拖拽图片到虚线框区域
- **截图** — 点击工具栏「截图」按钮（⌘⇧S），系统原生截图工具框选
- **剪贴板** — 点击「剪贴板」按钮（⌘V），加载剪贴板中的图片

### OCR 识别
1. 加载图片后，选择识别类型（通用文字识别、高精度等）
2. 点击「开始识别」（⌘R）
3. 结果展示在右侧/下方文本区域

### 选区识别
- 在图片上拖拽鼠标画框选区
- 只识别框内区域的文字
- 点击选区标记消除选区

### 批量识别
1. 点击工具栏「📂 文件夹」
2. 选择一个包含图片的目录
3. 左侧出现缩略图列表，单击切换
4. 点击「批量识别」对所有待处理图片执行 OCR
5. 识别结果支持导出，所有结果自动合并

### 批量导出

- 识别完成后，点击「导出」按钮可将所有结果保存为 CSV 文件

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| ⌘R | 开始识别 |
| ⌘⇧S | 截图 |
| ⌘V | 从剪贴板加载 |
| ⌘C | 复制结果 |
| ⌘, | 设置 |

## 项目结构

```
BaiduOCR/
├── Package.swift              # Swift Package Manager 配置
├── build.sh                   # Release 构建 + .app 打包脚本
├── Sources/BaiduOCR/
│   ├── App.swift              # 入口
│   ├── Models/                # 数据模型
│   │   ├── APICredentials.swift
│   │   ├── BatchImageItem.swift
│   │   ├── OCRResponse.swift
│   │   └── OCRType.swift
│   ├── Services/              # 服务层
│   │   ├── AuthService.swift       # 百度 OAuth 鉴权
│   │   ├── ImageProcessor.swift    # 图片裁剪
│   │   └── OCRService.swift        # OCR API 调用
│   ├── Utilities/             # 工具
│   │   └── KeychainHelper.swift    # 钥匙串读写
│   ├── ViewModels/            # MVVM ViewModel 层
│   │   └── OCRViewModel.swift
│   └── Views/                 # SwiftUI 视图
│       ├── ContentView.swift
│       ├── ToolbarView.swift
│       ├── ImageDropView.swift
│       ├── ImageRegionSelector.swift
│       ├── BatchSidebarView.swift
│       ├── OCRResultView.swift
│       ├── SettingsView.swift
│       └── ScreenshotOverlay.swift
```

## 架构

MVVM + Services，纯 SwiftUI + AppKit 桥接实现。

- **Models** — 数据类型（识别结果、批量项、API 凭证）
- **Services** — 网络请求（百度 OCR API）与图片处理
- **ViewModels** — `@Observable` 状态管理、业务逻辑
- **Views** — SwiftUI 声明式 UI，`ImageRegionSelector` 为 NSViewRepresentable 桥接 AppKit 鼠标事件

## 许可

MIT License. 详见 [LICENSE](LICENSE)。
