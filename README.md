# 拾词记（CapWords 鸿蒙融合版）

以实景识词为锚点的轻量化生活记录应用 —— 完整继承 CapWords「轻量、直觉、趣味、贴纸化」的设计逻辑，融合「日记叙事、轨迹记录」，基于 **HarmonyOS 6.1.1（API 24）/ ArkTS / ArkUI（状态管理 V2）** 实现。

## 已实现（本骨架）

| 设计要求 | 实现 |
|---|---|
| 冷启动直达相机取景，无开屏无引导 | `pages/Index.ets` — CameraHome，Camera Kit 真实后置预览（XComponent），模拟器/无权限时自动降级为演示取景 |
| 拍摄 → 贴纸撕拉弹出 → 一步确认 | 快门白闪 + `springMotion` 弹性缩放/旋转转场，底部 重拍/收下/取消 三按钮，无弹窗无跳转 |
| 贴纸统一视觉语言（白边+微投影+微圆角） | `components/WordSticker.ets`，词汇本/轨迹点位/日记缩略图三种形态统一 |
| 当日概览：上轨迹下日记 | `pages/DayOverviewPage.ets` — 轨迹画布点位按时间依次点亮再连线（`TrackCanvas`），日记文本自动生成、贴纸嵌入段落 |
| 一次动作双重价值 | 识词时静默记录时间戳 + 模糊地点标签（Mock，不采集真实坐标） |
| 日历总览 + 单词总库 | `pages/CalendarPage.ets` — 月历角标当日识词数，点日期直达当日概览 |
| 次级功能上下文唤起 | 详情/复习全部 `bindSheet` 半屏卡，发音波纹微反馈、掌握标记、删除可撤（低容错成本） |
| 复习实体卡片隐喻 | `components/ReviewSheet.ets` — Swiper 左右滑动 + 点击翻面 |
| 松弛感色彩体系 | `common/Theme.ets` — 米白基底 + 低饱和暖橙主色 + 马卡龙分类卡片色 |
| 本地持久化 | `@ohos.data.preferences`（`services/DataStore.ets`，V2 `@ObservedV2/@Trace` 单例） |

## 识别流水线（对齐 CapWords 真实架构）

拍照/选图 → `RecognitionService.recognizePhoto()`：

1. **真实拍照出片**：`CameraService.capturePhoto()`（PhotoOutput → JPEG → PixelMap）
2. **端侧 AI 抠图**：Core Vision Kit `subjectSegmentation`，把主体从照片里抠出来生成**透明 PNG 贴纸**并落盘（模拟器不支持时降级为整图贴纸）
3. **单词识别，四级降级（默认全程离线，无需任何 API Key）**：
   - **云端视觉大模型**（可选增强）：相机页 ⚙ 粘贴 [open.bigmodel.cn](https://open.bigmodel.cn) 的 GLM-4V-Flash Key 才启用；照片一次性识别即弃
   - **端侧离线模型（主力）**：MindSpore Lite + MobileNetV2（ImageNet-1000，13MB 内置于 rawfile），`LabelMapper` 把 1000 类映射到学习友好词库；top-5 候选词以「也许是」chips 展示，点选换词
   - **端侧粗分类**：Core Vision Kit `objectDetection`（15 类）
   - **内置词库**：演示兜底
4. 词条+贴纸+时间+模糊地点组装成 `WordCard` 持久化

贴纸候选浮层会显示词条来源徽标（AI 识别 / 本地粗识别 / 演示词条）。

## 如何运行

1. 用 **DevEco Studio 6.1** 打开 `D:\capwords`（File → Open）。
2. 首次打开等待 Sync 完成；Build → Build Hap(s) 或直接点击运行。
3. 在设备管理器启动模拟器（本机已装 Emulator 6.1）或连接 HarmonyOS 真机（需在 File → Project Structure → Signing Configs 勾选 Automatically generate signature，用华为账号自动签名）。
4. 命令行构建（无需打开 IDE）：

```powershell
$env:DEVECO_SDK_HOME = "D:\devecostudio-windows\DevEco Studio\sdk"
$env:NODE_PATH = "<任意目录>\hvigor_modules"   # 内含 @ohos/hvigor-ohos-plugin 的 junction，指向 IDE tools\hvigor
cd D:\capwords
& "D:\devecostudio-windows\DevEco Studio\tools\node\node.exe" `
  "D:\devecostudio-windows\DevEco Studio\tools\hvigor\hvigor\bin\hvigor.js" `
  --mode module -p product=default -p buildMode=debug --no-daemon assembleHap
```

产物：`entry\build\default\outputs\default\entry-default-unsigned.hap`。

## 正式版接入路线（设计文档 → 真实能力）

| 设计点 | 鸿蒙能力 | 替换位置 |
|---|---|---|
| AI 抠图生成贴纸 | Core Vision Kit `subjectSegmentation`（主体分割） | `RecognitionService` |
| 物体识别出词 | Core Vision Kit 物体检测 / 拍照出片走 `PhotoOutput` | `RecognitionService` + `CameraService` |
| 真实轨迹（模糊化） | Location Kit `geoLocationManager`（申请 `APPROXIMATELY_LOCATION`，只存街区级标签）；Map Kit 地图底图（需 AGC 项目 + 签名指纹） | `TrackCanvas` 数据源 |
| 发音 | Core Speech Kit `textToSpeech` | `StickerDetail.playRipple` |
| 元服务卡片（快速识词/今日日记） | Form Kit `FormExtensionAbility` | 新增 module |
| 实况窗晚间日记推送 | Live View Kit（需申请权益） | 新增 service |
| 平板分栏 | 当前 `deviceTypes` 已含 tablet/2in1，用断点 + `Navigation` Split 模式 | `Index.ets` |
| 深色模式 | `resources/dark` 限定词目录覆盖色值 | resources |
| 生物识别锁 | User Authentication Kit | 设置项 |
