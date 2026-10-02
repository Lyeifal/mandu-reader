/// 从对象 key 列表里挑漫画页面：三位数字命名的才算（封面/章节表剔除）。
/// 云端压缩与人工审阅共用。纯函数，单测对象。

/// 与 cloud_compress 曾内联的版本保持一致的正则。
final _pageKeyRe = RegExp(r'/(\d{3})\.\w+$');

List<String> pageKeysOf(List<String> keys) =>
    keys.where(_pageKeyRe.hasMatch).toList()..sort();
