import { WordCard } from '../model/WordCard';
import { Theme, categoryOf } from '../common/Theme';
import { WordSticker } from './WordSticker';
import { DataStore } from '../services/DataStore';

/**
 * 贴纸详情 — 以半屏卡形式从当前场景上拉呈现（上下文唤起，不做全屏跳转）。
 * 发音/掌握/删除等次级功能全部内嵌于此，随用随唤。
 */
@ComponentV2
export struct StickerDetail {
  @Require @Param card: WordCard;
  /** 删除后由宿主关闭弹层 */
  @Event onDeleted: () => void = () => {
  };
  /** 发音按钮的波纹反馈 */
  @Local rippleScale: number = 1;
  @Local rippleOpacity: number = 0;

  private playRipple(): void {
    // 正式版接入 Core Speech Kit textToSpeech；此处保留波纹微反馈动效
    this.rippleScale = 1;
    this.rippleOpacity = 0.5;
    this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
      this.rippleScale = 2.2;
      this.rippleOpacity = 0;
    });
  }

  build() {
    Column({ space: 16 }) {
      WordSticker({ card: this.card, stickerSize: 120, showWord: false })

      Row({ space: 10 }) {
        Text(this.card.word)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)

        Stack() {
          Circle()
            .width(36)
            .height(36)
            .fill(categoryOf(this.card.category).accent)
            .opacity(this.rippleOpacity)
            .scale({ x: this.rippleScale, y: this.rippleScale })
          Text('🔊')
            .fontSize(18)
        }
        .width(36)
        .height(36)
        .onClick(() => {
          this.playRipple();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text(this.card.phonetic)
        .fontSize(15)
        .fontColor(Theme.TEXT_SUB)

      Text(this.card.translation)
        .fontSize(18)
        .fontColor(Theme.TEXT)

      Column({ space: 6 }) {
        Text(this.card.example)
          .fontSize(14)
          .fontColor(Theme.TEXT)
          .opacity(0.85)
        Text(this.card.exampleCn)
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')
      .padding(14)
      .backgroundColor(categoryOf(this.card.category).bg)
      .borderRadius(Theme.RADIUS_CARD)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        Button(this.card.mastered ? '已掌握 ✓' : '标记掌握')
          .fontSize(14)
          .fontColor(this.card.mastered ? Color.White : Theme.TEXT)
          .backgroundColor(this.card.mastered ? categoryOf(this.card.category).accent : Theme.BG_SUB)
          .onClick(() => {
            DataStore.get().toggleMastered(this.card.id);
          })

        Button('删除')
          .fontSize(14)
          .fontColor(Theme.TEXT_SUB)
          .backgroundColor(Theme.BG_SUB)
          .onClick(() => {
            DataStore.get().removeWord(this.card.id);
            this.onDeleted();
          })
      }
      .margin({ top: 4 })
    }
    .width('100%')
    .padding({
      left: 24,
      right: 24,
      top: 20,
      bottom: 32
    })
    .alignItems(HorizontalAlign.Center)
  }
}
