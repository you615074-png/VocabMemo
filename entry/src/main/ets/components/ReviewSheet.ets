import { WordCard } from '../model/WordCard';
import { Theme, categoryOf } from '../common/Theme';
import { DataStore } from '../services/DataStore';

/**
 * 复习翻卡 — 延续 CapWords 实体卡片隐喻：
 * 左右滑动切换相邻单词，点击卡片翻面看释义，操作零学习成本。
 */
@ComponentV2
struct ReviewCard {
  @Require @Param card: WordCard;
  @Local showBack: boolean = false;

  build() {
    Column({ space: 12 }) {
      if (!this.showBack) {
        Text(this.card.emoji)
          .fontSize(64)
        Text(this.card.word)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
        Text(this.card.phonetic)
          .fontSize(14)
          .fontColor(Theme.TEXT_SUB)
        Text('点击卡片查看释义')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 16 })
      } else {
        Text(this.card.translation)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
        Text(this.card.example)
          .fontSize(14)
          .fontColor(Theme.TEXT)
          .opacity(0.85)
          .textAlign(TextAlign.Center)
        Text(this.card.exampleCn)
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
          .textAlign(TextAlign.Center)
        Button(this.card.mastered ? '已掌握 ✓' : '这个词我掌握了')
          .fontSize(13)
          .fontColor(this.card.mastered ? Color.White : Theme.TEXT)
          .backgroundColor(this.card.mastered ? categoryOf(this.card.category).accent : Theme.BG)
          .margin({ top: 10 })
          .onClick(() => {
            DataStore.get().toggleMastered(this.card.id);
          })
      }
    }
    .width('82%')
    .height(300)
    .justifyContent(FlexAlign.Center)
    .padding(20)
    .backgroundColor(categoryOf(this.card.category).bg)
    .borderRadius(Theme.RADIUS_CARD)
    .borderWidth(6)
    .borderColor(Color.White)
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
    Column({ space: 14 }) {
      Text('复习今日单词')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .margin({ top: 18 })

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
      .indicator(
        new DotIndicator()
          .color(Theme.BG_SUB)
          .selectedColor(Theme.PRIMARY)
      )
      .loop(false)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .height(340)

      Text(`${this.currentIndex + 1} / ${this.words.length}`)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .margin({ bottom: 20 })
    }
    .width('100%')
    .backgroundColor(Theme.BG)
  }
}
