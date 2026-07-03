import { Theme } from '../common/Theme';
import { WordCard } from '../model/WordCard';
import { TtsService } from '../services/TtsService';

/** 例句切段：关键词命中段落用橙色渲染 */
interface Seg {
  text: string;
  hit: boolean;
}

function splitByWord(sentence: string, word: string): Seg[] {
  const segs: Seg[] = [];
  if (word === '') {
    return [{ text: sentence, hit: false }];
  }
  const lower = sentence.toLowerCase();
  const key = word.toLowerCase();
  let pos = 0;
  while (pos < sentence.length) {
    const idx = lower.indexOf(key, pos);
    if (idx < 0) {
      segs.push({ text: sentence.substring(pos), hit: false });
      break;
    }
    if (idx > pos) {
      segs.push({ text: sentence.substring(pos, idx), hit: false });
    }
    segs.push({ text: sentence.substring(idx, idx + key.length), hit: true });
    pos = idx + key.length;
  }
  return segs;
}

/**
 * 例句列表 — 对齐 CapWords 例句页：
 * 英文例句中的关键词橙色高亮，每句带发音按钮和中文翻译。
 */
@ComponentV2
export struct ExampleList {
  @Require @Param card: WordCard;

  private pairs(): string[][] {
    const out: string[][] = [];
    for (let i = 0; i < this.card.examples.length; i++) {
      out.push([
        this.card.examples[i],
        i < this.card.examplesCn.length ? this.card.examplesCn[i] : ''
      ]);
    }
    return out;
  }

  build() {
    Column({ space: 18 }) {
      if (this.card.examples.length === 0) {
        Text('这个词还没有例句')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
      }
      ForEach(this.pairs(), (pair: string[]) => {
        Column({ space: 5 }) {
          Row() {
            Text() {
              ForEach(splitByWord(pair[0], this.card.word), (seg: Seg, i: number) => {
                Span(seg.text)
                  .fontColor(seg.hit ? Theme.HIGHLIGHT : Theme.TEXT)
                  .fontWeight(seg.hit ? FontWeight.Bold : FontWeight.Medium)
              }, (seg: Seg, i: number) => `${i}_${seg.text}`)
            }
            .fontSize(16)
            .layoutWeight(1)

            Text('🔊')
              .fontSize(15)
              .padding({ left: 8 })
              .onClick(() => {
                TtsService.speak(pair[0]);
              })
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')

          if (pair[1] !== '') {
            Text(pair[1])
              .fontSize(13)
              .fontColor(Theme.TEXT_SUB)
              .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (pair: string[], i: number) => `${i}_${pair[0]}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
