import { subjectSegmentation } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SegmentationService';

/**
 * 主体抠图 — Core Vision Kit subjectSegmentation。
 * 把照片中的主体「撕」下来生成透明背景贴纸（CapWords 贴纸效果的核心）。
 * 模拟器或不支持的机型上返回 null，由上层降级为整图贴纸。
 */
export class SegmentationService {
  static async cutout(pm: image.PixelMap): Promise<image.PixelMap | null> {
    try {
      await subjectSegmentation.init();
    } catch (e) {
      hilog.warn(0x0001, TAG, `segmentation init failed: ${JSON.stringify(e)}`);
      return null;
    }
    try {
      const result = await subjectSegmentation.doSegmentation(
        { pixelMap: pm },
        { maxCount: 1, enableSubjectDetails: false }
      );
      if (result.subjectCount <= 0) {
        return null;
      }
      const foreground = result.fullSubject.foregroundImage;
      // 裁到主体包围盒，让贴纸紧凑（失败则保留整幅前景）
      try {
        const rect = result.fullSubject.subjectRectangle;
        if (rect.width > 0 && rect.height > 0) {
          await foreground.crop({
            x: rect.left,
            y: rect.top,
            size: { width: rect.width, height: rect.height }
          });
        }
      } catch (cropErr) {
        hilog.warn(0x0001, TAG, `crop failed: ${JSON.stringify(cropErr)}`);
      }
      return foreground;
    } catch (e) {
      hilog.warn(0x0001, TAG, `segmentation failed: ${JSON.stringify(e)}`);
      return null;
    } finally {
      try {
        await subjectSegmentation.release();
      } catch (releaseErr) {
        hilog.warn(0x0001, TAG, `release failed: ${JSON.stringify(releaseErr)}`);
      }
    }
  }
}
