import { Theme } from '../common/Theme';
import { WordCard } from '../model/WordCard';
import { DataStore } from '../services/DataStore';
import { WordSticker } from '../components/WordSticker';
import { StickerDetail } from '../components/StickerDetail';

const WEEK_HEADERS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

function keyOf(year: number, month: number, day: number): string {
  const mm = month < 10 ? `0${month}` : `${month}`;
  const dd = day < 10 ? `0${day}` : `${day}`;
  return `${year}-${mm}-${dd}`;
}

/**
 * 日历总览页 — 全局回顾：月历上标记每日识词数量，
 * 点击日期直达当日概览；下方是可翻阅的单词总库。
 */
@ComponentV2
export struct CalendarPage {
  @Require @Param stack: NavPathStack;
  store: DataStore = DataStore.get();
  @Local year: number = new Date().getFullYear();
  @Local month: number = new Date().getMonth() + 1;
  @Local detailCard: WordCard | null = null;
  @Local showDetail: boolean = false;

  /** 月历网格：前导空位用 0 填充 */
  private monthCells(): number[] {
    const cells: number[] = [];
    const firstWeekday = new Date(this.year, this.month - 1, 1).getDay();
    const daysInMonth = new Date(this.year, this.month, 0).getDate();
    for (let i = 0; i < firstWeekday; i++) {
      cells.push(0);
    }
    for (let d = 1; d <= daysInMonth; d++) {
      cells.push(d);
    }
    return cells;
  }

  private changeMonth(delta: number): void {
    let m = this.month + delta;
    let y = this.year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    this.month = m;
    this.year = y;
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

  build() {
    NavDestination() {
      Column({ space: 14 }) {
        // ── 顶栏 ──
        Row({ space: 10 }) {
          Text('‹ 返回')
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
              this.stack.pop();
            })
          Blank()
          Text('◀')
            .fontSize(14)
            .fontColor(Theme.TEXT_SUB)
            .padding(8)
            .onClick(() => {
              this.changeMonth(-1);
            })
          Text(`${this.year}年${this.month}月`)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT)
          Text('▶')
            .fontSize(14)
            .fontColor(Theme.TEXT_SUB)
            .padding(8)
            .onClick(() => {
              this.changeMonth(1);
            })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })

        // ── 月历 ──
        Column({ space: 6 }) {
          Row() {
            ForEach(WEEK_HEADERS, (h: string) => {
              Text(h)
                .fontSize(12)
                .fontColor(Theme.TEXT_SUB)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
            }, (h: string) => h)
          }
          .width('100%')

          Grid() {
            ForEach(this.monthCells(), (day: number, index: number) => {
              GridItem() {
                if (day > 0) {
                  Column({ space: 3 }) {
                    Text(`${day}`)
                      .fontSize(14)
                      .fontColor(Theme.TEXT)
                    if (this.store.countOn(keyOf(this.year, this.month, day)) > 0) {
                      Text(`${this.store.countOn(keyOf(this.year, this.month, day))}`)
                        .fontSize(9)
                        .fontColor(Color.White)
                        .width(16)
                        .height(16)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(Theme.PRIMARY)
                        .borderRadius(8)
                    } else {
                      Row()
                        .height(16)
                    }
                  }
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                  .borderRadius(10)
                  .backgroundColor(
                    this.store.countOn(keyOf(this.year, this.month, day)) > 0 ? '#B3FFFFFF' : Color.Transparent
                  )
                  .onClick(() => {
                    this.store.selectedDate = keyOf(this.year, this.month, day);
                    this.stack.pushPathByName('overview', null);
                  })
                }
              }
            }, (day: number, index: number) => `${this.year}-${this.month}-${index}`)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
          .rowsGap(4)
          .height(252)
        }
        .width('92%')
        .padding(12)
        .backgroundColor('#CCFFFFFF')
        .borderRadius(Theme.RADIUS_CARD)
        .shadow({
          radius: 14,
          color: Theme.SHADOW,
          offsetX: 0,
          offsetY: 4
        })

        // ── 单词总库 ──
        Row() {
          Text('单词总库')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT)
          Blank()
          Text(`共 ${this.store.words.length} 个`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('92%')

        Scroll() {
          Flex({
            wrap: FlexWrap.Wrap,
            justifyContent: FlexAlign.Start
          }) {
            ForEach(this.store.words, (item: WordCard) => {
              Column() {
                WordSticker({ card: item, stickerSize: 68 })
              }
              .padding(6)
              .onClick(() => {
                this.detailCard = item;
                this.showDetail = true;
              })
            }, (item: WordCard) => item.id)
          }
          .width('100%')
        }
        .width('92%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
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
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG)
  }
}
