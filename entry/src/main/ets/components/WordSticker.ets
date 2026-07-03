import { WordCard } from '../model/WordCard';
import { Theme, categoryOf } from '../common/Theme';

/** 贴纸字：白描边深藏青粗体（用多向白色 textShadow 模拟描边） */
export function stickerTextShadows(): ShadowOptions[] {
  const s: ShadowOptions[] = [];
  const offsets: number[][] = [[-2, 0], [2, 0], [0, -2], [0, 2], [-1, -1], [1, -1], [-1, 1], [1, 1]];
  for (const o of offsets) {
    s.push({
      radius: 2,
      color: '#FFFFFF',
      offsetX: o[0],
      offsetY: o[1]
    });
  }
  return s;
}

/**
 * 单词贴纸 — CapWords 统一视觉符号：
 * 抠图 PNG 已在落盘时烘焙白描边，这里直接展示 + 柔投影；
 * 无实拍图时降级为白底圆角贴纸上的 emoji。
 * 词标签是白描边贴纸字，微微叠在贴纸下缘。
 */
@ComponentV2
export struct WordSticker {
  @Require @Param card: WordCard;
  @Param stickerSize: number = 96;
  @Param showWord: boolean = true;

  build() {
    Column() {
      if (this.card.imageUri !== '') {
        Image(this.card.imageUri)
          .width(this.stickerSize)
          .height(this.stickerSize)
          .objectFit(ImageFit.Contain)
          .shadow({
            radius: 10,
            color: Theme.SHADOW,
            offsetX: 0,
            offsetY: 4
          })
      } else {
        Text(this.card.emoji)
          .fontSize(this.stickerSize * 0.5)
          .width(this.stickerSize * 0.82)
          .height(this.stickerSize * 0.82)
          .textAlign(TextAlign.Center)
          .backgroundColor(categoryOf(this.card.category).bg)
          .borderRadius(this.stickerSize * 0.2)
          .borderWidth(Math.max(3, this.stickerSize * 0.045))
          .borderColor(Theme.STICKER_BORDER)
          .shadow({
            radius: 10,
            color: Theme.SHADOW,
            offsetX: 0,
            offsetY: 4
          })
      }

      if (this.showWord) {
        Text(this.card.word)
          .fontSize(Math.max(13, this.stickerSize * 0.17))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .textShadow(stickerTextShadows())
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .width(this.stickerSize * 1.2)
          .margin({ top: -Math.max(6, this.stickerSize * 0.08) })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }
}
