import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'CloudRecognition';

/**
 * 云端识别 — 与 CapWords 相同的架构：抠图后的主体一次性发给视觉大模型识别，
 * 识别后即弃，不在服务端留存。
 * 默认接智谱 GLM-4V-Flash（免费），在设置里粘贴 API Key 即启用。
 */
const ENDPOINT = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const MODEL = 'glm-4v-flash';

const PROMPT = '识别图片中最显眼的一个物体。只返回一个JSON对象，不要任何其他文字，格式:'
  + '{"word":"英文单词(小写)","translation":"中文名","phonetic":"国际音标如/mʌɡ/",'
  + '"examples":["含该单词的英文例句1","例句2","例句3"],'
  + '"examplesCn":["例句1中文翻译","例句2中文翻译","例句3中文翻译"],'
  + '"category":"从food/nature/object/place/animal中选一个"}'
  + ' 例句要简短地道、贴近日常生活。';

/** 云端返回的词条 */
export interface CloudWord {
  word: string;
  translation: string;
  phonetic: string;
  examples: string[];
  examplesCn: string[];
  category: string;
}

/** 云端识别结果：word 与 failReason 二选一 */
export interface CloudResult {
  word: CloudWord | null;
  /** 失败原因（用户可读），成功时为空串 */
  failReason: string;
}

interface RawCloudWord {
  word?: string;
  translation?: string;
  phonetic?: string;
  example?: string;
  exampleCn?: string;
  examples?: string[];
  examplesCn?: string[];
  category?: string;
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
   * @param base64Jpeg 压缩后的抠图主体 base64（不带 data: 前缀）
   */
  static async recognize(base64Jpeg: string, apiKey: string): Promise<CloudResult> {
    if (apiKey === '') {
      return { word: null, failReason: '未配置云端 Key' };
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
      if (resp.responseCode === 401) {
        hilog.warn(0x0001, TAG, 'unauthorized: bad api key');
        return { word: null, failReason: 'API Key 无效' };
      }
      if (resp.responseCode !== 200) {
        hilog.warn(0x0001, TAG, `http ${resp.responseCode}: ${resp.result}`);
        return { word: null, failReason: `云端服务异常(${resp.responseCode})` };
      }
      const parsed = JSON.parse(resp.result as string) as ChatResponse;
      if (parsed.choices === undefined || parsed.choices.length === 0) {
        return { word: null, failReason: '云端未返回结果' };
      }
      const w = CloudRecognitionService.extractWord(parsed.choices[0].message.content);
      if (w === null) {
        return { word: null, failReason: '云端结果解析失败' };
      }
      return { word: w, failReason: '' };
    } catch (e) {
      hilog.warn(0x0001, TAG, `cloud recognize failed: ${JSON.stringify(e)}`);
      return { word: null, failReason: '网络不可用或请求超时' };
    } finally {
      session.destroy();
    }
  }

  /** 剥掉可能的 ```json 围栏后解析词条 JSON，兼容单例句旧格式 */
  private static extractWord(content: string): CloudWord | null {
    try {
      const start = content.indexOf('{');
      const end = content.lastIndexOf('}');
      if (start < 0 || end <= start) {
        return null;
      }
      const raw = JSON.parse(content.substring(start, end + 1)) as RawCloudWord;
      if (raw.word === undefined || raw.word === '' || raw.translation === undefined) {
        return null;
      }
      let examples: string[] = raw.examples === undefined ? [] : raw.examples;
      let examplesCn: string[] = raw.examplesCn === undefined ? [] : raw.examplesCn;
      if (examples.length === 0 && raw.example !== undefined && raw.example !== '') {
        examples = [raw.example];
        examplesCn = raw.exampleCn === undefined ? [] : [raw.exampleCn];
      }
      return {
        word: raw.word,
        translation: raw.translation,
        phonetic: raw.phonetic === undefined ? '' : raw.phonetic,
        examples: examples,
        examplesCn: examplesCn,
        category: raw.category === undefined ? 'object' : raw.category
      };
    } catch (e) {
      hilog.warn(0x0001, TAG, `parse word failed: ${JSON.stringify(e)}`);
      return null;
    }
  }
}
