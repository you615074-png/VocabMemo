import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Theme, cnDate } from '../common/Theme';
import { todayKey } from '../model/WordCard';
import { DataStore } from '../services/DataStore';
import { RecognitionService } from '../services/RecognitionService';
import { CameraService } from '../services/CameraService';
import { ImageUtil } from '../services/ImageUtil';
import { ConfirmPage } from './ConfirmPage';
import { DayPage } from './DayPage';
import { MonthPage } from './MonthPage';

const TAG = 'CameraHome';

/**
 * 相机首页 — 1:1 对齐 CapWords 取景屏：
 * 全屏取景 + 左上日期/引导语 + 中央对焦框 +
 * 底部白色圆角面板（点阵纹理、拖拽条、彩环快门、相册入口）。
 * 拍摄 → 识别 → 跳转确认页。
 */
@ComponentV2
struct CameraHome {
  @Require @Param stack: NavPathStack;
  store: DataStore = DataStore.get();
  private cameraService: CameraService = new CameraService();
  private xController: XComponentController = new XComponentController();
  private surfaceId: string = '';
  private cameraStarted: boolean = false;
  /** 相机不可用（模拟器无摄像头/权限被拒）：取景降级，快门禁用并引导走相册 */
  @Local cameraFailed: boolean = false;
  @Local permissionGranted: boolean = false;
  /** 快门白闪反馈 */
  @Local flashOpacity: number = 0;
  /** 识别流水线进行中（抠图+出词，1~5秒） */
  @Local recognizing: boolean = false;
  /** 识别等待动效的呼吸缩放 */
  @Local pulseScale: number = 1;
  /** 拍照后定格帧 URI（覆盖取景层，识别期间定格画面） */
  @Local frozenFrameUri: string = '';
  /** 云端识别设置面板 */
  @Local showSettings: boolean = false;
  @Local apiKeyInput: string = '';

  aboutToAppear(): void {
    this.requestCameraPermission();
    // 从确认页返回时清除定格帧，恢复取景画面
    this.frozenFrameUri = '';
  }

  aboutToDisappear(): void {
    this.cameraService.stop();
  }

  /** 从各种 Error 类型中提取人类可读的错误信息 */
  static errMsg(e: Object): string {
    const err = e as BusinessError;
    if (err.message !== undefined && err.message !== null && err.message !== '') {
      const prefix = err.code !== undefined && err.code !== 0 ? `[${err.code}] ` : '';
      return `${prefix}${err.message}`;
    }
    if (typeof err === 'string') {
      return err as string;
    }
    return String(e);
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
        hilog.warn(0x0001, TAG, 'camera unavailable');
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

  /** 快门：拍真实照片 → 抠图 + 识别 → 确认页；相机不可用时明确提示 */
  private async captureAndRecognize(): Promise<void> {
    if (this.recognizing) {
      return;
    }
    if (this.cameraFailed) {
      this.getUIContext().getPromptAction().showToast({
        message: '当前设备没有可用摄像头，请点右下角从相册选图识别',
        duration: 2200
      });
      return;
    }
    this.playFlash();
    this.recognizing = true;
    this.startPulse();
    try {
      const photo = await this.cameraService.capturePhoto();
      // 定格：保存为临时 JPEG 覆盖取景层
      try {
        this.frozenFrameUri = await ImageUtil.saveTempJpeg(photo, this.hostContext());
      } catch (e) {
        hilog.warn(0x0001, TAG, `frozen frame save failed: ${JSON.stringify(e)}`);
      }
      await this.recognizePixelMap(photo);
      // 识别完成已跳转确认页，清除定格帧；下次返回时恢复取景
      this.frozenFrameUri = '';
    } catch (e) {
      const msg = CameraHome.errMsg(e);
      hilog.warn(0x0001, TAG, `capture failed: ${msg}`);
      this.getUIContext().getPromptAction().showToast({
        message: `拍照失败：${msg}`,
        duration: 3000
      });
      this.frozenFrameUri = '';
    } finally {
      this.recognizing = false;
    }
  }

  private async recognizePixelMap(photo: image.PixelMap): Promise<void> {
    const result = await RecognitionService.recognizePhoto(photo, this.hostContext(), this.store.apiKey);
    this.store.pending = result;
    this.stack.pushPathByName('confirm', null);
  }

  /**
   * 长按快门：用内置示例照片走完整识别管线（抠图+出词都是真实的）。
   * 给无相机的模拟器一条可体验全流程的通道，不是随机词。
   */
  private async recognizeSample(): Promise<void> {
    if (this.recognizing) {
      return;
    }
    this.getUIContext().getPromptAction().showToast({
      message: '示例照片 · 演示完整识别流程',
      duration: 1400
    });
    this.recognizing = true;
    this.startPulse();
    try {
      const raw = await this.hostContext().resourceManager.getRawFileContent('selftest_banana.jpg');
      const buf = raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength);
      const photo = await ImageUtil.fromJpegBuffer(buf as ArrayBuffer);
      await this.recognizePixelMap(photo);
    } catch (e) {
      hilog.error(0x0001, TAG, `sample recognize failed: ${JSON.stringify(e)}`);
    } finally {
      this.recognizing = false;
    }
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

  @Builder
  FocusCorner(left: boolean, top: boolean) {
    Row()
      .width(28)
      .height(28)
      .border({
        width: {
          left: left ? 3 : 0,
          right: left ? 0 : 3,
          top: top ? 3 : 0,
          bottom: top ? 0 : 3
        },
        color: '#D9FFFFFF',
        radius: {
          topLeft: left && top ? 8 : 0,
          topRight: !left && top ? 8 : 0,
          bottomLeft: left && !top ? 8 : 0,
          bottomRight: !left && !top ? 8 : 0
        }
      })
  }

  @Builder
  SettingsSheet() {
    Column({ space: 14 }) {
      Text('云端识别（推荐）')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .margin({ top: 20 })
      Text(this.store.apiKey === '' ? '未启用 — 当前用端侧离线模型识别，精度有限' : '已启用 — 拍照识别走云端大模型，失败时回退端侧')
        .fontSize(13)
        .fontColor(this.store.apiKey === '' ? Theme.TEXT_SUB : '#5B8C5A')
      Text('CapWords 的识别体验依赖云端视觉大模型。在 open.bigmodel.cn 免费注册领取 GLM-4V-Flash 的 API Key 粘贴到下方，即可获得同级识别效果；不配置则由端侧模型兜底。')
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
          .backgroundColor(Theme.ACCENT)
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
    Stack({ alignContent: Alignment.Bottom }) {
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
          Text('没有可用摄像头')
            .fontSize(14)
            .fontColor('#B3FFFFFF')
          Text('点击右下角相册按钮，选一张照片体验识别')
            .fontSize(11)
            .fontColor('#80FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .linearGradient({
          angle: 160,
          colors: [['#3A362F', 0.0], ['#4A4238', 0.55], ['#5C5044', 1.0]]
        })
      }

      // ── 快门白闪 ───────────────────────────
      Rect()
        .width('100%')
        .height('100%')
        .fill(Color.White)
        .opacity(this.flashOpacity)
        .hitTestBehavior(HitTestMode.None)

      // ── 拍照定格帧（覆盖取景层，识别期间冻结画面）─
      if (this.frozenFrameUri !== '') {
        Image(this.frozenFrameUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      }

      // ── 左上：日期 + 引导语；右上：设置 ──
      Column({ space: 6 }) {
        Row() {
          Text(cnDate(todayKey()))
            .fontSize(26)
            .fontFamily('serif')
            .fontColor(Color.White)
          Blank()
          Text('⚙')
            .fontSize(15)
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
              height: 360,
              backgroundColor: Theme.BG,
              onDisappear: () => {
                this.showSettings = false;
              }
            })
        }
        .width('100%')

        Text('把需要识别的物体放在屏幕中间位置')
          .fontSize(13)
          .fontColor('#CCFFFFFF')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 16, top: 56 })
      .position({ x: 0, y: 0 })

