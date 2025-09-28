// dashboard/ui/scan_barcode_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class ScanBarcodePage extends StatefulWidget {
  const ScanBarcodePage({super.key});

  @override
  State<ScanBarcodePage> createState() => _ScanBarcodePageState();
}

class _ScanBarcodePageState extends State<ScanBarcodePage> {
  String? batchId;
  bool isLoading = false;
  List<Map<String, dynamic>> productHistory = [];

  late Web3Client _web3client;
  late DeployedContract _contract;

  @override
  void initState() {
    super.initState();
    _web3client = Web3Client(
      "http://127.0.0.1:7545", // RPC Ganache/Hardhat
      Client(),
    );
    _loadContract();
  }

  Future<void> _loadContract() async {
    // Đọc ABI từ assets
    final abiCode = await DefaultAssetBundle.of(context)
        .loadString("assets/Products.json");

    // Địa chỉ contract đã deploy
    final contractAddr = EthereumAddress.fromHex(
      "0xcb5D82166261cf38B552A6d3F02277638C84DEC7",
    );

    _contract = DeployedContract(
      ContractAbi.fromJson(abiCode, "Products"),
      contractAddr,
    );
  }

  Future<void> _fetchProductHistory(String batchId) async {
    setState(() => isLoading = true);

    final getHistoryFn = _contract.function("getProductHistory");
    try {
      final result = await _web3client.call(
        contract: _contract,
        function: getHistoryFn,
        params: [batchId],
      );

      // result[0] = mảng struct ProductHistory
      List histories = result[0];
      final parsed = histories.map((h) {
        return {
          "from": h[0].toString(),
          "to": h[1].toString(),
          "note": h[4].toString(), // field note trong struct
          "time": DateTime.fromMillisecondsSinceEpoch(
            (BigInt.parse(h[3].toString()) * BigInt.from(1000)).toInt(),
          ),
        };
      }).toList();

      setState(() {
        productHistory = List<Map<String, dynamic>>.from(parsed);
      });
    } catch (e) {
      debugPrint("Error fetching product history: $e");
    }

    setState(() => isLoading = false);
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      setState(() {
        batchId = code;
      });
      _fetchProductHistory(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Barcode")),
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: MobileScanner(onDetect: _onDetect),
          ),
          const SizedBox(height: 16),
          if (batchId != null) Text("BatchId: $batchId"),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (productHistory.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: productHistory.length,
                itemBuilder: (ctx, i) {
                  final h = productHistory[i];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text("Note: ${h["note"]}"),
                      subtitle: Text(
                        "From: ${h["from"]}\nTo: ${h["to"]}\nTime: ${h["time"]}",
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Text("Chưa có lịch sử hoặc chưa scan"),
        ],
      ),
    );
  }
}
