// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, unused_element

import 'dart:async';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:client/classes/transfer.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:plugin_wifi_connect/plugin_wifi_connect.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

bool _pause = false;

String? _result;
String? _description;

class QRCodeScanner extends StatefulWidget {
  const QRCodeScanner({super.key});

  @override
  State<QRCodeScanner> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  final qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? barcode;

  String? resultCode;
  String? description;
  bool isConnected = false;

  QRViewController? controller;

  @override
  void initState() {
    _getId();
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();

    super.dispose();
  }

  // @override
  // void reassemble() {
  //   super.reassemble();
  //   if (Platform.isAndroid) {
  //     controller!.pauseCamera();
  //   }
  //   controller!.resumeCamera();
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            buildQrView(context),
            Positioned(bottom: 10, child: buildResult()),
            Positioned(top: 10, child: buildControlButtons()),
          ],
        ),
      ),
    );
  }

  Widget buildControlButtons() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white24,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () async {
                await controller?.toggleFlash();
                setState(() {});
              },
              icon: FutureBuilder<bool?>(
                  future: controller?.getFlashStatus(),
                  builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return Icon(
                          snapshot.data! ? Icons.flash_on : Icons.flash_off);
                    } else {
                      return Container();
                    }
                  }),
            ),
            IconButton(
              onPressed: () async {
                await controller?.flipCamera();
                setState(() {});
              },
              icon: FutureBuilder(
                  future: controller?.getCameraInfo(),
                  builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return const Icon(Icons.switch_camera);
                    } else {
                      return Container();
                    }
                  }),
            ),
            Visibility(
              visible: true,
              child: IconButton(
                onPressed: () {
                  controller!.resumeCamera();
                },
                icon: const Icon(Icons.play_arrow_outlined),
              ),
            )
          ],
        ),
      );
  Widget buildResult() => Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white24,
        ),
        child: Lottie.asset('assets/qr-code.json'),
      );
  Widget buildQrView(BuildContext context) => QRView(
        key: qrKey,
        onQRViewCreated: onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.cyan,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 15,
          cutOutSize: MediaQuery.of(context).size.width * .8,
        ),
      );
  void onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
      controller.scannedDataStream.listen(
        (barcode) => setState(
          (() {
            String decrypted =
                TransferData().rsa.decrypt(barcode.code.toString());
            print(decrypted);
            bool isValid = decrypted.split('-').length == 5;

            if (barcode.code != null && isValid) {
              controller.pauseCamera();
              List<String> data = dataExtraction(decrypted);

              TransferData().client.ipServer = data[2];
              TransferData().client.port = int.parse(data[3]);
              TransferData().client.code = data[4];

              PluginWifiConnect.connectToSecureNetwork(data[0], data[1])
                  .then((value) {
                if (value == true) {
                  TransferData().transferDataWifi();
                  status();
                } else {
                  controller.resumeCamera();
                }
              });
            }
          }),
        ),
      );
    });
  }

  void _getId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      var iosDeviceInfo = await deviceInfo.iosInfo;
      TransferData().client.ID =
          iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var androidIdPlugin = const AndroidId();
      TransferData().client.ID =
          await androidIdPlugin.getId(); // unique ID on Android
    }
  }

  List<String> dataExtraction(String data) {
    List<String> list, liIp = [];
    list = data.split('-');
    liIp = list[2].split('.');

    for (int i = 0; i < liIp.length; i++) {
      liIp[i] = int.parse(liIp[i], radix: 16).toString();
    }
    list[2] = '${liIp[0]}.${liIp[1]}.${liIp[2]}.${liIp[3]}';

    return list;
  }

  void status() async {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: ((context) {
        return Dialog(
          controller: controller!,
        );
      }),
    );
  }
}

class Dialog extends StatefulWidget {
  const Dialog({Key? key, required this.controller}) : super(key: key);

  final QRViewController controller;
  @override
  State<Dialog> createState() => _DialogState();
}

class _DialogState extends State<Dialog> {
  @override
  void initState() {
    TransferData().stream = getStream;
    super.initState();
  }

  Stream<String> get getStream async* {
    if (TransferData().client.result != null) {
      // * Server send Data
      if (TransferData().client.result!["result"] == '200') {
        // ?? Successful
        Navigator.of(context).pop();
        Navigator.pushNamedAndRemoveUntil(
            context, '/second', ((route) => false));
      } else if (TransferData().client.result!["result"] != '200') {
        _result = TransferData().client.result!["result"];

        switch (TransferData().client.result!["result"]) {
          case '100': // ?? Code Expaier
            _description = 'کد منقظی شده است.';
            break;
          case '300': // ?? Student is in List students and present
            _description = 'حاضری شما قبلا زده شده است.';
            break;
          case '400': // ?? Student Number Not Found
            _description = 'شماره دانشجویی شما یافت نشد.';
            break;
          case '500': // ?? Can Not Write on Excel File
            _description =
                ' مشکلی پیش آمده(لطفا به استاد بگویید فایل را ببندند.) و دوباره تلاش کنید.';
            break;
          case '600': // ?? duplicated ID
            _description = 'مشکلی پیش آمده، به استاد اطلاع دهید.  ';
            break;
          default:
            {
              _description = 'مشکلی پیش آمده.';
            }
            break;
        }
        TransferData().client.result = null;
        yield _description ?? "error";
      } else {
        _description = 'لطفا دوباره تلاش کنید';

        yield _description ?? "error";
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
        stream: getStream,
        builder: (context, snapshot) {
          return AlertDialog(
            title: !snapshot.hasData
                ? const Center(child: CircularProgressIndicator())
                : null,
            content: !snapshot.hasData
                ? const Text(
                    'لطفا صبر کنید',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_description}',
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
            actions: !snapshot.hasData
                ? []
                : [
                    ElevatedButton(
                      onPressed: () {
                        _pause = true;
                        TransferData().client.result = null;
                        widget.controller.resumeCamera();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'متوجه شدم',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.left,
                      ),
                    )
                  ],
          );
        });
  }
}
