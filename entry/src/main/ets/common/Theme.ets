/**
 * 全局视觉常量 — 1:1 对齐 CapWords 视觉体系：
 * 暖白点阵纸基底 + 深藏青文字 + 紫色强调 + 橙色关键词高亮 + 马卡龙日卡。
 */
export class Theme {
  /** 页面基底色（暖白纸） */
  static readonly BG: string = '#F2F1EE';
  /** 点阵颜色 */
  static readonly DOT: string = '#DDDAD4';
  /** 次级底色（浅灰卡） */
  static readonly BG_SUB: string = '#E9E7E2';
  /** 主文字色（深藏青） */
  static readonly TEXT: string = '#2C3A4A';
  /** 次级文字色 */
  static readonly TEXT_SUB: string = '#9C9A94';
  /** 强调紫（确认勾 / 链接 / 进度） */
  static readonly ACCENT: string = '#8B7CF6';
  /** 例句关键词橙 */
  static readonly HIGHLIGHT: string = '#E8833A';
  /** 兼容旧组件的主色引用（暖橙 → 强调紫过渡期保留） */
  static readonly PRIMARY: string = '#8B7CF6';
  /** 遗留：旧日记/轨迹页仍引用（已不挂导航） */
  static readonly PRIMARY_DEEP: string = '#7A6BE0';
  static readonly TRACK: string = '#C9B8A3';
  /** 贴纸白边 */
  static readonly STICKER_BORDER: string = '#FFFFFF';
  /** 软阴影色 */
  static readonly SHADOW: string = '#26404040';
  /** 卡片圆角 */
  static readonly RADIUS_CARD: number = 20;
  /** 贴纸圆角 */
  static readonly RADIUS_STICKER: number = 12;
  /** 贴纸后的暖黄光晕 */
  static readonly GLOW: string = '#F5E9C8';
}

/** 月份页日卡的马卡龙底色（按日期轮换） */
export const DAY_CARD_COLORS: string[] = ['#D2A3A9', '#B7B1DB', '#ABB18D', '#D8C48E'];

/** 词汇场景分类信息（emoji 贴纸底色等弱化场景仍在用） */
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

/** 中文日期，如「7月 3日」（月份页/相机页顶部的衬线体日期） */
export function cnDate(dateKey: string): string {
  const parts = dateKey.split('-');
  if (parts.length < 3) {
    return dateKey;
  }
  return `${Number(parts[1])}月 ${Number(parts[2])}日`;
}

/** 中文月份，如「7月」 */
export function cnMonth(dateKey: string): string {
  const parts = dateKey.split('-');
  if (parts.length < 2) {
    return dateKey;
  }
  return `${Number(parts[1])}月`;
}
