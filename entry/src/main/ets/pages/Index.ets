import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { curves } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../common/Theme';
import { WordCard, todayKey } from '../model/WordCard';
import { DataStore } from '../services/DataStore';
import { RecognitionService, RecognitionResult } from '../services/RecognitionService';
import { DictEntry } from '../services/Dictionary';
import { CameraService } from '../services/CameraService';
import { ImageUtil } from '../services/ImageUtil';
import { WordSticker } from '../components/WordSticker';
import { DayOverviewPage } from './DayOverviewPage';
import { CalendarPage } from './CalendarPage';

const TAG = 'CameraHome';

/**
 * 相机首页 — 冷启动直达取景：无开屏、无引导、无底部 Tab。
 * 拍摄 → AI 抠图贴纸撕拉弹出 + 单词/音标 → 一步收下。
 */
@ComponentV2
struct CameraHome {
  @Require @Param stack: NavPathStack;
  store: DataStore = DataStore.get();
  private cameraService: CameraService = new CameraService();
  private xController: XComponentController = new XComponentController();
  private surfaceId: string = '';
  private cameraStarted: boolean = false;
  /** 相机不可用（模拟器无摄像头/权限被拒）时降级为演示取景 */
  @Local cameraFailed: boolean = false;
  @Local permissionGranted: boolean = false;
  /** 快门白闪反馈 */
  @Local flashOpacity: number = 0;
  /** 识别流水线进行中（抠图+出词，1~5秒） */
  @Local recognizing: boolean = false;
  /** 识别等待动效的呼吸缩放 */
  @Local pulseScale: number = 1;
  /** 待确认的贴纸候选（撕拉弹出 → 重拍/收下/取消） */
  @Local pendingCard: WordCard | null = null;
  /** 端侧模型给出的备选词（识别不确定时让用户点选） */
  @Local alternates: DictEntry[] = [];
  /** 云端识别设置面板 */
  @Local showSettings: boolean = false;
  @Local apiKeyInput: string = '';

  aboutToAppear(): void {
    this.requestCameraPermission();
  }

