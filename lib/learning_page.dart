import 'package:arabic_learning/global.dart';
import 'package:arabic_learning/learning_pages_build.dart';
import 'package:flutter/material.dart';
import 'package:arabic_learning/statics_var.dart';
import 'package:provider/provider.dart';

class LearningPage extends StatelessWidget {
  const LearningPage({super.key});
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: mediaQuery.size.width * 0.9,
            height: mediaQuery.size.height * 0.2,
            alignment: Alignment.center,
            margin: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: StaticsVar.br,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: StaticsVar.br,
                ),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MixLearningPage()));
              },
              child: Container(
                width: mediaQuery.size.width * 0.9,
                height: mediaQuery.size.height * 0.2,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sync_alt, size: 24.0),
                    Text(
                      '中阿混合学习',
                      style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.01),
                    Text(
                      '还有{int}个单词待学习~',
                      style: TextStyle(fontSize: 12.0),
                    ),
                  ],
                ),
              ),
            )
          ),
          SizedBox(height: mediaQuery.size.height * 0.01),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: mediaQuery.size.width * 0.42,
                height: mediaQuery.size.height * 0.18,
                margin: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: StaticsVar.br,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: StaticsVar.br,
                    ),
                  ),
                  onPressed: () {
                    // TODO: to arabic learning page
                  }, 
                  child: Column(
                    children: [
                      Icon(Icons.arrow_back, size: 24.0),
                      Text("阿译中学习", style: TextStyle(fontSize: 32.0)),
                      SizedBox(height: mediaQuery.size.height * 0.01),
                    ],
                  ),
                ),
              ),
              Container(
                width: mediaQuery.size.width * 0.42,
                height: mediaQuery.size.height * 0.18,
                margin: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: StaticsVar.br,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: StaticsVar.br,
                    ),
                  ),
                  onPressed: () {
                    // TODO: to chinese learning page
                  },
                  child: Column(
                    children: [
                      Icon(Icons.arrow_forward, size: 24.0),
                      Text("中译阿学习", style: TextStyle(fontSize: 32.0)),
                      SizedBox(height: mediaQuery.size.height * 0.01),
                    ],
                  ),
                )
              )
            ]
          ),
        ]
      )
    );
  }
}

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

class MixLearningPage extends StatefulWidget {
  const MixLearningPage({super.key});
  @override
  State<MixLearningPage> createState() => _MixLearningPageState();
}

class _MixLearningPageState extends State<MixLearningPage> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final globalVar = Provider.of<Global>(context);
    final List<Widget> pages = learningPageBuilder(mediaQuery, context, (List<int>.from(globalVar.wordData["Classes"]["第二课：你好"]))..shuffle(), globalVar.wordData);
    return ChangeNotifierProvider<PageCounterModel>(
      create: (_) => PageCounterModel(),
      child: Builder(
        builder: (context) {
          var counter = context.watch<PageCounterModel>();
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  ElevatedButton(
                    onPressed: (){
                      Navigator.pop(context);
                    },
                    child: Icon(
                      Icons.close,
                      size: 24.0,
                      semanticLabel: 'Back',
                    )
                  ),
                  SizedBox(width: mediaQuery.size.width * 0.01),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0.0,
                        end: counter.currentPage / (pages.length - 1),
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: StaticsVar.curve,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          color: Theme.of(context).colorScheme.secondary,
                          minHeight: mediaQuery.size.height * 0.04,
                          borderRadius: StaticsVar.br,
                        );
                      },
                    )
                  ),
                ],
              ),
            ),
            body: Center(
              child: PageView.builder(
                scrollDirection: globalVar.isWideScreen ? Axis.vertical : Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                itemCount: pages.length,
                controller: counter._controller,
                onPageChanged: (index) {
                  counter.setPage(index);
                },
                itemBuilder: (context, index) {
                  return pages[index];
                },
              )
            )
          );
        }
      )
    );
  }
}
