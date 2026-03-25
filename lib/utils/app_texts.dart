class AppTexts {
  static const Map<String, Map<String, String>> translations = {
    'ru': {
      'orders': 'Заявки',
      'exchange': 'Биржа',
      'masters': 'Мастера',
      'income': 'Доходы',
      'documents': 'Документы',
      'my_buildings': 'Мои дома',
      'chats': 'Чаты',
      'profile': 'Профиль',
      'analytics': 'Аналитика',
      'knowledge': 'Знания',
      'help_menu': 'Меню помощи',
      'instruction': 'Инструкция',
      'support': 'Поддержка',
      'my_profile': 'Мой Профиль',
      'buy_template': 'Купить шаблон',
      'pay_button': 'Оплатить',
      'downloading': 'Загрузка...',
      'payment_success': '✅ Оплата прошла успешно!',
      'test_payment_desc': 'Это тестовый режим оплаты. Документ будет доступен после оплаты.',
    },
    'kk': {
      'orders': 'Өтінімдер',
      'exchange': 'Биржа',
      'masters': 'Шеберлер',
      'income': 'Табыстар',
      'documents': 'құжаттары',
      'my_buildings': 'Менің үйлерім',
      'chats': 'Чаттар',
      'profile': 'Профиль',
      'analytics': 'Аналитика',
      'knowledge': 'Білім',
      'help_menu': 'Көмек мәзірі',
      'instruction': 'Нұсқаулық',
      'support': 'Қолдау',
      'my_profile': 'Менің Профилім',
      'buy_template': 'Үлгіні сатып алу',
      'pay_button': 'Төлеу',
      'downloading': 'Жүктелуде...',
      'payment_success': '✅ Төлем сәтті өтті!',
      'test_payment_desc': 'Бұл тесттік төлем режимі. Құжат төлемнен кейін қолжетімді болады.',
    },
  };

  static String get(String key, String lang) {
    String shortLang = lang.length >= 2 ? lang.substring(0, 2).toLowerCase() : 'ru';
    return translations[shortLang]?[key] ?? translations['ru']![key] ?? key;
  }
}