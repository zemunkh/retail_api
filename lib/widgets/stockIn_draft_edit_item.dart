import 'dart:convert';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/home_screen.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import '../screens/stockIn_draft_screen.dart';
import '../helper/database_helper.dart';
import '../helper/file_manager.dart';
import '../helper/api.dart';
import '../model/stockIn.dart';

class StockInDraftEditTransaction extends StatefulWidget {
  @override
  _StockInDraftEditTransactionState createState() => _StockInDraftEditTransactionState();
}

class _StockInDraftEditTransactionState extends State<StockInDraftEditTransaction> {
  final dbHelper = DatabaseHelper.instance;
  bool _isButtonDisabled = true;
  bool _isDraftButtonDisabled = true;

  List<TextEditingController> _stockInputControllers = new List();
  List<TextEditingController> _lvl1InputControllers = new List();
  List<TextEditingController> _lvl2InputControllers = new List();

  List<FocusNode> _stockInputNodes = new List();
  List<FocusNode> _lvl1InputNodes = new List();
  List<FocusNode> _lvl2InputNodes = new List();

  String trxNumber = '';

  String statusTime = '';

  List<String> _baseUOMs = [];
  List<String> _stockNames = [];

  DateTime draftCreatedAt;

  // For the buffering from the saved and indexed values
  List<String> _otherList = [];
  List<String> _stockCodeList = [];
  List<String> _stockNameList = [];
  List<String> _lvl1uomList = [];
  List<String> _lvl2uomList = []; 
  List<String> _baseUomsList = [];

  bool postClicked = false;
  // Dropdown menu variables
  List<String> _descriptions = [];
  List<String> _descripts = [];
  String dropdownValue = '';
  String buffer = '';
  String trueVal = '';

  String ip, port, dbCode;
  String urlStatus = 'not found';
  String _url = '';

  Future<Null> initServerUrl() async {
    ip =  await FileManager.readProfile('ip_address');
    port =  await FileManager.readProfile('port_number');
    dbCode =  await FileManager.readProfile('company_name');
    if(ip != '' && port != '' && dbCode != '') {
      _url = 'http://$ip:$port/api/StocksIns';
    } else {
      _url = 'https://dev-api.qne.cloud/api/StockIns';
      dbCode = 'OUCOP7';
    }
    setState((){
      urlStatus = _url;
    });
  }

  Future<Null> _searchStockCode(int index, String stockCode) async {
    bool isEmpty = false;
    List<Map> stockData = await dbHelper.queryAllRows();

    stockData.forEach((row){
      if(row["stockCode"] == stockCode) {
        print('ID: ${row["id"]}');
        _stockNames[index] = (row["stockName"]);
        _baseUOMs[index] = (row["baseUOM"]);

        isEmpty = isEmpty || true;
        print('I got this :)');
        // _lvl1InputControllers[index].text = row["baseUOM"];
        
        // this will build baseUOM lvl1, lvl2 widgets
      } else {
        isEmpty = isEmpty || false;
      }
    });

    setState(() {
      _isButtonDisabled = !isEmpty;
      _isDraftButtonDisabled = !isEmpty;
    });
  }

  Future<Null> _stockInEventListener(int index, TextEditingController _controller) async {
    int length = _stockInputControllers.length;

    print('Length of the controllers: $length, index: $index');

    buffer = _controller.text;

    if(buffer.endsWith(r'$')) {
      buffer = buffer.substring(0, buffer.length - 1);
      trueVal = buffer;


      await Future.delayed(const Duration(milliseconds: 1000), (){
        _stockInputControllers[index].text = trueVal;
      }).then((value){
        _searchStockCode(index, trueVal);
        Future.delayed(const Duration(milliseconds: 500), (){
          // _stockInputController.clear();
          _stockInputNodes[index].unfocus();
          FocusScope.of(context).requestFocus(new FocusNode());
        });
      });
    }

  }

  Future<Null> _focusNode(BuildContext context, FocusNode node) async {
    FocusScope.of(context).requestFocus(node);
  }

