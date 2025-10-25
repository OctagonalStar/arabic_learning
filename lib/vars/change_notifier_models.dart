import 'dart:convert';
import 'package:arabic_learning/vars/statics_var.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class InLearningPageCounterModel extends ChangeNotifier {
  final int totalPages; // havn't found any better solution to avoid this value to be split also State & this Model
  InLearningPageCounterModel(this.totalPages);

  int _currentPage = 0;
  final PageController _controller = PageController(initialPage: 0);
  int get currentPage => _currentPage;
  PageController get controller => _controller;

  // Other value storage
  List<int> conrrects = [];
  int startTime = DateTime.now().millisecondsSinceEpoch;
  bool finished = false;
  bool get isLastPage => _currentPage == totalPages - 1;
  bool currentType = false;


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
  late final SharedPreferences prefs;

  Future<void> init() async { 
    prefs = await SharedPreferences.getInstance();
    _tpf = jsonDecode(prefs.getString("tempConfig") ?? jsonEncode(StaticsVar.tempConfig)) as Map<String, dynamic>;
    initialized = true;
    notifyListeners();
  }

  Future<void> save() async { 
    prefs.setString("tempConfig", jsonEncode(_tpf));
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
