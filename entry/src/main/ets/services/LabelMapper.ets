import { DICTIONARY, DictEntry } from './Dictionary';

/**
 * 标签映射器 — 把 ImageNet-1000 类别名映射到学习友好的词库单词。
 * 规则：多词关键字对整个标签做包含匹配；单词关键字只做分词后的全词匹配
 * （避免 catamaran 命中 cat 之类的误伤）。120 种狗统统映射为 dog。
 * 未覆盖的类别不出词，由识别级联继续降级。
 */
interface MapRule {
  /** 匹配关键字（含空格=整串包含匹配；单词=分词全词匹配） */
  kw: string;
  /** 词库中的目标单词 */
  word: string;
}

/** 顺序即优先级：specific 在前，generic 在后 */
const RULES: MapRule[] = [
  // ── 动物 ──
  { kw: 'terrier', word: 'dog' },
  { kw: 'retriever', word: 'dog' },
  { kw: 'spaniel', word: 'dog' },
  { kw: 'shepherd', word: 'dog' },
  { kw: 'sheepdog', word: 'dog' },
  { kw: 'hound', word: 'dog' },
  { kw: 'poodle', word: 'dog' },
  { kw: 'husky', word: 'dog' },
  { kw: 'corgi', word: 'dog' },
  { kw: 'pug', word: 'dog' },
  { kw: 'beagle', word: 'dog' },
  { kw: 'mastiff', word: 'dog' },
  { kw: 'collie', word: 'dog' },
  { kw: 'setter', word: 'dog' },
  { kw: 'schnauzer', word: 'dog' },
  { kw: 'pinscher', word: 'dog' },
  { kw: 'bulldog', word: 'dog' },
  { kw: 'dalmatian', word: 'dog' },
  { kw: 'chihuahua', word: 'dog' },
  { kw: 'rottweiler', word: 'dog' },
  { kw: 'samoyed', word: 'dog' },
  { kw: 'pomeranian', word: 'dog' },
  { kw: 'malamute', word: 'dog' },
  { kw: 'papillon', word: 'dog' },
  { kw: 'pekinese', word: 'dog' },
  { kw: 'maltese', word: 'dog' },
  { kw: 'dog', word: 'dog' },
  { kw: 'tabby', word: 'cat' },
  { kw: 'cat', word: 'cat' },
  { kw: 'kitten', word: 'cat' },
  { kw: 'goldfish', word: 'goldfish' },
  { kw: 'shark', word: 'fish' },
  { kw: 'tench', word: 'fish' },
  { kw: 'sturgeon', word: 'fish' },
  { kw: 'eel', word: 'fish' },
  { kw: 'stingray', word: 'fish' },
  { kw: 'lionfish', word: 'fish' },
  { kw: 'puffer', word: 'fish' },
  { kw: 'anemone fish', word: 'fish' },
  { kw: 'butterfly', word: 'butterfly' },
  { kw: 'monarch', word: 'butterfly' },
  { kw: 'admiral', word: 'butterfly' },
  { kw: 'jay', word: 'bird' },
  { kw: 'magpie', word: 'bird' },
  { kw: 'chickadee', word: 'bird' },
  { kw: 'robin', word: 'bird' },
  { kw: 'bulbul', word: 'bird' },
  { kw: 'finch', word: 'bird' },
  { kw: 'sparrow', word: 'sparrow' },
  { kw: 'junco', word: 'bird' },
  { kw: 'eagle', word: 'bird' },
  { kw: 'vulture', word: 'bird' },
  { kw: 'owl', word: 'bird' },
  { kw: 'peacock', word: 'bird' },
  { kw: 'quail', word: 'bird' },
  { kw: 'parrot', word: 'bird' },
  { kw: 'macaw', word: 'bird' },
  { kw: 'cockatoo', word: 'bird' },
  { kw: 'hummingbird', word: 'bird' },
  { kw: 'toucan', word: 'bird' },
  { kw: 'goose', word: 'bird' },
  { kw: 'swan', word: 'bird' },
  { kw: 'flamingo', word: 'bird' },
  { kw: 'heron', word: 'bird' },
  { kw: 'crane', word: 'bird' },
  { kw: 'stork', word: 'bird' },
  { kw: 'pelican', word: 'bird' },
  { kw: 'albatross', word: 'bird' },
  { kw: 'penguin', word: 'bird' },
  { kw: 'gull', word: 'bird' },
  { kw: 'hen', word: 'bird' },
  { kw: 'ostrich', word: 'bird' },
  // ── 食物/植物 ──
  { kw: 'banana', word: 'banana' },
  { kw: 'orange', word: 'orange' },
  { kw: 'granny smith', word: 'apple' },
  { kw: 'strawberry', word: 'strawberry' },
  { kw: 'lemon', word: 'lemon' },
  { kw: 'pineapple', word: 'pineapple' },
  { kw: 'broccoli', word: 'broccoli' },
  { kw: 'cucumber', word: 'cucumber' },
  { kw: 'mushroom', word: 'mushroom' },
  { kw: 'agaric', word: 'mushroom' },
  { kw: 'daisy', word: 'flower' },
  { kw: "lady's slipper", word: 'flower' },
  { kw: 'pizza', word: 'pizza' },
  { kw: 'cheeseburger', word: 'hamburger' },
  { kw: 'ice cream', word: 'ice cream' },
  { kw: 'ice lolly', word: 'ice cream' },
  { kw: 'french loaf', word: 'bread' },
  { kw: 'bagel', word: 'bread' },
  { kw: 'pretzel', word: 'bread' },
  { kw: 'croissant', word: 'croissant' },
  { kw: 'espresso', word: 'coffee' },
  { kw: 'noodle', word: 'noodles' },
  { kw: 'carbonara', word: 'noodles' },
  // ── 器物 ──
  { kw: 'coffee mug', word: 'mug' },
  { kw: 'cup', word: 'cup' },
  { kw: 'water bottle', word: 'bottle' },
  { kw: 'wine bottle', word: 'bottle' },
  { kw: 'pop bottle', word: 'bottle' },
  { kw: 'beer bottle', word: 'bottle' },
  { kw: 'pill bottle', word: 'bottle' },
  { kw: 'teapot', word: 'teapot' },
  { kw: 'umbrella', word: 'umbrella' },
  { kw: 'notebook', word: 'laptop' },
  { kw: 'laptop', word: 'laptop' },
  { kw: 'desktop computer', word: 'laptop' },
  { kw: 'keyboard', word: 'keyboard' },
  { kw: 'mouse', word: 'mouse' },
  { kw: 'cellular telephone', word: 'phone' },
  { kw: 'dial telephone', word: 'phone' },
  { kw: 'pay-phone', word: 'phone' },
  { kw: 'ipod', word: 'phone' },
  { kw: 'television', word: 'television' },
  { kw: 'monitor', word: 'television' },
  { kw: 'screen', word: 'television' },
  { kw: 'remote control', word: 'remote' },
  { kw: 'clock', word: 'clock' },
  { kw: 'digital watch', word: 'clock' },
  { kw: 'chair', word: 'chair' },
  { kw: 'couch', word: 'sofa' },
  { kw: 'four-poster', word: 'bed' },
  { kw: 'table lamp', word: 'lamp' },
  { kw: 'lampshade', word: 'lamp' },
  { kw: 'vase', word: 'vase' },
  { kw: 'plate', word: 'plate' },
  { kw: 'mixing bowl', word: 'bowl' },
  { kw: 'soup bowl', word: 'bowl' },
  { kw: 'wooden spoon', word: 'spoon' },
  { kw: 'ladle', word: 'spoon' },
  { kw: 'ballpoint', word: 'pen' },
  { kw: 'fountain pen', word: 'pen' },
  { kw: 'quill', word: 'pen' },
  { kw: 'sunglasses', word: 'glasses' },
  { kw: 'sunglass', word: 'glasses' },
  { kw: 'running shoe', word: 'shoe' },
  { kw: 'loafer', word: 'shoe' },
  { kw: 'sandal', word: 'shoe' },
  { kw: 'clog', word: 'shoe' },
  { kw: 'cowboy hat', word: 'hat' },
  { kw: 'sombrero', word: 'hat' },
  { kw: 'bonnet', word: 'hat' },
  { kw: 'sock', word: 'sock' },
  { kw: 'windsor tie', word: 'tie' },
  { kw: 'bow tie', word: 'tie' },
  { kw: 'bolo tie', word: 'tie' },
  { kw: 'balloon', word: 'balloon' },
  { kw: 'candle', word: 'candle' },
  { kw: 'guitar', word: 'guitar' },
  { kw: 'piano', word: 'piano' },
  { kw: 'violin', word: 'violin' },
  { kw: 'cello', word: 'violin' },
  { kw: 'drum', word: 'drum' },
  { kw: 'basketball', word: 'ball' },
  { kw: 'soccer ball', word: 'ball' },
  { kw: 'tennis ball', word: 'ball' },
  { kw: 'golf ball', word: 'ball' },
  { kw: 'baseball', word: 'ball' },
  { kw: 'volleyball', word: 'ball' },
  { kw: 'rugby ball', word: 'ball' },
  { kw: 'ping-pong ball', word: 'ball' },
  { kw: 'croquet ball', word: 'ball' },
  { kw: 'dumbbell', word: 'dumbbell' },
  { kw: 'park bench', word: 'bench' },
  { kw: 'fountain', word: 'fountain' },
  // ── 交通/场所 ──
  { kw: 'passenger car', word: 'train' },
  { kw: 'bullet train', word: 'train' },
  { kw: 'locomotive', word: 'train' },
  { kw: 'sports car', word: 'car' },
  { kw: 'convertible', word: 'car' },
  { kw: 'limousine', word: 'car' },
  { kw: 'jeep', word: 'car' },
  { kw: 'minivan', word: 'car' },
  { kw: 'beach wagon', word: 'car' },
  { kw: 'ambulance', word: 'car' },
  { kw: 'pickup', word: 'car' },
  { kw: 'racer', word: 'car' },
  { kw: 'cab', word: 'car' },
  { kw: 'school bus', word: 'bus' },
  { kw: 'trolleybus', word: 'bus' },
  { kw: 'minibus', word: 'bus' },
  { kw: 'airliner', word: 'airplane' },
  { kw: 'warplane', word: 'airplane' },
  { kw: 'mountain bike', word: 'bicycle' },
  { kw: 'bicycle', word: 'bicycle' },
  { kw: 'tricycle', word: 'bicycle' },
  { kw: 'motor scooter', word: 'motorcycle' },
  { kw: 'moped', word: 'motorcycle' },
  { kw: 'speedboat', word: 'boat' },
  { kw: 'canoe', word: 'boat' },
  { kw: 'gondola', word: 'boat' },
  { kw: 'lifeboat', word: 'boat' },
  { kw: 'fireboat', word: 'boat' },
  { kw: 'catamaran', word: 'boat' },
  { kw: 'trimaran', word: 'boat' },
  { kw: 'schooner', word: 'boat' },
  { kw: 'traffic light', word: 'traffic light' },
  { kw: 'castle', word: 'building' },
  { kw: 'palace', word: 'building' },
  { kw: 'monastery', word: 'building' },
  { kw: 'church', word: 'building' },
  { kw: 'mosque', word: 'building' },
  { kw: 'library', word: 'building' },
  { kw: 'cinema', word: 'building' },
  { kw: 'boathouse', word: 'building' },
  { kw: 'greenhouse', word: 'building' },
  { kw: 'lighthouse', word: 'building' },
  { kw: 'barn', word: 'building' }
];

export class LabelMapper {
  /** 单个 ImageNet 标签 → 词库词条（无映射返回 null） */
  static mapLabel(label: string): DictEntry | null {
    const lower = label.toLowerCase();
    const tokens = lower.split(/[^a-z']+/);
    for (const rule of RULES) {
      let hit = false;
      if (rule.kw.includes(' ') || rule.kw.includes('-')) {
        hit = lower.includes(rule.kw);
      } else {
        hit = tokens.includes(rule.kw);
      }
      if (hit) {
        return LabelMapper.entryOf(rule.word);
      }
    }
    return null;
  }

  private static entryOf(word: string): DictEntry | null {
    for (const e of DICTIONARY) {
      if (e.word === word) {
        return e;
      }
    }
    return null;
  }
}
