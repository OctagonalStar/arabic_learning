<!-- 提交前请阅读 CONTRIBUTING.md；标题建议使用 conventional commits（feat / fix / docs / chore …） -->

## 变更内容

<!-- 做了什么？为什么需要？ -->

-

## 关联 issue

<!-- 如 Closes #123；没有可留空 -->

## 变更类型

- [ ] 修复 bug
- [ ] 新功能
- [ ] 重构 / 性能优化
- [ ] 文档 / CI / 构建
- [ ] 其他

## 影响平台

- [ ] Android
- [ ] iOS（仅无签名 IPA）
- [ ] Windows
- [ ] Linux
- [ ] macOS
- [ ] Web

## 检查清单

- [ ] `flutter analyze` 无新增问题
- [ ] `flutter test` 通过
- [ ] 用户可见的变更已写入 `CHANGELOG.md`
- [ ] 新增的顶层存储键已加入 `SharedPreferences.usedKeys`（否则备份/恢复会丢数据）
- [ ] 新增按单词 id 关联的数据已处理 `AppData.compactUnreferencedWords` / `resetDictsPreservingFsrs` 等重排路径
- [ ] 新增原生依赖已确认 Web 端可编译（`fake_*.dart` 条件导入或运行时守卫），并重新生成 `lib/oss_licenses.dart`
- [ ] 提交已 `git commit -s`（DCO），且已 GPG 签名

## 截图 / 录屏

<!-- 有 UI 变化时附上，便于确认不同屏幕宽度下的表现 -->

## 备注

<!-- 已知限制、需要 reviewer 特别关注的地方 -->
