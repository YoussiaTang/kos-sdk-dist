# KOS SDK iOS 接入文档（XCFramework / CocoaPods）

> 版本：`1.0.5`  
> 适用：iOS 15+，Objective-C 或 Swift 宿主  
> 集成方式：下载 XCFramework、远程 podspec 或本地 CocoaPods，不依赖 Maven。

## 1. 环境要求

| 项 | 要求 |
| --- | --- |
| iOS | 15.0+ |
| 架构 | arm64 真机，arm64/x86_64 模拟器 |
| Xcode | 使用支持目标设备和上述架构的版本 |
| SDK 类型 | 动态 XCFramework，无 Flutter 引擎依赖 |

接入前移除旧 KOS SDK 及配套依赖，不要同时引入两份同名 Framework。

## 2. 集成 SDK

### 2.1 手动集成

从 [GitHub Release v1.0.5](https://github.com/YoussiaTang/kos-sdk-dist/releases/tag/v1.0.5) 下载 [KOSSDK-1.0.5.xcframework.zip](https://github.com/YoussiaTang/kos-sdk-dist/releases/download/v1.0.5/KOSSDK-1.0.5.xcframework.zip) 并解压。离线交付包也提供 `ios/KOSSDK.xcframework` 与同名 zip；两者是同一产物，只导入一份。

将 XCFramework 加入 App target 的 Frameworks, Libraries, and Embedded Content，选择 **Embed & Sign**。链接 UIKit、WebKit、ImageIO、Photos、AVFoundation、CoreMedia。

### 2.2 远程 CocoaPods（推荐）

在 Podfile 中直接引用本版本 podspec：

```ruby
platform :ios, '15.0'
target 'YourApp' do
  use_frameworks!
  pod 'KOSSDK', :podspec => 'https://raw.githubusercontent.com/YoussiaTang/kos-sdk-dist/v1.0.5/ios/KOSSDK.podspec'
end
```

执行 `pod install`，CocoaPods 会从 GitHub Release 下载 XCFramework，并校验 podspec 中固定的 SHA-256。构建机器需能访问 GitHub、raw.githubusercontent.com 和 GitHub Release 下载域名。网络受限时使用下方本地方式。

本版本未发布至 CocoaPods 公共 Specs，不能仅写 `pod 'KOSSDK', '1.0.5'`；不需要配置旧版私有 Specs 源。

### 2.3 本地 CocoaPods

将 `KOSSDK.podspec` 与 `KOSSDK.xcframework` 放在同一 `Vendor/KOSSDK/` 目录：

```ruby
platform :ios, '15.0'
target 'YourApp' do
  use_frameworks!
  pod 'KOSSDK', :path => 'Vendor/KOSSDK'
end
```

然后执行 `pod install`。Pod 方式由 podspec 声明系统 Framework。

本地方式不下载远程 SDK；目录中须同时存在 podspec 与已解压的 XCFramework。不要直接沿用旧版 `pod 'KOSSDK', '1.0.0'`。

## 3. 导入

Objective-C：

```objc
#import <KOSSDK/KOSSDK.h>
```

Swift：

```swift
import KOSSDK
```

## 4. 初始化

### 4.1 应用级 Delegate

```objc
@interface HostKosAdapter : NSObject <KOSSDKDelegate>
@property(nonatomic, strong, nullable) KOSUserInfo *user;
@end

@implementation HostKosAdapter
- (void)kosSDKRequestUserInfoWithCompletion:
    (void (^)(KOSUserInfo * _Nullable))completion {
    completion(self.user); // 未登录返回 nil，必须完成回调
}
- (void)kosSDKUserInfoDidExpireWithCompletion:
    (void (^)(KOSUserInfo * _Nullable))completion {
    // 宿主真实续期完成后，先更新 self.user，再 completion(self.user)。
    completion(nil); // 基础示例尚未接续期
}
- (void)kosSDKShareToWeChat:(KOSShareInfo *)info
               completion:(void (^)(KOSShareResult, NSString * _Nullable))completion {
    // 替换为宿主微信 SDK 的真实完成结果。
    completion(KOSShareResultNotSupported, @"宿主尚未接入微信分享");
}
@end
```

SDK 的 delegate 为 weak；宿主必须由 AppDelegate、单例等应用级对象强引用代理。所有代理方法在主线程调用，completion 可从任意线程完成，每次只回调一次。

### 4.2 配置与启动

以下 `self.kosAdapter` 是宿主强引用属性。在应用初始化时于主线程调用一次：

```objc
self.kosAdapter = [HostKosAdapter new];
BOOL configured = [KOSSDK
    configureH5WithTestURL:[NSURL URLWithString:@"https://YOUR-TEST-HOST/member/"]
    productionURL:[NSURL URLWithString:@"https://YOUR-PRODUCTION-HOST/member/"]];
if (!configured) { return; }
BOOL allowed = [KOSSDK setAllowedExternalHosts:
    [NSSet setWithArray:@[@"www.douyin.com"]]];
if (!allowed) { return; }
[KOSSDK setupWithAppKey:@"YOUR-PUBLIC-APP-KEY"
           environment:0
              delegate:self.kosAdapter];
```

Swift 对应配置方式如下，`hostAdapter` 须实现上面的代理协议并由宿主强引用：

```swift
guard let testURL = URL(string: "https://YOUR-TEST-HOST/member/"),
      let productionURL = URL(string: "https://YOUR-PRODUCTION-HOST/member/"),
      KOSSDK.configureH5(testURL: testURL, productionURL: productionURL) else { return }
KOSSDK.setup(appKey: "YOUR-PUBLIC-APP-KEY", environment: 0, delegate: hostAdapter)
```

`appKey` 为非空公开 App 标识，不是登录凭证。environment 0=测试、1=正式；两个环境可以传相同 URL。H5 地址必须为 HTTPS 基础地址，可含部署子目录，目录以 `/` 结尾，不含查询、Hash 或凭证；没有内置默认地址。SDK 自行追加 Hash 业务路由。

外链白名单填写精确域名，不带协议、路径或通配符；空集合禁用外链。修改配置前先关闭已有 SDK 页面。

## 5. 同步用户并打开页面

Objective-C：

```objc
KOSUserInfo *user = [[KOSUserInfo alloc] initWithUserId:hostUserId];
user.token = originalAppToken;
user.name = hostUserName;
self.kosAdapter.user = user;
[KOSSDK loginWithUserInfo:user];

UIViewController *page = [KOSSDK viewControllerForPage:@"home"
                                             params:@{@"tab": @"home"}];
if (page != nil) {
    page.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:page animated:YES completion:nil];
}
```

Swift 打开页面：

```swift
if let page = KOSSDK.viewController(page: "home", params: ["tab": "home"]) {
    page.modalPresentationStyle = .fullScreen
    present(page, animated: true)
}
```

`hostUserId/originalAppToken/hostUserName` 为宿主实际用户信息。page 固定为 `home`；tab 支持 `home/create/mall/data/profile`。SDK 自带原生顶部导航和底部 Tab。宿主也可 push，但须管理自己的导航栏显隐，避免重复；SDK 不自行获取 keyWindow，不替宿主管理整个导航栈。

H5 由部署方单独部署，站点根路径 `/api` 通过服务器转发后端，不包含在 XCFramework 中。

## 6. 登录、更新、退出

```objc
self.kosAdapter.user = user;
[KOSSDK loginWithUserInfo:user]; // 登录成功或冷启动已有登录态
[KOSSDK updateUserInfo:user];    // token/资料/账号变化前先同步代理 user
self.kosAdapter.user = nil;
[KOSSDK logout];                // 清空会话并关闭所属 SDK 页面
```

用户还支持 `mobile/avatarURL/dealerCode/extra`。SDK 不持久化 token，无公开 release；读取版本使用 `[KOSSDK sdkVersion]`。

原始宿主 token 由 H5 通过 `POST /api/member/auth/login` 换取成员 JWT；mobile 不能代替正式 token。手机号免密登录仅用于独立 H5 开发预览。H5 优先 refreshToken 刷新，失败再请求宿主续期；当前原生策略拒绝与失效原值相同的 token，该两层会话场景需真实宿主联调。

## 7. Delegate 与事件

必需代理为 `kosSDKRequestUserInfoWithCompletion:`。可选代理包括：

- `kosSDKUserInfoDidExpireWithCompletion:`：宿主续期。
- `kosSDKShareToWeChat:completion:`：宿主微信分享。
- `kosSDKDidReceiveEvent:params:`：实际事件通知。
- `kosSDKDidReceiveErrorCode:message:`：脱敏错误处理。

不在日志中输出 token 或完整用户对象。旧版演示事件不作为本期必须实现的事件。

## 8. 微信分享

宿主自行注册微信 AppID、实现 URL/Universal Link 回调，再将 SDK 请求映射至自己的微信 SDK。本期使用 `KOSShareTypeWebpage/KOSShareTypeImage` 与会话/朋友圈。

`title/desc/webpageURL` 为网页内容，`thumbFilePath/imageFilePath` 为可空临时文件路径。图片由宿主在完成回调前读取或复制；SDK 结束后清理，不通过 Bridge 传二进制。保留的 TEXT/MINI_PROGRAM 模型不代表本期页面已提供这些业务。

按真实结果返回 `KOSShareResultSuccess/Cancelled/Failed/NotInstalled/NotSupported`；仅拉起微信不能回调成功。

## 9. 超时与错误处理

| 操作 | 等待上限 |
| --- | --- |
| 获取用户 / 宿主续期 | 10 秒 |
| 微信分享 | 300 秒 |

本期分享超时为 300 秒，不能沿用旧 iOS 文档的 10 秒。迟到、重复回调被忽略。配置函数返回 BOOL，创建页面可能返回 nil，宿主必须处理失败。常见错误码包含 1001 参数错误、1002 配置不可用、1003 未初始化、1004 回调异常、1006 用户超时、1007 分享超时、1008 未设置代理、1009 分享未实现、1099 内部错误；以实际触发条件为准。

## 10. 签名与权限

动态 Framework 由宿主按自身 Team 执行 Embed & Sign。本次无旧 Flutter 嵌套引擎，不沿用旧版“嵌套运行时已签名”的描述；SDK 文件不是 IPA。

相册保存需在 Info.plist 配置 `NSPhotoLibraryAddUsageDescription` 和真实用途。实际使用网页拍摄/录音时，宿主补对应相机/麦克风说明及授权处理；标准文件选择由 WKWebView 系统选择器处理，不承诺 capture 在所有设备一致。

图片仅公开 HTTPS PNG/JPEG（10MB），视频为有效公开 HTTPS MP4（200MB），不携带成员鉴权头/Cookie。下载、相册和微信能力均需真机验收。

## 11. 接入验证与常见问题

- [ ] 真机/模拟器目标均能链接，动态 Framework 已 Embed & Sign。
- [ ] HTTPS H5 与 `/api` 转发正常，无重复导航。
- [ ] 原始 token 登录、更新、换号、退出和续期正确。
- [ ] 返回、弹层、键盘、安全区、前后台及文件选择正常。
- [ ] 微信真实回执、下载与相册权限/取消/失败通过真机验证。

**Pod 找不到**：远程方式须写完整 `:podspec` URL；本地 `:path` 方式须确认 podspec 与 XCFramework 位于同一目录。本版本没有发布公共 Specs。

**页面无法打开**：检查 configureH5/setup 已完成、代理强引用、控制器有效及 HTTPS 可达。

**出现双层导航**：宿主隐藏重复 UINavigationBar，SDK 自带导航无需再次添加。

**用户为空或分享超时**：检查代理在规定时间内返回真实结果，未登录回 nil，不返回假成功。
