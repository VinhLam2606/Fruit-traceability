// lib/dashboard/ui/scan_barcode_page.dart
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
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
  final TextEditingController _batchIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionTimeoutMs: 1000);
  }

  void _startNewScan() {
    setState(() {
      _lastScannedCode = null;
      _batchIdController.clear();
    });
    context.read<ScanBloc>().add(ScanInitializeEvent());
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _batchIdController.dispose();
    super.dispose();
  }

  Future<void> _showUpdateDialog(Product product) async {
    final descriptionController = TextEditingController();
    final scanBloc = context.read<ScanBloc>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF243B55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Update Product Information',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: descriptionController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new description or note',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.greenAccent),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
              ),
              child: const Text(
                'Submit',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                final desc = descriptionController.text.trim();
                if (desc.isNotEmpty) {
                  scanBloc.add(
                    UpdateProductDescriptionEvent(
                      batchId: product.batchId,
                      description: desc,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- HÀM MỚI: Chọn icon dựa trên nội dung ghi chú ---
  IconData _getIconForHistoryNote(String note) {
    final lowerNote = note.toLowerCase();
    if (lowerNote.contains('create')) {
      return Icons.factory_outlined; // Icon nhà máy
    }
    if (lowerNote.contains('transfer')) {
      return Icons.local_shipping_outlined; // Icon xe tải
    }
    if (lowerNote.contains('receive')) {
      return Icons.storefront_outlined; // Icon cửa hàng
    }
    if (lowerNote.contains('update')) {
      return Icons.edit_note_outlined; // Icon chỉnh sửa
    }
    return Icons.info_outline; // Icon mặc định
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
          'Scan or Enter Product Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: BlocBuilder<OrganizationBloc, OrganizationState>(
          builder: (context, orgState) {
            return BlocConsumer<ScanBloc, ScanState>(
              listener: (context, scanState) {
                if (scanState is ScanErrorState) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text("❌ ${scanState.error}"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                }
              },
              builder: (context, scanState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildScannerSection(scanBloc),
                      _buildManualInputSection(scanBloc),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _buildContent(
                          context,
                          scanState,
                          orgState,
                          scanBloc,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildScannerSection(ScanBloc scanBloc) {
    return Container(
      padding: const EdgeInsets.only(top: 80),
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final code = capture.barcodes.first.rawValue;
                if (code != null &&
                    code.isNotEmpty &&
                    _lastScannedCode != code) {
                  setState(() => _lastScannedCode = code);
                  _batchIdController.text = code;
                  scanBloc.add(BarcodeScannedEvent(code));
                  _controller.stop();
                }
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.greenAccent.withOpacity(0.7),
                width: 3,
              ),
            ),
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
    );
  }

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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Colors.greenAccent,
                    width: 2,
                  ),
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
                FocusScope.of(context).unfocus();
                setState(() => _lastScannedCode = batchId);
                scanBloc.add(BarcodeScannedEvent(batchId));
              }
            },
            child: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScanState scanState,
    OrganizationState orgState,
    ScanBloc bloc,
  ) {
    if (scanState is ScanLoadingState ||
        scanState is ProductHistoryLoadingState) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    if (scanState is ScanInitialState || scanState is ScanErrorState) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            scanState is ScanErrorState
                ? "Error: ${scanState.error}\nPlease scan again."
                : "Scan a barcode or enter an ID to search.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    if (scanState is ProductInfoLoadedState) {
      return RefreshIndicator(
        color: Colors.greenAccent,
        backgroundColor: const Color(0xFF243B55),
        onRefresh: () async =>
            bloc.add(BarcodeScannedEvent(scanState.product.batchId)),
        child: Column(
          children: [
            _buildProductHeader(context, scanState.product),
            const SizedBox(height: 20),
            _buildActionAndHistorySection(context, scanState, orgState, bloc),
            if (scanState.historyErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  scanState.historyErrorMessage!,
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
    return const SizedBox.shrink();
  }

  Widget _buildProductHeader(BuildContext context, Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(0.6),
          width: 1.2,
        ),
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
          _infoRow(
            'Batch ID',
            product.batchId,
            isAddress: true,
            context: context,
          ),
          _infoRow('Organization', product.organizationName),
          _infoRow(
            'Date Created',
            DateFormat('dd/MM/yyyy HH:mm').format(
              DateTime.fromMillisecondsSinceEpoch(
                product.date.toInt() * 1000,
              ).toLocal(),
            ),
          ),
          _infoRow(
            'Current Owner',
            product.currentOwner,
            isAddress: true,
            context: context,
          ),
        ],
      ),
    );
  }

  Widget _buildActionAndHistorySection(
    BuildContext context,
    ProductInfoLoadedState scanState,
    OrganizationState orgState,
    ScanBloc bloc,
  ) {
    bool canUpdate = false;
    if (orgState is OrganizationLoaded) {
      canUpdate =
          scanState.product.organizationName ==
          orgState.organization.organizationName;
    }

    if (scanState is! ProductDetailsLoadedState) {
      return Center(
        child: Column(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.withOpacity(0.9),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.history, size: 20),
              label: const Text(
                "View Transaction History",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () =>
                  bloc.add(FetchProductHistoryEvent(scanState.product.batchId)),
            ),
            const SizedBox(height: 15),
            if (canUpdate)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.edit, size: 20),
                label: const Text(
                  "Update Product Info",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showUpdateDialog(scanState.product),
              ),
          ],
        ),
      );
    }

    // --- THAY ĐỔI LỚN: Xây dựng giao diện TIMELINE thay vì danh sách thường ---
    return _buildHistoryTimeline(scanState.history);
  }

  // --- WIDGET MỚI: Xây dựng toàn bộ dòng thời gian ---
  Widget _buildHistoryTimeline(List<ProductHistory> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Transaction History",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        if (history.isEmpty)
          const Center(
            child: Text(
              "No transactions have been recorded yet.",
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              return _buildHistoryItemCard(
                history[index],
                index,
                history.length,
              );
            },
          ),
      ],
    );
  }

  // --- WIDGET ĐƯỢC VIẾT LẠI HOÀN TOÀN: Giao diện cho một mục trong timeline ---
  Widget _buildHistoryItemCard(ProductHistory h, int index, int totalItems) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phần 1: Cột Timeline (Icon và đường kẻ)
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Đường kẻ phía trên (trừ item đầu tiên)
                Expanded(
                  child: Container(
                    width: 2,
                    color: index == 0
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
                // Icon ở giữa
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.greenAccent.withOpacity(0.8),
                  child: Icon(
                    _getIconForHistoryNote(h.note),
                    color: Colors.black87,
                    size: 24,
                  ),
                ),
                // Đường kẻ phía dưới (trừ item cuối cùng)
                Expanded(
                  child: Container(
                    width: 2,
                    color: index == totalItems - 1
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Phần 2: Card chứa nội dung chi tiết
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.note, // Tiêu đề hành động
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                      fontSize: 16,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  _historyDetailRow('From', h.from),
                  const SizedBox(height: 4),
                  _historyDetailRow('To', h.to),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      DateFormat(
                        'dd/MM/yyyy HH:mm:ss',
                      ).format(h.dateTime.toLocal()),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value, {
    bool isAddress = false,
    BuildContext? context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$title:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: isAddress ? "monospace" : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isAddress)
                  Builder(
                    builder: (builderContext) {
                      return GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(builderContext).showSnackBar(
                            const SnackBar(
                              content: Text('📋 Address copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.copy,
                          color: Colors.greenAccent,
                          size: 18,
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
    return Row(
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
    );
  }
}
