import { objectDetection, visionBase } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DICTIONARY, DictEntry } from './Dictionary';

const TAG = 'DeviceRecognition';

/**
 * 端侧粗识别 — Core Vision Kit objectDetection（离线可用）。
 * 只有 15 个粗粒度标签，作为无网络/无 API Key 时的兜底：
 * 0 场景 1 动物 2 植物 3 建筑 6 桌台 9 猫 10 狗 11 食物 12 车 13 人。
 */
interface LabelMapping {
  label: number;
  /** 精确词（如猫/狗），空串则回退到按分类抽词 */
  word: string;
  category: string;
}

const LABEL_MAP: LabelMapping[] = [
  { label: 9, word: 'kitten', category: 'animal' },
  { label: 10, word: 'puppy', category: 'animal' },
  { label: 1, word: '', category: 'animal' },
  { label: 2, word: 'plant', category: 'nature' },
  { label: 11, word: '', category: 'food' },
  { label: 12, word: 'car', category: 'object' },
  { label: 6, word: 'table', category: 'object' },
  { label: 3, word: 'building', category: 'place' },
  { label: 13, word: 'person', category: 'object' },
  { label: 5, word: 'person', category: 'object' },
  { label: 8, word: 'person', category: 'object' }
];

export class DeviceRecognitionService {
  /**
   * 返回最可信物体对应的词条；识别失败或标签无法映射返回 null。
   */
  static async recognize(pm: image.PixelMap): Promise<DictEntry | null> {
    let detector: objectDetection.ObjectDetector | null = null;
    try {
      detector = await objectDetection.ObjectDetector.create();
      const request: visionBase.Request = {
        inputData: { pixelMap: pm }
      };
      const response = await detector.process(request);
      let best: LabelMapping | null = null;
      let bestScore = 0;
      for (const obj of response.objects) {
        for (const label of obj.labels) {
          for (const m of LABEL_MAP) {
            if (m.label === label && obj.score > bestScore) {
              best = m;
              bestScore = obj.score;
            }
          }
        }
      }
      if (best === null) {
        return null;
      }
      return DeviceRecognitionService.entryFor(best);
    } catch (e) {
      hilog.warn(0x0001, TAG, `object detection failed: ${JSON.stringify(e)}`);
      return null;
    } finally {
      if (detector !== null) {
        try {
          await detector.destroy();
        } catch (destroyErr) {
          hilog.warn(0x0001, TAG, `destroy failed: ${JSON.stringify(destroyErr)}`);
        }
      }
    }
  }

  private static entryFor(mapping: LabelMapping): DictEntry | null {
    if (mapping.word !== '') {
      for (const e of DICTIONARY) {
        if (e.word === mapping.word) {
          return e;
        }
      }
    }
    const pool: DictEntry[] = [];
    for (const e of DICTIONARY) {
      if (e.category === mapping.category) {
        pool.push(e);
      }
    }
    if (pool.length === 0) {
      return null;
    }
    return pool[Math.floor(Math.random() * pool.length)];
  }
}