      // ── 中央对焦框 ──
      if (!this.recognizing) {
        Stack() {
          Column() {
            Row() {
              this.FocusCorner(true, true)
              Blank()
              this.FocusCorner(false, true)
            }
            .width('100%')

            Blank()
            Row() {
              this.FocusCorner(true, false)
              Blank()
              this.FocusCorner(false, false)
            }
            .width('100%')
          }
          .width(150)
          .height(150)
        }
        .width('100%')
        .height('100%')
        .align(Alignment.Center)
        .hitTestBehavior(HitTestMode.None)
      }

      // ── 识别等待浮层 ──
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

      // ── 底部白色快门面板（点阵纸纹理）──
      Column({ space: 10 }) {
        // 拖拽条：上滑/点击进入今日贴纸墙
        Row()
          .width(38)
          .height(4)
          .borderRadius(2)
          .backgroundColor('#D0CDC6')
          .margin({ top: 10 })

        Row() {
          // 今日收集数 → 今日贴纸墙
          Column({ space: 2 }) {
            Text(`${this.store.todayCount()}`)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
            Text('今日')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .width(52)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#EFEDE8')
          .borderRadius(26)
          .onClick(() => {
            this.store.selectedDate = todayKey();
            this.stack.pushPathByName('day', null);
          })

          Blank()

          // 彩色圆环快门
          Stack() {
            Row()
              .width(78)
              .height(78)
              .borderRadius(39)
              .sweepGradient({
                center: [39, 39],
                start: 0,
                end: 360,
                colors: [['#F5E36B', 0.0], ['#F0B3C8', 0.25], ['#A8D8CB', 0.5], ['#B7B1DB', 0.75], ['#F5E36B', 1.0]]
              })
            Row()
              .width(62)
              .height(62)
              .borderRadius(31)
              .backgroundColor(Color.White)
              .shadow({
                radius: 6,
                color: Theme.SHADOW,
                offsetX: 0,
                offsetY: 2
              })
          }
          .onClick(() => {
            this.captureAndRecognize();
          })
          .gesture(
            LongPressGesture()
              .onAction(() => {
                this.recognizeSample();
              })
          )

          Blank()

          // 相册入口
          Text('🖼️')
            .fontSize(20)
            .width(52)
            .height(52)
            .textAlign(TextAlign.Center)
            .backgroundColor('#EFEDE8')
            .borderRadius(26)
            .onClick(() => {
              this.pickFromGallery();
            })
        }
        .width('100%')
        .padding({ left: 28, right: 28, bottom: 34 })
      }
      .width('100%')
      .backgroundColor(Color.White)
      .backgroundImage($r('app.media.dot_grid'), ImageRepeat.XY)
      .borderRadius({ topLeft: 28, topRight: 28 })
      .gesture(
        SwipeGesture({ direction: SwipeDirection.Vertical })
          .onAction(() => {
            this.store.selectedDate = todayKey();
            this.stack.pushPathByName('day', null);
          })
      )
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
    if (name === 'confirm') {
      ConfirmPage({ stack: this.pathStack })
    } else if (name === 'day') {
      DayPage({ stack: this.pathStack })
    } else if (name === 'month') {
      MonthPage({ stack: this.pathStack })
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
