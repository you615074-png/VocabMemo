import { WordCard } from '../model/WordCard';
import { Theme } from '../common/Theme';
import { WordSticker } from './WordSticker';
import { ExampleList } from './ExampleList';
import { DataStore } from '../services/DataStore';
import { TtsService } from '../services/TtsService';

/**
 * 词卡详情 — 对齐 CapWords 词卡页（半屏卡形态）：
 * 贴纸 + 单词 + 译文 + 音标发音 + 「查看例句」展开；
 * 掌握标记 / 删除收在底部弱化区。
 */
@ComponentV2
export struct StickerDetail {
  @Require @Param card: WordCard;
  /** 删除后由宿主关闭弹层 */
  @Event onDeleted: () => void = () => {
  };
  @Local showExamples: boolean = false;

  aboutToAppear(): void {
    this.showExamples = false;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        WordSticker({ card: this.card, stickerSize: 150, showWord: false })
          .margin({ top: 22 })

        Text(this.card.word)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)

        Text(this.card.translation)
          .fontSize(16)
          .fontColor(Theme.TEXT_SUB)

        Row({ space: 6 }) {
          Text(this.card.phonetic)
            .fontSize(14)
            .fontColor(Theme.TEXT_SUB)
          Text('🔊')
            .fontSize(15)
        }
        .padding({
          left: 12,
          right: 12,
          top: 6,
          bottom: 6
        })
        .backgroundColor(Color.White)
        .borderRadius(14)
        .onClick(() => {
          TtsService.speak(this.card.word);
        })

        if (!this.showExamples) {
          Text('💡 查看例句')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.ACCENT)
            .padding({
              left: 26,
              right: 26,
              top: 11,
              bottom: 11
            })
            .backgroundColor(Color.White)
            .borderRadius(24)
            .shadow({
              radius: 8,
              color: Theme.SHADOW,
              offsetX: 0,
              offsetY: 3
            })
            .margin({ top: 8 })
            .onClick(() => {
              this.showExamples = true;
            })
        } else {
          Column() {
            ExampleList({ card: this.card })
          }
          .width('88%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(Theme.RADIUS_CARD)
          .margin({ top: 8 })
        }

        Row({ space: 22 }) {
          Text(this.card.mastered ? '已掌握 ✓' : '标记掌握')
            .fontSize(13)
            .fontColor(this.card.mastered ? Theme.ACCENT : Theme.TEXT_SUB)
            .onClick(() => {
              DataStore.get().toggleMastered(this.card.id);
            })
          Text('删除')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .onClick(() => {
              DataStore.get().removeWord(this.card.id);
              this.onDeleted();
            })
        }
        .margin({ top: 10, bottom: 36 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.BG)
    .backgroundImage($r('app.media.dot_grid'), ImageRepeat.XY)
  }
}
