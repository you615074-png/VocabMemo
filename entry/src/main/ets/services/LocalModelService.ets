import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'LocalModelService';
const MODEL_FILE = 'mobilenetv2.ms';
const LABEL_FILE = 'imagenet_labels.txt';
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
 * 完全离线、免 Key、免联网；模型 13MB 打包在 rawfile。
 * 模型懒加载并常驻，单次推理在手机上约几十毫秒。
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

  /**
   * 分类照片，返回按置信度排序的 top-5 候选。
   * 注意：会就地把 PixelMap 缩放到 224×224，须在抠图之后调用。
   */
  static async classify(pm: image.PixelMap, context: common.UIAbilityContext): Promise<Candidate[]> {
    const ok = await LocalModelService.ensureLoaded(context);
    if (!ok || LocalModelService.model === null) {
      return [];
    }
    try {
      const input = await LocalModelService.preprocess(pm);
      const tensors = LocalModelService.model.getInputs();
      tensors[0].setData(input.buffer as ArrayBuffer);
      const outputs = await LocalModelService.model.predict(tensors);
      const logits = new Float32Array(outputs[0].getData());
      return LocalModelService.top5(logits);
    } catch (e) {
      hilog.error(0x0001, TAG, `inference failed: ${JSON.stringify(e)}`);
      return [];
    }
  }

  /** RGBA PixelMap → NHWC float32(1×224×224×3)，ImageNet 归一化 */
  private static async preprocess(pm: image.PixelMap): Promise<Float32Array> {
    const info = await pm.getImageInfo();
    if (info.size.width !== INPUT_EDGE || info.size.height !== INPUT_EDGE) {
      await pm.scale(INPUT_EDGE / info.size.width, INPUT_EDGE / info.size.height);
    }
    const rgbaBuf = new ArrayBuffer(INPUT_EDGE * INPUT_EDGE * 4);
    await pm.readPixelsToBuffer(rgbaBuf);
    const rgba = new Uint8Array(rgbaBuf);
    const floats = new Float32Array(INPUT_EDGE * INPUT_EDGE * 3);
    const pixels = INPUT_EDGE * INPUT_EDGE;
    for (let i = 0; i < pixels; i++) {
      floats[i * 3] = (rgba[i * 4] - MEANS[0]) / STDS[0];
      floats[i * 3 + 1] = (rgba[i * 4 + 1] - MEANS[1]) / STDS[1];
      floats[i * 3 + 2] = (rgba[i * 4 + 2] - MEANS[2]) / STDS[2];
    }
    return floats;
  }

  private static top5(logits: Float32Array): Candidate[] {
    // 输出可能是 1000 或 1001（带 background），对齐标签表
    const offset = logits.length - LocalModelService.labels.length;
    // softmax 得到置信度
    let maxLogit = -Infinity;
    for (let i = 0; i < logits.length; i++) {
      if (logits[i] > maxLogit) {
        maxLogit = logits[i];
      }
    }
    let sum = 0;
    const exps = new Float32Array(logits.length);
    for (let i = 0; i < logits.length; i++) {
      exps[i] = Math.exp(logits[i] - maxLogit);
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
