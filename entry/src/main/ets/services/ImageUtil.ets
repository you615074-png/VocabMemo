import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

/**
 * 图片工具 — 负责 JPEG buffer/相册 uri → PixelMap、
 * 贴纸 PixelMap → 透明 PNG 落盘、上传用 base64 压缩。
 */
export class ImageUtil {
  static async fromJpegBuffer(buffer: ArrayBuffer): Promise<image.PixelMap> {
    const source = image.createImageSource(buffer);
    const pm = await source.createPixelMap({
      editable: true,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    await source.release();
    return pm;
  }

  static async fromUri(uri: string): Promise<image.PixelMap> {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const source = image.createImageSource(file.fd);
    const pm = await source.createPixelMap({
      editable: true,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    await source.release();
    fs.closeSync(file);
    return pm;
  }

  /** 贴纸存成透明 PNG，返回 file:// uri（Image 组件可直接加载） */
  static async savePng(pm: image.PixelMap, context: common.UIAbilityContext, name: string): Promise<string> {
    const packer = image.createImagePacker();
    const data = await packer.packToData(pm, { format: 'image/png', quality: 100 });
    await packer.release();
    const path = `${context.filesDir}/${name}.png`;
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, data);
    fs.closeSync(file);
    return `file://${path}`;
  }

  /**
   * 压缩为 base64 JPEG（云端识别的上传体）。
   * 注意：会就地缩放传入的 PixelMap，须在抠图完成后再调用。
   */
  static async toBase64Jpeg(pm: image.PixelMap, maxEdge: number): Promise<string> {
    const info = await pm.getImageInfo();
    const longEdge = Math.max(info.size.width, info.size.height);
    if (longEdge > maxEdge) {
      const ratio = maxEdge / longEdge;
      await pm.scale(ratio, ratio);
    }
    const packer = image.createImagePacker();
    const data = await packer.packToData(pm, { format: 'image/jpeg', quality: 85 });
    await packer.release();
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(new Uint8Array(data));
  }
}
