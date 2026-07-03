import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WordCard } from '../model/WordCard';
import { DICTIONARY, DictEntry } from './Dictionary';
import { SegmentationService } from './SegmentationService';
import { CloudRecognitionService, CloudWord } from './CloudRecognitionService';
import { DeviceRecognitionService } from './DeviceRecognitionService';
import { LocalModelService, Candidate } from './LocalModelService';
import { LabelMapper } from './LabelMapper';
import { ImageUtil } from './ImageUtil';

const TAG = 'RecognitionService';

const MOCK_PLACES_MORNING: string[] = ['家附近', '早餐铺子旁', '小区花园'];
const MOCK_PLACES_DAY: string[] = ['街角咖啡店', '公司楼下', '公园长椅边', '书店门口'];
const MOCK_PLACES_EVENING: string[] = ['傍晚的江边', '夜市入口', '回家的路上'];

const VALID_CATEGORIES: string[] = ['food', 'nature', 'object', 'place', 'animal'];
const CATEGORY_EMOJI: string[] = ['🍽️', '🌿', '📦', '📍', '🐾'];

/** 识别结果：主词条 + 可切换的候选词条（方案三交互） */
export interface RecognitionResult {
  card: WordCard;
  alternates: DictEntry[];
}

/**
 * 识别流水线 — 全程可离线：
 *   拍照/选图(PixelMap)
 *     → ① 端侧主体抠图，生成透明贴纸并落盘（Core Vision Kit）
 *     → ② 单词识别，四级降级：
 *          云端视觉大模型（可选增强，配了 API Key 才走）
 *          → 端侧离线模型（MindSpore Lite + MobileNetV2，主力方案）
 *          → 端侧粗分类（objectDetection）
 *          → 内置词库随机（演示兜底）
 * 端侧模型给出 top-5 候选，识别不确定时由用户在候选词中点选。
 */
export class RecognitionService {
  private static lastIndex: number = -1;

  /**
   * 完整识别：抠图 + 出词。耗时 1~5 秒，UI 层应展示等待动效。
   */
  static async recognizePhoto(photo: image.PixelMap, context: common.UIAbilityContext,
    apiKey: string): Promise<RecognitionResult> {
    const id = `${Date.now()}_${Math.floor(Math.random() * 10000)}`;

    // ① 主体抠图 → 透明 PNG 贴纸（失败则整图作贴纸）
    let sticker: image.PixelMap = photo;
    const cutout = await SegmentationService.cutout(photo);
    if (cutout !== null) {
      sticker = cutout;
    }
    let stickerUri = '';
    try {
      stickerUri = await ImageUtil.savePng(sticker, context, `sticker_${id}`);
    } catch (e) {
      hilog.error(0x0001, TAG, `save sticker failed: ${JSON.stringify(e)}`);
    }

    // ② 出词：云端(可选) → 端侧模型 → 端侧粗分类 → 词库
    //    注意顺序依赖：云端会把 photo 缩到 1024，端侧模型再缩到 224，只缩不放
    let result: RecognitionResult | null = null;
    if (apiKey !== '') {
      result = await RecognitionService.byCloud(photo, apiKey);
    }
    if (result === null) {
      result = await RecognitionService.byLocalModel(photo, context);
    }
    if (result === null) {
      result = await RecognitionService.byDevice(photo);
    }
    if (result === null) {
      result = RecognitionService.byMock();
    }

    result.card.id = id;
    result.card.imageUri = stickerUri;
    result.card.timestamp = Date.now();
    result.card.place = RecognitionService.mockPlace();
    return result;
  }

  /** 无照片可用时的纯演示识别（相机降级模式） */
  static recognizeMock(): RecognitionResult {
    const result = RecognitionService.byMock();
    result.card.id = `${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    result.card.timestamp = Date.now();
    result.card.place = RecognitionService.mockPlace();
    return result;
  }

  private static async byCloud(photo: image.PixelMap, apiKey: string): Promise<RecognitionResult | null> {
    try {
      const base64 = await ImageUtil.toBase64Jpeg(photo, 1024);
      const w: CloudWord | null = await CloudRecognitionService.recognize(base64, apiKey);
      if (w === null) {
        return null;
      }
      const card = new WordCard();
      card.word = w.word.toLowerCase();
      card.translation = w.translation;
      card.phonetic = w.phonetic === undefined ? '' : w.phonetic;
      card.example = w.example === undefined ? '' : w.example;
      card.exampleCn = w.exampleCn === undefined ? '' : w.exampleCn;
      card.category = VALID_CATEGORIES.includes(w.category) ? w.category : 'object';
      card.emoji = CATEGORY_EMOJI[VALID_CATEGORIES.indexOf(card.category)];
      card.source = 'cloud';
      return { card: card, alternates: [] };
    } catch (e) {
      hilog.warn(0x0001, TAG, `cloud path failed: ${JSON.stringify(e)}`);
      return null;
    }
  }

  /** 端侧离线模型：top-5 类别映射到词库，第一个作主词，其余作候选 */
  private static async byLocalModel(photo: image.PixelMap,
    context: common.UIAbilityContext): Promise<RecognitionResult | null> {
    const candidates: Candidate[] = await LocalModelService.classify(photo, context);
    if (candidates.length === 0) {
      return null;
    }
    const entries: DictEntry[] = [];
    for (const c of candidates) {
      const entry = LabelMapper.mapLabel(c.label);
      if (entry !== null) {
        let dup = false;
        for (const e of entries) {
          if (e.word === entry.word) {
            dup = true;
            break;
          }
        }
        if (!dup) {
          entries.push(entry);
        }
      }
    }
    if (entries.length === 0) {
      return null;
    }
    const card = RecognitionService.fromEntry(entries[0]);
    card.source = 'local';
    return { card: card, alternates: entries.slice(1, 4) };
  }

  private static async byDevice(photo: image.PixelMap): Promise<RecognitionResult | null> {
    const entry = await DeviceRecognitionService.recognize(photo);
    if (entry === null) {
      return null;
    }
    const card = RecognitionService.fromEntry(entry);
    card.source = 'device';
    return { card: card, alternates: [] };
  }

  private static byMock(): RecognitionResult {
    let idx = Math.floor(Math.random() * DICTIONARY.length);
    if (idx === RecognitionService.lastIndex) {
      idx = (idx + 1) % DICTIONARY.length;
    }
    RecognitionService.lastIndex = idx;
    const card = RecognitionService.fromEntry(DICTIONARY[idx]);
    card.source = 'mock';
    return { card: card, alternates: [] };
  }

  private static fromEntry(entry: DictEntry): WordCard {
    const card = new WordCard();
    card.word = entry.word;
    card.translation = entry.translation;
    card.phonetic = entry.phonetic;
    card.example = entry.example;
    card.exampleCn = entry.exampleCn;
    card.category = entry.category;
    card.emoji = entry.emoji;
    return card;
  }

  private static mockPlace(): string {
    const hour = new Date().getHours();
    let pool: string[] = MOCK_PLACES_DAY;
    if (hour < 10) {
      pool = MOCK_PLACES_MORNING;
    } else if (hour >= 18) {
      pool = MOCK_PLACES_EVENING;
    }
    return pool[Math.floor(Math.random() * pool.length)];
  }
}
