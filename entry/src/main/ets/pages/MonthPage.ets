import { Theme, DAY_CARD_COLORS, cnDate, cnMonth } from '../common/Theme';
import { WordCard, dateKeyOf, todayKey } from '../model/WordCard';
import { DataStore } from '../services/DataStore';
import { WordSticker } from '../components/WordSticker';
import { ReviewSheet } from '../components/ReviewSheet';

/** 一天的收集摘要 */
interface DayGroup {
  dateKey: string;
  words: WordCard[];
}

/**
 * 月份日卡列表 — 对齐 CapWords 月览：
 * 顶部月份衬线标题，纵向滚动的马卡龙色日卡，
 * 每张卡：日期 + N 个单词 + 当日贴纸一排；点卡片进当日贴纸墙。
 */
@ComponentV2
export struct MonthPage {
  @Require @Param stack: NavPathStack;
  store: DataStore = DataStore.get();
  @Local showReview: boolean = false;

  /** 按日期分组（新→旧） */
  private dayGroups(): DayGroup[] {
    const map = new Map<string, WordCard[]>();
    for (const w of this.store.words) {
      const key = dateKeyOf(w.timestamp);
      const list = map.get(key);
      if (list === undefined) {
        map.set(key, [w]);
      } else {
        list.push(w);
      }
    }
    const groups: DayGroup[] = [];
    map.forEach((words: WordCard[], dateKey: string) => {
      groups.push({ dateKey: dateKey, words: words });
    });
    groups.sort((a: DayGroup, b: DayGroup) => b.dateKey.localeCompare(a.dateKey));
    return groups;
  }

  @Builder
  ReviewSheetBuilder() {
    ReviewSheet({ words: this.store.words })
  }

  build() {
    NavDestination() {
      Column() {
        // ── 顶栏：返回 + 月份 + 复习 ──
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
          Text(cnMonth(todayKey()))
            .fontSize(24)
            .fontFamily('serif')
            .fontColor(Theme.TEXT)
          Blank()
          if (this.store.words.length > 0) {
            Text('⚡')
              .fontSize(16)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .backgroundColor(Color.White)
              .borderRadius(20)
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
          } else {
            Row()
              .width(40)
              .height(40)
          }
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 52, bottom: 8 })

        if (this.dayGroups().length === 0) {
          Column({ space: 10 }) {
            Text('🗓️')
              .fontSize(52)
            Text('还没有任何收集记录')
              .fontSize(14)
              .fontColor(Theme.TEXT_SUB)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          // ── 马卡龙日卡列表 ──
          List({ space: 14 }) {
            ForEach(this.dayGroups(), (group: DayGroup, index: number) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(cnDate(group.dateKey))
                      .fontSize(19)
                      .fontWeight(FontWeight.Medium)
                      .fontFamily('serif')
                      .fontColor(Theme.TEXT)
                    Blank()
                    Text('⋯')
                      .fontSize(16)
                      .fontColor('#66000000')
                  }
                  .width('100%')

                  Text(`${group.words.length} 个单词`)
                    .fontSize(12)
                    .fontColor('#8C2C3A4A')

                  Row({ space: 10 }) {
                    ForEach(group.words.slice(0, 5), (item: WordCard) => {
                      WordSticker({ card: item, stickerSize: 52, showWord: false })
                    }, (item: WordCard) => item.id)
                    if (group.words.length > 5) {
                      Text(`+${group.words.length - 5}`)
                        .fontSize(12)
                        .fontColor('#8C2C3A4A')
                    }
                  }
                  .padding({ top: 4, bottom: 4 })
                }
                .width('100%')
                .padding(18)
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(DAY_CARD_COLORS[index % DAY_CARD_COLORS.length])
                .borderRadius(24)
                .onClick(() => {
                  this.store.selectedDate = group.dateKey;
                  this.stack.pop();
                })
              }
            }, (group: DayGroup) => group.dateKey)
          }
          .width('92%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .contentEndOffset(40)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
      .backgroundImage($r('app.media.dot_grid'), ImageRepeat.XY)
    }
    .hideTitleBar(true)
  }
}
