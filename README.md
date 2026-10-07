# Aevum 1.0 — Apple Watch 身体年龄参考

App 版本为 **1.0**，构建号为 **1**（Debug / Release 均已设置）。文件夹名中的 v2.1 仅表示代码包修订批次，不是 App 版本号。

SwiftUI + HealthKit，watchOS 10.0+，**只需手表 App，没有 iOS 业务端、服务器、账号或网络依赖**。2.0 改为点击导航：首页只放参考年龄、正负差值和“健康 / 更多”入口。使用薄荷绿叠层光晕、星点、彩色指标块及短暂弹入、按压回弹。支持系统返回、数字表冠滚动、VoiceOver 和“减少动态效果”。装饰不代表健康分数。

## 2.1 构建结构修订：直接编译算法源码

针对用户报告的 `Undefined symbol: BodyAgeCore...`，2.1 将 Core 中的 5 个算法源文件直接加入 Aevum target 的 Compile Sources，App 不再 import 或链接 BodyAgeCore 包。保持 2.0 界面和算法不变。Core/Package.swift 仅用于 `swift test` 独立算法测试；应用构建不再解析该包。

**推荐使用完整工程**：解压 `AevumWatch-v2.1.zip` 到独立目录，关闭旧工程，打开新目录下的 `Aevum.xcodeproj`，设置自己的 Team 和 Bundle Identifier，选择 Apple Watch destination 后构建。不要在新工程重新添加 BodyAgeCore 包，也不要把旧版含有 `import BodyAgeCore` 的 App 文件覆盖回来。

如果要保留自己已有的工程及签名：

1. 备份工程，在 Project → Package Dependencies 移除 Core/BodyAgeCore 的依赖引用，保留磁盘上的 Core 文件夹。在 Aevum target 的 Link Binary With Libraries 中移除 BodyAgeCore product。
2. 使用新版 App 文件替换旧版同名文件（不仅仅是 Views；所有 App 文件里的 `import BodyAgeCore` 都已移除）。
3. 将 `Core/Sources/BodyAgeCore` 下的 **AgePresentation.swift、Aggregation.swift、ContextAnalysis.swift、FitnessAge.swift、Models.swift** 作为普通源码加入 Aevum target。已有文件只需核对成员归属，不重复复制。
4. Build Phases → Compile Sources 应包含 11 个 App Swift 文件和上述 5 个算法文件，每个仅一次。不要加入 `Core/Package.swift` 或 `Core/Tests`。
5. 确认 Info.plist 只保留 `WKWatchOnly = YES`，不定义 `WKRunsIndependentlyOfCompanionApp`。Version 设为 1.0，Build 设为 1；Info.plist 的 CFBundleShortVersionString / CFBundleVersion 也分别设为 1.0 / 1。
6. Clean Build Folder，然后 Build/Run。无需设置 Library Search Paths、手写 `-lBodyAgeCore` 或强制嵌入 Swift 标准库。

`Undefined symbol` 说明链接器缺少对应实现。仅凭单条日志不能判定旧工程是依赖关联、产物混用还是其他链接问题；直接编译版本移除了这条包链接依赖路径，不等同于已经在 Xcode 验证通过。本次环境仍为 Windows。

## 新页面结构

```text
身体年龄首页
├── 点年龄 → 年龄详情 → 估算波动 / 读懂年龄 / 数据状态
├── 健康 → 六块指标卡
│   ├── 睡眠 / 心率 / HRV / 呼吸 / 运动 → 单项详情
│   │   └── 每日记录 / 怎么看
│   └── 体能 → 年龄详情中的 VO₂max
└── 更多 → 我的资料 / 数据与刷新 / 读懂年龄 / 隐私与授权
```

年龄下方的差值按 **显示的整数参考年龄 − 实际年龄** 计算。例如显示 37、实际 42，则显示 `-5 岁`；显示 43、实际 40，则显示 `+3 岁`；相同时显示 `0 岁`。负值用薄荷绿、正值用暖杏色。它不是衰老速度，也不判定疾病。常模端点 `≤25 / ≥75` 不具备精确年龄差，改为显示“已到参考边界”。

