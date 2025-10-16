import 'dart:convert';
import 'dart:io';
import 'package:arabic_learning/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';


class PageCounterModel extends ChangeNotifier {
  int _currentPage = 0;
  final PageController _controller = PageController(initialPage: 0);
  int get currentPage => _currentPage;
  PageController get controller => _controller;
  void increment() {
    _currentPage++;
    notifyListeners();
  }
  void setPage(int page) {
    _currentPage = page;
    notifyListeners();
  }
}


class ClassSelectModel extends ChangeNotifier { 
  late Map<String, dynamic> _tpf;
  List<List<String>> get selectedClasses => (_tpf["SelectedClasses"] as List).cast<List>().map((e) => e.cast<String>()).toList();
  bool initialized = false;

  Future<void> init() async { 
    final directory = await getApplicationDocumentsDirectory();
    final tempConfig = File('${directory.path}/${StaticsVar.tempConfigPath}');
    if (!await tempConfig.exists()) {
      await tempConfig.create(recursive: true);
      await tempConfig.writeAsString(jsonEncode(StaticsVar.tempConfig));
      _tpf = StaticsVar.tempConfig;
    } else {
      try {
        _tpf = jsonDecode(await tempConfig.readAsString());
      } catch (e) {
        await tempConfig.writeAsString(jsonEncode(StaticsVar.tempConfig));
        _tpf = StaticsVar.tempConfig;
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> save() async { 
    final directory = await getApplicationDocumentsDirectory();
    final tempConfig = File('${directory.path}/${StaticsVar.tempConfigPath}');
    await tempConfig.writeAsString(jsonEncode(_tpf));
  }

  void addClass(List<String> className){
    if (!_tpf["SelectedClasses"].any((e) => e[0] == className[0] && e[1] == className[1])) {
      _tpf["SelectedClasses"].add(className);
      save();
      notifyListeners(); 
    }
  }

  void removeClass(List<String> className) {
    _tpf["SelectedClasses"].removeWhere((e) => e[0] == className[0] && e[1] == className[1]);
    save();
    notifyListeners(); 
  }

  void commitTempConfig(Map<String, dynamic> tpf) {
    _tpf = tpf;
    save();
    notifyListeners();
  }
}
