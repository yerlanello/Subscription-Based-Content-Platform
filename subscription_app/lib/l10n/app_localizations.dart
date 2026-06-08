import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';

class L10n {
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'feed': 'Feed',
      'authors': 'Authors',
      'posts': 'Posts',
      'account': 'Account',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'edit_profile': 'Edit Profile',
      'change_avatar': 'Change Avatar',
      'become_creator': 'Become a Creator',
      'my_subscriptions': 'My Subscriptions',
      'new_post': 'New Post',
      'my_posts': 'My Posts',
      'subscribe': 'Subscribe',
      'subscribed': 'Subscribed',
      'subscribe_free': 'Subscribe (Free)',
      'follow': 'Follow',
      'following': 'Following',
      'unfollow': 'Unfollow',
      'unsubscribe': 'Unsubscribe',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'publish': 'Publish',
      'unpublish': 'Unpublish',
      'edit': 'Edit',
      'draft': 'Draft',
      'published': 'Published',
      'paid': 'Paid',
      'free_post': 'Free post',
      'free_post_subtitle': 'Visible to everyone, not just subscribers',
      'publish_immediately': 'Publish immediately',
      'publish_immediately_subtitle': 'Leave off to save as draft',
      'title': 'Title',
      'content': 'Content',
      'bio': 'Bio',
      'write_something': 'Write something...',
      'what_is_post_about': 'What is this post about?',
      'add_attachments': 'Add Images',
      'no_posts_yet': 'No posts yet',
      'feed_empty': 'Your feed is empty',
      'feed_empty_subtitle': 'Subscribe to creators to see their posts here.',
      'no_notifications': 'No notifications',
      'no_notifications_subtitle': 'You\'re all caught up!',
      'mark_all_read': 'Mark all read',
      'appearance': 'Appearance',
      'language': 'Language',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'preferences': 'PREFERENCES',
      'privacy_security': 'PRIVACY & SECURITY',
      'about': 'ABOUT',
      'change_password': 'Change Password',
      'privacy_policy': 'Privacy Policy',
      'terms_of_service': 'Terms of Service',
      'app_version': 'App Version',
      'help_support': 'Help & Support',
      'log_out': 'Log Out',
      'subscriptions': 'Subscriptions',
      'following_count': 'Following',
      'role': 'Role',
      'creator': 'CREATOR',
      'profile': 'PROFILE',
      'retry': 'Retry',
      'refresh': 'Refresh',
      'post_saved': 'Post saved!',
      'post_published': 'Post published!',
      'draft_saved': 'Draft saved.',
      'post_deleted': 'Post deleted',
      'title_required': 'Title is required',
      'unsubscribe_confirm': 'Unsubscribe?',
      'delete_post_confirm': 'Delete post?',
      'delete_cannot_undo': 'This cannot be undone.',
      'comments': 'Comments',
      'no_comments': 'No comments yet. Be the first!',
      'reply': 'Reply',
      'write_comment': 'Write a comment…',
      'replying_to': 'Replying to',
      'subscribe_to_read': 'Subscribe to read this post',
      'support_creators': 'Support your favourite creators',
      'exclusive_content': 'Subscribe and get exclusive content',
      'search_creators': 'Search creators…',
      'no_creators_yet': 'No creators yet.',
      'no_match_search': 'No creators match your search.',
      'current_password': 'Current password',
      'new_password': 'New password',
      'confirm_password': 'Confirm new password',
      'passwords_no_match': 'Passwords do not match',
      'password_changed': 'Password changed successfully',
      'wrong_password': 'Current password is incorrect',
      'subscribers': 'Subscribers',
      'followers': 'Followers',
      'filter_all': 'All',
      'filter_free': 'Free',
      'filter_paid': 'Paid',
      'pinned': 'Pinned',
      'pin': 'Pin post',
      'unpin': 'Unpin post',
      'no_subscriptions': 'No subscriptions yet',
      'no_subscriptions_subtitle': 'Subscribe to a creator to see them here.',
      'not_a_creator': 'Not a creator',
      'not_a_creator_subtitle': 'This user hasn\'t set up a creator profile.',
      'dashboard': 'Dashboard',
      'creator_dashboard': 'Creator Dashboard',
      'my_profile': 'My profile',
      'free_subscription': 'Free subscription',
      'per_month': '/mo',
      'edit_creator_profile': 'Edit creator profile',
      'profile_settings': 'Profile settings',
      'cover_banner': 'Banner cover',
      'cover_banner_hint': 'Banner cover — JPG, PNG, WebP',
      'upload_cover': 'Upload cover',
      'uploading_cover': 'Uploading…',
      'display_name': 'Display name',
      'about_me': 'About me',
      'category': 'Category',
      'choose_category': 'Choose a category',
      'subscription_price': 'Subscription price (₸, 0 = free)',
      'subscription_price_hint': 'Example: 500 ₸',
      'subscription_benefits': 'What subscribers will get',
      'profile_saved': 'Profile saved',
      'cat_music': 'Music',
      'cat_art': 'Art',
      'cat_podcasts': 'Podcasts',
      'cat_games': 'Games',
      'cat_education': 'Education',
      'cat_other': 'Other',
    },
    'ru': {
      'feed': 'Лента',
      'authors': 'Авторы',
      'posts': 'Посты',
      'account': 'Аккаунт',
      'settings': 'Настройки',
      'notifications': 'Уведомления',
      'edit_profile': 'Редактировать профиль',
      'change_avatar': 'Изменить аватар',
      'become_creator': 'Стать автором',
      'my_subscriptions': 'Мои подписки',
      'new_post': 'Новый пост',
      'my_posts': 'Мои посты',

      // Paid subscription
      'subscribe': 'Оформить подписку',
      'subscribed': 'Подписка активна ✓',
      'subscribe_free': 'Бесплатная подписка',
      'unsubscribe': 'Отменить подписку',

      // Social follow
      'follow': 'Подписаться',
      'following': 'Вы подписаны',
      'unfollow': 'Отписаться',

      'save': 'Сохранить',
      'cancel': 'Отмена',
      'delete': 'Удалить',
      'publish': 'Опубликовать',
      'unpublish': 'Скрыть',
      'edit': 'Редактировать',
      'draft': 'Черновик',
      'published': 'Опубликован',
      'paid': 'Платный',

      'free_post': 'Бесплатный пост',
      'free_post_subtitle': 'Виден всем, не только подписчикам',

      'publish_immediately': 'Опубликовать сразу',
      'publish_immediately_subtitle': 'Выключите, чтобы сохранить как черновик',

      'title': 'Заголовок',
      'content': 'Контент',
      'bio': 'О себе',

      'write_something': 'Напишите что-нибудь...',
      'what_is_post_about': 'О чём этот пост?',
      'add_attachments': 'Добавить изображения',

      'no_posts_yet': 'Постов пока нет',
      'feed_empty': 'Лента пока пуста',
      'feed_empty_subtitle':
          'Подпишитесь на авторов, чтобы видеть их посты.',

      'no_notifications': 'Нет уведомлений',
      'no_notifications_subtitle': 'Всё прочитано!',
      'mark_all_read': 'Отметить всё как прочитанное',

      'appearance': 'Оформление',
      'language': 'Язык',

      'light': 'Светлая',
      'dark': 'Тёмная',
      'system': 'Системная',

      'preferences': 'НАСТРОЙКИ',
      'privacy_security': 'КОНФИДЕНЦИАЛЬНОСТЬ',
      'about': 'О ПРИЛОЖЕНИИ',

      'change_password': 'Изменить пароль',
      'privacy_policy': 'Политика конфиденциальности',
      'terms_of_service': 'Условия использования',
      'app_version': 'Версия приложения',
      'help_support': 'Помощь и поддержка',
      'log_out': 'Выйти',

      'subscriptions': 'Подписки',
      'following_count': 'Подписки',

      'role': 'Роль',
      'creator': 'АВТОР',
      'profile': 'ПРОФИЛЬ',

      'retry': 'Повторить',
      'refresh': 'Обновить',

      'post_saved': 'Пост сохранён!',
      'post_published': 'Пост опубликован!',
      'draft_saved': 'Черновик сохранён.',
      'post_deleted': 'Пост удалён',

      'title_required': 'Введите заголовок',

      'unsubscribe_confirm': 'Отменить подписку?',
      'delete_post_confirm': 'Удалить пост?',
      'delete_cannot_undo': 'Это действие нельзя отменить.',

      'comments': 'Комментарии',
      'no_comments': 'Комментариев пока нет. Будьте первым!',
      'reply': 'Ответить',
      'write_comment': 'Написать комментарий…',
      'replying_to': 'В ответ на',

      'subscribe_to_read': 'Оформите подписку, чтобы читать этот пост',
      'support_creators': 'Поддержите любимых авторов',
      'exclusive_content': 'Подпишитесь и получите эксклюзивный контент',

      'search_creators': 'Поиск авторов…',
      'no_creators_yet': 'Авторов пока нет.',
      'no_match_search': 'Авторы не найдены.',

      'current_password': 'Текущий пароль',
      'new_password': 'Новый пароль',
      'confirm_password': 'Подтвердите новый пароль',

      'passwords_no_match': 'Пароли не совпадают',
      'password_changed': 'Пароль успешно изменён',
      'wrong_password': 'Неверный текущий пароль',

      'subscribers': 'Подписчики',
      'followers': 'Подписчики',

      'filter_all': 'Все',
      'filter_free': 'Бесплатные',
      'filter_paid': 'Платные',

      'pinned': 'Закреплено',
      'pin': 'Закрепить',
      'unpin': 'Открепить',

      'no_subscriptions': 'Подписок пока нет',
      'no_subscriptions_subtitle':
          'Оформите подписку на автора, чтобы увидеть его здесь.',

      'not_a_creator': 'Не автор',
      'not_a_creator_subtitle':
          'Этот пользователь ещё не настроил профиль автора.',
      'dashboard': 'Кабинет',
      'creator_dashboard': 'Кабинет автора',
      'my_profile': 'Мой профиль',
      'free_subscription': 'Бесплатная подписка',
      'per_month': '/мес',
      'edit_creator_profile': 'Редактировать профиль автора',
      'profile_settings': 'Настройки профиля',
      'cover_banner': 'Обложка',
      'cover_banner_hint': 'Обложка-баннер — JPG, PNG, WebP',
      'upload_cover': 'Загрузить обложку',
      'uploading_cover': 'Загрузка…',
      'display_name': 'Отображаемое имя',
      'about_me': 'О себе',
      'category': 'Категория',
      'choose_category': 'Выберите категорию',
      'subscription_price': 'Цена подписки (₸, 0 = бесплатно)',
      'subscription_price_hint': 'Например: 500 ₸',
      'subscription_benefits': 'Что получат подписчики',
      'profile_saved': 'Профиль сохранён',
      'cat_music': 'Музыка',
      'cat_art': 'Искусство',
      'cat_podcasts': 'Подкасты',
      'cat_games': 'Игры',
      'cat_education': 'Образование',
      'cat_other': 'Другое',
    },
    'kk': {
      'feed': 'Таспа',
      'authors': 'Авторлар',
      'posts': 'Жазбалар',
      'account': 'Аккаунт',
      'settings': 'Параметрлер',
      'notifications': 'Хабарландырулар',
      'edit_profile': 'Профильді өңдеу',
      'change_avatar': 'Аватарды өзгерту',
      'become_creator': 'Автор болу',
      'my_subscriptions': 'Менің жазылымдарым',
      'new_post': 'Жаңа жазба',
      'my_posts': 'Менің жазбаларым',

      // Paid subscription
      'subscribe': 'Жазылым рәсімдеу',
      'subscribed': 'Жазылым белсенді ✓',
      'subscribe_free': 'Тегін жазылым',
      'unsubscribe': 'Жазылымнан бас тарту',

      // Social follow
      'follow': 'Жазылу',
      'following': 'Жазылған',
      'unfollow': 'Жазылымнан шығу',

      'save': 'Сақтау',
      'cancel': 'Болдырмау',
      'delete': 'Жою',
      'publish': 'Жариялау',
      'unpublish': 'Жасыру',
      'edit': 'Өңдеу',

      'draft': 'Жоба',
      'published': 'Жарияланды',
      'paid': 'Ақылы',

      'free_post': 'Тегін жазба',
      'free_post_subtitle':
          'Барлығына көрінеді, тек жазылушыларға ғана емес',

      'publish_immediately': 'Бірден жариялау',
      'publish_immediately_subtitle':
          'Жоба ретінде сақтау үшін өшіріңіз',

      'title': 'Тақырып',
      'content': 'Контент',
      'bio': 'Өзім туралы',

      'write_something': 'Бірдеңе жазыңыз...',
      'what_is_post_about': 'Бұл жазба не туралы?',
      'add_attachments': 'Суреттер қосу',

      'no_posts_yet': 'Әлі жазбалар жоқ',
      'feed_empty': 'Таспа бос',
      'feed_empty_subtitle':
          'Жазбаларын көру үшін авторларға жазылыңыз.',

      'no_notifications': 'Хабарландырулар жоқ',
      'no_notifications_subtitle': 'Барлығы оқылды!',

      'mark_all_read': 'Барлығын оқылды деп белгілеу',

      'appearance': 'Көрініс',
      'language': 'Тіл',

      'light': 'Ашық',
      'dark': 'Қараңғы',
      'system': 'Жүйелік',

      'preferences': 'ПАРАМЕТРЛЕР',
      'privacy_security': 'ҚҰПИЯЛЫЛЫҚ',
      'about': 'ҚОЛДАНБА ТУРАЛЫ',

      'change_password': 'Құпия сөзді өзгерту',
      'privacy_policy': 'Құпиялылық саясаты',
      'terms_of_service': 'Пайдалану шарттары',

      'app_version': 'Қолданба нұсқасы',
      'help_support': 'Көмек және қолдау',
      'log_out': 'Шығу',

      'subscriptions': 'Жазылымдар',
      'following_count': 'Жазылғандар',

      'role': 'Рөл',
      'creator': 'АВТОР',
      'profile': 'ПРОФИЛЬ',

      'retry': 'Қайталау',
      'refresh': 'Жаңарту',

      'post_saved': 'Жазба сақталды!',
      'post_published': 'Жазба жарияланды!',
      'draft_saved': 'Жоба сақталды.',
      'post_deleted': 'Жазба жойылды',

      'title_required': 'Тақырып міндетті',

      'unsubscribe_confirm': 'Жазылымнан бас тартасыз ба?',
      'delete_post_confirm': 'Жазбаны жою керек пе?',
      'delete_cannot_undo': 'Бұл әрекетті қайтару мүмкін емес.',

      'comments': 'Пікірлер',
      'no_comments': 'Әлі пікір жоқ. Бірінші болыңыз!',
      'reply': 'Жауап беру',

      'write_comment': 'Пікір жазыңыз…',
      'replying_to': 'Жауап ретінде',

      'subscribe_to_read': 'Бұл жазбаны оқу үшін жазылыңыз',

      'support_creators': 'Сүйікті авторларыңызды қолдаңыз',
      'exclusive_content':
          'Жазылып, эксклюзивті контент алыңыз',

      'search_creators': 'Авторларды іздеу…',

      'no_creators_yet': 'Әлі авторлар жоқ.',
      'no_match_search': 'Авторлар табылмады.',

      'current_password': 'Ағымдағы құпия сөз',
      'new_password': 'Жаңа құпия сөз',

      'confirm_password': 'Жаңа құпия сөзді растаңыз',

      'passwords_no_match': 'Құпия сөздер сәйкес келмейді',
      'password_changed': 'Құпия сөз сәтті өзгертілді',

      'wrong_password': 'Ағымдағы құпия сөз қате',

      'subscribers': 'Жазылушылар',
      'followers': 'Жазылушылар',

      'filter_all': 'Барлығы',
      'filter_free': 'Тегін',
      'filter_paid': 'Ақылы',

      'pinned': 'Бекітілді',
      'pin': 'Бекіту',
      'unpin': 'Бекітуден шығару',

      'no_subscriptions': 'Әлі жазылымдар жоқ',
      'no_subscriptions_subtitle':
          'Авторға жазылып, оны осы жерден көріңіз.',

      'not_a_creator': 'Автор емес',
      'not_a_creator_subtitle':
          'Бұл пайдаланушы автор профилін әлі орнатпаған.',
      'dashboard': 'Кабинет',
      'creator_dashboard': 'Автор кабинеті',
      'my_profile': 'Менің профилім',
      'free_subscription': 'Тегін жазылым',
      'per_month': '/ай',
      'edit_creator_profile': 'Автор профилін өңдеу',
      'profile_settings': 'Профиль баптаулары',
      'cover_banner': 'Мұқаба',
      'cover_banner_hint': 'Мұқаба баннері — JPG, PNG, WebP',
      'upload_cover': 'Мұқаба жүктеу',
      'uploading_cover': 'Жүктелуде…',
      'display_name': 'Көрсетілетін аты',
      'about_me': 'Өзім туралы',
      'category': 'Санат',
      'choose_category': 'Санатты таңдаңыз',
      'subscription_price': 'Жазылым бағасы (₸, 0 = тегін)',
      'subscription_price_hint': 'Мысалы: 500 ₸',
      'subscription_benefits': 'Жазылушылар не алады',
      'profile_saved': 'Профиль сақталды',
      'cat_music': 'Музыка',
      'cat_art': 'Өнер',
      'cat_podcasts': 'Подкасттар',
      'cat_games': 'Ойындар',
      'cat_education': 'Білім',
      'cat_other': 'Басқа',
    },
  };

  static String t(String key) {
    final loc = AppSettingsService.locale.value;
    return _strings[loc]?[key] ?? _strings['en']?[key] ?? key;
  }

  static String get currentLanguageLabel {
    switch (AppSettingsService.locale.value) {
      case 'ru':
        return 'Русский';
      case 'kk':
        return 'Қазақша';
      default:
        return 'English';
    }
  }

  static Locale get currentLocale {
    switch (AppSettingsService.locale.value) {
      case 'ru':
        return const Locale('ru');
      case 'kk':
        return const Locale('kk');
      default:
        return const Locale('en');
    }
  }
}
