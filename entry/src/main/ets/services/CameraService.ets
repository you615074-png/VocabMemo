import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ImageUtil } from './ImageUtil';

const TAG = 'CameraService';
const CAPTURE_TIMEOUT_MS = 8000;

/** 把 BusinessError 格式化成 "code message" 字符串，方便日志与 toast 排查 */
function fmtError(e: Object): string {
  const err = e as BusinessError;
  const code = err.code !== undefined && err.code !== 0 ? `[${err.code}] ` : '';
  const msg = err.message !== undefined && err.message !== null && err.message !== '' ? err.message : `${e}`;
  return `${code}${msg}`;
}

/**
 * 相机服务 — 后置摄像头预览 + 真实拍照出片。
 * capturePhoto() 返回照片 PixelMap，交给识别流水线做抠图与出词。
 */
export class CameraService {
  private cameraInput: camera.CameraInput | null = null;
  private previewOutput: camera.PreviewOutput | null = null;
  private photoOutput: camera.PhotoOutput | null = null;
  private session: camera.PhotoSession | null = null;
  private photoResolver: ((pm: image.PixelMap) => void) | null = null;
  private photoRejecter: ((reason: Error) => void) | null = null;
  private captureTimer: number | null = null;

  /**
   * 启动预览会话（含拍照输出流）。失败时抛出异常，由页面降级为演示取景。
   */
  async start(context: common.UIAbilityContext, surfaceId: string): Promise<void> {
    const manager = camera.getCameraManager(context);
    const devices = manager.getSupportedCameras();
    if (devices.length === 0) {
      throw new Error('no camera device');
    }
    let device = devices[0];
    for (const d of devices) {
      if (d.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK) {
        device = d;
        break;
      }
    }
    const capability = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
    const previewProfiles = capability.previewProfiles;
    const photoProfiles = capability.photoProfiles;
    if (previewProfiles.length === 0 || photoProfiles.length === 0) {
      throw new Error('no camera profile');
    }
    // 优先选 JPEG 格式的 profile（设备可能同时支持 HEIF，不选 JPEG 后面 getComponent 拿不到数据）
    const previewProfile = CameraService.pickProfile(previewProfiles, false);
    const photoProfile = CameraService.pickProfile(photoProfiles, true);
    hilog.info(0x0001, TAG,
      `preview ${previewProfile.size.width}x${previewProfile.size.height}, photo ${photoProfile.size.width}x${photoProfile.size.height}`);

    this.cameraInput = manager.createCameraInput(device);
    await this.cameraInput.open();
    this.previewOutput = manager.createPreviewOutput(previewProfile, surfaceId);
    this.photoOutput = manager.createPhotoOutput(photoProfile);
    this.listenPhoto(this.photoOutput);

    this.session = manager.createSession<camera.PhotoSession>(camera.SceneMode.NORMAL_PHOTO);
    this.session.beginConfig();
    this.session.addInput(this.cameraInput);
    this.session.addOutput(this.previewOutput);
    this.session.addOutput(this.photoOutput);
    await this.session.commitConfig();
    await this.session.start();
    hilog.info(0x0001, TAG, 'photo session started');
  }

  /**
   * 挑选最优 profile：JPEG 格式优先（photoOnly=true 时），
   * 其次选接近全面屏比例 (4:3~16:9) 且分辨率适中的流。
   */
  private static pickProfile(profiles: Array<camera.Profile>, photoOnly: boolean): camera.Profile {
    // 第一轮：photoOnly 时只挑 JPEG 格式
    if (photoOnly) {
      for (const p of profiles) {
        const long = Math.max(p.size.width, p.size.height);
        if (long <= 1920 && CameraService.isJpegProfile(p)) {
          return p;
        }
      }
      // 没有合适的 JPEG profile，退回到任意格式
      hilog.warn(0x0001, TAG, 'no JPEG photo profile found, falling back to any format');
    }
    // 第二轮：按分辨率选
    let picked = profiles[0];
    for (const p of profiles) {
      const long = Math.max(p.size.width, p.size.height);
      const short = Math.min(p.size.width, p.size.height);
      const ratio = long / short;
      if (long <= 1920 && ratio > 1.3 && ratio < 1.8) {
        picked = p;
        break;
      }
    }
    return picked;
  }

