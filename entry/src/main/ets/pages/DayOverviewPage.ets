import { Theme, categoryOf } from '../common/Theme';
import { WordCard } from '../model/WordCard';
import { DataStore } from '../services/DataStore';
import { DiaryService, DiarySegment } from '../services/DiaryService';
import { TrackCanvas } from '../components/TrackCanvas';
import { StickerDetail } from '../components/StickerDetail';
import { ReviewSheet } from '../components/ReviewSheet';

const WEEKDAYS: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function labelOf(dateKey: string): string {
  const parts = dateKey.split('-');
  const y = Number(parts[0]);
  const m = Number(parts[1]);
  const d = Number(parts[2]);
  const wd = new Date(y, m - 1, d).getDay();
  return `${m}月${d}日 · ${WEEKDAYS[wd]}`;
}

function shiftDate(dateKey: string, deltaDays: number): string {
  const parts = dateKey.split('-');
  const dt = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  dt.setDate(dt.getDate() + deltaDays);
  const m = dt.getMonth() + 1;
  const d = dt.getDate();
  const mm = m < 10 ? `0${m}` : `${m}`;
  const dd = d < 10 ? `0${d}` : `${d}`;
  return `${dt.getFullYear()}-${mm}-${dd}`;
}

/**
 * 当日概览页 — 双功能融合的核心页面：
 * 上半区轨迹地图（点到线），下半区自动生成的日记（线到面），
 * 复习与详情全部以半屏卡上下文唤起，不做全屏跳转。
 */
@ComponentV2
export struct DayOverviewPage {
  @Require @Param stack: NavPathStack;
  store: DataStore = DataStore.get();
  @Local dayWords: WordCard[] = [];
  @Local detailCard: WordCard | null = null;
  @Local showDetail: boolean = false;
  @Local showReview: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.dayWords = this.store.wordsOfDate(this.store.selectedDate);
  }

  private changeDay(delta: number): void {
    this.store.selectedDate = shiftDate(this.store.selectedDate, delta);
    this.refresh();
  }

  private openDetail(card: WordCard): void {
    this.detailCard = card;
    this.showDetail = true;
  }

  @Builder
  DetailSheetBuilder() {
    Column() {
      if (this.detailCard !== null) {
        StickerDetail({
          card: this.detailCard,
          onDeleted: () => {
            this.showDetail = false;
            this.refresh();
          }
        })
      }
    }
  }

  @Builder
  ReviewSheetBuilder() {
    ReviewSheet({ words: this.dayWords })
  }

  @Builder
  IconChip(label: string, onTap: () => void) {
    Text(label)
      .fontSize(15)
      .fontColor(Theme.TEXT)
      .padding({
        left: 12,
        right: 12,
        top: 6,
        bottom: 6
      })
      .backgroundColor('#B3FFFFFF')
      .borderRadius(15)
      .onClick(() => {
        onTap();
      })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column({ space: 14 }) {
          // ── 顶栏：返回 / 前后翻日 / 日历入口 ──
          Row({ space: 10 }) {
            this.IconChip('‹ 返回', () => {
              this.stack.pop();
            })
            Blank()
            this.IconChip('◀', () => {
              this.changeDay(-1);
            })
            Column({ space: 2 }) {
              Text(labelOf(this.store.selectedDate))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.TEXT)
              Text(`${this.dayWords.length} 张单词贴纸`)
                .fontSize(11)
                .fontColor(Theme.TEXT_SUB)
            }
            this.IconChip('▶', () => {
              this.changeDay(1);
            })
            Blank()
            this.IconChip('日历', () => {
              this.stack.pushPathByName('calendar', null);
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12 })

          // ── 上半区：当日足迹（概览点位，非精准坐标） ──
          Column() {
            TrackCanvas({
              words: this.dayWords,
              onPick: (card: WordCard) => {
                this.openDetail(card);
              }
            })
          }
          .width('92%')
          .height(200)
          .backgroundColor('#CCFFFFFF')
          .borderRadius(Theme.RADIUS_CARD)
          .shadow({
            radius: 14,
            color: Theme.SHADOW,
            offsetX: 0,
            offsetY: 4
          })

          // ── 下半区:自动生成的日记，单词贴纸像手账素材一样嵌入段落 ──
          List({ space: 10 }) {
            ForEach(DiaryService.generateSegments(this.dayWords, labelOf(this.store.selectedDate)),
              (seg: DiarySegment) => {
                ListItem() {
                  Column({ space: 8 }) {
                    Text(seg.text)
                      .fontSize(15)
                      .fontColor(Theme.TEXT)
                      .lineHeight(24)
                      .width('100%')
                    if (seg.card !== null) {
                      Row({ space: 10 }) {
                        Text(seg.card.emoji)
                          .fontSize(22)
                          .width(40)
                          .height(40)
                          .textAlign(TextAlign.Center)
                          .backgroundColor(categoryOf(seg.card.category).bg)
                          .borderRadius(10)
                          .borderWidth(3)
                          .borderColor(Color.White)
                        Column({ space: 2 }) {
                          Text(seg.card.word)
                            .fontSize(16)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(categoryOf(seg.card.category).accent)
                          Text(seg.card.phonetic)
                            .fontSize(11)
                            .fontColor(Theme.TEXT_SUB)
                        }
                        .alignItems(HorizontalAlign.Start)
                        Blank()
                        Text('详情 ›')
                          .fontSize(12)
                          .fontColor(Theme.TEXT_SUB)
                      }
                      .width('100%')
                      .padding(10)
                      .backgroundColor('#99FFFFFF')
                      .borderRadius(12)
                      .onClick(() => {
                        if (seg.card !== null) {
                          this.openDetail(seg.card);
                        }
                      })
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
              },
              (seg: DiarySegment, index: number) => `${this.store.selectedDate}_${index}`)

            // 底部留白，避免被悬浮按钮遮挡
            ListItem() {
              Row()
                .height(72)
            }
          }
          .width('92%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .bindSheet(this.showDetail, this.DetailSheetBuilder(), {
            height: 480,
            backgroundColor: Theme.BG,
            onDisappear: () => {
              this.showDetail = false;
            }
          })
        }
        .width('100%')
        .height('100%')

        // ── 悬浮复习按钮：轻量不遮挡内容 ──
        if (this.dayWords.length > 0) {
          Button(`复习今日单词（${this.dayWords.length}）`)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor(Theme.PRIMARY)
            .padding({
              left: 28,
              right: 28,
              top: 12,
              bottom: 12
            })
            .shadow({
              radius: 14,
              color: Theme.SHADOW,
              offsetX: 0,
              offsetY: 4
            })
            .margin({ bottom: 28 })
            .onClick(() => {
              this.showReview = true;
            })
            .bindSheet(this.showReview, this.ReviewSheetBuilder(), {
              height: 470,
              backgroundColor: Theme.BG,
              onDisappear: () => {
                this.showReview = false;
              }
            })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG)
  }
}
