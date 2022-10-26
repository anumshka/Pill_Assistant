import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Scanner extends StatefulWidget {
  const Scanner({super.key});

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  var medicineId;
  var userId;
  var myMedicineScannedData;

  void initState() {
    super.initState();
    _loadUserInfo();
  }

  _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    userId = prefs.get('userid').toString();
  }

  void scanQR() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      medicineId = null;
    });
    setState(() {
      myMedicineScannedData = null;
    });

    if (await Permission.storage.request().isGranted) {
      // String cameraScanResult = await scanner.scan();

      // print(cameraScanResult);
      var uriloaded = Uri.parse('http://api.qrserver.com/v1/read-qr-code/');

      PickedFile? pickedImage =
          await ImagePicker().getImage(source: ImageSource.gallery);

      var request2 = http.MultipartRequest('POST', uriloaded);

      if (pickedImage != null) {
        File? croppedImage = await ImageCropper().cropImage(
          sourcePath: pickedImage.path,
          maxWidth: 1080,
          maxHeight: 1080,
        );

        if (croppedImage != null) {
          var multipartFile = await http.MultipartFile(
              'file',
              File(croppedImage.path).readAsBytes().asStream(),
              File(croppedImage.path).lengthSync(),
              filename: croppedImage.path.split("/").last);

          //request2.fields["MAX_FILE_SIZE"] = "4048576";

          request2.files.add(await multipartFile);

          print("size of contentlength is " +
              await request2.contentLength.toString() +
              " " +
              await multipartFile.length.toString());
          request2.headers["Content-Length"] =
              request2.contentLength.toString();
          request2.headers["Content-Type"] = "multipart/form-data";

          print('directory is ' + pickedImage.path);
          print("size of file is " +
              File(pickedImage.path).lengthSync().toString());

          final response2 = await request2.send();

          print("response 2 .......");

          print(await response2.statusCode);

          // print(await response2.stream.bytesToString());

          var response = await http.Response.fromStream(response2);

          print("This is response " + response.body);
          var myData = json.decode(response.body);

          for (var myMed in myData) {
            print(myMed["symbol"][0]["data"]);

            setState(() {
              medicineId = myMed["symbol"][0]["data"];
            });
          }
          print('json decoded data' + myData.toString());

          final queryParameters = {'type': 'user'};

          var uri = Uri.https(
              'pill-management-backend.herokuapp.com',
              "/mobile-app-ws/users/${userId}/medicine/${medicineId}",
              queryParameters);

          final http.Response getResponse = await http.get(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'authorization': prefs.get('authToken').toString(),
              'userid': userId
            },
          );

          print(getResponse.body);
          setState(() {
            myMedicineScannedData = json.decode(getResponse.body);
          });
          print(getResponse.statusCode);
          print(getResponse.headers);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR Code Scanner")),
      body: SingleChildScrollView(
          child: Column(
        children: [
          TextButton(onPressed: scanQR, child: Text("Scan any qr code")),
          if (myMedicineScannedData != null) ...{
            Column(children: [
              Text(myMedicineScannedData["name"]),
              Text(myMedicineScannedData["expiryDate"].toString()),
              Text('Available Count ' +
                  myMedicineScannedData["availableCount"].toString())
            ])
          }
        ],
      )),
    );
  }
}
