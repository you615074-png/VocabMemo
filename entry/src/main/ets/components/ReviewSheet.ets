import { WordCard } from '../model/WordCard';
import { Theme } from '../common/Theme';
import { DataStore } from '../services/DataStore';
import { TtsService } from './../services/TtsService';
import { ExampleList } from './ExampleList';

/**
 * 复习翻卡 — 对齐 CapWords 复习页：
 * 顶部进度胶囊，白色大卡（音标在上、大词居中、分隔线、译文），
 * 点击翻面看译文与例句，左右滑动切换。
 */
@ComponentV2
struct ReviewCard {
  @Require @Param card: WordCard;
  @Local showBack: boolean = false;

  build() {
    Column() {
      if (!this.showBack) {
        Row({ space: 6 }) {
          Text(this.card.phonetic)
            .fontSize(14)
            .fontColor(Theme.TEXT_SUB)
          Text('🔊')
            .fontSize(14)
            .onClick(() => {
              TtsService.speak(this.card.word);
            })
        }
        .width('100%')

        Blank()
        Text(this.card.word)
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .width('100%')
        Blank()

        Divider()
          .color('#E5E2DC')
          .strokeWidth(1)
        Text('点击卡片翻面')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 12 })
      } else {
        Text(this.card.translation)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .width('100%')
        Divider()
          .color('#E5E2DC')
          .strokeWidth(1)
          .margin({ top: 14, bottom: 14 })
        Scroll() {
          ExampleList({ card: this.card })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Text(this.card.mastered ? '已掌握 ✓' : '这个词我掌握了')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.card.mastered ? Color.White : Theme.TEXT)
          .padding({
            left: 20,
            right: 20,
            top: 9,
            bottom: 9
          })
          .backgroundColor(this.card.mastered ? Theme.ACCENT : Theme.BG_SUB)
          .borderRadius(18)
          .alignSelf(ItemAlign.Center)
          .margin({ top: 10 })
          .onClick(() => {
            DataStore.get().toggleMastered(this.card.id);
          })
      }
    }
    .width('84%')
    .height(330)
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({
      radius: 16,
      color: Theme.SHADOW,
      offsetX: 0,
      offsetY: 6
    })
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
        this.showBack = !this.showBack;
      });
    })
  }
}

@ComponentV2
export struct ReviewSheet {
  @Require @Param words: WordCard[];
  @Local currentIndex: number = 0;

  build() {
    Column({ space: 16 }) {
      // 进度胶囊
      Text() {
        Span(`${this.currentIndex + 1}`)
          .fontColor(Theme.ACCENT)
          .fontWeight(FontWeight.Bold)
        Span(` / ${this.words.length}`)
          .fontColor(Theme.TEXT_SUB)
      }
      .fontSize(14)
      .padding({
        left: 18,
        right: 18,
        top: 7,
        bottom: 7
      })
      .backgroundColor('#EDEBE6')
      .borderRadius(16)
      .margin({ top: 20 })

      Swiper() {
        ForEach(this.words, (item: WordCard) => {
          Column() {
            ReviewCard({ card: item })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }, (item: WordCard) => item.id)
      }
      .index(this.currentIndex)
      .indicator(false)
      .loop(false)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .height(350)

      Text('点击翻面 · 左右滑动切换')
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
        .margin({ bottom: 20 })
    }
    .width('100%')
    .backgroundColor(Theme.BG)
    .backgroundImage($r('app.media.dot_grid'), ImageRepeat.XY)
  }
}
