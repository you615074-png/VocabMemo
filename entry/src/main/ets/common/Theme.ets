/**
 * 全局视觉常量 — 继承 CapWords「低饱和、柔性质感」的色彩体系
 * 基底：米白/暖灰；卡片：低饱和马卡龙色系；投影：软阴影
 */
export class Theme {
  /** 页面基底色（米白） */
  static readonly BG: string = '#F7F4EE';
  /** 次级底色（浅麻灰） */
  static readonly BG_SUB: string = '#EFEAE2';
  /** 主文字色（暖深棕灰） */
  static readonly TEXT: string = '#4A3E36';
  /** 次级文字色 */
  static readonly TEXT_SUB: string = '#9A8F84';
  /** 品牌主色（低饱和暖橙） */
  static readonly PRIMARY: string = '#E8A87C';
  /** 品牌主色-深 */
  static readonly PRIMARY_DEEP: string = '#D18B5C';
  /** 轨迹线颜色 */
  static readonly TRACK: string = '#C9B8A3';
  /** 贴纸白边 */
  static readonly STICKER_BORDER: string = '#FFFFFF';
  /** 软阴影色 */
  static readonly SHADOW: string = '#33786450';
  /** 卡片圆角 */
  static readonly RADIUS_CARD: number = 16;
  /** 贴纸圆角 */
  static readonly RADIUS_STICKER: number = 12;
}

/** 词汇场景分类信息（决定卡片马卡龙底色） */
export interface CategoryStyle {
  key: string;
  label: string;
  /** 卡片背景色 */
  bg: string;
  /** 强调色 */
  accent: string;
}

const CATEGORY_LIST: CategoryStyle[] = [
  { key: 'food', label: '餐饮', bg: '#FBE8D8', accent: '#E09B5F' },
  { key: 'nature', label: '自然', bg: '#E3EEDD', accent: '#8BAE7C' },
  { key: 'object', label: '物品', bg: '#DEEAF2', accent: '#7FA6BF' },
  { key: 'place', label: '场所', bg: '#EAE2F2', accent: '#A48BC4' },
  { key: 'animal', label: '动物', bg: '#F7E0E4', accent: '#CE8B98' }
];

export function categoryOf(key: string): CategoryStyle {
  for (const c of CATEGORY_LIST) {
    if (c.key === key) {
      return c;
    }
  }
  return CATEGORY_LIST[2];
}
