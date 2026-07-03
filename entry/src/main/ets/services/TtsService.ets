import { textToSpeech } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TtsService';

/**
 * 发音服务 — Core Speech Kit textToSpeech。
 * 引擎懒加载常驻；设备不支持（模拟器）时静默降级，不影响其他交互。
 */
export class TtsService {
  private static engine: textToSpeech.TextToSpeechEngine | null = null;
  private static unavailable: boolean = false;
  private static seq: number = 0;

  private static async ensureEngine(): Promise<textToSpeech.TextToSpeechEngine | null> {
    if (TtsService.engine !== null) {
      return TtsService.engine;
    }
    if (TtsService.unavailable) {
      return null;
    }
    try {
      const params: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 0,
        online: 1
      };
      TtsService.engine = await textToSpeech.createEngine(params);
      return TtsService.engine;
    } catch (e) {
      TtsService.unavailable = true;
      hilog.warn(0x0001, TAG, `tts unavailable: ${JSON.stringify(e)}`);
      return null;
    }
  }

  /** 朗读一段文本（单词或例句）；不可用时静默返回 */
  static async speak(text: string): Promise<void> {
    if (text === '') {
      return;
    }
    const engine = await TtsService.ensureEngine();
    if (engine === null) {
      return;
    }
    try {
      if (engine.isBusy()) {
        engine.stop();
      }
      TtsService.seq++;
      const params: textToSpeech.SpeakParams = {
        requestId: `capwords_${TtsService.seq}`,
        extraParams: { 'speed': 1, 'volume': 2, 'pitch': 1, 'playType': 1, 'queueMode': 0 }
      };
      engine.speak(text, params);
    } catch (e) {
      hilog.warn(0x0001, TAG, `speak failed: ${JSON.stringify(e)}`);
    }
  }
}
