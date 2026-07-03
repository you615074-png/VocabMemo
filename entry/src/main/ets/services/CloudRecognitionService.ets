import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'CloudRecognition';

/**
 * 云端识别 — 与 CapWords 相同的架构：照片一次性发给第三方视觉大模型识别，
 * 识别后即弃，不在服务端留存。
 * 默认接智谱 GLM-4V-Flash（免费），在设置里粘贴 API Key 即启用。
 */
const ENDPOINT = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const MODEL = 'glm-4v-flash';

const PROMPT = '识别图片中最显眼的一个物体。只返回一个JSON对象，不要任何其他文字，格式:'
  + '{"word":"英文单词(小写)","translation":"中文名","phonetic":"国际音标如/mʌɡ/",'
  + '"example":"含该单词的简短英文例句","exampleCn":"例句中文翻译",'
  + '"category":"从food/nature/object/place/animal中选一个"}';

/** 云端返回的词条 */
export interface CloudWord {
  word: string;
  translation: string;
  phonetic: string;
  example: string;
  exampleCn: string;
  category: string;
}

interface ImageUrl {
  url: string;
}

interface ContentPart {
  type: string;
  text?: string;
  image_url?: ImageUrl;
}

interface ChatMessage {
  role: string;
  content: ContentPart[];
}

interface ChatBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
}

interface RespMessage {
  content: string;
}

interface RespChoice {
  message: RespMessage;
}

interface ChatResponse {
  choices: RespChoice[];
}

export class CloudRecognitionService {
  /**
   * @param base64Jpeg 压缩后的照片 base64（不带 data: 前缀）
   * @returns 识别的词条；网络/Key/解析失败返回 null，由上层降级
   */
  static async recognize(base64Jpeg: string, apiKey: string): Promise<CloudWord | null> {
    if (apiKey === '') {
      return null;
    }
    const body: ChatBody = {
      model: MODEL,
      temperature: 0.2,
      messages: [
        {
          role: 'user',
          content: [
            { type: 'image_url', image_url: { url: base64Jpeg } },
            { type: 'text', text: PROMPT }
          ]
        }
      ]
    };
    const session = http.createHttp();
    try {
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      };
      const resp = await session.request(ENDPOINT, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 30000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        hilog.warn(0x0001, TAG, `http ${resp.responseCode}: ${resp.result}`);
        return null;
      }
      const parsed = JSON.parse(resp.result as string) as ChatResponse;
      if (parsed.choices === undefined || parsed.choices.length === 0) {
        return null;
      }
      return CloudRecognitionService.extractWord(parsed.choices[0].message.content);
    } catch (e) {
      hilog.warn(0x0001, TAG, `cloud recognize failed: ${JSON.stringify(e)}`);
      return null;
    } finally {
      session.destroy();
    }
  }

  /** 剥掉可能的 ```json 围栏后解析词条 JSON */
  private static extractWord(content: string): CloudWord | null {
    try {
      const start = content.indexOf('{');
      const end = content.lastIndexOf('}');
      if (start < 0 || end <= start) {
        return null;
      }
      const w = JSON.parse(content.substring(start, end + 1)) as CloudWord;
      if (w.word === undefined || w.word === '' || w.translation === undefined) {
        return null;
      }
      return w;
    } catch (e) {
      hilog.warn(0x0001, TAG, `parse word failed: ${JSON.stringify(e)}`);
      return null;
    }
  }
}