  /** 检查 profile 是否为 JPEG 格式（兼容不同 SDK 版本） */
  private static isJpegProfile(p: camera.Profile): boolean {
    try {
      // CameraFormat.CAMERA_FORMAT_JPEG 通常为 0 或特定枚举值
      if (p.format !== undefined && p.format !== null) {
        // 通过枚举值或字符串比较来判断
        const fmt = p.format;
        // CAMERA_FORMAT_JPEG 在多数 SDK 中值为 0
        if (fmt === 0) {
          return true;
        }
        // 部分 SDK 可能用字符串
        if (typeof fmt === 'string' && (fmt === 'CAMERA_FORMAT_JPEG' || fmt === 'jpeg' || fmt === 'JPEG')) {
          return true;
        }
        // 打印未知格式用于调试
        hilog.info(0x0001, TAG, `photo profile format: ${fmt} (${typeof fmt})`);
      }
    } catch (e) {
      // format 属性可能不存在，静默降级
    }
    return false;
  }

  private listenPhoto(output: camera.PhotoOutput): void {
    // 设备级错误（对焦失败、传感器异常等）——必须监听，否则静默丢失
    output.on('error', (err: BusinessError) => {
      hilog.error(0x0001, TAG, `photoOutput error: ${fmtError(err)}`);
      this.finishReject(new Error(`相机异常：${fmtError(err)}`));
    });

    output.on('photoAvailable', (err: BusinessError, photo: camera.Photo) => {
      if (err !== undefined && err !== null && err.code !== 0) {
        hilog.error(0x0001, TAG, `photoAvailable error: ${fmtError(err)}`);
        this.finishReject(new Error(`photoAvailable ${fmtError(err)}`));
        return;
      }
      if (photo === undefined || photo === null || photo.main === undefined || photo.main === null) {
        hilog.error(0x0001, TAG, 'photoAvailable returned empty photo.main');
        this.finishReject(new Error('拍照数据为空'));
        return;
      }
      const imageObj = photo.main;
      // 先问设备这张照片有哪些格式可用，再逐个尝试解码
      CameraService.decodeFromBestComponent(imageObj)
        .then((pm: image.PixelMap) => {
          this.finishResolve(pm);
        })
        .catch((finalErr: Error) => {
          hilog.error(0x0001, TAG, `all decode formats failed: ${finalErr.message}`);
          this.finishReject(finalErr);
        })
        .finally(() => {
          imageObj.release();
        });
    });
  }

  /**
   * 从照片中提取图像数据并解码。
   * 直接尝试 JPEG 组件——上层 pickProfile 已确保 photo profile 为 JPEG 格式。
   * createImageSource 可自动识别 JPEG/HEIF/PNG 等格式。
   */
  private static async decodeFromBestComponent(imageObj: image.Image): Promise<image.PixelMap> {
    return CameraService.tryDecodeComponent(imageObj, image.ComponentType.JPEG, 'JPEG');
  }

  /**
   * 从 PhotoAsset 中提取指定格式的图像数据并解码为 PixelMap。
   * buffer < 512 字节视为空数据（真机 HEIF 模式下 JPEG 组件常见）。
   */
  private static tryDecodeComponent(imageObj: image.Image, compType: image.ComponentType,
    label: string): Promise<image.PixelMap> {
    return new Promise<image.PixelMap>((resolve, reject) => {
      imageObj.getComponent(compType, (compErr: BusinessError, component: image.Component) => {
        // 兼容不同 SDK 的 callback 行为：err 可能为 undefined/null/{code:0,message:""}
        if (compErr !== undefined && compErr !== null && compErr.code !== undefined && compErr.code !== 0) {
          reject(new Error(`${label}: ${fmtError(compErr)}`));
          return;
        }
        const buf = component.byteBuffer;
        if (buf === undefined || buf === null || buf.byteLength < 512) {
          const sz = (buf === undefined || buf === null) ? 0 : buf.byteLength;
          reject(new Error(`${label}数据为空（${sz}B）`));
          return;
        }
        // createImageSource 自动识别 JPEG/HEIF/PNG 等格式
        ImageUtil.fromJpegBuffer(buf)
          .then((pm: image.PixelMap) => {
            pm.getImageInfo().then((info: image.ImageInfo) => {
              hilog.info(0x0001, TAG, `${label} decoded ${info.size.width}x${info.size.height} (${buf.byteLength}B)`);
              resolve(pm);
            });
          })
          .catch((decodeErr: BusinessError) => {
            reject(new Error(`${label}解码失败（${buf.byteLength}B）：${fmtError(decodeErr)}`));
          });
      });
    });
  }

