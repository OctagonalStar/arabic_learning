import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:arabic_learning/vars/global.dart';
import 'package:arabic_learning/funcs/ui.dart';

class SettingItem extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;
  const SettingItem({super.key, required this.title, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.info("构建 SettingItem: $title");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    List<Container> decoratedContainers = children.map((widget) {
      return Container(
        width: mediaQuery.size.width * 0.90,
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          borderRadius: BorderRadius.all(Radius.circular(5.0)),
        ),
        child: widget,
      );
    }).toList();

    if(decoratedContainers.length > 1){
      decoratedContainers[0] = Container(
        width: mediaQuery.size.width * 0.90,
        margin: decoratedContainers[0].margin,
        padding: decoratedContainers[0].padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.0), bottom: Radius.circular(5.0)),
        ),
        child: decoratedContainers[0].child,
      );
      decoratedContainers[decoratedContainers.length - 1] = Container(
        width: mediaQuery.size.width * 0.90,
        margin: decoratedContainers[decoratedContainers.length - 1].margin,
        padding: decoratedContainers[decoratedContainers.length - 1].padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25.0), top: Radius.circular(5.0)),
        ),
        child: decoratedContainers[decoratedContainers.length - 1].child,
      );
    } else {
      decoratedContainers[0] = Container(
        width: mediaQuery.size.width * 0.90,
        margin: decoratedContainers[0].margin,
        padding: decoratedContainers[0].padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
        child: decoratedContainers[0].child,
      );
    }
    //Add Sizedbox between each item in list
    List<Widget> newList = [];
    for (var i = 0; i < decoratedContainers.length; i++) {
      newList.add(decoratedContainers[i]);
      if (i != decoratedContainers.length - 1) {
        newList.add(SizedBox(height: mediaQuery.size.height * 0.005));
      }
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextContainer(text: title),
        Center(
          child: Column(
            children: newList,
          ),
        ),
      ]
    );
  }
}