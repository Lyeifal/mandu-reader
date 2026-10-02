import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/jm/jm_models.dart';

void main() {
  group('收藏夹解析', () {
    test('list + folder_list + total', () {
      final page = JmFavoritePage.fromJson(
        jsonDecode('''
        {
          "list": [
            {"id": "363859", "author": "紺菓", "name": "[無邪氣] 測試本",
             "category": {"id": "1", "title": "同人"}, "image": ""}
          ],
          "folder_list": [
            {"0": "87", "FID": "123", "1": "456", "UID": "456",
             "2": "默认收藏", "name": "默认收藏"}
          ],
          "total": "87", "count": 20
        }
        ''') as Map<String, dynamic>,
      );
      expect(page.total, 87);
      expect(page.items.single.albumId, '363859');
      expect(page.items.single.category, '同人');
      expect(page.folders.single.fid, '123');
      expect(page.folders.single.name, '默认收藏');
      expect(page.folders.single.count, 87);
    });

    test('folder_list 缺 name 时回退数字键', () {
      final page = JmFavoritePage.fromJson(
        jsonDecode('''
        {"list": [], "folder_list": [{"0": "3", "FID": "9", "2": "备用"}],
         "total": "3"}
        ''') as Map<String, dynamic>,
      );
      expect(page.folders.single.name, '备用');
      expect(page.folders.single.count, 3);
    });
  });

  group('登录结果解析', () {
    test('uid/用户名/收藏数/等级', () {
      final info = JmLoginInfo.fromJson(
        jsonDecode('''
        {"uid": "123", "username": "tester", "album_favorites": "42",
         "level_name": "LV5", "s": "token"}
        ''') as Map<String, dynamic>,
      );
      expect(info.uid, '123');
      expect(info.username, 'tester');
      expect(info.albumFavorites, 42);
      expect(info.levelName, 'LV5');
    });
  });
}