指标入口不铺曲线和长文。单项页只显示数值、小趋势和两个入口；历史表、口径说明、授权和研究资料分别进入下一页。辅助大字体下指标网格切为单列，首页允许滚动，避免通过裁切隐藏内容。动效仅在入场或交互时短暂播放，不持续循环耗电。

## 先明确这个数字是什么

严格意义的“全身生物年龄”不能用几条公开健康指标随意加权得到。本实现显示的是 **心肺体能参考年龄**：将 Apple Watch 估计的 VO₂max 与公开 FRIEND 人群常模比较。首页保留“心肺体能参考”短标签；首次引导、年龄详情和方法页解释其非全身生物年龄及未经临床验证的边界。睡眠、静息心率、HRV、呼吸及运动用于观察个人状态，**不直接加减年龄**。

这满足可以解释、可复核的原型边界，但不能声称已经实现临床验证的多系统身体年龄模型。完整证据、公式、限制和后续验证路径见 [科学依据](Docs/SCIENCE.md)。如果产品必须输出经过验证的多变量生物年龄，应先完成其中的队列研究与外部验证，再更换核心模型，不能把本原型改个名称就宣称验证完成。

## 文件结构

```text
AevumWatch/
├── Aevum.xcodeproj/           # 可直接打开的单 watchOS 应用工程
├── App/
│   ├── AevumApp.swift         # SwiftUI 入口、前台刷新
│   ├── Health/               # 手表端授权、查询、来源过滤
│   ├── Model/                # 状态、受保护的个人设置、Debug 演示数据
│   ├── Views/                # 概览、指标、详情、引导、设置
│   └── PrivacyInfo.xcprivacy
├── Core/                     # 算法源码；App 直接编译，不作为包链接
│   ├── Package.swift         # 仅用于独立算法测试
│   ├── Sources/BodyAgeCore/   # 5 个文件加入 App 的 Compile Sources
│   └── Tests/BodyAgeCoreTests/
├── Config/                   # Info.plist、HealthKit entitlement
├── Docs/SCIENCE.md
├── Docs/VALIDATION.md
└── Tools/verify_source.py     # 可在 Windows/Mac 运行的静态一致性检查
```

## 方式一：在 Mac 上打开附带工程

1. 将整个 `AevumWatch-v2.1` 文件夹复制到 Mac，保留 `Core` 与工程的相对位置。用 **Xcode 15 或更新版本**打开 `Aevum.xcodeproj`。真机系统较新时，必须使用支持该系统的 Xcode 版本；安装相应 watchOS SDK/模拟器。无需添加任何本地包依赖。
2. 选择 **Aevum** target → **Signing & Capabilities**。把 `PRODUCT_BUNDLE_IDENTIFIER` 的 `com.example.Aevum.watchapp` 改为自己的唯一标识，选择 Team，启用自动签名。
3. 确認 **HealthKit** capability 已开启，签名配置支持该 entitlement。App 只读数据，不启用 Background Delivery、Clinical Health Records、Workout Processing、App Groups、WatchConnectivity 或 iCloud。
4. Build Settings 中确认 Deployment Target 为 **watchOS 10.0**，Swift Language Version 为 **Swift 5**。工程使用 Swift 5.9 语法；较新的 Swift 6 编译器可在 Swift 5 语言模式编译。不要直接切换成严格 Swift 6 模式而跳过并发检查。
5. 选择 Apple Watch 模拟器或已连接的 Apple Watch，运行 **Aevum** scheme。首次运行按“开始”，填写周岁和常模，下一步核对适用范围，再按“保存并授权”。系统授权界面也在手表上显示。
6. 健康数据不可用、未授权或没有 VO₂max 时，应用会进入真实的空状态。不会暗中使用模拟数据。

附带工程是直接面向 watchOS 的单应用 target。Apple 不同版本的 Watch-only 模板可能额外创建用于分发的容器/stub；它不代表需要开发 iPhone App。准备 App Store 分发时，如果所用 Xcode 要求容器，请使用下面的官方模板迁移路径并保留模板创建的容器。

### 无健康数据时预览界面

Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Arguments Passed On Launch，添加 `-demo`，使用 **Debug** 配置运行。

各页顶部会持续显示“演示 · 非本人数据”。演示模式不请求 HealthKit、不保存演示设置。**Release 构建不包含演示数据代码，`-demo` 在 Release 无效。** 移除参数后重新启动，即恢复真实授权与查询流程。模拟器适合检查视觉及导航；真实采样与授权行为须用真机测试。

