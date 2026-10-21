// 单词总览页（含设置弹层与检索入口）：从 learning_pages_build.dart 拆分而来。
import 'dart:async';

import 'package:arabic_learning/core/extensions.dart' show StringExtensions;
import 'package:arabic_learning/screens/setting/dict_manage_page.dart' show DictManagePage;
import 'package:arabic_learning/services/app_data.dart' show AppData;
import 'package:arabic_learning/services/global_state.dart' show Global;
import 'package:arabic_learning/theme/tokens.dart' show AppMotion;
import 'package:arabic_learning/widgets/empty_dict_dialog.dart' show showEmptyDictDialog;
import 'package:arabic_learning/widgets/kit.dart' show Button;
import 'package:arabic_learning/widgets/shared.dart' show appInputDecoration;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'word_lookup_layout.dart';
import 'word_overview_layout.dart';

class WordCardOverViewPage extends StatefulWidget {
  const WordCardOverViewPage({super.key});

  @override
  State<StatefulWidget> createState() => _WordCardOverViewPage();
}

class _WordCardOverViewPage extends State<WordCardOverViewPage> {
  final TextEditingController searchController = TextEditingController();
  /// 搜索输入框焦点由页面显式管理：进入搜索时聚焦、退出或打开词卡时取消，
  /// 避免输入法在弹层关闭后自动重新唤起。
  final FocusNode _searchFocusNode = FocusNode();
  bool inSearch = false;

  /// 已提交给检索的查询串（实时模式下经防抖更新，避免每次按键都触发检索）
  String _query = "";
  Timer? _searchDebounce;

  void _toggleSearch() {
    _searchDebounce?.cancel();
    setState(() {
      inSearch = !inSearch;
      _query = inSearch ? searchController.text : "";
    });
    if (inSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && inSearch) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  /// 实时模式：输入停顿 200ms 后再检索
  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if(mounted) setState(() => _query = text);
    });
  }

  /// 立即检索（点击「查找」或回车）
  void _searchNow(String text) {
    _searchDebounce?.cancel();
    setState(() => _query = text);
  }

  @override
  void initState() {
    super.initState();
    // 词库为空时给出明确的引导弹窗（含「去导入词库」出口），
    // 替代原先没有任何反馈的空白页面。
    if (AppData().wordCount == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showEmptyDictDialog(
          context,
          // 跳转由 widget 层的调用方注入，避免 widgets/ 依赖 screens/。
          onImport: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (BuildContext context) => const DictManagePage()),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      // 搜索框位于 AppBar，键盘弹出时不应压缩 body：否则网格 LayoutBuilder
      // 会按缩短后的高度重算卡片尺寸，导致搜索结果卡片整体缩放/重排。
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        bottom: inSearch ? PreferredSize(
          preferredSize: Size(mediaQuery.size.width, 75), 
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: inSearch ? 1.0 : 0.0), 
            duration: AppMotion.quick, 
            curve: AppMotion.standardCurve,
            builder: (context, value, child){
              return Center(
                child: SizedBox(
                  width: mediaQuery.size.width * value,
                  child: TextField(
                    textDirection: searchController.text.textDirection,
                    controller: searchController,
                    focusNode: _searchFocusNode,
                    expands: false,
                    maxLines: 1,
                    decoration: appInputDecoration(
                      context,
                      labelText: "词汇检索",
                      hintText: "阿语单词或中文释义",
                      suffix: Button(
                        onPressed: () => _searchNow(searchController.text), 
                        child: Text("查找")
                      ),
                    ),
                    onSubmitted: (text) {
                      _searchNow(text);
                    },
                    onChanged: AppData().config.learning.wordLookupRealtime ? _onSearchChanged : null,
                  ),
                ),
              );
            }
          )
        ) : null,
        title: Text(inSearch ? "单词检索" : "单词总览"),
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: inSearch ? Icon(Icons.search_off) : Icon(Icons.search)
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context, 
                builder: (context) {
                  // 主题的 bottomSheetTheme 已统一提供拖拽横条（showDragHandle: true），
                  // 这里不能再嵌套 BottomSheet，否则会渲染出两条拖拽横条。
                  int forceCloumn = AppData().config.learning.overviewForceColumn;
                  bool lookupRealtime = AppData().config.learning.wordLookupRealtime;
                  return StatefulBuilder(
                        builder: (context, setLocalState) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text("设置固定列数"),
                                  Slider(
                                    min: 0,
                                    max: 5,
                                    divisions: 5,
                                    value: forceCloumn.toDouble(), 
                                    onChanged: (value){
                                      setLocalState(() {
                                        forceCloumn = value.ceil();
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      context.read<Global>().uiLogger.info("设置固定列数为$value");
                                    },
                                  ),
                                  Text(forceCloumn == 0 ? "0(自动)" : forceCloumn.toString()),
                                ],
                              ),
                              Row(
                                children: [
                                  Text("搜索时实时显示结果"),
                                  Switch(
                                    value: lookupRealtime, 
                                    onChanged: (value){
                                      setLocalState(() {
                                        lookupRealtime = value;
                                      });
                                      context.read<Global>().uiLogger.info("设置实时查找为$value");
                                    }
                                  )
                                ],
                              ),
                              Button(
                                size: Size(mediaQuery.size.width * 0.6, 100),
                                onPressed: (){
                                  setState(() {
                                    AppData().config = AppData().config.copyWith(
                                      learning: AppData().config.learning.copyWith(
                                        overviewForceColumn: forceCloumn,
                                        wordLookupRealtime: lookupRealtime
                                      )
                                    );
                                    context.read<Global>().updateSetting(refresh: false);
                                  });
                                  Navigator.pop(context);
                                }, 
                                icon: Icon(Icons.done),
                                child: Text("确认"),
                              )
                            ],
                          );
                        }
                      );
                }
              );
            }, 
            icon: Icon(Icons.settings)
          )
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _toggleSearch,
        child: inSearch ? Icon(Icons.search_off) : Icon(Icons.search)
      ),

      body: SafeArea(
        top: false,
        child: inSearch ? WordLookupLayout(lookfor: _query) : WordCardOverViewLayout(),
      )
    );
  }
}
