# AppShareKit

`AppShareKit` 将常见的应用推广分享流程封装成 Swift Package，输入若干可选参数（名称、推广语、Logo、二维码、直达链接和可选的分享按钮样式）即可在 iOS 13 及以上系统生成一张排版良好的分享图片，并通过系统分享面板分发。

- 💡 **弹性入参**：`appName`、`prompt`、`logo`、`qrcode`、`officeURL` 及分享按钮相关参数全部可选；缺失的元素会自动隐藏，但分享流程仍可执行。
- 🖼️ **自动构图**：内置 `UIImage` 渲染器，会按“Logo + 文案 + 二维码 + 直达地址”的布局生成推广图，整体风格简洁醒目。
- 🪄 **一键分享**：当不需要内置按钮时，可直接在任意 `Button` 的 action 中调用 `AppShareKit.appshare(...)` 立刻唤起分享面板。
- 🔘 **自带分享按钮**：只要提供任意一个 `shareButtonIcon` / `shareButtonImage` / `shareButtonName`，`AppShareKit.appshare(...)` 就会返回一个 SwiftUI 按钮视图，点击后生成并分享推广图。
- 📲 **iOS 13+**：使用 UIKit + SwiftUI 结合实现，在所有 iOS 13 及以上版本可用。

## 安装

1. 在 Xcode > File > Add Packages… 中添加当前目录，或在 `Package.swift` 中加入：

```swift
.package(path: "../AppShareKit")
```

2. 在目标的依赖里引用 `AppShareKit` 模块。

## 快速上手

### 外部自定义按钮（无内置分享按钮）

```swift
import SwiftUI
import AppShareKit

struct ContentView: View {
    var body: some View {
        Button {
            AppShareKit.appshare(
                appName: "Hello AI",
                prompt: "AI 创作助手 · 秒出灵感",
                logo: UIImage(named: "app_logo"),
                qrcode: UIImage(named: "qr_install"),
                officeURL: "https://hello.ai/app"
            )
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
```

- `AppShareKit.appshare` 在未提供任何分享按钮参数时会立即生成图片并弹出分享面板。
- 可在任意 SwiftUI / UIKit 交互中调用，确保当前界面永远可以触发分享。

### 内置分享按钮（自带样式）

```swift
struct ShareSection: View {
    var body: some View {
        AppShareKit.appshare(
            appName: "Hello AI",
            prompt: "AI 创作助手 · 秒出灵感",
            logo: UIImage(named: "app_logo"),
            qrcode: UIImage(named: "qr_install"),
            officeURL: "https://hello.ai/app",
            shareButtonIcon: "sparkles",
            shareButtonName: "立即分享"
        )
    }
}
```

- 当 `shareButtonIcon`、`shareButtonImage`、`shareButtonName` 任意一个存在时，`appshare` 会返回一个 SwiftUI 视图。
- 点击按钮后会生成推广图并弹出 `UIActivityViewController`。

### 分享图片构成逻辑

1. 使用白色背景与浅灰投影的卡片布局，整体长方形比例，兼容主流社交平台裁剪。
2. 上部为 Logo + App 名称 + 推广语，缺失的元素会让剩余内容自动居左。
3. 下部为二维码和直达链接文案，二维码缺失时仅展示链接。
4. 统一使用系统字体和自动换行策略，保证 iOS 13 上的渲染效果。

## 下一步

- 将本 README 中示例涉及的 API 正式实现。
- 提供可复用的图片渲染器与 SwiftUI 按钮视图。
- 按需扩展更多分享内容（如多语言、暗色主题等）。
