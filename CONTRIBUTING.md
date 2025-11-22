# 开源项目贡献规则

本开源项目接受并鼓励各位懂得编程，设计，文档编写等各个方面的人参与项目开发。

你或许在查看 README 的时候，发现了损坏的链接，又或者拼写错误。又或者是你是一名新手，使用的过程中发现了问题，又或者是某问题应该在文档中注明。
请不要坐视不理，径直绕开，或者是请求他人修复，伸出你的援助之手，解决这些你能看到的问题。而这正是开源的精髓之所在！

> 如果你从未进行过贡献（甚至不知道PR是什么的），推荐你先阅读Github的[为开放源代码做出贡献文档](https://docs.github.com/zh/get-started/exploring-projects-on-github/contributing-to-open-source)和[Open Source Guides](https://opensource.guide/zh-hans/how-to-contribute/)

## 贡献流程

### 事前检查

在正式开始之前，做一些快速的检查项，以确保没有人讨论过你的想法。
比如在项目的Issues或Pull Requests中。

> 通常，我们会将已经计划好的更新/修复内容加入Issues中。

### 开始准备

如果你做的是一个非常实际的贡献（比如一个新的功能），在正式开启之前，先创建一个 issue。
并在里面**写明**你想要负责这项工作。

我们会尽快回复你的请求。如果你的请求合理，我们会将这项issue分配给你。

当然，如果你要提供一个bug的补丁，你也可以直接创建一个PR草稿。

### 尽早提起PR

一个 PR 并不代表着工作已经完成。
它通常是尽早的开启一个 PR，是为了其他人可以观看或者给作者反馈意见。只需要在子标题标记为”WIP”（正在进行中）。

### 申请审查

当你完成了你的提交后，你应当在Github的Pull Requests页面中申请进行审查，以便对你的贡献进行规范核查。

待审查通过后，你的提交就会被合并。

## 你必须做到的

请在你进行提交和PR时关注以下的问题:

### GPG验证

这个项目设置了必须要有GPG验证了是你的更改后才能进行合并。

> 如果你不知道GPG是什么，请参照[这篇文章](https://docs.github.com/zh/authentication/managing-commit-signature-verification/about-commit-signature-verification)

### DCO签名

参与本项目的开发需要你签署DCO(Developers Certificate of Origin)协议以避免相关版权问题。

协议内容详见 [DCO.md](DCO.md)

你可以通过 `git commit -s` 对提交进行签署。

## 其他的事项

### 代码规范

我们知道要让人们只遵循一个规范是基本不可能的。每个人都会有自己的开发风格，这无伤大雅，在开发时你只需要注意以下一些规范即可。

#### 类与函数的命名

在Dart/Flutter中有着明显的规则：

- 对于一个类，请使用大写字母或者下划线开头
- 对于一个函数，请使用小写字母开头

违反此规定的PR会要求进行相应修改后即可

#### 存储单词数据的变量

在应用中，存储单个阿拉伯语单词数据的变量使用`word`为变量名`Map<String, dynamic>`为其类型，内部详细结构如下

``` dart
Map<String, dynamic> word = {"arabic": "{Arabic}",
                             "chinese": "{Chinese}",
                             "explanation": "{explanation}",
                             "subClass": "{className}",
                             "learningProgress": "{times}", //int
                             "id": "{id}" // int getSelectedWords函数结果中会有，并且所有面向用户的界面中调用的数据都应具有此键值对。
                            };
```
