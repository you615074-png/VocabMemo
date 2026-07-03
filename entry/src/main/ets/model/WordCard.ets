/**
 * 单词贴纸 — 整个产品的最小信息单元
 * 一次识词动作同时完成「单词学习」与「生活打点」：
 * 除词条本身外，静默记录时间戳与模糊地点。
 */
@ObservedV2
export class WordCard {
  id: string = '';
  word: string = '';
  translation: string = '';
  phonetic: string = '';
  example: string = '';
  exampleCn: string = '';
  /** 例句列表（云端返回 3 条；example/exampleCn 恒为第一条，兼容旧视图） */
  examples: string[] = [];
  examplesCn: string[] = [];
  /** 场景分类 key，见 Theme.categoryOf */
  category: string = 'object';
  /** 贴纸占位图形（相机路径无实拍图时展示） */
  emoji: string = '📦';
  /** 相册路径拍摄的原图 uri，相机路径为空 */
  imageUri: string = '';
  /** 收集时间（毫秒时间戳） */
  timestamp: number = 0;
  /** 模糊地点标签（默认不记录精确坐标，隐私可感知） */
  place: string = '';
  /** 复习中是否已标记掌握 */
  @Trace mastered: boolean = false;
  /** 词条来源：cloud=云端大模型 / device=端侧粗识别 / mock=演示词库 */
  source: string = '';
}

/** preferences 持久化用的纯数据形态 */
export interface WordData {
  id: string;
  word: string;
  translation: string;
  phonetic: string;
  example: string;
  exampleCn: string;
  examples?: string[];
  examplesCn?: string[];
  category: string;
  emoji: string;
  imageUri: string;
  timestamp: number;
  place: string;
  mastered: boolean;
  source?: string;
}

export function toData(c: WordCard): WordData {
  return {
    id: c.id,
    word: c.word,
    translation: c.translation,
    phonetic: c.phonetic,
    example: c.example,
    exampleCn: c.exampleCn,
    examples: c.examples,
    examplesCn: c.examplesCn,
    category: c.category,
    emoji: c.emoji,
    imageUri: c.imageUri,
    timestamp: c.timestamp,
    place: c.place,
    mastered: c.mastered,
    source: c.source
  };
}

export function fromData(d: WordData): WordCard {
  const c = new WordCard();
  c.id = d.id;
  c.word = d.word;
  c.translation = d.translation;
  c.phonetic = d.phonetic;
  c.example = d.example;
  c.exampleCn = d.exampleCn;
  // 旧数据没有例句数组时，用单条例句补齐
  c.examples = d.examples === undefined ? (d.example === '' ? [] : [d.example]) : d.examples;
  c.examplesCn = d.examplesCn === undefined ? (d.exampleCn === '' ? [] : [d.exampleCn]) : d.examplesCn;
  c.category = d.category;
  c.emoji = d.emoji;
  c.imageUri = d.imageUri;
  c.timestamp = d.timestamp;
  c.place = d.place;
  c.mastered = d.mastered;
  c.source = d.source === undefined ? '' : d.source;
  return c;
}

/** 以本地时区把时间戳转成 YYYY-MM-DD，作为日记归档维度 */
export function dateKeyOf(timestamp: number): string {
  const d = new Date(timestamp);
  const m = d.getMonth() + 1;
  const day = d.getDate();
  const mm = m < 10 ? `0${m}` : `${m}`;
  const dd = day < 10 ? `0${day}` : `${day}`;
  return `${d.getFullYear()}-${mm}-${dd}`;
}

export function todayKey(): string {
  return dateKeyOf(Date.now());
}
