import 'package:arabic_learning/funcs/ui.dart';
import 'package:flutter/material.dart';

Widget settingItem(BuildContext context, MediaQueryData mediaQuery, List<Widget> list, String title, {bool withPadding = true}) {
  List<Container> decoratedContainers = list.map((widget) {
    return Container(
      width: mediaQuery.size.width * 0.90,
      //height: mediaQuery.size.height * 0.08,
      padding: withPadding ? EdgeInsets.all(8.0) : EdgeInsets.zero,
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
      //height: mediaQuery.size.height * 0.08,
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
      //height: mediaQuery.size.height * 0.08,
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
      //height: mediaQuery.size.height * 0.08,
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