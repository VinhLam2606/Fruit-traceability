// lib/dashboard/ui/scan_barcode_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled/dashboard/bloc/user_organization_bloc.dart';
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
  bool _isDisposed = false;

  final List<String> _processTypes = const [
    'Cultivation', 'Processing', 'Packaging', 'Transport', 'Distribution'
  ];

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionTimeoutMs: 1000);
  }

  void _startNewScan() {
    if (_isDisposed) return;
    setState(() {
      _lastScannedCode = null;
      _batchIdController.clear();
    });
    context.read<ScanBloc>().add(ScanInitializeEvent());
    _controller.start();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    _batchIdController.dispose();
    super.dispose();
  }

  /// ✅ 2. SỬA LẠI: Kiểm tra xem user có thuộc tổ chức nào không
  /// bằng cách đọc từ UserOrganizationBloc.
  bool _hasOrganization(BuildContext context) {
    // Dùng context.watch để widget tự động cập nhật khi trạng thái BLoC thay đổi.
    final orgState = context.watch<UserOrganizationBloc>().state;
    return orgState is UserOrganizationLoaded;
  }

  /// ✅ 3. SỬA LẠI: Lấy tên tổ chức từ UserOrganizationBloc.
  String? _getOrganizationName(BuildContext context) {
    // Dùng context.read vì chỉ cần đọc giá trị hiện tại, không cần lắng nghe thay đổi.
    final state = context.read<UserOrganizationBloc>().state;
    if (state is UserOrganizationLoaded) {
      return state.organization.organizationName;
    }
    return null;
  }

  /// Dialog để thêm một bước quy trình mới
  Future<void> _showAddProcessDialog(Product product) async {
    final processNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final scanBloc = context.read<ScanBloc>();
    int selectedProcessTypeIndex = 0; // Mặc định là 'Cultivation'

    if (!mounted) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF243B55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Add Process Step', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: processNameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dialogInputDecoration('Process Name (e.g., "Harvesting Lot A")'),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      value: selectedProcessTypeIndex,
                      items: _processTypes.asMap().entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedProcessTypeIndex = value;
                          });
                        }
                      },
                      decoration: _dialogInputDecoration('Process Type'),
                      dropdownColor: const Color(0xFF141E30),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: _dialogInputDecoration('Description or Note'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  child: const Text('Submit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final name = processNameController.text.trim();
                    final desc = descriptionController.text.trim();
                    if (name.isNotEmpty) {
                      scanBloc.add(AddProcessStepEvent(
                        batchId: product.batchId,
                        processName: name,
                        processType: selectedProcessTypeIndex,
                        description: desc,
                      ));
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _dialogInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
    );
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
        child: BlocConsumer<ScanBloc, ScanState>(
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
                    child: _buildContent(context, scanState, scanBloc),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionAndHistorySection(BuildContext context, ProductInfoLoadedState scanState, ScanBloc bloc) {
    // ✅ Logic này giờ đã hoạt động đúng vì các hàm helper đã được sửa
    final userOrgName = _getOrganizationName(context);
    final canUpdate = userOrgName != null && userOrgName == scanState.product.organizationName;

    if (scanState is! ProductDetailsLoadedState) {
      return Center(
        child: Column(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.withOpacity(0.9),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
              ),
              icon: const Icon(Icons.history, size: 20),
              label: const Text("View Transaction History", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => bloc.add(FetchProductHistoryEvent(scanState.product.batchId)),
            ),
            const SizedBox(height: 15),
            if (canUpdate)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text("Add Process Step", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showAddProcessDialog(scanState.product),
              )
            else if (!_hasOrganization(context))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "💡 Join an organization to add process steps to products",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Transaction History",
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (scanState.history.isEmpty)
          const Text("No transactions have been recorded yet.",
              style: TextStyle(color: Colors.white54))
        else
          ...scanState.history.map((h) => _buildHistoryItemCard(h)).toList(),
      ],
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
                if (_isDisposed) return;

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
              onSubmitted: (value) {
                final batchId = value.trim();
                if (batchId.isNotEmpty) {
                  setState(() => _lastScannedCode = batchId);
                  scanBloc.add(BarcodeScannedEvent(batchId));
                }
              },
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
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildProductHeader(context, scanState.product),
            const SizedBox(height: 20),
            _buildActionAndHistorySection(context, scanState, bloc),
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

  // === HÀM MỚI: Helper để tạo nhóm thông tin ===
  Widget _buildInfoGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.greenAccent, // Màu nhấn cho tiêu đề nhóm
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children, // Thêm các _infoRow vào đây
        const SizedBox(height: 16), // Khoảng cách giữa các nhóm
      ],
    );
  }

  // === HÀM ĐƯỢC VIẾT LẠI: Gom nhóm thông tin ===
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
          // Tiêu đề chính (Tên sản phẩm)
          Text(
            product.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white38, height: 25),

          // --- Nhóm 1: Thông tin Truy xuất ---
          _buildInfoGroup(
            "Tracking Information",
            [
              _infoRow('Batch ID', product.batchId, isAddress: true),
              _infoRow('Status', product.status),
              _infoRow('Current Owner', product.currentOwner, isAddress: true),
              _infoRow('Organization', product.organizationName),
            ],
          ),

          // --- Nhóm 2: Chi tiết Sản phẩm ---
          _buildInfoGroup(
            "Product Details",
            [
              _infoRow('Seed Variety', product.seedVariety),
              _infoRow('Origin', product.origin),
              _infoRow('Date Created', DateTime.fromMillisecondsSinceEpoch(product.date.toInt() * 1000).toLocal().toString().split(' ')[0]),
            ],
          ),
        ],
      ),
    );
  }

  // === HÀM NÀY GIỮ NGUYÊN (dùng cho _buildInfoGroup) ===
  Widget _infoRow(String title, String value, {bool isAddress = false}) {
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
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItemCard(ProductHistory h) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            h.note,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          _historyDetailRow('From', h.from),
          _historyDetailRow('To', h.to),
          _historyDetailRow('Time', h.dateTime.toString().split('.')[0]),
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