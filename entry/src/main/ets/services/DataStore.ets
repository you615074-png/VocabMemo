import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WordCard, WordData, toData, fromData, dateKeyOf, todayKey } from '../model/WordCard';
import { RecognitionResult } from './RecognitionService';

const PREF_NAME = 'capwords_store';
const KEY_WORDS = 'words';
const KEY_API = 'cloud_api_key';
const TAG = 'DataStore';

/**
 * 全局数据仓库（V2 状态管理单例）。
 * 所有单词贴纸集中存放，按 dateKey 派生出「当日词汇 / 日历计数」等视图；
 * 通过 @ohos.data.preferences 本地持久化，无网络依赖。
 */
@ObservedV2
export class DataStore {
  private static instance: DataStore | null = null;

  static get(): DataStore {
    if (DataStore.instance === null) {
      DataStore.instance = new DataStore();
    }
    return DataStore.instance;
  }

  /** 全部收集的单词贴纸（新→旧） */
  @Trace words: WordCard[] = [];
  /** 当日概览页正在查看的日期（YYYY-MM-DD） */
  @Trace selectedDate: string = todayKey();
  /** 云端识别 API Key（空串=未启用，降级端侧模型） */
  @Trace apiKey: string = '';
  /** 拍照后待确认的识别结果（相机页写入 → 确认页消费） */
  @Trace pending: RecognitionResult | null = null;

  private pref: preferences.Preferences | null = null;
  private inited: boolean = false;

  /** 在首页 aboutToAppear 中调用一次；重复调用无副作用 */
  init(context: common.UIAbilityContext): void {
    if (this.inited) {
      return;
    }
    this.inited = true;
    try {
      const options: preferences.Options = { name: PREF_NAME };
      this.pref = preferences.getPreferencesSync(context, options);
      const raw = this.pref.getSync(KEY_WORDS, '[]') as string;
      const dataList = JSON.parse(raw) as WordData[];
      const loaded: WordCard[] = [];
      for (const d of dataList) {
        loaded.push(fromData(d));
      }
      // 新的在前，方便瀑布流展示
      loaded.sort((a: WordCard, b: WordCard) => b.timestamp - a.timestamp);
      this.words = loaded;
      this.apiKey = this.pref.getSync(KEY_API, '') as string;
      if (this.apiKey === '') {
        this.apiKey = '5e254dfb0a7e4be9af429532c72048bf.l1KGqg0vm9bFRvlg';
      }
    } catch (e) {
      hilog.error(0x0001, TAG, `init failed: ${JSON.stringify(e)}`);
    }
  }

  setApiKey(key: string): void {
    this.apiKey = key.trim();
    if (this.pref !== null) {
      this.pref.putSync(KEY_API, this.apiKey);
      this.pref.flush();
    }
  }

  addWord(card: WordCard): void {
    this.words.unshift(card);
    this.persist();
  }

  removeWord(id: string): void {
    const idx = this.words.findIndex((w: WordCard) => w.id === id);
    if (idx >= 0) {
      this.words.splice(idx, 1);
      this.persist();
    }
  }

  toggleMastered(id: string): void {
    for (const w of this.words) {
      if (w.id === id) {
        w.mastered = !w.mastered;
        break;
      }
    }
    this.persist();
  }

  /** 某天收集的单词（旧→新，符合日记时间线） */
  wordsOfDate(dateKey: string): WordCard[] {
    return this.words
      .filter((w: WordCard) => dateKeyOf(w.timestamp) === dateKey)
      .sort((a: WordCard, b: WordCard) => a.timestamp - b.timestamp);
  }

  /** 今日已收集数量（相机页顶部积累感提示） */
  todayCount(): number {
    return this.wordsOfDate(todayKey()).length;
  }

  /** 某天的收集数量（日历页角标） */
  countOn(dateKey: string): number {
    let n = 0;
    for (const w of this.words) {
      if (dateKeyOf(w.timestamp) === dateKey) {
        n++;
      }
    }
    return n;
  }

  private persist(): void {
    if (this.pref === null) {
      return;
    }
    try {
      const dataList: WordData[] = [];
      for (const w of this.words) {
        dataList.push(toData(w));
      }
      this.pref.putSync(KEY_WORDS, JSON.stringify(dataList));
      this.pref.flush();
    } catch (e) {
      hilog.error(0x0001, TAG, `persist failed: ${JSON.stringify(e)}`);
    }
  }
}