  Future<Null> _clearTextController(BuildContext context, TextEditingController _controller, FocusNode node) async {
    Future.delayed(Duration(milliseconds: 50), () {
      setState(() {
        _controller.clear();
      });
      FocusScope.of(context).requestFocus(node);
    });
  }


  Future<Null> _postTransaction(DateTime date) async {
    final api = Api();

    int len = _stockInputControllers.length;
    List<String> _bodyList = [];

    List<String> _stockCodeList = [];
    List<String> _stockNameList = [];
    List<String> _lvl1uomList = [];
    List<String> _lvl2uomList = [];

    for(int i = 0; i < len; i++) {
      _stockCodeList.add(_stockInputControllers[i].text);
      _stockNameList.add(_stockNames[i]);
      _lvl1uomList.add(_lvl1InputControllers[i].text);
      _lvl2uomList.add(_lvl2InputControllers[i].text);
    }

    for(int i = 0; i < len; i++) {
      Details details = Details(
        numbering: null,
        stock: _stockInputControllers[i].text,
        pos: 1,
        description: dropdownValue,
        price: 0,
        uom: _baseUOMs[0],
        qty: int.parse(_lvl1InputControllers[i].text),
        amount: 1,
        note: null,
        costCentre: null,
        project: "Serdang",
        stockLocation: "HQ",
      );

      List<Details> detail = [details];

      // With API, it gathers all the data, and make the POST request to the server
      // Have to add multiple post requests.

      StockIn firstData = new StockIn(
        stockInCode: trxNumber,
        stockInDate: DateFormat("yyyy-MM-dd").format(date),
        description: dropdownValue,
        referenceNo: null,
        title: "Test",
        isCancelled: false,
        notes: null,
        costCentre: null,
        project: "Serdang",
        stockLocation: "HQ",
        details: detail,
      );

      var body = jsonEncode(firstData.toJson());
      print("Object to send: $body");
      print("Other status: $dbCode, $_url");

      _bodyList.add(body);
      
      // final api = Api();
      // await api.postStockIns(dbCode, body, _url).then((_){
      //   print("Post request is done!");
      // });
    }

    await api.postMultipleStockIns(dbCode, _bodyList, _url).then((_){
      print("Post requests are done!");
    });
    
  }


  Future<Null> _saveTheDraft(DateTime createdDate) async {
    int len = _stockInputControllers.length;

    List<String> _stockCodeList = [];
    List<String> _stockNameList = [];
    List<String> _lvl1uomList = [];
    List<String> _lvl2uomList = [];
    List<String> _otherList = [];

    for(int i = 0; i < len; i++) {
      _stockCodeList.add(_stockInputControllers[i].text);
      _stockNameList.add(_stockNames[i]);
      _lvl1uomList.add(_lvl1InputControllers[i].text);
      _lvl2uomList.add(_lvl2InputControllers[i].text);
    }

    _otherList.add(draftCreatedAt.toString());
    _otherList.add(trxNumber);
    _otherList.add(dropdownValue);

    int draftIndex = await FileManager.getSelectedIndex();
    String index = draftIndex.toString();
    // String draftName = '$trxNumber';
    // Saving draft list to Draft Bank for the Draft list page.
    // FileManager.saveDraftList(draftName);

    // Draft updating feature started
    print('Draft names: draft_stockCode_$index, draft_stockName_$index');

    FileManager.saveDraft('draft_stockCode_$index', _stockCodeList);
    FileManager.saveDraft('draft_stockName_$index', _stockNameList);
    FileManager.saveDraft('draft_lvl1uomList_$index', _lvl1uomList);
    FileManager.saveDraft('draft_lvl2uomList_$index', _lvl2uomList);
    FileManager.saveDraft('draft_other_$index', _otherList);
    FileManager.saveDraft('draft_baseUoms_$index', _baseUOMs);

  }

