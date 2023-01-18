import 'dart:io';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:server/animation/textkit.dart';

import 'package:server/page_initalapp/Details.dart';
import 'package:server/page_initalapp/table.dart';

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  TextEditingController _textControllerFile = TextEditingController();
  TextEditingController _textControllerCourse = TextEditingController();
  List<List<String>> listData = [];
  var fileExcelPath = '';
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        filePicker(),
        listData.isNotEmpty
            ? DesginedTable(
                Datas: listData,
              )
            : Container(
                color: Colors.white.withOpacity(.2),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: DesignAnimatedTextKit(
                    text: ".را انتخاب کنید excel لطفا مسیر فایل ",
                    fontsize: 50,
                  ),
                ),
              ),
        listData.isNotEmpty ? Details(datas: listData) : SizedBox(),
      ],
    );
  }

  Widget filePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          color: Colors.white,
          width: 700,
          height: 50,
          child: TextField(
            readOnly: true,
            controller: _textControllerFile,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
                border: InputBorder.none, contentPadding: EdgeInsets.all(10)),
          ),
        ),
        FittedBox(
          fit: BoxFit.cover,
          child: Container(
            child: IconButton(
              color: Colors.white,
              splashRadius: 1,
              iconSize: 25,
              onPressed: _pickerFile,
              icon: const Icon(Icons.folder_open),
            ),
          ),
        )
      ],
    );
  }

  void _pickerFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowedExtensions: ['xlsx'],
    );
    if (result == null) return;
    String file = result.files.single.path.toString();
    setState(() {});
    _textControllerFile.text = file.toString();

    fileExcelPath = _textControllerFile.text;
    try {
      var bytes = File(fileExcelPath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      for (var row in excel.tables[excel.tables.keys.first]!.rows) {
        listData.add(row.map((e) => e!.value.toString()).toList());
      }

      listData.insert(
          0, List.generate(listData[0].length, (index) => "ستون: $index"));
    } catch (e) {
      dialog();
    }
  }

  Future dialog() {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "خطا",
          style: TextStyle(fontFamily: 'bnazanin', fontSize: 20),
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "تعداد ستون های تمامی سطر ها برابر نیست",
              style: TextStyle(fontFamily: 'bnazanin', fontSize: 20),
            ),
            Text(
              "$fileExcelPath",
              style: TextStyle(fontFamily: 'bnazanin', fontSize: 20),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              _textControllerFile.clear();
              fileExcelPath = '';
              listData.clear();
              setState(() {});
              Navigator.of(ctx).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              child: const Text(
                "باشه",
                style: TextStyle(fontFamily: 'bnazanin', fontSize: 25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
