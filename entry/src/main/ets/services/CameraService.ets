import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ImageUtil } from './ImageUtil';

const TAG = 'CameraService';
const CAPTURE_TIMEOUT_MS = 8000;

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
    output.on('photoAvailable', (err: BusinessError, photo: camera.Photo) => {
      if (err !== undefined && err !== null && err.code !== 0) {
        this.finishReject(new Error(`photoAvailable error ${err.code}`));
        return;
      }
      const imageObj = photo.main;
      imageObj.getComponent(image.ComponentType.JPEG, (compErr: BusinessError, component: image.Component) => {
        if (compErr !== undefined && compErr !== null && compErr.code !== 0) {
          this.finishReject(new Error(`getComponent error ${compErr.code}`));
          imageObj.release();
          return;
        }
        ImageUtil.fromJpegBuffer(component.byteBuffer)
          .then((pm: image.PixelMap) => {
            this.finishResolve(pm);
          })
          .catch((decodeErr: BusinessError) => {
            this.finishReject(new Error(`decode failed ${decodeErr.message}`));
          })
          .finally(() => {
            imageObj.release();
          });
      });
    });
  }

  /**
   * 拍一张照片并返回 PixelMap。超时或异常会 reject，由页面降级为演示识别。
   */
  capturePhoto(): Promise<image.PixelMap> {
    return new Promise<image.PixelMap>((resolve, reject) => {
      if (this.photoOutput === null) {
        reject(new Error('camera not started'));
        return;
      }
      this.photoResolver = resolve;
      this.photoRejecter = reject;
      const timer = setTimeout(() => {
        this.finishReject(new Error('capture timeout'));
      }, CAPTURE_TIMEOUT_MS);
      let rotation = camera.ImageRotation.ROTATION_0;
      try {
        rotation = this.photoOutput.getPhotoRotation(0);
      } catch (e) {
        hilog.warn(0x0001, TAG, 'getPhotoRotation unsupported, use 0');
      }
      const setting: camera.PhotoCaptureSetting = {
        quality: camera.QualityLevel.QUALITY_LEVEL_MEDIUM,
        rotation: rotation
      };
      this.photoOutput.capture(setting).catch((err: BusinessError) => {
        clearTimeout(timer);
        this.finishReject(new Error(`capture failed ${err.code}`));
      });
    });
  }

  private finishResolve(pm: image.PixelMap): void {
    if (this.photoResolver !== null) {
      const r = this.photoResolver;
      this.photoResolver = null;
      this.photoRejecter = null;
      r(pm);
    }
  }

  private finishReject(reason: Error): void {
    if (this.photoRejecter !== null) {
      const r = this.photoRejecter;
      this.photoResolver = null;
      this.photoRejecter = null;
      r(reason);
    }
  }

  async stop(): Promise<void> {
    try {
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
      const err = e as BusinessError;
      hilog.error(0x0001, TAG, `stop failed: ${err.code} ${err.message}`);
    }
  }
}