  /**
   * 拍一张照片并返回 PixelMap。超时或异常会 reject。
   */
  capturePhoto(): Promise<image.PixelMap> {
    return new Promise<image.PixelMap>((resolve, reject) => {
      if (this.photoOutput === null) {
        reject(new Error('相机未启动'));
        return;
      }

      // 防止重复按快门导致 "capture too frequently" 错误
      if (this.photoResolver !== null || this.photoRejecter !== null) {
        reject(new Error('上一张照片仍在处理中'));
        return;
      }

      this.photoResolver = resolve;
      this.photoRejecter = reject;

      this.captureTimer = setTimeout(() => {
        hilog.warn(0x0001, TAG, 'capture timeout (8s)');
        this.finishReject(new Error('拍照超时，请重试'));
      }, CAPTURE_TIMEOUT_MS);

      // 获取设备旋转角度；部分设备不支持此 API，静默降级
      let rotation: camera.ImageRotation = camera.ImageRotation.ROTATION_0;
      try {
        rotation = this.photoOutput.getPhotoRotation(0);
        hilog.info(0x0001, TAG, `photo rotation: ${rotation}`);
      } catch (e) {
        hilog.warn(0x0001, TAG, `getPhotoRotation unsupported, use ROTATION_0`);
      }

      const setting: camera.PhotoCaptureSetting = {
        quality: camera.QualityLevel.QUALITY_LEVEL_MEDIUM,
        rotation: rotation
      };

      hilog.info(0x0001, TAG, 'calling capture()...');
      this.photoOutput.capture(setting)
        .then(() => {
          hilog.info(0x0001, TAG, 'capture() resolved — waiting for photoAvailable');
          // capture() 成功只表示请求已受理，真正的照片数据走 photoAvailable 事件
        })
        .catch((err: BusinessError) => {
          hilog.error(0x0001, TAG, `capture() rejected: ${fmtError(err)}`);
          this.clearCaptureTimer();
          this.finishReject(new Error(`拍照失败：${fmtError(err)}`));
        });
    });
  }

  private clearCaptureTimer(): void {
    if (this.captureTimer !== null) {
      clearTimeout(this.captureTimer);
      this.captureTimer = null;
    }
  }

  private finishResolve(pm: image.PixelMap): void {
    this.clearCaptureTimer();
    if (this.photoResolver !== null) {
      const r = this.photoResolver;
      this.photoResolver = null;
      this.photoRejecter = null;
      r(pm);
    }
  }

  private finishReject(reason: Error): void {
    this.clearCaptureTimer();
    if (this.photoRejecter !== null) {
      const r = this.photoRejecter;
      this.photoResolver = null;
      this.photoRejecter = null;
      r(reason);
    }
  }

  async stop(): Promise<void> {
    try {
      this.clearCaptureTimer();
      // 清理未完成的 capture promise
      if (this.photoRejecter !== null) {
        const r = this.photoRejecter;
        this.photoResolver = null;
        this.photoRejecter = null;
        r(new Error('相机已关闭'));
      }
      if (this.session !== null) {
        await this.session.stop();
        await this.session.release();
        this.session = null;
      }
      if (this.previewOutput !== null) {
        await this.previewOutput.release();
        this.previewOutput = null;
      }
      if (this.photoOutput !== null) {
        await this.photoOutput.release();
        this.photoOutput = null;
      }
      if (this.cameraInput !== null) {
        await this.cameraInput.close();
        this.cameraInput = null;
      }
    } catch (e) {
      hilog.error(0x0001, TAG, `stop failed: ${fmtError(e)}`);
    }
  }
}