  aboutToDisappear(): void {
    this.cameraService.stop();
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private requestCameraPermission(): void {
    const perms: Permissions[] = ['ohos.permission.CAMERA'];
    const atManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(this.hostContext(), perms)
      .then((result) => {
        let granted = true;
        for (const r of result.authResults) {
          if (r !== 0) {
            granted = false;
          }
        }
        this.permissionGranted = granted;
        if (granted) {
          this.tryStartCamera();
        } else {
          this.cameraFailed = true;
        }
      })
      .catch(() => {
        this.cameraFailed = true;
      });
  }

  private tryStartCamera(): void {
    if (this.cameraStarted || !this.permissionGranted || this.surfaceId === '') {
      return;
    }
    this.cameraStarted = true;
    this.cameraService.start(this.hostContext(), this.surfaceId)
      .catch(() => {
        hilog.warn(0x0001, TAG, 'camera unavailable, fallback to demo viewfinder');
        this.cameraFailed = true;
      });
  }

  private playFlash(): void {
    this.flashOpacity = 0.7;
    this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.flashOpacity = 0;
    });
  }

  private startPulse(): void {
    this.pulseScale = 1;
    this.getUIContext().animateTo({
      duration: 700,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.pulseScale = 1.18;
    });
  }

  /** 快门：拍真实照片 → 抠图 + 识别；相机不可用时走演示识别 */
  private async captureAndRecognize(): Promise<void> {
    if (this.recognizing) {
      return;
    }
    this.playFlash();
    if (this.cameraFailed) {
      this.applyResult(RecognitionService.recognizeMock());
      return;
    }
    this.recognizing = true;
    this.startPulse();
    try {
      const photo = await this.cameraService.capturePhoto();
      await this.recognizePixelMap(photo);
    } catch (e) {
      hilog.warn(0x0001, TAG, `capture failed, fallback mock: ${JSON.stringify(e)}`);
      this.applyResult(RecognitionService.recognizeMock());
    } finally {
      this.recognizing = false;
    }
  }

  private async recognizePixelMap(photo: image.PixelMap): Promise<void> {
    const result = await RecognitionService.recognizePhoto(photo, this.hostContext(), this.store.apiKey);
    this.applyResult(result);
  }

  private applyResult(result: RecognitionResult): void {
    this.alternates = result.alternates;
    this.pendingCard = result.card;
  }

  /** 用户点选候选词：换词条内容，贴纸/时间/地点保持不变 */
  private applyAlternate(entry: DictEntry): void {
    if (this.pendingCard === null) {
      return;
    }
    const old = this.pendingCard;
    const next = new WordCard();
    next.id = old.id;
    next.imageUri = old.imageUri;
    next.timestamp = old.timestamp;
    next.place = old.place;
    next.source = old.source;
    next.word = entry.word;
    next.translation = entry.translation;
    next.phonetic = entry.phonetic;
    next.example = entry.example;
    next.exampleCn = entry.exampleCn;
    next.category = entry.category;
    next.emoji = entry.emoji;
    // 原主词退回候选列表，保持可来回切换
    const newAlts: DictEntry[] = [];
    newAlts.push({
      word: old.word,
      translation: old.translation,
      phonetic: old.phonetic,
      example: old.example,
      exampleCn: old.exampleCn,
      category: old.category,
      emoji: old.emoji
    });
    for (const a of this.alternates) {
      if (a.word !== entry.word) {
        newAlts.push(a);
      }
    }
    this.alternates = newAlts;
    this.pendingCard = next;
  }

  private async pickFromGallery(): Promise<void> {
    if (this.recognizing) {
      return;
    }
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picked = await picker.select(options);
      if (picked.photoUris.length === 0) {
        return;
      }
      this.recognizing = true;
      this.startPulse();
      const photo = await ImageUtil.fromUri(picked.photoUris[0]);
      await this.recognizePixelMap(photo);
    } catch (e) {
      hilog.error(0x0001, TAG, `gallery recognize failed: ${JSON.stringify(e)}`);
    } finally {
      this.recognizing = false;
    }
  }

  private confirmSticker(): void {
    if (this.pendingCard === null) {
      return;
    }
    this.store.addWord(this.pendingCard);
    this.pendingCard = null;
    this.alternates = [];
    this.getUIContext().getPromptAction().showToast({
      message: '✓ 已收进今日词汇',
      duration: 1200
    });
  }

  private sourceLabel(source: string): string {
    if (source === 'cloud') {
      return 'AI 识别';
    }
    if (source === 'local') {
      return '离线识别';
    }
    if (source === 'device') {
      return '本地粗识别';
    }
    return '演示词条';
  }

  @Builder
  ActionButton(label: string, primary: boolean, onTap: () => void) {
    Button(label)
      .fontSize(15)
      .fontWeight(primary ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(primary ? Color.White : Theme.TEXT)
      .backgroundColor(primary ? Theme.PRIMARY : '#E6FFFFFF')
      .padding({
        left: 26,
        right: 26,
        top: 10,
        bottom: 10
      })
      .onClick(() => {
        onTap();
      })
  }

  @Builder
  SettingsSheet() {
    Column({ space: 14 }) {
      Text('云端识别')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .margin({ top: 20 })
      Text(this.store.apiKey === '' ? '未启用 — 当前使用端侧离线模型识别（免联网）' : '已启用 — 优先云端大模型，失败时回退端侧模型')
        .fontSize(13)
        .fontColor(this.store.apiKey === '' ? Theme.TEXT_SUB : '#5B8C5A')
      Text('可选增强：在 open.bigmodel.cn 免费申请 GLM-4V-Flash 的 API Key 粘贴到下方，识别更准。不配置也能用——内置离线模型可识别数百种日常物品。')
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .width('86%')
      TextInput({ placeholder: '粘贴 API Key', text: this.apiKeyInput })
        .width('86%')
        .fontSize(13)
        .onChange((value: string) => {
          this.apiKeyInput = value;
        })
      Row({ space: 12 }) {
        Button('保存')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(Theme.PRIMARY)
          .onClick(() => {
            this.store.setApiKey(this.apiKeyInput);
            this.showSettings = false;
            this.getUIContext().getPromptAction().showToast({
              message: this.store.apiKey === '' ? '已清除，回到离线模式' : '已启用云端识别',
              duration: 1500
            });
          })
        Button('清除')
          .fontSize(14)
          .fontColor(Theme.TEXT_SUB)
          .backgroundColor(Theme.BG_SUB)
          .onClick(() => {
            this.apiKeyInput = '';
            this.store.setApiKey('');
          })
      }
      .margin({ bottom: 24 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.BG)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ── 取景层 ─────────────────────────────
      if (!this.cameraFailed) {
        XComponent({ type: XComponentType.SURFACE, controller: this.xController })
          .onLoad(() => {
            this.surfaceId = this.xController.getXComponentSurfaceId();
            this.tryStartCamera();
          })
          .width('100%')
          .height('100%')
      } else {
        Column({ space: 8 }) {
          Text('◌')
            .fontSize(46)
            .fontColor('#B3FFFFFF')
          Text('演示取景模式')
            .fontSize(14)
            .fontColor('#B3FFFFFF')
          Text('无摄像头或未授权，快门仍可体验识词流程')
            .fontSize(11)
            .fontColor('#80FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .linearGradient({
          angle: 160,
          colors: [['#5C4E42', 0.0], ['#8A7563', 0.55], ['#B99B7E', 1.0]]
        })
      }

      // ── 快门白闪 ───────────────────────────
      Rect()
        .width('100%')
        .height('100%')
        .fill(Color.White)
        .opacity(this.flashOpacity)
        .hitTestBehavior(HitTestMode.None)

      // ── 顶部：设置 / 积累感提示 / 回顾入口 ──
      Row({ space: 8 }) {
        Text('⚙')
          .fontSize(16)
          .fontColor(Color.White)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor('#33000000')
          .borderRadius(16)
          .onClick(() => {
            this.apiKeyInput = this.store.apiKey;
            this.showSettings = true;
          })
          .bindSheet(this.showSettings, this.SettingsSheet(), {
            height: 340,
            backgroundColor: Theme.BG,
            onDisappear: () => {
              this.showSettings = false;
            }
          })

        Text(`今日已收集 ${this.store.todayCount()} 个单词`)
          .fontSize(12)
          .fontColor(Color.White)
          .padding({
            left: 12,
            right: 12,
            top: 6,
            bottom: 6
          })
          .backgroundColor('#33000000')
          .borderRadius(14)

        Blank()

        Text('今日手记 ›')
          .fontSize(13)
          .fontColor(Color.White)
          .padding({
            left: 14,
            right: 14,
            top: 7,
            bottom: 7
          })
          .backgroundColor('#33000000')
          .borderRadius(16)
          .onClick(() => {
            this.store.selectedDate = todayKey();
            this.stack.pushPathByName('overview', null);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 52 })
      .position({ x: 0, y: 0 })

      // ── 识别等待浮层：把等待变成看点 ──
      if (this.recognizing) {
        Column({ space: 18 }) {
          Text('✂️')
            .fontSize(46)
            .scale({ x: this.pulseScale, y: this.pulseScale })
          Text('正在把它从照片里撕下来…')
            .fontSize(14)
            .fontColor(Color.White)
          Text(this.store.apiKey === '' ? '端侧离线识别中' : 'AI 识别中')
            .fontSize(11)
            .fontColor('#99FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#59000000')
      }

      // ── 贴纸候选浮层：撕拉弹出 + 单词/音标 + 一步确认 ──
      if (this.pendingCard !== null) {
        Column() {
          Blank()
          WordSticker({ card: this.pendingCard, stickerSize: 190, showWord: false })
            .transition(
              TransitionEffect.scale({ x: 0.25, y: 0.25 })
                .combine(TransitionEffect.rotate({ angle: -8 }))
                .combine(TransitionEffect.OPACITY)
                .animation({ curve: curves.springMotion(0.42, 0.68) })
            )
          Text(this.pendingCard.word)
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 18 })
          Text(this.pendingCard.phonetic)
            .fontSize(14)
            .fontColor('#CCFFFFFF')
            .margin({ top: 2 })
          Row({ space: 8 }) {
            Text(this.pendingCard.translation)
              .fontSize(16)
              .fontColor(Color.White)
            Text(this.sourceLabel(this.pendingCard.source))
              .fontSize(10)
              .fontColor('#B3FFFFFF')
              .padding({
                left: 8,
                right: 8,
                top: 3,
                bottom: 3
              })
              .backgroundColor('#33FFFFFF')
              .borderRadius(9)
          }
          .margin({ top: 8 })

          // 识别不确定时的候选词：点一下换词，贴纸不变
          if (this.alternates.length > 0) {
            Row({ space: 8 }) {
              Text('也许是')
                .fontSize(11)
                .fontColor('#99FFFFFF')
              ForEach(this.alternates, (entry: DictEntry) => {
                Text(`${entry.emoji} ${entry.word}`)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .padding({
                    left: 10,
                    right: 10,
                    top: 5,
                    bottom: 5
                  })
                  .backgroundColor('#40FFFFFF')
                  .borderRadius(13)
                  .onClick(() => {
                    this.applyAlternate(entry);
                  })
              }, (entry: DictEntry) => entry.word)
            }
            .margin({ top: 12 })
          }
          Blank()
          Row({ space: 14 }) {
            this.ActionButton('重拍', false, () => {
              this.pendingCard = null;
              this.alternates = [];
            })
            this.ActionButton('收下 ✓', true, () => {
              this.confirmSticker();
            })
            this.ActionButton('取消', false, () => {
              this.pendingCard = null;
              this.alternates = [];
            })
          }
          .margin({ bottom: 64 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#8C000000')
      }

      // ── 底部操作区：相册入口 + 拍摄主按钮（单手可达） ──
      if (this.pendingCard === null && !this.recognizing) {
        Row() {
          Text('🖼️')
            .fontSize(24)
            .width(52)
            .height(52)
            .textAlign(TextAlign.Center)
            .backgroundColor('#33000000')
            .borderRadius(26)
            .onClick(() => {
              this.pickFromGallery();
            })

          Blank()

          Stack() {
            Circle()
              .width(76)
              .height(76)
              .fillOpacity(0)
              .stroke(Color.White)
              .strokeWidth(4)
            Circle()
              .width(60)
              .height(60)
              .fill(Color.White)
          }
          .onClick(() => {
            this.captureAndRecognize();
          })

          Blank()

          // 占位保持快门居中
          Row()
            .width(52)
            .height(52)
        }
        .width('100%')
        .padding({ left: 32, right: 32, bottom: 48 })
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#2E2823')
  }
}

@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack();

  @Builder
  pageMap(name: string) {
    if (name === 'overview') {
      DayOverviewPage({ stack: this.pathStack })
    } else if (name === 'calendar') {
      CalendarPage({ stack: this.pathStack })
    }
  }

  build() {
    Navigation(this.pathStack) {
      CameraHome({ stack: this.pathStack })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.pageMap)
  }
}
