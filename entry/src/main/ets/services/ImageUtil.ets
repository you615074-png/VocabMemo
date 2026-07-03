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

  /**
   * 贴纸存成透明 PNG，返回 file:// uri（Image 组件可直接加载）。
   * 抠图贴纸（带透明区）会烘焙 CapWords 式白描边：
   * 对 alpha 做两趟盒式模糊近似膨胀，膨胀圈涂白后与原图合成。
   * 整图贴纸（无透明区）原样保存。
   */
  static async savePng(pm: image.PixelMap, context: common.UIAbilityContext, name: string): Promise<string> {
    const outlined = await ImageUtil.withStickerOutline(pm);
    const target = outlined === null ? pm : outlined;
    const packer = image.createImagePacker();
    const data = await packer.packToData(target, { format: 'image/png', quality: 100 });
    await packer.release();
    if (outlined !== null) {
      outlined.release();
    }
    const path = `${context.filesDir}/${name}.png`;
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, data);
    fs.closeSync(file);
    return `file://${path}`;
  }

  /**
   * 生成带白描边的贴纸副本；输入不含透明像素（整图）时返回 null。
   * 长边超过 800 时先缩小（贴纸展示尺寸 ≤400vp，够用且省内存）。
   */
  private static async withStickerOutline(pm: image.PixelMap): Promise<image.PixelMap | null> {
    const info = await pm.getImageInfo();
    let w = info.size.width;
    let h = info.size.height;
    const srcBuf = new ArrayBuffer(w * h * 4);
    await pm.readPixelsToBuffer(srcBuf);
    let rgba = new Uint8Array(srcBuf);

    // 需要缩小时经由副本 PixelMap 缩放，不动原图
    const MAX_EDGE = 800;
    if (Math.max(w, h) > MAX_EDGE) {
      const copy = await image.createPixelMap(srcBuf, {
        size: { width: w, height: h },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
      });
      const ratio = MAX_EDGE / Math.max(w, h);
      await copy.scale(ratio, ratio);
      const scaledInfo = await copy.getImageInfo();
      w = scaledInfo.size.width;
      h = scaledInfo.size.height;
      const scaledBuf = new ArrayBuffer(w * h * 4);
      await copy.readPixelsToBuffer(scaledBuf);
      copy.release();
      rgba = new Uint8Array(scaledBuf);
    }

    // 是否真的有透明区（抽样即可）
    let hasAlpha = false;
    for (let i = 3; i < rgba.length; i += 64) {
      if (rgba[i] < 200) {
        hasAlpha = true;
        break;
      }
    }
    if (!hasAlpha) {
      return null;
    }

    const n = w * h;
    const alpha = new Uint8Array(n);
    for (let i = 0; i < n; i++) {
      alpha[i] = rgba[i * 4 + 3];
    }
    const radius = Math.max(5, Math.round(Math.min(w, h) / 55));
    const blurred = ImageUtil.boxBlurAlpha(alpha, w, h, radius);

    const out = new Uint8Array(n * 4);
    for (let i = 0; i < n; i++) {
      const a = alpha[i];
      const b = blurred[i];
      const o = i * 4;
      if (a >= 200) {
        out[o] = rgba[o];
        out[o + 1] = rgba[o + 1];
        out[o + 2] = rgba[o + 2];
        out[o + 3] = 255;
      } else if (b > 10) {
        // 膨胀圈：白描边（半透明边缘用原色与白混合，柔化锯齿）
        const t = a / 200;
        out[o] = 255 - Math.round((255 - rgba[o]) * t);
        out[o + 1] = 255 - Math.round((255 - rgba[o + 1]) * t);
        out[o + 2] = 255 - Math.round((255 - rgba[o + 2]) * t);
        out[o + 3] = 255;
      }
    }
    return await image.createPixelMap(out.buffer as ArrayBuffer, {
      size: { width: w, height: h },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: false
    });
  }

  /** 两趟滑窗盒式模糊（水平+垂直），O(n)，用于 alpha 膨胀近似 */
  private static boxBlurAlpha(src: Uint8Array, w: number, h: number, radius: number): Uint8Array {
    const tmp = new Uint8Array(src.length);
    const dst = new Uint8Array(src.length);
    const win = radius * 2 + 1;
    for (let y = 0; y < h; y++) {
      const row = y * w;
      let sum = 0;
      for (let x = -radius; x <= radius; x++) {
        sum += src[row + Math.min(w - 1, Math.max(0, x))];
      }
      for (let x = 0; x < w; x++) {
        tmp[row + x] = Math.min(255, Math.round(sum / win * 2.4));
        sum += src[row + Math.min(w - 1, x + radius + 1)] - src[row + Math.max(0, x - radius)];
      }
    }
    for (let x = 0; x < w; x++) {
      let sum = 0;
      for (let y = -radius; y <= radius; y++) {
        sum += tmp[Math.min(h - 1, Math.max(0, y)) * w + x];
      }
      for (let y = 0; y < h; y++) {
        dst[y * w + x] = Math.min(255, Math.round(sum / win * 2.4));
        sum += tmp[Math.min(h - 1, y + radius + 1) * w + x] - tmp[Math.max(0, y - radius) * w + x];
      }
    }
    return dst;
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
