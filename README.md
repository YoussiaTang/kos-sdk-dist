# KOS SDK 分发仓库

提供 iOS 和 HarmonyOS NEXT SDK 的版本下载与接入文档。本仓库不包含业务源码、H5 部署包或宿主 App。

## 1.0.5 下载

[Release v1.0.5](https://github.com/YoussiaTang/kos-sdk-dist/releases/tag/v1.0.5)

| 平台 | 下载 | 接入说明 |
| --- | --- | --- |
| iOS 15+ | [KOSSDK-1.0.5.xcframework.zip](https://github.com/YoussiaTang/kos-sdk-dist/releases/download/v1.0.5/KOSSDK-1.0.5.xcframework.zip) | [iOS 接入指南](docs/iOS接入指南.md) |
| HarmonyOS NEXT | [kos_sdk-1.0.5.har](https://github.com/YoussiaTang/kos-sdk-dist/releases/download/v1.0.5/kos_sdk-1.0.5.har) | [鸿蒙接入指南](docs/HarmonyOS-NEXT接入指南.md) |

## iOS CocoaPods

```ruby
platform :ios, '15.0'
target 'YourApp' do
  use_frameworks!
  pod 'KOSSDK', :podspec => 'https://raw.githubusercontent.com/YoussiaTang/kos-sdk-dist/v1.0.5/ios/KOSSDK.podspec'
end
```

执行 `pod install`，自动下载 Release 中的 XCFramework 并校验 SHA-256。本版本没有发布至 CocoaPods 公共 Specs。也可下载并手动集成，或使用本地 `:path`。

## HarmonyOS NEXT

下载 HAR 放入宿主工程根目录 `libs/`，在 `entry/oh-package.json5` 中声明：

```json
{ "dependencies": { "kos_sdk": "file:../libs/kos_sdk-1.0.5.har" } }
```

在 DevEco Studio 同步依赖或执行 `ohpm install`。本包没有发布到 OHPM 远程仓库，不适用于旧鸿蒙 Android 兼容模式。

## 接入条件

- SDK 不内置 H5；部署方提供可访问的 HTTPS H5，支持根目录或子目录部署。
- 使用 `configureH5` 配置测试、正式地址，`environment=0/1` 保持现有含义。
- 宿主提供真实用户和原始 token，由 H5 通过 `/api/member/auth/login` 换取成员会话。
- 微信分享由宿主对接；不要将登录凭证或签名私钥提交至本仓库。

Android SDK 已单独发布到私有 Maven：`com.kos.sdk:kos-sdk:1.0.5`，不在本仓库分发。
