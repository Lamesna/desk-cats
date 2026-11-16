// English text is the key. Russian and Chinese dictionaries, same as the macOS app.
(function (K) {
  'use strict';

  K.langs = [
    { id: 'en', title: 'English' },
    { id: 'ru', title: 'Русский' },
    { id: 'zh', title: '中文' },
  ];
  K.lang = 'en';

  K.detectLang = function (locale) {
    const l = String(locale || '').toLowerCase();
    if (l.startsWith('ru')) return 'ru';
    if (l.startsWith('zh')) return 'zh';
    return 'en';
  };

  K.catNames = {
    en: ['Whiskers', 'Misty', 'Fluffy', 'Ginger', 'Smokey', 'Simba', 'Luna', 'Hush', 'Muffin', 'Mochi',
      'Bun', 'Fenya', 'Sleepy', 'Bagel', 'Peach', 'Ember', 'Snowball', 'Marquis', 'Nightie', 'Pumpkin'],
    ru: ['Барсик', 'Мурка', 'Пушок', 'Рыжик', 'Дымка', 'Симба', 'Луна', 'Тиша', 'Кекс', 'Масик',
      'Плюша', 'Феня', 'Соня', 'Бублик', 'Персик', 'Уголёк', 'Снежок', 'Маркиз', 'Ночка', 'Тыковка'],
    zh: ['咪咪', '小花', '毛毛', '橘子', '烟烟', '辛巴', '露娜', '团团', '蛋糕', '麻糬',
      '包子', '豆豆', '瞌睡', '贝果', '桃桃', '煤球', '雪球', '侯爵', '夜夜', '南瓜'],
  };

  const ru = {
    'Language': 'Язык',
    'Cats are roaming your screen': 'Коты гуляют по экрану',
    'All cats are hidden. Switch on to bring them back.': 'Все коты спрятаны. Включите, чтобы вернуть.',
    'Add a cat': 'Добавить кота',
    'Laser pointer instead of cursor': 'Лазерная указка вместо курсора',
    'Care': 'Уход',
    'Food bowl': 'Миска корма', 'Water bowl': 'Миска воды', 'Refill food': 'Насыпать корм', 'Refill water': 'Налить воду',
    'Feed everyone': 'Покормить всех', 'Remove bowls': 'Убрать миски',
    'Click anywhere on the screen to place the bowl. Right-click to cancel.': 'Кликните в любое место экрана, чтобы поставить миску. Правый клик: отмена.',
    '• Hold the cursor over a cat and it purrs': '• Подержите курсор на коте, и он замурчит',
    '• Ctrl + drag: pick up a cat or a bowl': '• Ctrl + перетаскивание: взять кота или миску',
    '• Close a window and the cat on it tumbles down': '• Закроете окно, и кот с него свалится',
    'Quit (remove all cats)': 'Выйти (убрать всех котов)',
    'Hidden': 'Спрятан', 'Hide': 'Спрятать', 'Show': 'Выпустить', 'Customize': 'Настроить',
    'Back': 'Назад', 'Name': 'Имя', 'Size': 'Размер', 'Coat': 'Окрас', 'Eyes': 'Глаза', 'Hat': 'Шапка', 'Costume': 'Костюм',
    'Delete cat': 'Удалить кота', 'Done': 'Готово', 'Cat': 'Кот', 'Show cats': 'Показать котов',
    'Gray and white': 'Серо-белый', 'Ginger': 'Рыжий', 'Black': 'Чёрный', 'White': 'Белый', 'Blue': 'Голубой',
    'Ginger and white': 'Рыже-белый', 'Tuxedo': 'Смокинг', 'Calico': 'Трёхцветный', 'Tortoiseshell': 'Черепаховый',
    'Gray tabby': 'Серый полосатый', 'Brown tabby': 'Бурый полосатый', 'Cream': 'Кремовый', 'Siamese': 'Сиамский',
    'Chocolate': 'Шоколадный', 'Smoky': 'Дымчатый', 'Silver': 'Серебристый', 'Peach': 'Персиковый', 'Black and white': 'Чёрно-белый',
    'Green eyes': 'Зелёные', 'Yellow eyes': 'Жёлтые', 'Amber eyes': 'Янтарные', 'Blue eyes': 'Голубые',
    'Copper eyes': 'Медные', 'Odd eyes': 'Разные',
    'No hat': 'Без шапки', 'Shark': 'Акула', 'Frog': 'Лягушка', 'Crown': 'Корона', 'Party hat': 'Колпак', 'Bow': 'Бантик',
    'Spider mask': 'Маска паука', 'Horned helm': 'Рогатый шлем', 'Winged helm': 'Крылатый шлем', 'Chick': 'Цыплёнок',
    'Black jester': 'Чёрный шут', 'Banana': 'Банан', 'Dinosaur': 'Динозавр', 'Panda': 'Панда', 'Bunny': 'Зайка',
    'Red cap': 'Красная кепка', 'Bee': 'Пчёлка', 'Cowboy': 'Ковбой', 'Teddy bear': 'Мишка', 'Penguin': 'Пингвин',
    'Mercenary mask': 'Маска наёмника', 'Witch': 'Ведьма', 'Monster': 'Монстрик', 'Ghost': 'Призрак', 'Unicorn': 'Единорог',
    'Pink dino': 'Розовый дино', 'Vampire': 'Вампир', 'Santa': 'Дед Мороз', 'Top hat': 'Цилиндр',
    'Star helmet': 'Шлем со звездой', 'Iron helmet': 'Железный шлем',
    'No costume': 'Без костюма', 'Hero cape': 'Плащ героя', 'Bow tie': 'Бабочка', 'Star shield': 'Щит со звездой',
    'Glowing reactor': 'Сияющий реактор', 'Overalls': 'Комбинезон', 'Bow jumpsuit': 'Комбез с бантиком', 'Wizard': 'Волшебник',
    'Froggy': 'Лягушонок', 'Mercenary': 'Наёмник', 'Spider': 'Паук', 'Royal robe': 'Королевская мантия', 'Party': 'Праздничный',
    'Trickster': 'Трикстер', 'Jester': 'Шут',
    'Sleeping 💤': 'Спит 💤', 'Offended 💢': 'Обиделся 💢', 'Eating': 'Кушает', 'Drinking': 'Пьёт', 'Purring ♥': 'Мурчит ♥',
    'Sharpening claws': 'Точит когти', 'Climbing up': 'Лезет наверх', 'Dangling': 'Висит в лапах', 'Hunting': 'Охотится',
    'Hanging on the cursor': 'Висит на курсоре', 'Stalking': 'Крадётся', 'About to pounce': 'Сейчас прыгнет',
    'Climbing the screen edge': 'Лезет по краю экрана', 'Hanging under a window': 'Висит под окном', 'Sliding down': 'Сползает вниз',
    'Scratching the screen edge': 'Точит когти о край экрана', 'Sniffing noses': 'Нюхается', 'Boxing': 'Боксирует',
    'Play-fighting': 'Дерётся понарошку', 'Playing tag': 'Играет в догонялки', 'Playing': 'Играет', 'Hungry': 'Голодный',
    'Thirsty': 'Хочет пить', 'Sleepy': 'Сонный', 'Bored': 'Скучает', 'Roaming': 'Гуляет', 'Sitting on a window': 'Сидит на окне',
    'Meow?!': 'Мяу?!', 'Meow!!': 'Мяу!!', 'Meow!': 'Мяу!', 'Meow~': 'Мяу~', 'Mew!': 'Мяв!', 'Meeow!': 'Мяяу!',
  };

  const zh = {
    'Language': '语言',
    'Cats are roaming your screen': '小猫们正在屏幕上闲逛',
    'All cats are hidden. Switch on to bring them back.': '所有小猫都藏起来了。打开开关，它们就会回来。',
    'Add a cat': '添加小猫',
    'Laser pointer instead of cursor': '用激光笔代替光标',
    'Care': '照顾',
    'Food bowl': '猫粮碗', 'Water bowl': '水碗', 'Refill food': '添加猫粮', 'Refill water': '加水',
    'Feed everyone': '喂饱所有小猫', 'Remove bowls': '收起碗',
    'Click anywhere on the screen to place the bowl. Right-click to cancel.': '点击屏幕任意位置放下碗，右键取消。',
    '• Hold the cursor over a cat and it purrs': '• 把光标停在小猫身上，它就会打呼噜',
    '• Ctrl + drag: pick up a cat or a bowl': '• 按住 Ctrl 拖动：拎起小猫或碗',
    '• Close a window and the cat on it tumbles down': '• 关掉窗口，窗口上的小猫会摔下来',
    'Quit (remove all cats)': '退出（移除所有小猫）',
    'Hidden': '已隐藏', 'Hide': '隐藏', 'Show': '放出来', 'Customize': '自定义',
    'Back': '返回', 'Name': '名字', 'Size': '大小', 'Coat': '毛色', 'Eyes': '眼睛', 'Hat': '帽子', 'Costume': '服装',
    'Delete cat': '删除小猫', 'Done': '完成', 'Cat': '小猫', 'Show cats': '显示小猫',
    'Gray and white': '灰白色', 'Ginger': '橘色', 'Black': '黑色', 'White': '白色', 'Blue': '蓝灰色',
    'Ginger and white': '橘白色', 'Tuxedo': '黑白燕尾服色', 'Calico': '三花', 'Tortoiseshell': '玳瑁色',
    'Gray tabby': '灰虎斑', 'Brown tabby': '棕虎斑', 'Cream': '奶油色', 'Siamese': '暹罗色',
    'Chocolate': '巧克力色', 'Smoky': '烟灰色', 'Silver': '银色', 'Peach': '桃色', 'Black and white': '黑白花',
    'Green eyes': '绿色眼睛', 'Yellow eyes': '黄色眼睛', 'Amber eyes': '琥珀色眼睛', 'Blue eyes': '蓝色眼睛',
    'Copper eyes': '铜色眼睛', 'Odd eyes': '异瞳',
    'No hat': '无帽子', 'Shark': '鲨鱼', 'Frog': '青蛙', 'Crown': '王冠', 'Party hat': '派对帽', 'Bow': '蝴蝶结',
    'Spider mask': '蜘蛛面具', 'Horned helm': '角盔', 'Winged helm': '翼盔', 'Chick': '小鸡',
    'Black jester': '黑色小丑', 'Banana': '香蕉', 'Dinosaur': '恐龙', 'Panda': '熊猫', 'Bunny': '兔子',
    'Red cap': '红帽子', 'Bee': '小蜜蜂', 'Cowboy': '牛仔', 'Teddy bear': '小熊', 'Penguin': '企鹅',
    'Mercenary mask': '佣兵面具', 'Witch': '女巫', 'Monster': '小怪兽', 'Ghost': '幽灵', 'Unicorn': '独角兽',
    'Pink dino': '粉色恐龙', 'Vampire': '吸血鬼', 'Santa': '圣诞老人', 'Top hat': '礼帽',
    'Star helmet': '星星头盔', 'Iron helmet': '铁头盔',
    'No costume': '无服装', 'Hero cape': '英雄披风', 'Bow tie': '领结', 'Star shield': '星星盾牌',
    'Glowing reactor': '发光反应堆', 'Overalls': '背带裤', 'Bow jumpsuit': '蝴蝶结连体衣', 'Wizard': '巫师',
    'Froggy': '小青蛙', 'Mercenary': '佣兵', 'Spider': '蜘蛛', 'Royal robe': '王袍', 'Party': '派对装',
    'Trickster': '诡计之神', 'Jester': '小丑',
    'Sleeping 💤': '睡觉中 💤', 'Offended 💢': '生气了 💢', 'Eating': '在吃东西', 'Drinking': '在喝水', 'Purring ♥': '呼噜呼噜 ♥',
    'Sharpening claws': '在磨爪子', 'Climbing up': '往上爬', 'Dangling': '被拎着', 'Hunting': '在捕猎',
    'Hanging on the cursor': '挂在光标上', 'Stalking': '悄悄靠近', 'About to pounce': '准备扑过去',
    'Climbing the screen edge': '在爬屏幕边缘', 'Hanging under a window': '挂在窗口下', 'Sliding down': '往下滑',
    'Scratching the screen edge': '在磨屏幕边缘', 'Sniffing noses': '碰碰鼻子', 'Boxing': '在打拳',
    'Play-fighting': '在打闹', 'Playing tag': '在玩追逐', 'Playing': '在玩耍', 'Hungry': '饿了',
    'Thirsty': '渴了', 'Sleepy': '困了', 'Bored': '无聊', 'Roaming': '闲逛中', 'Sitting on a window': '坐在窗口上',
    'Meow?!': '喵？！', 'Meow!!': '喵！！', 'Meow!': '喵！', 'Meow~': '喵~', 'Mew!': '咪！', 'Meeow!': '喵呜！',
  };

  K.tr = function (s) {
    if (K.lang === 'ru') return ru[s] || s;
    if (K.lang === 'zh') return zh[s] || s;
    return s;
  };
  K._dicts = { ru, zh };
})(globalThis.K = globalThis.K || {});
