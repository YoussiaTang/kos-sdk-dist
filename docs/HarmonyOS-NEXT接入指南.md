# KOS SDK 鸿蒙 NEXT 接入文档（HAR）

> 版本：`1.0.5`  
> 适用：HarmonyOS NEXT 原生 Stage / ArkTS 宿主  
> 集成方式：从 GitHub Release 下载 HAR，以本地依赖接入，不依赖 Maven。

## 1. 环境要求

| 项 | 要求 |
| --- | --- |
| 应用模型 | Stage、ArkTS/ArkUI |
| 兼容基线 | 工程配置 API 12+，最低版本行为需设备验证 |
| 本包构建工具 | DevEco Studio 26.0.0.865、HarmonyOS SDK API 26 |
| SDK 文件 | `kos_sdk-1.0.5.har` |

本包面向 HarmonyOS NEXT 原生应用，不是 Android AAR，不用于旧鸿蒙的 Android 兼容模式；没有 Flutter 引擎依赖。

## 2. 添加 HAR 依赖

从 [GitHub Release v1.0.5](https://github.com/YoussiaTang/kos-sdk-dist/releases/tag/v1.0.5) 下载 [kos_sdk-1.0.5.har](https://github.com/YoussiaTang/kos-sdk-dist/releases/download/v1.0.5/kos_sdk-1.0.5.har)。也可使用离线交付包中的 `harmony/kos_sdk-1.0.5.har`。

将 HAR 复制至宿主工程根目录 `libs/`，在 `entry/oh-package.json5` 的 dependencies 中加入：

```json
{
  "dependencies": {
    "kos_sdk": "file:../libs/kos_sdk-1.0.5.har"
  }
}
```

路径相对于该 `oh-package.json5` 文件，按实际 entry 模块目录调整。执行 `ohpm install` 或在 DevEco 同步依赖。HAR 已在 GitHub Release 提供下载，但没有发布到远程 OHPM 仓库；依赖仍使用上述 `file:` 本地路径，不要直接写成远程版本号。

## 3. 导入

```typescript
import {
  KosSdk, KosUserInfo, KosSdkDelegate, UserCompletion,
  KosShareInfo, ShareCompletion, KosShareResult,
  KosPage, KosPageController
} from 'kos_sdk';
```

在不同文件中按实际使用项导入即可。

## 4. 初始化

### 4.1 应用级代理

以下内容可放在宿主的 `HostKosAdapter.ets` 中，由应用级模块持有：

```typescript
import {
  KosSdk, KosUserInfo, KosSdkDelegate, UserCompletion,
  KosShareInfo, ShareCompletion, KosShareResult
} from 'kos_sdk';

class HostKosAdapter implements KosSdkDelegate {
  user: KosUserInfo | null = null;

  requestUserInfo(callback: UserCompletion): void {
    callback(this.user); // 未登录返回 null，必须完成回调
  }

  onUserInfoExpired(callback: UserCompletion): void {
    // 宿主真实续期完成后，先更新 this.user，再 callback(this.user)。
    callback(null); // 基础示例尚未接续期
  }

  shareToWeChat(info: KosShareInfo, callback: ShareCompletion): void {
    // 替换为宿主微信能力，根据真实完成结果回调。
    callback(KosShareResult.NOT_SUPPORTED, '宿主尚未接入微信分享');
  }
}

export const hostKosAdapter = new HostKosAdapter();

export function setupKOS(): void {
  KosSdk.configureH5(
    'https://YOUR-TEST-HOST/member/',
    'https://YOUR-PRODUCTION-HOST/member/'
  );
  KosSdk.setAllowedExternalHosts(['www.douyin.com']);
  KosSdk.init('YOUR-PUBLIC-APP-KEY', 0, hostKosAdapter);
}
```

在应用初始化时调用一次 `setupKOS()`，不要放入每次重新进入页面都会执行的生命周期；重复 init 会报 `ALREADY_INITIALIZED`。进程重新启动后须重新初始化并从宿主会话模块提供当前用户。

### 4.2 地址与环境

| 参数 | 说明 |
| --- | --- |
| `configureH5(testURL, productionURL)` | 必须配置两个 HTTPS 基础地址，没有内置默认地址 |
| `environment` | 0=测试，1=正式；两个地址可以相同 |
| 外链白名单 | 精确域名，不带协议、路径、通配符；空数组禁用外链 |

H5 可部署在根目录或子目录，目录地址以 `/` 结尾，不含查询、Hash、用户名密码或 token。SDK 自动追加 Hash 业务路由。页面由部署方单独部署，网站根路径 `/api` 通过服务器转发后端。

`appKey` 为非空公开 App 标识，不代替登录凭证。修改 H5 配置或外链白名单前，先关闭当前 SDK 容器。

## 5. 同步用户并打开页面

### 5.1 宿主登录成功

在已导入 KosSdk/KosUserInfo 和应用级 hostKosAdapter 的位置执行：

```typescript
const user = new KosUserInfo(hostUserId);
user.token = originalAppToken;
user.name = hostUserName;
hostKosAdapter.user = user;
KosSdk.login(user);
```

`hostUserId/originalAppToken/hostUserName` 表示宿主真实会话字段，不是示例固定值。

### 5.2 创建页面

```typescript
import { KosPage, KosPageController } from 'kos_sdk';

@Entry
@Component
struct KosHostPage {
  @State private opened: boolean = true;
  private pageController: KosPageController = new KosPageController();
  private pageVisible: boolean = true;
  @StorageLink('kosHostForeground') @Watch('syncVisibility')
  private foreground: boolean = true;

  private syncVisibility(): void {
    this.pageController.setActive(this.foreground && this.pageVisible);
  }
  onPageShow(): void {
    this.pageVisible = true;
    this.syncVisibility();
  }
  onPageHide(): void {
    this.pageVisible = false;
    this.syncVisibility();
  }
  onBackPress(): boolean {
    return this.opened && this.pageController.requestBack();
  }
  build() {
    if (this.opened) {
      KosPage({
        pageController: this.pageController,
        initialTab: 'home',
        onClose: () => { this.opened = false; }
      })
    } else {
      Text('KOS 页面已关闭')
    }
  }
}
```

示例 onClose 切换为关闭占位；实际接入应由宿主关闭对应页面或返回自身路由。每个容器持有独立 controller，SDK 不控制整个 App 的路由栈。

initialTab 支持 `home/create/mall/data/profile`。SDK 包含原生顶部导航和底部 Tab，宿主不要重复叠加。

## 6. 登录、更新、退出

```typescript
hostKosAdapter.user = user;
KosSdk.login(user);          // 登录成功或冷启动已有会话
KosSdk.updateUserInfo(user); // token/资料/账号变化时先同步代理 user
hostKosAdapter.user = null;
KosSdk.logout();             // 清空会话并通知容器关闭
```

模型支持 `userId/token/name/mobile/avatarUrl/dealerCode`。SDK 不持久化 token；版本通过 `KosSdk.SDK_VERSION` 获取。宿主应关闭并销毁退出后的页面，避免保留旧容器。

原始宿主 token 由 H5 通过 `POST /api/member/auth/login` 换取成员 JWT，mobile 字段不能替代正式 token。手机号免密登录仅用于独立 H5 开发预览。H5 优先 refreshToken 续期，失败再请求宿主；当前原生续期拒绝返回与失效值相同的 token，两层会话下的真实行为需宿主联调。

## 7. 生命周期与系统返回

宿主 UIAbility 需初始化并更新前后台状态，与上例 AppStorage key 保持一致：

```typescript
// UIAbility.onCreate 中，初始化 UI 状态后调用一次 setupKOS()。
AppStorage.setOrCreate<boolean>('kosHostForeground', true);

// UIAbility.onForeground 中：
AppStorage.setOrCreate<boolean>('kosHostForeground', true);

// UIAbility.onBackground 中：
AppStorage.setOrCreate<boolean>('kosHostForeground', false);
```

这些语句应放入宿主自己的对应生命周期方法，而不是重复声明第二个 UIAbility。真实可见状态为“Ability 前台且页面可见”，由 `pageController.setActive(...)` 转发。系统返回调用 `requestBack()` 并返回其布尔结果；SDK 可先关闭弹层、返回子页，再请求根页退出。

## 8. 微信分享

`shareToWeChat` 将分享请求交给宿主已有的微信能力。本期模型只有 `WEBPAGE/IMAGE` 和 `SESSION/TIMELINE`；主要字段为 `type/scene/title/webpageUrl/imageFilePath`，不照搬旧 Android/iOS 的小程序或缩略图字段。

宿主在完成回调前读取或复制临时图片路径。回调返回 `SUCCESS/CANCELLED/FAILED/NOT_INSTALLED/NOT_SUPPORTED`，不能将拉起微信视为成功。微信平台注册及回调配置由宿主提供，SDK 不内置微信 AppID。

## 9. 超时与失败处理

| 操作 | 等待上限 |
| --- | --- |
| 获取用户 / 宿主续期 | 10 秒 |
| 微信分享 | 300 秒 |

每次仅回调一次，迟到或重复回调被忽略。初始化、地址或状态不正确时可能抛出 `INVALID_CONFIGURATION/ALREADY_INITIALIZED/H5_NOT_CONFIGURED/CONFIGURATION_IN_USE/INVALID_USER`，宿主应在对应配置入口处理。不要将旧引擎错误码当作本包的完整协议。

## 10. 权限与签名

宿主 `module.json5` 声明：

```json
{ "requestPermissions": [{ "name": "ohos.permission.INTERNET" }] }
```

该片段合并进现有 module 配置，不替换整个文件。UIAbility 保留有效 label/icon，用于系统保存授权界面。HAR 本身无需提供宿主签名私钥，最终应用 HAP 按宿主的应用签名流程构建。

文件选择、下载导出和相册保存使用系统选择/确认流程，不申请任意文件访问权限。图片仅公开 HTTPS PNG/JPEG（10MB），视频为有效公开 HTTPS MP4（200MB），不附带成员认证头/Cookie。视频按系统能力声明，不能只凭 API 版本认定设备支持。用户取消、授权失败、磁盘/网络错误须分别处理。

## 11. 接入验证与常见问题

- [ ] HAR 依赖同步，宿主 debug/release 构建和签名正常。
- [ ] HTTPS H5 与 `/api` 转发可访问，原生导航无重复。
- [ ] 宿主 token 登录、资料更新、换号、续期及退出正确。
- [ ] 系统返回、弹层、键盘、安全区、页面与 Ability 前后台正常。
- [ ] 系统选择器、下载/相册、微信真实回执通过真机验证。

**找不到 kos_sdk**：确认本地 HAR 路径相对于 entry 模块，并重新执行 ohpm install。

**页面无法打开**：确认只初始化一次、配置 HTTPS 地址、调用登录或由用户代理提供会话，设备能够访问站点。

**后台或返回异常**：检查 UIAbility 和页面可见性已组合转发，系统返回已交给 controller，onClose 确实退出对应宿主页面。
