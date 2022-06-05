import 'package:flutter/material.dart';
import 'package:foto/model/selection.dart';
import 'package:provider/provider.dart';

class Inspector extends StatelessWidget {
  const Inspector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectionModel>(
      builder: (_, selection, __) {
        return Center(
          child: Text((selection.get.length == 1) ? selection.get.first : ''),
        );
      },
    );
  }
}
