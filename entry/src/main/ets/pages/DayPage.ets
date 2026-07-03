import { Theme, cnDate } from '../common/Theme';
import { WordCard, todayKey } from '../model/WordCard';
import { DataStore } from '../services/DataStore';
import { WordSticker } from '../components/WordSticker';
import { StickerDetail } from '../components/StickerDetail';
import { ReviewSheet } from '../components/ReviewSheet';

/**
 * 当日贴纸墙 — 对齐 CapWords 单日收藏页：
 * 点阵纸背景、日期 + N 个单词、贴纸两列错落排布（词标签为贴纸字）、
 * 底部中央彩色圆环相机按钮回到取景。
 */
@ComponentV2
export struct DayPage {
  @Require @Param stack: NavPathStack;
  store: DataStore = DataStore.get();
  @Local detailCard: WordCard | null = null;
  @Local showDetail: boolean = false;
  @Local showReview: boolean = false;

  private dayWords(): WordCard[] {
    return this.store.wordsOfDate(this.store.selectedDate);
  }

  @Builder
  DetailSheetBuilder() {
    Column() {
      if (this.detailCard !== null) {
        StickerDetail({
          card: this.detailCard,
          onDeleted: () => {
            this.showDetail = false;
          }
        })
      }
    }
  }

  @Builder
  ReviewSheetBuilder() {
    ReviewSheet({ words: this.dayWords() })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // ── 顶栏 ──
          Row() {
            Text('‹')
              .fontSize(26)
              .fontColor(Theme.TEXT)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.stack.pop();
              })
            Blank()
            if (this.dayWords().length > 0) {
              Text('⚡ 复习')
                .fontSize(13)
                .fontColor(Theme.ACCENT)
                .padding({
                  left: 14,
                  right: 14,
                  top: 7,
                  bottom: 7
                })
                .backgroundColor(Color.White)
                .borderRadius(16)
                .shadow({
                  radius: 6,
                  color: Theme.SHADOW,
                  offsetX: 0,
                  offsetY: 2
                })
                .onClick(() => {
                  this.showReview = true;
                })
                .bindSheet(this.showReview, this.ReviewSheetBuilder(), {
                  height: 520,
                  backgroundColor: Theme.BG,
                  onDisappear: () => {
                    this.showReview = false;
                  }
                })
            }
            Text('全部 ›')
              .fontSize(13)
              .fontColor(Theme.TEXT_SUB)
              .padding({
                left: 12,
                right: 12,
                top: 7,
                bottom: 7
              })
              .margin({ left: 8 })
              .onClick(() => {
                this.stack.pushPathByName('month', null);
              })
          }
          .width('100%')
          .padding({ left: 12, right: 16, top: 52 })

          // ── 日期标题 ──
          Column({ space: 2 }) {
            Text(cnDate(this.store.selectedDate))
              .fontSize(30)
              .fontFamily('serif')
              .fontColor(Theme.TEXT)
            Text(`${this.dayWords().length} 个单词`)
              .fontSize(13)
              .fontColor(Theme.TEXT_SUB)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 26, top: 6, bottom: 10 })

          // ── 贴纸墙：两列错落 ──
          if (this.dayWords().length === 0) {
            Column({ space: 10 }) {
              Text('🫙')
                .fontSize(52)
              Text(this.store.selectedDate === todayKey() ? '今天还没收集到单词' : '这一天没有收集单词')
                .fontSize(14)
                .fontColor(Theme.TEXT_SUB)
              Text('对准身边的物体拍一张吧')
                .fontSize(12)
                .fontColor(Theme.TEXT_SUB)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            Scroll() {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(this.dayWords(), (item: WordCard, index: number) => {
                  Column() {
                    WordSticker({ card: item, stickerSize: 132, showWord: true })
                  }
                  .width('50%')
                  .alignItems(HorizontalAlign.Center)
                  .padding({
                    top: index % 2 === 1 ? 44 : 10,
                    bottom: 16
                  })
                  .onClick(() => {
                    this.detailCard = item;
                    this.showDetail = true;
                  })
                }, (item: WordCard) => item.id)
              }
              .width('100%')
              .padding({ bottom: 130 })
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .bindSheet(this.showDetail, this.DetailSheetBuilder(), {
              height: 560,
              backgroundColor: Theme.BG,
              onDisappear: () => {
                this.showDetail = false;
              }
            })
          }
        }
        .width('100%')
        .height('100%')

        // ── 底部中央相机按钮（彩色圆环）──
        Stack() {
          Row()
            .width(68)
            .height(68)
            .borderRadius(34)
            .sweepGradient({
              center: [34, 34],
              start: 0,
              end: 360,
              colors: [['#F5E36B', 0.0], ['#F0B3C8', 0.25], ['#A8D8CB', 0.5], ['#B7B1DB', 0.75], ['#F5E36B', 1.0]]
            })
          Row()
            .width(54)
            .height(54)
            .borderRadius(27)
            .backgroundColor(Color.White)
          Text('📷')
            .fontSize(22)
        }
        .margin({ bottom: 46 })
        .shadow({
          radius: 12,
          color: Theme.SHADOW,
          offsetX: 0,
          offsetY: 4
        })
        .onClick(() => {
          this.stack.pop();
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
      .backgroundImage($r('app.media.dot_grid'), ImageRepeat.XY)
    }
    .hideTitleBar(true)
  }
}
