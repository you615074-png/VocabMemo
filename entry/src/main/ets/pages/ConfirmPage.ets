import { curves } from '@kit.ArkUI';
import { Theme, cnDate } from '../common/Theme';
import { WordCard, todayKey } from '../model/WordCard';
import { DataStore } from '../services/DataStore';
import { RecognitionService, searchDict } from '../services/RecognitionService';
import { DictEntry } from '../services/Dictionary';
import { TtsService } from '../services/TtsService';

/**
 * 确认页 — 对齐 CapWords 拍后确认屏：
 * 点阵纸背景、贴纸居中带暖黄光晕、词气泡贴在贴纸上（词+发音+译文）、
 * ↻/✓/✕ 三圆钮、底部「点击调整」人工纠错入口。
 * 识别失败时如实展示原因，仍可手动选词把贴纸收下。
 */
@ComponentV2
export struct ConfirmPage {
  @Require @Param stack: NavPathStack;
  store: DataStore = DataStore.get();
  @Local card: WordCard | null = null;
  @Local alternates: DictEntry[] = [];
  @Local failReason: string = '';
  @Local stickerUri: string = '';
  @Local showAdjust: boolean = false;
  @Local searchText: string = '';
  @Local searchResults: DictEntry[] = [];
  @Local stickerScale: number = 0.3;

  aboutToAppear(): void {
    const pending = this.store.pending;
    if (pending !== null) {
      this.card = pending.card;
      this.alternates = pending.alternates;
      this.failReason = pending.failReason;
      this.stickerUri = pending.stickerUri;
    }
    this.stickerScale = 0.3;
  }

  /** 换词/选词：贴纸与时间不变，只换词条内容 */
  private applyEntry(entry: DictEntry): void {
    const old = this.card;
    const next = RecognitionService.cardFromEntry(entry, old === null ? 'manual' : old.source);
    if (old !== null) {
      next.id = old.id;
      next.imageUri = old.imageUri;
      next.timestamp = old.timestamp;
      next.place = old.place;
      // 原主词退回候选，可来回切换
      const newAlts: DictEntry[] = [{
        word: old.word,
        translation: old.translation,
        phonetic: old.phonetic,
        example: old.example,
        exampleCn: old.exampleCn,
        category: old.category,
        emoji: old.emoji
      }];
      for (const a of this.alternates) {
        if (a.word !== entry.word) {
          newAlts.push(a);
        }
      }
      this.alternates = newAlts;
    } else {
      next.imageUri = this.stickerUri;
      next.source = 'manual';
      this.failReason = '';
    }
    this.card = next;
    this.showAdjust = false;
  }

  private confirm(): void {
    if (this.card === null) {
      return;
    }
    this.store.addWord(this.card);
    this.store.pending = null;
    this.getUIContext().getPromptAction().showToast({
      message: '✓ 已收进今日词汇',
      duration: 1200
    });
    this.stack.pop();
  }

  private dismiss(): void {
    this.store.pending = null;
    this.stack.pop();
  }

  private sourceLabel(source: string): string {
    if (source === 'cloud') {
      return 'AI 识别';
    }
    if (source === 'local') {
      return '离线识别';
    }
    if (source === 'device') {
      return '本地粗识别';
    }
    return '手动选词';
  }

  @Builder
  RoundButton(symbol: string, size: number, symbolColor: ResourceColor, onTap: () => void) {
    Text(symbol)
      .fontSize(size * 0.4)
      .fontWeight(FontWeight.Bold)
      .fontColor(symbolColor)
      .width(size)
      .height(size)
      .textAlign(TextAlign.Center)
      .backgroundColor(Color.White)
      .borderRadius(size / 2)
      .shadow({
        radius: 12,
        color: Theme.SHADOW,
        offsetX: 0,
        offsetY: 4
      })
      .onClick(() => {
        onTap();
      })
  }

