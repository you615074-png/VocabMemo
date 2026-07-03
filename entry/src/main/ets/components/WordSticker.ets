import { WordCard } from '../model/WordCard';
import { Theme, categoryOf } from '../common/Theme';

/**
 * 单词贴纸 — 全产品统一的核心视觉符号：
 * 白边 + 微投影 + 微圆角，自带「可触摸、可收集」的心理暗示。
 */
@ComponentV2
export struct WordSticker {
  @Require @Param card: WordCard;
  @Param stickerSize: number = 96;
  @Param showWord: boolean = true;

  build() {
    Column({ space: 4 }) {
      Stack() {
        if (this.card.imageUri !== '') {
          // 抠图贴纸是透明 PNG，Contain 完整呈现主体轮廓
          Image(this.card.imageUri)
            .width('92%')
            .height('92%')
            .objectFit(ImageFit.Contain)
            .borderRadius(Theme.RADIUS_STICKER)
        } else {
          Text(this.card.emoji)
            .fontSize(this.stickerSize * 0.44)
        }
      }
      .width(this.stickerSize)
      .height(this.stickerSize)
      .backgroundColor(categoryOf(this.card.category).bg)
      .borderRadius(Theme.RADIUS_STICKER)

      if (this.showWord) {
        Text(this.card.word)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(this.stickerSize)
          .textAlign(TextAlign.Center)
      }
    }
    .padding(6)
    .backgroundColor(Theme.STICKER_BORDER)
    .borderRadius(Theme.RADIUS_STICKER + 6)
    .shadow({
      radius: 12,
      color: Theme.SHADOW,
      offsetX: 0,
      offsetY: 4
    })
  }
}
