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
    const previewProfile = CameraService.pickProfile(previewProfiles);
    const photoProfile = CameraService.pickProfile(photoProfiles);
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

  /** 优先挑接近全面屏比例(4:3~16:9)且分辨率适中的流 */
  private static pickProfile(profiles: Array<camera.Profile>): camera.Profile {
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
      // JPEG 优先；若组件数据为空（部分设备 HEIF 模式下 JPEG 占位为空），
      // 尝试不指定类型获取原始图像数据
      CameraService.tryDecodeComponent(imageObj, image.ComponentType.JPEG, 'JPEG')
        .catch((jpegErr: Error) => {
          hilog.warn(0x0001, TAG, `JPEG unavailable: ${jpegErr.message}, trying raw...`);
          // 某些设备可能把图像存在其他 component 类型，直接尝遍所有可用 component
          return CameraService.tryDecodeRaw(imageObj);
        })
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
   * 从 PhotoAsset 中提取指定格式的图像数据并解码为 PixelMap。
   * getComponent 成功但 buffer 为空/过小时也会 reject（真机 HEIF 模式下 JPEG 组件常见）。
   */
  private static tryDecodeComponent(imageObj: image.Image, compType: image.ComponentType,
    label: string): Promise<image.PixelMap> {
    return new Promise<image.PixelMap>((resolve, reject) => {
      imageObj.getComponent(compType, (compErr: BusinessError, component: image.Component) => {
        if (compErr !== undefined && compErr !== null && compErr.code !== 0) {
          reject(new Error(`${label}组件不可用：${fmtError(compErr)}`));
          return;
        }
        const buf = component.byteBuffer;
        if (buf === undefined || buf === null || buf.byteLength < 512) {
          const sz = (buf === undefined || buf === null) ? 0 : buf.byteLength;
          reject(new Error(`${label}数据为空（${sz} 字节，设备可能输出 HEIF 格式）`));
          return;
        }
        ImageUtil.fromJpegBuffer(buf)
          .then((pm: image.PixelMap) => {
            pm.getImageInfo().then((info: image.ImageInfo) => {
              hilog.info(0x0001, TAG, `${label} decoded ${info.size.width}x${info.size.height}`);
              resolve(pm);
            });
          })
          .catch((decodeErr: BusinessError) => {
            reject(new Error(`${label}解码失败（${buf.byteLength} 字节）：${fmtError(decodeErr)}`));
          });
      });
    });
  }

  /**
   * JPEG 组件不可用时的兜底：再取一次 JPEG 组件（部分设备首次返回空，第二次返回完整数据），
   * 通过 createImageSource 自动识别 JPEG/HEIF/PNG 等格式。
   */
  private static tryDecodeRaw(imageObj: image.Image): Promise<image.PixelMap> {
    return new Promise<image.PixelMap>((resolve, reject) => {
      imageObj.getComponent(image.ComponentType.JPEG, (compErr: BusinessError, component: image.Component) => {
        if (compErr !== undefined && compErr !== null && compErr.code !== 0) {
          reject(new Error(`无法读取照片数据：${fmtError(compErr)}`));
          return;
        }
        const buf = component.byteBuffer;
        if (buf === undefined || buf === null || buf.byteLength < 64) {
          const sz = (buf === undefined || buf === null) ? 0 : buf.byteLength;
          reject(new Error(`照片数据为空（${sz} 字节），设备可能使用 HEIF 且当前 SDK 不支持`));
          return;
        }
        ImageUtil.fromJpegBuffer(buf)
          .then((pm: image.PixelMap) => {
            pm.getImageInfo().then((info: image.ImageInfo) => {
              hilog.info(0x0001, TAG, `raw decoded ${info.size.width}x${info.size.height}`);
              resolve(pm);
            });
          })
          .catch((decodeErr: BusinessError) => {
            reject(new Error(`照片解码失败（${buf.byteLength} 字节）：${fmtError(decodeErr)}`));
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