  @Builder
  ChipRow(entries: DictEntry[]) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(entries, (entry: DictEntry) => {
        Text(`${entry.emoji} ${entry.word} ${entry.translation}`)
          .fontSize(13)
          .fontColor(Theme.TEXT)
          .padding({
            left: 12,
            right: 12,
            top: 7,
            bottom: 7
          })
          .backgroundColor(Color.White)
          .borderRadius(16)
          .margin(4)
          .shadow({
            radius: 6,
            color: Theme.SHADOW,
            offsetX: 0,
            offsetY: 2
          })
          .onClick(() => {
            this.applyEntry(entry);
          })
      }, (entry: DictEntry) => entry.word)
    }
  }

  @Builder
  AdjustSheet() {
    Column({ space: 12 }) {
      Text('调整词条')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .margin({ top: 18 })
      if (this.alternates.length > 0) {
        Text('也许是')
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
        this.ChipRow(this.alternates)
      }
      TextInput({ placeholder: '输入英文或中文搜索词库…', text: this.searchText })
        .width('88%')
        .fontSize(14)
        .onChange((value: string) => {
          this.searchText = value;
          this.searchResults = searchDict(value);
        })
      if (this.searchResults.length > 0) {
        this.ChipRow(this.searchResults)
      } else if (this.searchText.trim() !== '') {
        Text('词库里没找到，换个词试试')
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
      }
      Blank()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.BG)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          // ── 顶栏：返回 + 日期 ──
          Row({ space: 12 }) {
            Text('‹')
              .fontSize(26)
              .fontColor(Theme.TEXT)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.dismiss();
              })
            Blank()
          }
          .width('100%')
          .padding({ left: 12, top: 52 })

          Text(cnDate(todayKey()))
            .fontSize(26)
            .fontFamily('serif')
            .fontColor(Theme.TEXT)
            .width('100%')
            .padding({ left: 26 })

          Blank()

          // ── 贴纸 + 光晕 + 词气泡 ──
          Stack({ alignContent: Alignment.Bottom }) {
            // 暖黄光晕
            Row()
              .width(320)
              .height(320)
              .radialGradient({
                center: ['50%', '50%'],
                radius: 160,
                colors: [[Theme.GLOW, 0.0], ['#80F5E9C8', 0.55], ['#00F5E9C8', 1.0]]
              })

            Column() {
              if (this.stickerUri !== '') {
                Image(this.stickerUri)
                  .width(250)
                  .height(250)
                  .objectFit(ImageFit.Contain)
                  .shadow({
                    radius: 14,
                    color: Theme.SHADOW,
                    offsetX: 0,
                    offsetY: 6
                  })
              } else if (this.card !== null) {
                Text(this.card.emoji)
                  .fontSize(110)
              }
            }
            .margin({ bottom: 60 })

            // 词气泡（识别成功时）
            if (this.card !== null) {
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text(this.card.word)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A1A1A')
                  Text('🔊')
                    .fontSize(16)
                    .onClick(() => {
                      TtsService.speak(this.card === null ? '' : this.card.word);
                    })
                }
                .padding({
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 8
                })
                .backgroundColor(Color.White)
                .borderRadius(18)
                .shadow({
                  radius: 8,
                  color: Theme.SHADOW,
                  offsetX: 0,
                  offsetY: 3
                })

                Text(this.card.translation)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1A1A')
                  .padding({
                    left: 10,
                    right: 10,
                    top: 4,
                    bottom: 4
                  })
                  .backgroundColor(Color.White)
                  .borderRadius(12)
                  .shadow({
                    radius: 6,
                    color: Theme.SHADOW,
                    offsetX: 0,
                    offsetY: 2
                  })
              }
              .margin({ bottom: 14 })
            } else {
              // 识别失败态：如实说明
              Column({ space: 6 }) {
                Text('没认出来这是什么 😳')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.TEXT)
                Text(this.failReason)
                  .fontSize(11)
                  .fontColor(Theme.TEXT_SUB)
                  .maxLines(2)
                  .textAlign(TextAlign.Center)
                  .width('80%')
              }
              .padding(14)
              .backgroundColor('#F2FFFFFF')
              .borderRadius(16)
              .margin({ bottom: 10 })
            }
          }
          .scale({ x: this.stickerScale, y: this.stickerScale })
          .onAppear(() => {
            this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.68) }, () => {
              this.stickerScale = 1;
            });
          })

          // 词条来源徽标
          if (this.card !== null) {
            Text(this.sourceLabel(this.card.source))
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
              .padding({
                left: 10,
                right: 10,
                top: 4,
                bottom: 4
              })
              .backgroundColor('#B3FFFFFF')
              .borderRadius(10)
              .margin({ top: 10 })
          }

          Blank()

          // ── 三个圆形操作钮：重拍 / 确认 / 取消 ──
          Row({ space: 26 }) {
            this.RoundButton('↻', 56, Theme.TEXT_SUB, () => {
              this.dismiss();
            })
            if (this.card !== null) {
              this.RoundButton('✓', 74, Theme.ACCENT, () => {
                this.confirm();
              })
            } else {
              this.RoundButton('✎', 74, Theme.ACCENT, () => {
                this.showAdjust = true;
              })
            }
            this.RoundButton('✕', 56, Theme.TEXT_SUB, () => {
              this.dismiss();
            })
          }
          .margin({ bottom: 26 })

          // ── 人工纠错入口 ──
          Text(this.card !== null ? '✎ 和你知道的物品名称不一样？点击调整' : '✎ 手动选一个词，把这张贴纸收下')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .padding({
              left: 18,
              right: 18,
              top: 10,
              bottom: 10
            })
            .backgroundColor('#CCFFFFFF')
            .borderRadius(20)
            .margin({ bottom: 56 })
            .onClick(() => {
              this.showAdjust = true;
            })
            .bindSheet(this.showAdjust, this.AdjustSheet(), {
              height: 420,
              backgroundColor: Theme.BG,
              onDisappear: () => {
                this.showAdjust = false;
              }
            })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
      .backgroundImage($r('app.media.dot_grid'), ImageRepeat.XY)
    }
    .hideTitleBar(true)
  }
}