## 方式二：迁移到自己的 Watch-only 工程

1. File → New → Project → **watchOS → App**，选择 **Watch-only App**，Interface 选 SwiftUI、Language 选 Swift。不同版本的模板选项名称可能略有变化。不要选择带新 iOS companion 的模板。
2. 设置 watchOS 10.0+，在实际运行代码的 Watch App target 上操作后续步骤，不要把源码放到包装用的 stub target。
3. 删除模板自带的 `ContentView.swift` 和带 `@main` 的 App 文件。将本项目 `App` 文件夹拖入工程，选择 Copy items if needed，并勾选 Watch App target。确认整个应用**只有一个 `@main`**。
4. 复制 `Core` 文件夹，将 `Core/Sources/BodyAgeCore` 下的 5 个 `.swift` 文件作为普通源码加入 Watch App target。不要 Add Local Package，不要加入 Package.swift 或 Tests。新版 App 已不含 `import BodyAgeCore`，App 和算法源码属于同一编译模块。
5. Signing & Capabilities → `+ Capability` → **HealthKit**。只勾普通 HealthKit。不要为了读静息心率创建虚假的 workout session。
6. Target → Info，加入 `Privacy - Health Share Usage Description`，内容复制自 `Config/Info.plist` 的 `NSHealthShareUsageDescription`。本版本 `toShare: []`，不会写健康记录；不要添加无用途的写入授权。如果未来增加写入，再添加 `NSHealthUpdateUsageDescription` 和具体写入类型。
7. 确认 `WKApplication = YES`、`WKWatchOnly = YES`，并完全删除 `WKRunsIndependentlyOfCompanionApp` 键（不要仅设为 NO）。这两个独立运行相关标志不能同时定义；本项目使用 Watch-only 配置。若 Build Settings 中存在 `INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp`，也要移除。优先保留官方 Watch-only 模板生成的其他结构；不要添加 `WKCompanionAppBundleIdentifier` 来绑定一个不存在的 iOS app。
8. 将 `App/PrivacyInfo.xcprivacy` 加入 Watch App 的 Copy Bundle Resources。不要把 `Info.plist` 或 entitlement 加入 Copy Bundle Resources。如果使用模板自动生成 Info.plist，只复制所需 keys，不再把本项目的完整 plist 设为另一份重复输入。
9. 确保 `CODE_SIGN_ENTITLEMENTS` 指向模板开启 HealthKit 后生成的文件，或本项目 `Config/Aevum.entitlements`，不要让两份配置互相覆盖。
10. 选择 Apple Watch destination，Build/Run。签名、设备配对和 Developer Mode 按 Xcode 提示配置。

**无需 iOS 端**是指本应用不依赖配套 iOS 软件，不表示 Apple Watch 的系统激活、配对或苹果自身某些健康功能初始化必然完全脱离 iPhone。某些设备、家庭设置及地区可能无法产生所需指标，此时应用仍可运行，但不会伪造年龄。

## 数据与计算行为

| 数据 | HealthKit 类型 | 用法 |
|---|---|---|
| 心肺体能 | `vo2Max` | 近 28 天，先日中位数，再跨日中位数，换算参考年龄 |
| 静息心率 | `restingHeartRate` | 日中位数与个人基线比较 |
| 心率变异性 | `heartRateVariabilitySDNN` | ms；不与 RMSSD 混用 |
| 呼吸频率 | `respiratoryRate` | 已采集样本的日中位数，不假设全天连续采集 |
| 睡眠 | `sleepAnalysis` | asleep 各阶段区间取并集；排除 inBed/awake；中午到中午 |
| 运动 | `appleExerciseTime` | 已记录运动分钟，按日积分并去除重叠 |

