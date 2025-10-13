// dashboard/ui/scan_barcode_page.dart
// ignore_for_file: use_build_context_synchronously
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/model/productHistory.dart';

class ScanBarcodePage extends StatefulWidget {
  const ScanBarcodePage({super.key});

  @override
  State<ScanBarcodePage> createState() => _ScanBarcodePageState();
}

class _ScanBarcodePageState extends State<ScanBarcodePage> {
  late MobileScannerController _controller;
  String? _lastScannedCode;
  // ✅ 1. Thêm TextEditingController để quản lý ô nhập liệu
  final TextEditingController _batchIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionTimeoutMs: 1000);
  }

  void _startNewScan() {
    setState(() {
      _lastScannedCode = null;
      // ✅ 2. Xóa nội dung trong ô nhập liệu khi quét lại
      _batchIdController.clear();
    });
    _controller.start(); // Bật lại camera để quét
  }

  @override
  void dispose() {
    _controller.dispose();
    // ✅ 3. Hủy controller để tránh rò rỉ bộ nhớ
    _batchIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanBloc = context.read<ScanBloc>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scan or Enter Product Code', // Cập nhật tiêu đề
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: BlocConsumer<ScanBloc, ScanState>(
          listener: (context, state) {
            if (state is ScanErrorState) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text("❌ ${state.error}"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                // --- 1. Barcode Scanner ---
                Container(
                  padding: const EdgeInsets.only(top: 80),
                  height: 300, // Giảm chiều cao một chút
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          final code = capture.barcodes.first.rawValue;
                          developer.log("✅ Barcode detected! Raw value: '$code'");
                          if (code != null &&
                              code.isNotEmpty &&
                              _lastScannedCode != code) {
                            developer.log("Processing new barcode: $code");
                            setState(() => _lastScannedCode = code);
                            _batchIdController.text = code; // Hiển thị code đã quét vào ô input
                            scanBloc.add(BarcodeScannedEvent(code));
                            _controller.stop(); // Dừng camera sau khi quét
                          }
                        },
                      ),
                      if (_lastScannedCode != null)
                        Positioned(
                          bottom: 20,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text(
                              "Scan / Clear",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _startNewScan,
                          ),
                        ),
                    ],
                  ),
                ),

                // ✅ 4. Thêm Widget cho việc nhập liệu thủ công
                _buildManualInputSection(scanBloc),

                // --- 2. Dữ liệu / trạng thái ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildContent(context, state, scanBloc),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ✅ 5. Widget mới cho ô nhập liệu và nút tìm kiếm
  Widget _buildManualInputSection(ScanBloc scanBloc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _batchIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Or enter Batch ID here',
                hintStyle: const TextStyle(color: Colors.white54),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(16),
            ),
            onPressed: () {
              final batchId = _batchIdController.text.trim();
              if (batchId.isNotEmpty) {
                // Ẩn bàn phím
                FocusScope.of(context).unfocus();
                // Cập nhật state và gửi event
                setState(() => _lastScannedCode = batchId);
                scanBloc.add(BarcodeScannedEvent(batchId));
              }
            },
            child: const Icon(Icons.search),
          )
        ],
      ),
    );
  }

  // ====================================================================
  //                         BUILDER FUNCTIONS
  // ====================================================================

  Widget _buildContent(BuildContext context, ScanState state, ScanBloc bloc) {
    // ... (Không có thay đổi gì trong hàm này)
    if (state is ScanLoadingState || state is ProductHistoryLoadingState) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }

    if (state is ScanInitialState || state is ScanErrorState) {
      final message = state is ScanErrorState
          ? "Error: ${state.error}\nPlease scan again."
          : "Point the camera at a barcode or enter an ID to search.";

      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    if (state is ProductInfoLoadedState) {
      final product = state.product;
      final history = state.history;

      return RefreshIndicator(
        color: Colors.greenAccent,
        onRefresh: () async {
          bloc.add(BarcodeScannedEvent(product.batchId));
        },
        child: ListView(
          children: [
            _buildProductHeader(context, product),
            const SizedBox(height: 20),
            _buildHistorySection(context, product, history, state, bloc),

            if (state.historyErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  state.historyErrorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return const Center(child: Text("Loading data..."));
  }

  Widget _buildProductHeader(BuildContext context, Product product) {
    // ... (Không có thay đổi gì trong hàm này)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white38, height: 25),
          _infoRow('Batch ID', product.batchId,
              isAddress: true, context: context),
          _infoRow('Organization', product.organizationName),
          _infoRow(
            'Date Created',
            DateTime.fromMillisecondsSinceEpoch(
              product.date.toInt() * 1000,
            ).toLocal().toString().split(' ')[0],
          ),
          _infoRow('Current Owner', product.currentOwner,
              isAddress: true, context: context),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
      BuildContext context,
      Product product,
      List<ProductHistory>? history,
      ProductInfoLoadedState state,
      ScanBloc bloc,
      ) {
    // ... (Không có thay đổi gì trong hàm này)
    if (state is! ProductDetailsLoadedState) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.withOpacity(0.9),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.history, size: 20),
            label: const Text(
              "View Transaction History",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              bloc.add(FetchProductHistoryEvent(product.batchId));
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          "Transaction History",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (history!.isEmpty)
          const Text(
            "No transactions have been recorded yet.",
            style: TextStyle(color: Colors.white54),
          )
        else
          ...history.map((h) => _buildHistoryItemCard(h)).toList(),
      ],
    );
  }

  Widget _buildHistoryItemCard(ProductHistory h) {
    // ... (Không có thay đổi gì trong hàm này)
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          h.note,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _historyDetailRow('From', h.from),
            _historyDetailRow('To', h.to),
            _historyDetailRow(
              'Time',
              DateTime.fromMillisecondsSinceEpoch(
                h.timestamp.toInt() * 1000,
              ).toLocal().toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value,
      {bool isAddress = false, BuildContext? context}) {
    // ... (Không có thay đổi gì trong hàm này)
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$title:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isAddress ? 13 : 16,
                      color: Colors.white,
                      fontFamily: isAddress ? "monospace" : null,
                    ),
                    maxLines: isAddress ? 1 : 2,
                    overflow: isAddress
                        ? TextOverflow.ellipsis
                        : TextOverflow.clip,
                  ),
                ),
                if (isAddress && context != null)
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Address copied to clipboard!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyDetailRow(String title, String value) {
    // ... (Không có thay đổi gì trong hàm này)
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title: ",
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}