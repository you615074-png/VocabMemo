import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WordCard } from '../model/WordCard';
import { DICTIONARY, DictEntry } from './Dictionary';
import { SegmentationService } from './SegmentationService';
import { CloudRecognitionService, CloudWord } from './CloudRecognitionService';
import { DeviceRecognitionService } from './DeviceRecognitionService';
import { ImageUtil } from './ImageUtil';

const TAG = 'RecognitionService';

const MOCK_PLACES_MORNING: string[] = ['家附近', '早餐铺子旁', '小区花园'];
const MOCK_PLACES_DAY: string[] = ['街角咖啡店', '公司楼下', '公园长椅边', '书店门口'];
const MOCK_PLACES_EVENING: string[] = ['傍晚的江边', '夜市入口', '回家的路上'];

const VALID_CATEGORIES: string[] = ['food', 'nature', 'object', 'place', 'animal'];
const CATEGORY_EMOJI: string[] = ['🍽️', '🌿', '📦', '📍', '🐾'];

/**
 * 识别流水线 — 与 CapWords 相同的体验链路：
 *   拍照/选图(PixelMap)
 *     → ① 端侧主体抠图，生成透明贴纸并落盘（Core Vision Kit）
 *     → ② 单词识别，三级降级：
 *          云端视觉大模型（配了 API Key，词最准）
 *          → 端侧粗分类（objectDetection，离线可用）
 *          → 内置词库随机（演示模式）
 * 照片仅本机处理，云端一次性识别后即弃。
 */
export class RecognitionService {
  private static lastIndex: number = -1;

  /**
   * 完整识别：抠图 + 出词。耗时 1~5 秒，UI 层应展示等待动效。
   */
  static async recognizePhoto(photo: image.PixelMap, context: common.UIAbilityContext,
    apiKey: string): Promise<WordCard> {
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

    // ② 出词：云端 → 端侧 → 词库
    let card: WordCard | null = null;
    if (apiKey !== '') {
      card = await RecognitionService.byCloud(photo, apiKey);
    }
    if (card === null) {
      card = await RecognitionService.byDevice(photo);
    }
    if (card === null) {
      card = RecognitionService.byMock();
    }

    card.id = id;
    card.imageUri = stickerUri;
    card.timestamp = Date.now();
    card.place = RecognitionService.mockPlace();
    return card;
  }

  /** 无照片可用时的纯演示识别（相机降级模式） */
  static recognizeMock(): WordCard {
    const card = RecognitionService.byMock();
    card.id = `${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    card.timestamp = Date.now();
    card.place = RecognitionService.mockPlace();
    return card;
  }

  private static async byCloud(photo: image.PixelMap, apiKey: string): Promise<WordCard | null> {
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
      return card;
    } catch (e) {
      hilog.warn(0x0001, TAG, `cloud path failed: ${JSON.stringify(e)}`);
      return null;
    }
  }

  private static async byDevice(photo: image.PixelMap): Promise<WordCard | null> {
    const entry = await DeviceRecognitionService.recognize(photo);
    if (entry === null) {
      return null;
    }
    const card = RecognitionService.fromEntry(entry);
    card.source = 'device';
    return card;
  }

  private static byMock(): WordCard {
    let idx = Math.floor(Math.random() * DICTIONARY.length);
    if (idx === RecognitionService.lastIndex) {
      idx = (idx + 1) % DICTIONARY.length;
    }
    RecognitionService.lastIndex = idx;
    const card = RecognitionService.fromEntry(DICTIONARY[idx]);
    card.source = 'mock';
    return card;
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
