import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/reader/reader_page.dart';

void main() {
  group('parseHm', () {
    test('合法 HH:mm 解析为分钟数', () {
      expect(parseHm('20:00'), 1200);
      expect(parseHm('07:30'), 450);
      expect(parseHm('0:00'), 0);
      expect(parseHm('23:59'), 1439);
    });

    test('非法输入返回 null', () {
      expect(parseHm('24:00'), isNull);
      expect(parseHm('12:60'), isNull);
      expect(parseHm('abc'), isNull);
      expect(parseHm('12-30'), isNull);
      expect(parseHm(''), isNull);
    });
  });

  group('inNightWindow', () {
    test('同日窗口', () {
      expect(inNightWindow(8 * 60, 12 * 60, 10 * 60), isTrue);
      expect(inNightWindow(8 * 60, 12 * 60, 12 * 60), isFalse); // 半开区间
      expect(inNightWindow(8 * 60, 12 * 60, 7 * 60), isFalse);
    });

    test('跨零点窗口（20:00–07:00）', () {
      expect(inNightWindow(1200, 420, 23 * 60), isTrue);
      expect(inNightWindow(1200, 420, 6 * 60 + 59), isTrue);
      expect(inNightWindow(1200, 420, 7 * 60), isFalse);
      expect(inNightWindow(1200, 420, 12 * 60), isFalse);
    });
  });

  group('evaluateThemeSchedule', () {
    const night = 'night';

    test('off 恒不覆盖', () {
      expect(
        evaluateThemeSchedule('off', night, '20:00', '07:00', 23 * 60, true),
        isNull,
      );
    });

    test('system 跟随系统深色', () {
      expect(
        evaluateThemeSchedule('system', night, '', '', 12 * 60, true),
        night,
      );
      expect(
        evaluateThemeSchedule('system', night, '', '', 12 * 60, false),
        isNull,
      );
    });

    test('time 窗口内覆盖、窗口外不覆盖', () {
      expect(
        evaluateThemeSchedule('time', night, '20:00', '07:00', 23 * 60, false),
        night,
      );
      expect(
        evaluateThemeSchedule('time', night, '20:00', '07:00', 12 * 60, false),
        isNull,
      );
    });

    test('time 遇非法时段串回退不覆盖', () {
      expect(
        evaluateThemeSchedule('time', night, 'bad', '07:00', 23 * 60, false),
        isNull,
      );
    });
  });

  group('parseHexColor / formatHexColor', () {
    test('解析 #RRGGBB 与裸 RRGGBB，大小写不限', () {
      expect(parseHexColor('#C7EDCC'), const Color(0xFFC7EDCC));
      expect(parseHexColor('c7edcc'), const Color(0xFFC7EDCC));
      expect(parseHexColor('111318'), const Color(0xFF111318));
    });

    test('非法输入返回 null', () {
      expect(parseHexColor('#FFF'), isNull); // 3 位不支持
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#1234567'), isNull);
    });

    test('format→parse roundtrip', () {
      const c = Color(0xFF3A4A3C);
      expect(parseHexColor(formatHexColor(c)), c);
      expect(formatHexColor(const Color(0xFFFFFFFF)), '#FFFFFF');
      expect(formatHexColor(const Color(0xFF000000)), '#000000');
    });
  });

  group('fontFamilyFor', () {
    test('常规文件名：user_ + 基名', () {
      expect(fontFamilyFor('LXGW.ttf'), 'user_LXGW');
      expect(fontFamilyFor('SourceHanSerif.otf'), 'user_SourceHanSerif');
    });

    test('中文/空格/点号清洗为下划线', () {
      expect(fontFamilyFor('霞鹜文楷.ttf'), 'user_____'); // user_ + 4 字各换 _
      expect(fontFamilyFor('My Font.v2.ttf'), 'user_My_Font_v2');
    });

    test('空基名回退 font；无点号文件整体作基名', () {
      expect(fontFamilyFor(''), 'user_font');
      expect(fontFamilyFor('.ttf'), 'user__ttf');
    });
  });

  group('paginateNovel widthFactor', () {
    test('收紧行容量后长行更早折行（页数不减、行不超限）', () {
      final paras = ['汉字' * 50]; // 100 字
      final wide = paginateNovel(
        paras,
        contentWidth: 400,
        contentHeight: 100000,
        fontSize: 20,
      );
      final narrow = paginateNovel(
        paras,
        contentWidth: 400,
        contentHeight: 100000,
        fontSize: 20,
        widthFactor: 0.5,
      );
      // 容量减半 → 折行数至少翻倍
      expect(
        narrow.pages.single.length,
        greaterThan(wide.pages.single.length * 2 - 1),
      );
    });
  });
}
