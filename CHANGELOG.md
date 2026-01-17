# Changelog

## v0.1.13 - ????-??-?? - (??????)

### Added

- 添加了备份数据文件导出功能 [#50](https://github.com/OctagonalStar/arabic_learning/issues/50)
- 添加了易混词偏好配置
- 添加了词汇查找功能 [#49](https://github.com/OctagonalStar/arabic_learning/issues/49)
- 添加了常见问题页面
- 给部分文本框添加了动画

### Improvement

- 优化了选择题单词挑选逻辑 [#48](https://github.com/OctagonalStar/arabic_learning/issues/48)
- 修复了BKTree日志刷屏问题
- 移除了提醒配置的中间页面

### Fix

- 将设置选项重新放回首页
- 修复了拼写题错误问题

## v0.1.12 - 2025-12-27 - (000112)

### Added

- 添加了日志捕获 [#23](https://github.com/OctagonalStar/arabic_learning/issues/23)
- 添加了调试页面
- 添加了个性化FSRS预设页面 [#26](https://github.com/OctagonalStar/arabic_learning/issues/26)
- 添加了安卓通知功能 [#24](https://github.com/OctagonalStar/arabic_learning/issues/24)
- 添加了题型可拖动提示 [#43](https://github.com/OctagonalStar/arabic_learning/issues/43)

### Improvement

- 优化了网页端字体加载逻辑
- 重构了Config数据结构 [#27](https://github.com/OctagonalStar/arabic_learning/issues/27)
- 重构了软件运行时数据结构 [#16](https://github.com/OctagonalStar/arabic_learning/issues/16)
- 优化连胜逻辑: FSRS复习也计算为连胜
- 调整了部分按钮的UI设计
- 去除了查看详解时，单词卡片的高斯模糊
- 按照FSRS学习单词计算总学习单词[#45](https://github.com/OctagonalStar/arabic_learning/issues/45)

### Fix

- 修复了FSRS算法对已经过期的单词无法计数的问题
- 修复了日志中FSRS信息输出错误的问题
- 修复了新用户无法进入的问题
- 修复了FSRS复习界面中，“下一题”动画期间文字溢出的问题
- 修复了固定列数文本溢出的问题[#44](https://github.com/OctagonalStar/arabic_learning/issues/44)

### Delete

- 移除了iOS系统的ipa安装支持

## v0.1.11 - 2025-11-28 - (000111)

### Added

- 添加了独立字体文件
- 支持了在浏览器上使用IndexDB存储数据`该更新将使你之前的浏览器中的存档无效`
- 添加了题目配置
- 添加了单词卡片题型
- 添加了拼写题型
- 添加了单词总览
- 添加了WebDav数据备份/恢复功能

### Improvement

- 支持自动对阿拉伯文字使用阿拉伯字体
- 移除了Google Font依赖(使用独立字体文件替代)
- 优化了软件打开逻辑
- 去除了HTTP依赖项
- 重构了InLearning加载
- 优化了主页面UI
- 优化了听写界面UI

### FIX

- 修复了FSRS页面中可能测试单词混乱的问题
- 修复了连胜天数显示
- 修复了激活彩蛋后更换主题时屏幕闪烁的问题
- 修复了每日单词重构后出现的卡死问题
- 修复了题目数量异常的问题

## v0.1.9 - 2025-11-9 - (000109)

### Added

- 添加了`开放源代码协议`页面
- 允许用户重新选择FSRS难度
- 添加了一个彩蛋( ~ 自己找去吧 ~ ) :D

### Improvement

- 优化了听写没选词时的逻辑
- 优化了更新日志弹窗逻辑
- 优化了 系统TTS和请求TTS 下的音频延迟
- 重构了学习页面
- 优化了FSRS学习页面逻辑

### Fix

- 修复了听写无法选词的bug

## v0.1.8 - 2025-11-2 - (000108)

### Added

- 实现了通过FSRS算法进行规律学习功能（基本实现）
- 添加了ChangeLog
- 添加了软件更新内容提示

### Improvement

- 重构了UI相关代码

### Fix

- 修复了混合学习中单词没有倍增的bug
- 修复了单词倍增错误出现的bug
- 修复了连胜天数计算错误

### NOTICE

此版本的连胜天数设置不再与之前的版本兼容

> 我之前怎么蠢到直接拿YYYYMMDD做int相减啊

## v0.1.7 - 2025-10-27 - (000107)

### Added

- 添加了自主听写功能

## v0.1.6 - 2025-10-22 - (000106)

### Added

- 添加了通过ViTS进行本地语音合成，引用项目地址

### Improvement

- 一些UI改善
- ...

## v0.1.5 - 2025-10-19 - (000105)

### Added

- 支持了连胜机制
- 支持了学习统计
- 完成了TODO: 中译阿题目
- 添加的抗遗忘学习（目前仅UI 具体实现在TODO #5）
- 其他细节更新

## v0.1.4 - 2025-10-18 - (000104)

### Added

实现了软件基础功能

- 阿拉伯语选中文
- 词库 (@JYinherit )
- 每日一词
- ...

网页版已通过Github Pages部署： [网页版](https://octagonalstar.github.io/arabic_learning/)

> 网页版使用的是最新构建版，相对于软件版本可能有更多功能和更多bug
> 目前软件处在快速开发阶段，功能还未完善。
