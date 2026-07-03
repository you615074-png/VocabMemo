import { WordCard } from '../model/WordCard';

/**
 * 日记生成服务 — 把一天收集的单词贴纸聚合成一段轻量叙事文本。
 * 日记是识词行为的自然副产品：哪怕只拍了一个词，也能生成完整的当日记录。
 */
interface Slot {
  label: string;
  fromHour: number;
  toHour: number;
}

const SLOTS: Slot[] = [
  { label: '清晨', fromHour: 5, toHour: 9 },
  { label: '上午', fromHour: 9, toHour: 12 },
  { label: '中午', fromHour: 12, toHour: 14 },
  { label: '下午', fromHour: 14, toHour: 18 },
  { label: '傍晚', fromHour: 18, toHour: 21 },
  { label: '夜晚', fromHour: 21, toHour: 24 },
  { label: '深夜', fromHour: 0, toHour: 5 }
];

const OPENINGS: string[] = [
  '今天的目光落在了这些小东西上。',
  '又是收集了一小把词的一天。',
  '生活的注脚，藏在这些随手一拍里。'
];

function slotOf(timestamp: number): string {
  const hour = new Date(timestamp).getHours();
  for (const s of SLOTS) {
    if (hour >= s.fromHour && hour < s.toHour) {
      return s.label;
    }
  }
  return '某个时刻';
}

/** 日记中的一个叙事片段（供 UI 内嵌贴纸缩略图） */
export interface DiarySegment {
  text: string;
  /** 该片段对应的单词卡；开头/结尾等无卡片段为 null */
  card: WordCard | null;
}

export class DiaryService {
  /** 生成分段日记：每个识词動作一句话，句中单词由 UI 高亮并可点开详情 */
  static generateSegments(words: WordCard[], dateLabel: string): DiarySegment[] {
    const segments: DiarySegment[] = [];
    if (words.length === 0) {
      segments.push({ text: '今天还没有收集到单词。出门走走，对准一个让你好奇的东西拍一张吧。', card: null });
      return segments;
    }
    const sorted = words.slice(0).sort((a: WordCard, b: WordCard) => a.timestamp - b.timestamp);
    const openIdx = sorted[0].timestamp % OPENINGS.length;
    segments.push({ text: OPENINGS[openIdx], card: null });

    let lastSlot = '';
    for (const w of sorted) {
      const slot = slotOf(w.timestamp);
      const prefix = slot === lastSlot ? '随后' : `${slot}在${w.place}`;
      lastSlot = slot;
      segments.push({
        text: `${prefix}，你注意到了「${w.translation}」——`,
        card: w
      });
    }

    const count = words.length;
    segments.push({
      text: `这一天（${dateLabel}）一共收下了 ${count} 张单词贴纸。它们不催你背，只是替你记得。`,
      card: null
    });
    return segments;
  }
}