  Future<bool> _deleteRow(int index) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Do you want to delete #${index + 1} row?"),
        actions: <Widget>[
          FlatButton(
            child: Text('Yes'),
            onPressed: () {
              print('Yes clicked');
              setState(() {
                _baseUOMs.removeAt(index);
                _stockNames.removeAt(index);
                _stockInputControllers.removeAt(index);
                _lvl1InputControllers.removeAt(index);
                _lvl2InputControllers.removeAt(index);

                _stockInputNodes.removeAt(index);
                _lvl1InputNodes.removeAt(index);
                _lvl2InputNodes.removeAt(index);
                if(index == 0) {
                  setState(() {
                    _isButtonDisabled = true;
                  });
                }
              });
              Navigator.pop(context, true);
            },
          ),
          FlatButton(
            child: Text('No'),
            onPressed: () {
              print('No clicked');
              Navigator.pop(context, true);
            },
          ),
        ],
      )
    );
  }

  Future<Null> setInitials() async {
    // =============== GET SELECTED DRAFT LIST VALUE ============== //
    int draftIndex = await FileManager.getSelectedIndex();
    _otherList = await FileManager.readDraft('draft_other_$draftIndex');
    
    _stockCodeList = await FileManager.readDraft('draft_stockCode_$draftIndex');
    _stockNameList = await FileManager.readDraft('draft_stockName_$draftIndex');
    _lvl1uomList = await FileManager.readDraft('draft_lvl1uomList_$draftIndex');
    _lvl2uomList = await FileManager.readDraft('draft_lvl2uomList_$draftIndex');
    _baseUomsList = await FileManager.readDraft('draft_baseUoms_$draftIndex');

    _descripts = await FileManager.readDescriptions();
    if(_descripts.isEmpty || _descripts == null) {
      setState(() {
        dropdownValue = 'Not Selected';
      });
      for(int i = 0; i < _descripts.length; i++) {
        setState(() {
          // _descriptionControllers[i].text = 'NaN';
          _descriptions[i] = '#$i. Not Available';
        });
      }
    } else {
      setState(() {
        dropdownValue = _otherList[2];
        _descriptions = _descripts;
      });
    }

    // Now Extracting Saved String List values to the fields based on index
    DateTime draftDate = DateTime.parse(_otherList[0]);
    
    setState(() {
      draftCreatedAt = draftDate;
      statusTime = DateFormat("yyyy/MM/dd HH:mm:ss").format(draftDate);
      trxNumber = _otherList[1];
      for(int i = 0; i < _stockCodeList.length; i++) {
        print('Adding!');
        _stockInputControllers.add(new TextEditingController());
        _lvl1InputControllers.add(new TextEditingController());
        _lvl2InputControllers.add(new TextEditingController());
        _stockNames.add('');
        _baseUOMs.add('');

        // Complete & Draft button enabling logic is here
        if(_stockCodeList[i] != '' && (_lvl1uomList[i] != '' || _lvl1uomList[i] != '') && _stockNameList[i] != 'StockCode' && _baseUomsList[i] != 'Unit') {
          _isButtonDisabled = false;
          print('All requirements are filled');
        }

        _stockInputControllers[i].text = _stockCodeList[i];
        _lvl1InputControllers[i].text = _lvl1uomList[i];
        _lvl2InputControllers[i].text = _lvl2uomList[i];
        _stockNames[i] = _stockNameList[i];
        _baseUOMs[i] = _baseUomsList[i];

        _stockInputNodes.add(new FocusNode());
        _lvl1InputNodes.add(new FocusNode());
        _lvl2InputNodes.add(new FocusNode());
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setInitials();
    initServerUrl();
  }

  @override
  Widget build(BuildContext context) {
    DateTime createdDate = DateTime.now();

    Widget deleteRowButton(int index) {
      return Padding(
        padding: EdgeInsets.all(5),
        child: MaterialButton(
          onPressed: () {
            // delete current row
            print("Clicked row index: $index");
            _deleteRow(index);
            _isDraftButtonDisabled = false;
          },
          child: Icon(
            Icons.delete,
            color: Colors.red,
            size: 30,
          ),
          // shape: StadiumBorder(),
          // color: Colors.teal[300],
          splashColor: Colors.grey,
          // height: 50,
          // minWidth: 250,
          elevation: 2,
        ),
      );
    } 

    Widget _stockMeasurement(int index, TextEditingController _lvl1Controller, TextEditingController _lvl2Controller, FocusNode _lvl1Node, FocusNode _lvl2Node) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.all(2.0),
              child: Container(
                height: 40,
                child: TextFormField(
                    style: TextStyle(
                    fontSize: 12, 
                    color: Color(0xFF004B83),
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration.collapsed(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: '  lvl1: ${_baseUOMs[index]}',
                    hintStyle: TextStyle(
                      color: Color(0xFF004B83), 
                      fontWeight: FontWeight.w200,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                  autofocus: false,
                  controller: _lvl1Controller,
                  focusNode: _lvl1Node,
                  onTap: () {
                    _focusNode(context, _lvl1Node);
                    // _clearTextController(context, _lvl1Controller, _lvl1Node);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _baseUOMs[index],
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14, 
                color: Color(0xFF004B83),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Container(
                height: 40,
                child: TextFormField(
                  style: TextStyle(
                    fontSize: 12, 
                    color: Color(0xFF004B83),
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration.collapsed(
                    filled: true,
                    fillColor: Colors.white,
                    hintText:'  lvl2: ${_baseUOMs[index]}',
                    hintStyle: TextStyle(
                      color: Color(0xFF004B83), 
                      fontWeight: FontWeight.w200,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                  autofocus: false,
                  controller: _lvl2Controller,
                  focusNode: _lvl2Node,
                  onTap: () {
                    _focusNode(context, _lvl2Node);
                    // _clearTextController(context, _lvl2Controller, _lvl2Node);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _baseUOMs[index],
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14, 
                color: Color(0xFF004B83),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: deleteRowButton(index),
          )
        ],
      );
    }
    
    Widget _stockInput(int index, TextEditingController _controller, FocusNode _stockNode) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              'StockIn: ${index + 1}',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14, 
                color: Color(0xFF004B83),
                fontWeight: FontWeight.bold,
              ),
            )
          ),
          Expanded(
            flex: 8,
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Container(
                height: 40,
                child: TextFormField(
                  style: TextStyle(
                    fontSize: 14, 
                    color: Color(0xFF004B83),
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Stock code',
                    hintStyle: TextStyle(
                      color: Color(0xFF004B83), 
                      fontWeight: FontWeight.w200,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    errorStyle: TextStyle(
                      color: Colors.yellowAccent,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(EvaIcons.close, 
                        color: Colors.blueAccent, 
                        size: 24,
                      ),
                      onPressed: () {
                        _clearTextController(context, _controller, _stockNode);
                      },
                    ),
                  ),
                  autofocus: false,
                  controller: _controller,
                  focusNode: _stockNode,
                  onTap: () {
                    _focusNode(context, _stockNode);
                  },
                  onChanged: (value) {
                    _stockInEventListener(index, _controller);
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }

    final addStockInputButton = Center(
      child: Padding(
        padding: EdgeInsets.all(10),
        child: MaterialButton(
          onPressed: () {
            setState(() {
              _baseUOMs.add('');
              _stockNames.add('');
              _stockInputControllers.add(new TextEditingController());
              _lvl1InputControllers.add(new TextEditingController());
              _lvl2InputControllers.add(new TextEditingController());

              _stockInputNodes.add(new FocusNode());
              _lvl1InputNodes.add(new FocusNode());
              _lvl2InputNodes.add(new FocusNode());

              _isDraftButtonDisabled = false;
            });
          },
          child: Icon(
            EvaIcons.plusCircleOutline,
            color: Colors.blueGrey,
            size: 40,
          ),
          // shape: StadiumBorder(),
          // color: Colors.lightBlue[600],
          splashColor: Colors.teal,
          height: 50,
          // minWidth: MediaQuery.of(context).size.width / 2,
          elevation: 2,
        ),
      ),
    );

    final postButton = Center(
      child: Padding(
        padding: EdgeInsets.all(10),
        child: MaterialButton(
          onPressed: _isButtonDisabled ? null : () {
            // gather all the information and post data to db by api lib.
            return showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Do you want to upload the transactions?"),
                actions: <Widget>[
                  FlatButton(
                    child: Text('Yes'),
                    onPressed: () {
                      print('Yes clicked');
                      if(!postClicked) {
                        print('Yes clicked');
                        _postTransaction(createdDate).then((_) {
                          Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
                        });
                        setState(() {
                          postClicked = true;
                        });
                      }
                    },
                  ),
                  FlatButton(
                    child: Text('No'),
                    onPressed: () {
                      print('No clicked');
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              )
            );

          },
          child: Text(
            'Complete Trx',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'QuickSand',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          shape: StadiumBorder(),
          color: Colors.teal[300],
          splashColor: Colors.green[50],
          height: 40,
          minWidth: 140,
          elevation: 2,
        ),
      ),
    );


    Widget _saveDraftButton(BuildContext context) {
      return Padding(
        padding: EdgeInsets.all(5),
        child: MaterialButton(
          onPressed: _isDraftButtonDisabled ? null : () {
            print('You pressed Draft Button!');
            _saveTheDraft(createdDate).then((_){

              Alert(
                context: context,
                type: AlertType.success,
                title: "StockIn draft is saved successfully",
                desc: "Current Draft is saved again",
                buttons: [
                  DialogButton(
                    child: Text(
                      "OK",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    onPressed: () => Navigator.of(context).pushReplacementNamed(StockInDraftScreen.routeName),
                    width: 120,
                  )
                ],
              ).show();
            });

          },
          child: Text(
            'Save as Draft',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'QuickSand',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          shape: StadiumBorder(),
          color: Colors.orange[800],
          splashColor: Colors.yellow[200],
          height: 40,
          minWidth: 100,
          elevation: 2,
        )
      );
    }

    Widget _descriptionMenu(BuildContext context, String header) {
      return Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              '$header',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF004B83),
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: Container(
                child: DropdownButton<String>(
                  value: dropdownValue,
                  icon: Icon(EvaIcons.arrowDownOutline),
                  iconSize: 24,
                  elevation: 16,
                  style: TextStyle(color: Colors.deepPurple),
                  underline: Container(
                    height: 2,
                    color: Colors.deepPurpleAccent,
                  ),
                  onChanged: (String newValue) {
                    setState(() {
                      dropdownValue = newValue;
                      _isDraftButtonDisabled = false;
                    });
                    // Add some functions to handle change.
                  },
                  items: _descriptions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget statusBar(String time) {
      return Padding(
        padding: const EdgeInsets.only(left: 2, right: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                time,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'QuickSand',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Text(
                'System Auto: $trxNumber',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'QuickSand',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildContainer(Widget child) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5)
        ),
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(5),
        height: 350,
        width: 400,
        child: child,
      );  
    }

    final transaction = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        statusBar(statusTime),
        // descriptionMenu,
        // stockParameters,
        _descriptionMenu(context, 'Description:'),
        new Divider(height: 20.0, color: Colors.black87,),

        buildContainer(
          ListView.builder(
            itemCount: _stockInputControllers?.length,
            itemBuilder: (BuildContext context, int index) {
              return Container(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _stockInput(index, _stockInputControllers[index], _stockInputNodes[index]),
                    Text('Stock Name: ${_stockNames[index]}'),
                    _stockMeasurement(index, _lvl1InputControllers[index], _lvl2InputControllers[index], _lvl1InputNodes[index], _lvl2InputNodes[index]),
                    new Divider(height: 15.0,color: Colors.black87,),
                  ],
                ),
              );
            },
          ),
        ),
        addStockInputButton,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Expanded(
              child: postButton,
            ),
            Expanded(
              child: _saveDraftButton(context),
            )
          ],
        ),
      ],
    );

    

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if(constraints.maxHeight > constraints.maxWidth) {
          return SingleChildScrollView(
            child: transaction,
          );
        } else {
          return Center(
            child: Container(
              width: 450,
              child: transaction,
            ),
          );
        }
      },
    );
  }
}