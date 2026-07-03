/**
 * 内置演示词库 — Mock 识别服务的数据源。
 * 正式版接入 Core Vision Kit 物体识别后，此表退化为「识别结果 → 词条」的映射兜底。
 */
export interface DictEntry {
  word: string;
  translation: string;
  phonetic: string;
  example: string;
  exampleCn: string;
  category: string;
  emoji: string;
}

export const DICTIONARY: DictEntry[] = [
  { word: 'mug', translation: '马克杯', phonetic: '/mʌɡ/', example: 'A mug of hot cocoa warms the morning.', exampleCn: '一杯热可可温暖了清晨。', category: 'food', emoji: '☕' },
  { word: 'croissant', translation: '牛角包', phonetic: '/krwɑːˈsɒ̃/', example: 'She bought a croissant at the corner bakery.', exampleCn: '她在街角面包店买了个牛角包。', category: 'food', emoji: '🥐' },
  { word: 'tangerine', translation: '橘子', phonetic: '/ˌtændʒəˈriːn/', example: 'The tangerine peel smells like winter.', exampleCn: '橘子皮闻起来像冬天的味道。', category: 'food', emoji: '🍊' },
  { word: 'noodles', translation: '面条', phonetic: '/ˈnuːdlz/', example: 'A bowl of noodles is the best late-night comfort.', exampleCn: '深夜的一碗面最抚慰人心。', category: 'food', emoji: '🍜' },
  { word: 'kettle', translation: '水壶', phonetic: '/ˈketl/', example: 'The kettle whistled softly on the stove.', exampleCn: '水壶在炉子上轻轻鸣响。', category: 'food', emoji: '🫖' },
  { word: 'maple', translation: '枫树', phonetic: '/ˈmeɪpl/', example: 'The maple leaves turned red overnight.', exampleCn: '枫叶一夜之间红了。', category: 'nature', emoji: '🍁' },
  { word: 'fern', translation: '蕨类植物', phonetic: '/fɜːn/', example: 'A fern unfurls quietly in the shade.', exampleCn: '一株蕨在树荫下静静舒展。', category: 'nature', emoji: '🌿' },
  { word: 'pebble', translation: '鹅卵石', phonetic: '/ˈpebl/', example: 'He skipped a pebble across the lake.', exampleCn: '他往湖面打了个水漂。', category: 'nature', emoji: '🪨' },
  { word: 'cloud', translation: '云', phonetic: '/klaʊd/', example: 'A single cloud drifted over the rooftop.', exampleCn: '一朵云飘过屋顶。', category: 'nature', emoji: '☁️' },
  { word: 'dandelion', translation: '蒲公英', phonetic: '/ˈdændɪlaɪən/', example: 'She blew the dandelion seeds into the wind.', exampleCn: '她把蒲公英的种子吹向风里。', category: 'nature', emoji: '🌼' },
  { word: 'umbrella', translation: '雨伞', phonetic: '/ʌmˈbrelə/', example: 'He forgot his umbrella on the bus again.', exampleCn: '他又把伞落在公交车上了。', category: 'object', emoji: '☂️' },
  { word: 'lantern', translation: '灯笼', phonetic: '/ˈlæntən/', example: 'A paper lantern glowed by the doorway.', exampleCn: '门边一盏纸灯笼亮着。', category: 'object', emoji: '🏮' },
  { word: 'bicycle', translation: '自行车', phonetic: '/ˈbaɪsɪkl/', example: 'The bicycle leaned against the old wall.', exampleCn: '自行车斜靠在老墙边。', category: 'object', emoji: '🚲' },
  { word: 'notebook', translation: '笔记本', phonetic: '/ˈnəʊtbʊk/', example: 'Her notebook is full of tiny sketches.', exampleCn: '她的笔记本上画满了小涂鸦。', category: 'object', emoji: '📓' },
  { word: 'sneakers', translation: '运动鞋', phonetic: '/ˈsniːkəz/', example: 'New sneakers make every walk feel lighter.', exampleCn: '新运动鞋让每一步都轻快。', category: 'object', emoji: '👟' },
  { word: 'headphones', translation: '耳机', phonetic: '/ˈhedfəʊnz/', example: 'He put on headphones and the city went quiet.', exampleCn: '他戴上耳机，城市便安静了。', category: 'object', emoji: '🎧' },
  { word: 'bench', translation: '长椅', phonetic: '/bentʃ/', example: 'They shared the bench and said nothing.', exampleCn: '他们同坐一条长椅，谁也没说话。', category: 'place', emoji: '🪑' },
  { word: 'crosswalk', translation: '人行横道', phonetic: '/ˈkrɒswɔːk/', example: 'Wait for the green light at the crosswalk.', exampleCn: '在人行横道等绿灯。', category: 'place', emoji: '🚸' },
  { word: 'bookstore', translation: '书店', phonetic: '/ˈbʊkstɔː/', example: 'The bookstore smells of paper and rain.', exampleCn: '书店里有纸张和雨水的气味。', category: 'place', emoji: '📚' },
  { word: 'fountain', translation: '喷泉', phonetic: '/ˈfaʊntən/', example: 'Children chased pigeons around the fountain.', exampleCn: '孩子们绕着喷泉追鸽子。', category: 'place', emoji: '⛲' },
  { word: 'balcony', translation: '阳台', phonetic: '/ˈbælkəni/', example: 'She waters the plants on the balcony at dusk.', exampleCn: '黄昏时她在阳台上浇花。', category: 'place', emoji: '🪴' },
  { word: 'sparrow', translation: '麻雀', phonetic: '/ˈspærəʊ/', example: 'A sparrow hopped along the windowsill.', exampleCn: '一只麻雀在窗台上蹦跳。', category: 'animal', emoji: '🐦' },
  { word: 'kitten', translation: '小猫', phonetic: '/ˈkɪtn/', example: 'The kitten curled up inside the shoebox.', exampleCn: '小猫蜷在鞋盒里。', category: 'animal', emoji: '🐱' },
  { word: 'goldfish', translation: '金鱼', phonetic: '/ˈɡəʊldfɪʃ/', example: 'The goldfish circles its little glass world.', exampleCn: '金鱼绕着它的小玻璃世界打转。', category: 'animal', emoji: '🐠' },
  { word: 'butterfly', translation: '蝴蝶', phonetic: '/ˈbʌtəflaɪ/', example: 'A butterfly rested on the handlebar.', exampleCn: '一只蝴蝶停在车把上。', category: 'animal', emoji: '🦋' },
  { word: 'puppy', translation: '小狗', phonetic: '/ˈpʌpi/', example: 'The puppy chased its own tail in the yard.', exampleCn: '小狗在院子里追自己的尾巴。', category: 'animal', emoji: '🐶' },
  { word: 'plant', translation: '植物', phonetic: '/plɑːnt/', example: 'A green plant brightens the whole desk.', exampleCn: '一株绿植点亮了整张书桌。', category: 'nature', emoji: '🪴' },
  { word: 'car', translation: '汽车', phonetic: '/kɑː/', example: 'A red car waited at the traffic light.', exampleCn: '一辆红色汽车在红绿灯前等待。', category: 'object', emoji: '🚗' },
  { word: 'table', translation: '桌子', phonetic: '/ˈteɪbl/', example: 'The table was set for two.', exampleCn: '桌子上摆好了两人份的餐具。', category: 'object', emoji: '🪑' },
  { word: 'building', translation: '建筑', phonetic: '/ˈbɪldɪŋ/', example: 'The old building glows at sunset.', exampleCn: '日落时分老建筑泛着光。', category: 'place', emoji: '🏢' },
  { word: 'person', translation: '人', phonetic: '/ˈpɜːsn/', example: 'A person waved from across the street.', exampleCn: '街对面有人挥了挥手。', category: 'object', emoji: '🧍' }
];
