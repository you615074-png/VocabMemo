# 拾词记（VocabMemo）

拍照识词 · AI 抠图贴纸 · 例句收藏复习。基于 **HarmonyOS 6.1.1（API 24）/ ArkTS / ArkUI（状态管理 V2）**。

## 架构

```
拍照(PhotoOutput) / 相册选图
  → ① 端侧抠图: Core Vision Kit subjectSegmentation → 透明 PNG + 烘焙白描边
  → ② 出词级联（喂抠图主体，绝不编造）:
       云端 GLM-4V-Flash（主力，含 3 条例句）
       → MindSpore Lite + MobileNetV2（离线降级，top-5 候选）
       → objectDetection 粗分类
       → 诚实失败态（展示原因；可「点击调整」手动选词收下贴纸）
  → ③ 确认页: 重拍 / 收下 / 取消 / 点击调整
```

**没有随机词。** 识别失败会明说原因，绝不用无关词条冒充结果。

## 页面结构

| 屏 | 文件 | 说明 |
|---|---|---|
| 相机取景 | `pages/Index.ets` | 衬线日期+引导语、中央对焦框、底部快门面板、彩虹圆环快门、相册/今日入口 |
| 确认页 | `pages/ConfirmPage.ets` | 点阵纸背景、贴纸暖黄光晕、词气泡(词+🔊+译文)、↻/✓/✕ 三圆钮、「点击调整」 |
| 当日贴纸墙 | `pages/DayPage.ets` | 两列错落贴纸、白描边贴纸字标签、底部彩环相机钮 |
| 月份日卡 | `pages/MonthPage.ets` | 马卡龙色日卡（日期+N 个单词+贴纸一排） |
| 词卡详情 | `components/StickerDetail.ets` | 贴纸+词+译文+音标🔊+「💡 查看例句」 |
| 例句 | `components/ExampleList.ets` | 关键词橙色高亮、逐句发音、中文翻译 |
| 复习 | `components/ReviewSheet.ets` | 进度胶囊(紫色数字)、白色大卡翻面、左右滑动 |
| 发音 | `services/TtsService.ets` | Core Speech Kit textToSpeech |

视觉体系：暖白点阵纸底（`media/dot_grid.png` 平铺）、深藏青文字、强调紫 `#8B7CF6`、关键词橙 `#E8833A`、贴纸统一白描边+柔投影（`common/Theme.ets`）。

## 如何运行

1. **DevEco Studio 6.1** 打开本项目，Sync 后直接 Run（真机需 File → Project Structure → Signing Configs 自动签名）。
2. 相机页 ⚙ 可粘贴 [open.bigmodel.cn](https://open.bigmodel.cn) 免费申请的 GLM-4V-Flash Key，识别质量更佳；不配置则走端侧离线模型。
3. **模拟器**：虚拟相机只有预览、无法拍照出片，抠图/粗分类 NPU 能力也不可用——**长按快门**用内置示例照片走完整真实识别管线（端侧模型可用，香蕉自检 top1 置信度 0.99）；相册选图同样可用。完整体验（真实拍照+抠图贴纸）需真机。

## 命令行构建 / 签名 / 装模拟器（无需打开 IDE）

```powershell
# 构建
$env:DEVECO_SDK_HOME = "D:\devecostudio-windows\DevEco Studio\sdk"
$env:NODE_PATH = "<任意目录>\hvigor_modules"   # 内含 @ohos/hvigor-ohos-plugin 的 junction
& "D:\devecostudio-windows\DevEco Studio\tools\node\node.exe" `
  "D:\devecostudio-windows\DevEco Studio\tools\hvigor\hvigor\bin\hvigor.js" `
  --mode module -p product=default -p buildMode=debug --no-daemon assembleHap

# 本地调试签名（模拟器可装，不需要华为账号）：
# 1) 用 SDK toolchains/lib/UnsgnedDebugProfileTemplate.json 生成 profile：
#    改 bundle-name 为 com.capwords.shiciji、device-ids 为 `hdc shell bm get --udid`
# 2) hap-sign-tool sign-profile：keyAlias "openharmony application profile debug"
#    keystore OpenHarmony.p12 (密码 123456)、profileCertFile OpenHarmonyProfileDebug.pem
# 3) 证书链：p12 里导出的 leaf 是自签变体，须用模板 development-certificate 里的官方
#    Release 证书(与 p12 私钥同公钥) + OpenHarmonyProfileDebug.pem 的 CA/根 拼链
# 4) hap-sign-tool sign-app：keyAlias "openharmony application release"
# 5) hdc uninstall 后 install（重复 install -r 会报 9568332 sign info inconsistent）
```

## 真机验证清单

- [ ] PhotoOutput 真实拍照出片
- [ ] subjectSegmentation 抠图 → 透明贴纸 + 白描边效果
- [ ] objectDetection 粗分类兜底
- [ ] textToSpeech 发音（模拟器上引擎不可用时静默降级）

## 正式版接入路线（可选增强）

| 设计点 | 鸿蒙能力 |
|---|---|
| 多语种词卡 | 云端 prompt 扩展 10 语种 |
| 元服务卡片（快速识词） | Form Kit FormExtensionAbility |
| 智能复习推送 | 后台任务 + 通知 Kit |
| 平板分栏 | Navigation Split 模式（deviceTypes 已含 tablet/2in1） |
| 深色模式 | resources/dark 限定词目录 |
