import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WordCard } from '../model/WordCard';
import { DICTIONARY, DictEntry } from './Dictionary';
import { SegmentationService } from './SegmentationService';
import { CloudRecognitionService, CloudResult } from './CloudRecognitionService';
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

/**
 * 识别结果 — 诚实原则：card 为 null 即识别失败，failReason 告知原因；
 * 绝不用随机词条冒充识别结果。
 */
export interface RecognitionResult {
  card: WordCard | null;
  /** 端侧模型不确定时的备选词（用户点选换词） */
  alternates: DictEntry[];
  /** 识别失败原因（card 为 null 时非空） */
  failReason: string;
  /** 抠图贴纸 uri（即使出词失败也保留，供手动补词时展示） */
  stickerUri: string;
}

/**
 * 识别流水线 — 对齐 CapWords 原版架构：
 *   拍照/选图 → ① 端侧主体抠图（透明贴纸落盘）
 *             → ② 出词：云端视觉大模型（主力，喂抠图主体）
 *                      → 端侧离线模型（无 Key/无网降级，同样喂抠图）
 *                      → 端侧粗分类（objectDetection）
 *                      → 失败态（提示原因，用户可手动选词/输词）
 */
export class RecognitionService {
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

    // ② 出词级联 — 每级都喂抠图后的主体，失败原因逐级累积
    const reasons: string[] = [];

    let result: RecognitionResult | null = await RecognitionService.byCloud(sticker, apiKey, reasons);
    if (result === null) {
      result = await RecognitionService.byLocalModel(sticker, context, reasons);
    }
    if (result === null) {
      result = await RecognitionService.byDevice(sticker, reasons);
    }
    if (result === null) {
      // 诚实失败：不编造词条，把原因告诉用户
      hilog.warn(0x0001, TAG, `all engines failed: ${reasons.join(' / ')}`);
      return {
        card: null,
        alternates: [],
        failReason: reasons.join('；'),
        stickerUri: stickerUri
      };
    }

    if (result.card !== null) {
      result.card.id = id;
      result.card.imageUri = stickerUri;
      result.card.timestamp = Date.now();
      result.card.place = RecognitionService.mockPlace();
    }
    result.stickerUri = stickerUri;
    return result;
  }

  /** 手动选词/纠错时从词条组卡（贴纸 uri 由调用方补） */
  static cardFromEntry(entry: DictEntry, source: string): WordCard {
    const card = RecognitionService.fromEntry(entry);
    card.source = source;
    card.id = `${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    card.timestamp = Date.now();
    card.place = RecognitionService.mockPlace();
    return card;
  }

  private static async byCloud(subject: image.PixelMap, apiKey: string,
    reasons: string[]): Promise<RecognitionResult | null> {
    if (apiKey === '') {
      reasons.push('未配置云端 Key');
      return null;
    }
    try {
      const base64 = await ImageUtil.toBase64Jpeg(subject, 1024);
      const r: CloudResult = await CloudRecognitionService.recognize(base64, apiKey);
      if (r.word === null) {
        reasons.push(r.failReason);
        return null;
      }
      const card = new WordCard();
      card.word = r.word.word.toLowerCase();
      card.translation = r.word.translation;
      card.phonetic = r.word.phonetic;
      card.examples = r.word.examples;
      card.examplesCn = r.word.examplesCn;
      card.example = r.word.examples.length > 0 ? r.word.examples[0] : '';
      card.exampleCn = r.word.examplesCn.length > 0 ? r.word.examplesCn[0] : '';
      card.category = VALID_CATEGORIES.includes(r.word.category) ? r.word.category : 'object';
      card.emoji = CATEGORY_EMOJI[VALID_CATEGORIES.indexOf(card.category)];
      card.source = 'cloud';
      return { card: card, alternates: [], failReason: '', stickerUri: '' };
    } catch (e) {
      hilog.warn(0x0001, TAG, `cloud path failed: ${JSON.stringify(e)}`);
      reasons.push('云端识别异常');
      return null;
    }
  }

  /** 端侧离线模型：top-5 类别映射到词库，第一个作主词，其余作候选 */
  private static async byLocalModel(subject: image.PixelMap,
    context: common.UIAbilityContext, reasons: string[]): Promise<RecognitionResult | null> {
    const candidates: Candidate[] = await LocalModelService.classify(subject, context);
    if (candidates.length === 0) {
      reasons.push(LocalModelService.isUnavailable() ? '端侧模型在当前设备不可用' : '端侧模型推理失败');
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
      reasons.push('未能识别出词库内的物体');
      return null;
    }
    const card = RecognitionService.fromEntry(entries[0]);
    card.source = 'local';
    return { card: card, alternates: entries.slice(1, 4), failReason: '', stickerUri: '' };
  }

  private static async byDevice(subject: image.PixelMap, reasons: string[]): Promise<RecognitionResult | null> {
    const entry = await DeviceRecognitionService.recognize(subject);
    if (entry === null) {
      reasons.push('端侧粗分类无结果');
      return null;
    }
    const card = RecognitionService.fromEntry(entry);
    card.source = 'device';
    return { card: card, alternates: [], failReason: '', stickerUri: '' };
  }

  private static fromEntry(entry: DictEntry): WordCard {
    const card = new WordCard();
    card.word = entry.word;
    card.translation = entry.translation;
    card.phonetic = entry.phonetic;
    card.example = entry.example;
    card.exampleCn = entry.exampleCn;
    card.examples = entry.example === '' ? [] : [entry.example];
    card.examplesCn = entry.exampleCn === '' ? [] : [entry.exampleCn];
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

/** 词库模糊搜索：手动纠错时给候选（词首匹配优先，其次包含、译文包含） */
export function searchDict(query: string): DictEntry[] {
  const q = query.trim().toLowerCase();
  if (q === '') {
    return [];
  }
  const starts: DictEntry[] = [];
  const contains: DictEntry[] = [];
  for (const e of DICTIONARY) {
    if (e.word.startsWith(q)) {
      starts.push(e);
    } else if (e.word.includes(q) || e.translation.includes(query.trim())) {
      contains.push(e);
    }
  }
  return starts.concat(contains).slice(0, 8);
}
