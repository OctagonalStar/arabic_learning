import 'package:arabic_learning/models/dict.dart';
import 'package:arabic_learning/services/memberships.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WordMembershipIndex 反查全部归属并按词库/课程顺序返回', () {
    const List<SourceItem> classes = <SourceItem>[
      SourceItem(
        sourceJsonFileName: 'a.json',
        displayName: '词库A',
        subClasses: <ClassItem>[
          ClassItem(className: '第一课', wordIndexs: <int>[0, 1]),
        ],
      ),
      SourceItem(
        sourceJsonFileName: 'b.json',
        displayName: '词库B',
        subClasses: <ClassItem>[
          ClassItem(className: '课程一', wordIndexs: <int>[1]),
          ClassItem(className: '课程二', wordIndexs: <int>[1]),
        ],
      ),
    ];

    final WordMembershipIndex index = WordMembershipIndex.instance;
    index.rebuild(classes);

    expect(index.isReady, isTrue);
    expect(
      index.of(0).map((WordMembership m) => m.label).toList(),
      <String>['词库A › 第一课'],
    );
    expect(
      index.of(1).map((WordMembership m) => m.label).toList(),
      <String>['词库A › 第一课', '词库B › 课程一', '词库B › 课程二'],
    );
    expect(index.of(9), isEmpty);

    index.clear();
    expect(index.isReady, isFalse);
  });
}