- 年龄换算要求实际年龄 20–79 岁、选择了常模、没有标记常模不适用；近 28 天至少 3 个不同采样日，最近 VO₂max 不超过 14 天，输入在 Apple 支持的 14–65 mL/kg/min 范围。3 天/14 天是保守产品规则，并非医学标准。
- 个人指标使用近 7 个完整日期，与此前 21 天比较；需至少 3 个近期采样日及 7 个基线采样日，近期最后样本距读取时刻不超过 3 天。睡眠使用已结束的中午窗口，上午未到中午时，昨晚数据要等窗口结束后才纳入。
- 不把缺失日填 0，不用实际年龄作为缺测默认值，不把采样覆盖率包装成“准确率”。运动的零值仅在存在真实零值记录时保留。
- 数量指标通常在当地日期内按样本取中位数。睡眠取时间区间并集，处理跨午夜、重复记录和夏令时。运动按区间内均匀分布处理，重叠区间取最高分钟速率，不保证与系统圆环累计完全一致。详细取舍见科学文档。
- 只接收可确认来自 Apple 系统及 Watch 设备的记录，排除手填及无法确认来源的数据。若系统版本缺少来源元数据，可能保守地显示无数据；应先核查真实样本，不要直接放开所有来源。
- 手表本地历史可短于请求窗口，且读权限可能仅覆盖部分数据。本版本**不落盘保存健康历史**，因此不承诺首次启动就有 28 天基线，也不会在权限撤销后继续展示旧磁盘缓存。
- 前台打开及点按刷新时查询；不持续唤醒、不采集原始 PPG、不启动后台 workout。每种查询最多 20 秒、20,000 条，达到上限时整个该指标失败，避免拿截断数据分析。每项错误单独展示。

## 测试与构建

在 Mac 终端进入项目目录：

```bash
# 纯 Foundation 算法测试，不依赖 HealthKit/模拟器
swift test --package-path Core

# 查看当前 Xcode 能用的目标，然后选择适合自己的模拟器
xcodebuild -list -project Aevum.xcodeproj
xcodebuild -showdestinations -project Aevum.xcodeproj -scheme Aevum

# 验证 watchOS SDK 编译（不签名，不代表已通过真机安装）
xcodebuild -project Aevum.xcodeproj -scheme Aevum \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

# 跨平台静态一致性检查；不替代 Swift 编译或单元测试
python3 Tools/verify_source.py
```

24 个核心测试方法包含常模节点、插值、单调性、边界、缺测、适用人群、数据过期、采样日去重、敏感性方向、睡眠重叠及夏令时、运动重叠及跨日，以及新增的正负差值、取整一致性和端点不生成精确差值。详细验收步骤及本次真实执行状态见 [验证记录](Docs/VALIDATION.md)。

**本次交付环境为 Windows，没有 Xcode/watchOS SDK/Swift 编译器。已执行文件和公式的静态检查；Swift 单元测试、Xcode 编译、模拟器视觉和真机授权均尚待在 Mac 上运行。不要把附带的测试代码误认为测试已通过。**

## 隐私与上架前补充

健康样本只在内存中使用，不输出到日志，不联网，不写回 HealthKit。个人设置以启用 complete file protection 的 JSON 保存在应用沙箱 Application Support，并排除系统备份；没有 UserDefaults、分析 SDK、广告或第三方库。清除本地设置不删除系统健康记录，也不撤销系统授权。应用进入后台清除可见健康快照，界面标记为 privacy sensitive；操作系统最终控制截图/常亮遮罩行为，需真机验证。

这是实现源码包，不包含上架用的品牌图标、商店截图、开发者签名或已签名安装包。发布前在 Xcode Assets 中设置自己的 App Icon，配置发布签名，完成真机验收及适用的商店隐私信息。商店描述应使用“心肺体能参考年龄”，不能声称“精准测得身体年龄”“医学诊断”或“睡一晚年轻几岁”。增加 SDK 或数据上传后必须重新核对隐私清单和说明。

## 设计参考

参考 [BodyCharge App Store 页面](https://apps.apple.com/us/app/bodycharge-health-monitor/id6738761582) 对多指标健康概览与单一重点信息的组织思路；本实现的 Aevum 品牌、配色、叠层光晕及卡片均为原创 SwiftUI。没有复用其商标、截图、素材或私有评分公式，也未将其宣传作为算法验证证据。

Apple 官方技术入口：[Watch-only 独立应用](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps)、[HealthKit 授权](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)、[单 target watchOS 应用](https://developer.apple.com/documentation/watchkit/wkapplication)、[心肺体能产生条件](https://support.apple.com/en-us/108790)。资料核查日期：2026-10-07。
