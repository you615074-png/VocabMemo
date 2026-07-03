import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'LocalModelService';
const MODEL_FILE = 'mobilenetv2.ms';
const LABEL_FILE = 'imagenet_labels.txt';
const SELFTEST_FILE = 'selftest_banana.jpg';
const INPUT_EDGE = 224;
/** ImageNet 标准归一化参数（×255 后的均值/方差） */
const MEANS: number[] = [123.675, 116.28, 103.53];
const STDS: number[] = [58.395, 57.12, 57.375];

/** 一个分类候选：ImageNet 标签 + softmax 置信度 */
export interface Candidate {
  label: string;
  score: number;
}

/**
 * 端侧离线分类 — MindSpore Lite + MobileNetV2（ImageNet-1000）。
 * 离线降级方案：云端不可用时出词。模型 13MB 打包在 rawfile，懒加载常驻。
 * 输入应为抠图后的主体（背景越少分类越准）。
 */
export class LocalModelService {
  private static model: mindSporeLite.Model | null = null;
  private static labels: string[] = [];
  private static loadFailed: boolean = false;

  private static async ensureLoaded(context: common.UIAbilityContext): Promise<boolean> {
    if (LocalModelService.model !== null) {
      return true;
    }
    if (LocalModelService.loadFailed) {
      return false;
    }
    try {
      const modelRaw = await context.resourceManager.getRawFileContent(MODEL_FILE);
      const modelBuf = modelRaw.buffer.slice(modelRaw.byteOffset, modelRaw.byteOffset + modelRaw.byteLength);
      LocalModelService.model = await mindSporeLite.loadModelFromBuffer(modelBuf as ArrayBuffer);

      const labelRaw = await context.resourceManager.getRawFileContent(LABEL_FILE);
      const decoder = util.TextDecoder.create('utf-8');
      const text = decoder.decodeToString(labelRaw);
      LocalModelService.labels = text.split('\n').map((s: string) => s.trim()).filter((s: string) => s !== '');
      hilog.info(0x0001, TAG, `model loaded, labels: ${LocalModelService.labels.length}`);
      return true;
    } catch (e) {
      LocalModelService.loadFailed = true;
      hilog.error(0x0001, TAG, `model load failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /** 模型是否已确认不可用（用于 UI 提示与降级判断） */
  static isUnavailable(): boolean {
    return LocalModelService.loadFailed;
  }

  /**
   * 分类，返回按置信度排序的 top-5 候选。不修改传入的 PixelMap。
   */
  static async classify(pm: image.PixelMap, context: common.UIAbilityContext): Promise<Candidate[]> {
    const ok = await LocalModelService.ensureLoaded(context);
    if (!ok || LocalModelService.model === null) {
      return [];
    }
    try {
      const input = await LocalModelService.preprocess(pm);
      const tensors = LocalModelService.model.getInputs();
      const expected = INPUT_EDGE * INPUT_EDGE * 3 * 4;
      if (tensors[0].dataSize !== expected) {
        hilog.error(0x0001, TAG, `input tensor mismatch: dataSize=${tensors[0].dataSize} expected=${expected}`);
        return [];
      }
      tensors[0].setData(input.buffer as ArrayBuffer);
      const outputs = await LocalModelService.model.predict(tensors);
      const logits = new Float32Array(outputs[0].getData());
      return LocalModelService.top5(logits);
    } catch (e) {
      hilog.error(0x0001, TAG, `inference failed: ${JSON.stringify(e)}`);
      return [];
    }
  }

  /**
   * 自检：用内置测试图跑一次完整推理，结果写 hilog。
   * 应用启动后异步调用，一条日志即可判断当前设备上模型是否可用。
   */
  static async selfTest(context: common.UIAbilityContext): Promise<void> {
    try {
      const raw = await context.resourceManager.getRawFileContent(SELFTEST_FILE);
      const buf = raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength);
      const source = image.createImageSource(buf as ArrayBuffer);
      const pm = await source.createPixelMap({
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      await source.release();
      const t0 = Date.now();
      const top = await LocalModelService.classify(pm, context);
      pm.release();
      if (top.length === 0) {
        hilog.error(0x0001, TAG, 'SELFTEST FAILED: no candidates (model unavailable on this device)');
        return;
      }
      hilog.info(0x0001, TAG,
        `SELFTEST OK in ${Date.now() - t0}ms, top1=${top[0].label}(${top[0].score.toFixed(3)})`);
    } catch (e) {
      hilog.error(0x0001, TAG, `SELFTEST FAILED: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 预处理：复制像素 → 中心裁剪成正方形 → 等比缩到 224 → NHWC float32 归一化。
   * 全程在副本上操作，不污染入参。
   */
  private static async preprocess(pm: image.PixelMap): Promise<Float32Array> {
    const info = await pm.getImageInfo();
    const w = info.size.width;
    const h = info.size.height;
    // 读出原像素，重建一个可编辑副本
    const srcBuf = new ArrayBuffer(w * h * 4);
    await pm.readPixelsToBuffer(srcBuf);
    const copy = await image.createPixelMap(srcBuf, {
      size: { width: w, height: h },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true
    });
    try {
      // 中心裁剪成正方形，避免非等比缩放扭曲物体
      const edge = Math.min(w, h);
      if (w !== h) {
        await copy.crop({
          x: Math.floor((w - edge) / 2),
          y: Math.floor((h - edge) / 2),
          size: { width: edge, height: edge }
        });
      }
      if (edge !== INPUT_EDGE) {
        await copy.scale(INPUT_EDGE / edge, INPUT_EDGE / edge);
      }
      const rgbaBuf = new ArrayBuffer(INPUT_EDGE * INPUT_EDGE * 4);
      await copy.readPixelsToBuffer(rgbaBuf);
      const rgba = new Uint8Array(rgbaBuf);
      const floats = new Float32Array(INPUT_EDGE * INPUT_EDGE * 3);
      const pixels = INPUT_EDGE * INPUT_EDGE;
      for (let i = 0; i < pixels; i++) {
        floats[i * 3] = (rgba[i * 4] - MEANS[0]) / STDS[0];
        floats[i * 3 + 1] = (rgba[i * 4 + 1] - MEANS[1]) / STDS[1];
        floats[i * 3 + 2] = (rgba[i * 4 + 2] - MEANS[2]) / STDS[2];
      }
      return floats;
    } finally {
      copy.release();
    }
  }

  private static top5(logits: Float32Array): Candidate[] {
    // 输出可能是 1000 或 1001（带 background），对齐标签表
    const offset = logits.length - LocalModelService.labels.length;
    // 模型尾部可能自带 Softmax（输出全在 [0,1] 且求和≈1），此时直接用概率，
    // 不能再套一次 softmax（会把分布压平成 1/1000 量级）
    let maxLogit = -Infinity;
    let minLogit = Infinity;
    let total = 0;
    for (let i = 0; i < logits.length; i++) {
      if (logits[i] > maxLogit) {
        maxLogit = logits[i];
      }
      if (logits[i] < minLogit) {
        minLogit = logits[i];
      }
      total += logits[i];
    }
    const isProbability = minLogit >= 0 && maxLogit <= 1 && Math.abs(total - 1) < 0.05;
    let sum = 0;
    const exps = new Float32Array(logits.length);
    for (let i = 0; i < logits.length; i++) {
      exps[i] = isProbability ? logits[i] : Math.exp(logits[i] - maxLogit);
      sum += exps[i];
    }
    const picked: Candidate[] = [];
    const used: boolean[] = new Array<boolean>(logits.length).fill(false);
    for (let k = 0; k < 5; k++) {
      let bestIdx = -1;
      let bestVal = -Infinity;
      for (let i = offset; i < logits.length; i++) {
        if (!used[i] && exps[i] > bestVal) {
          bestVal = exps[i];
          bestIdx = i;
        }
      }
      if (bestIdx < 0) {
        break;
      }
      used[bestIdx] = true;
      const labelIdx = bestIdx - offset;
      if (labelIdx >= 0 && labelIdx < LocalModelService.labels.length) {
        picked.push({
          label: LocalModelService.labels[labelIdx],
          score: exps[bestIdx] / sum
        });
      }
    }
    hilog.info(0x0001, TAG, `top5: ${JSON.stringify(picked)}`);
    return picked;
  }
}
