// lib/dashboard/ui/scan_barcode_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart';
import 'package:untitled/dashboard/bloc/user_organization_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/model/productHistory.dart';
// === THÊM MỚI: Import model timeline ===
import 'package:untitled/dashboard/model/timeline_item.dart';

class ScanBarcodePage extends StatefulWidget {
  const ScanBarcodePage({super.key});

  @override
  State<ScanBarcodePage> createState() => _ScanBarcodePageState();
}

// 💡 SỬA LỖI 1: Thêm "with WidgetsBindingObserver"
class _ScanBarcodePageState extends State<ScanBarcodePage>
    with WidgetsBindingObserver {
  late MobileScannerController _controller;
  String? _lastScannedCode;
  final TextEditingController _batchIdController = TextEditingController();
  bool _isDisposed = false;

  bool _isCameraRunning = false;

  final List<String> _processTypes = const [
    'Cultivation',
    'Processing',
    'Packaging',
    'Transport',
    'Distribution',
  ];

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionTimeoutMs: 1000);
    // 💡 Đăng ký theo dõi
    WidgetsBinding.instance.addObserver(this);
  }

  // 💡 SỬA LỖI 1: Thêm hàm xử lý vòng đời ứng dụng
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isDisposed) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // Khi quay lại app, nếu camera đang được phép chạy, hãy bật lại
        if (_isCameraRunning) {
          _controller.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden: // 💡 THÊM "hidden" VÀO ĐÂY
        // Khi rời app (hoặc chuyển tab), luôn luôn tắt camera
        if (_isCameraRunning) {
          _controller.stop();
        }
        break;
    }
  }

  void _startNewScan() {
    if (_isDisposed) return;
    setState(() {
      _lastScannedCode = null;
      _batchIdController.clear();
      _isCameraRunning = true; // 💡 Đánh dấu camera đang chạy
    });
    context.read<ScanBloc>().add(ScanInitializeEvent());
    _controller.start();
  }

  // 💡 SỬA LỖI 2: Cập nhật hàm onDetect
  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isDisposed) return;
    final code = capture.barcodes.first.rawValue;

    if (code != null && code.isNotEmpty && _lastScannedCode != code) {
      setState(() {
        _lastScannedCode = code;
        _isCameraRunning = false; // 💡 Dừng camera
      });
      _batchIdController.text = code;
      // 💡 SỬA LỖI: Dùng context.read<ScanBloc>()
      context.read<ScanBloc>().add(BarcodeScannedEvent(code));
      _controller.stop();
    }
  }

  @override
  void dispose() {
    // 💡 Huỷ đăng ký
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    _controller.dispose();
    _batchIdController.dispose();
    super.dispose();
  }

  bool _hasOrganization(BuildContext context) {
    // (Giữ nguyên)
    final orgState = context.watch<UserOrganizationBloc>().state;
    return orgState is UserOrganizationLoaded;
  }

  String? _getOrganizationName(BuildContext context) {
    // (Giữ nguyên)
    final state = context.read<UserOrganizationBloc>().state;
    if (state is UserOrganizationLoaded) {
      return state.organization.organizationName;
    }
    return null;
  }

  Future<void> _showAddProcessDialog(Product product) async {
    // (Giữ nguyên)
    final processNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final scanBloc = context.read<ScanBloc>();
    int selectedProcessTypeIndex = 0;
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF243B55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                'Add Process Step',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: processNameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dialogInputDecoration(
                        'Process Name (e.g., "Harvesting Lot A")',
                      ),
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
                    final name = processNameController.text.trim();
                    final desc = descriptionController.text.trim();
                    if (name.isNotEmpty) {
                      scanBloc.add(
                        AddProcessStepEvent(
                          batchId: product.batchId,
                          processName: name,
                          processType: selectedProcessTypeIndex,
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
      },
    );
  }

  InputDecoration _dialogInputDecoration(String hint) {
    // (Giữ nguyên)
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white70),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.greenAccent),
      ),
    );
  }

  // 💡 HÀM MỚI: Lấy icon cho từng loại quy trình
  IconData _getIconForProcess(int processType) {
    switch (processType) {
      case 0: // Cultivation (Trồng trọt)
        return Icons.eco_outlined; // 🌿
      case 1: // Processing (Sơ chế)
        return Icons.settings_outlined; // 🏭
      case 2: // Packaging (Đóng gói)
        return Icons.inventory_2_outlined; // 📦
      case 3: // Transport (Vận chuyển)
        return Icons.local_shipping_outlined; // 🚚
      case 4: // Distribution (Phân phối)
        return Icons.store_outlined; // 🏪
      default:
        return Icons.help_outline;
    }
  }

  // 💡 SỬA LỖI 3: Bỏ "default"
  IconData _getIconForHistory(HistoryType type) {
    switch (type) {
      case HistoryType.create:
        return Icons.add_circle_outline;
      case HistoryType.transferred:
        return Icons.swap_horiz_outlined;
      case HistoryType.processed:
        return Icons.settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    // (Giữ nguyên)
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

  // === THAY ĐỔI LỚN: VIẾT LẠI HOÀN TOÀN HÀM NÀY ===
  Widget _buildActionAndHistorySection(
    BuildContext context,
    ProductInfoLoadedState scanState,
    ScanBloc bloc,
  ) {
    final userOrgName = _getOrganizationName(context);
    final canUpdate =
        userOrgName != null &&
        userOrgName == scanState.product.organizationName;

    // ---
    // GIAI ĐOẠN 1: Mới tải xong Product, CHƯA tải Timeline
    // (State là ProductInfoLoadedState NHƯNG KHÔNG PHẢI ProductDetailsLoadedState)
    // ---
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
              // Đổi tên nút
              label: const Text(
                "View Full Timeline",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () =>
                  bloc.add(FetchProductHistoryEvent(scanState.product.batchId)),
            ),
            const SizedBox(height: 15),
            // Logic hiển thị nút "Add Process Step"
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
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  "Add Process Step",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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

    // ---
    // GIAI ĐOẠN 2: Đã tải xong Timeline (State là ProductDetailsLoadedState)
    // ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Product Timeline", // Đổi tên tiêu đề
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // Vẫn hiển thị nút "Add" ở đây nếu có quyền
        if (canUpdate)
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  "Add Process Step",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showAddProcessDialog(scanState.product),
              ),
            ),
          ),

        // Đọc từ `scanState.timeline` (danh sách đã gộp)
        if (scanState.timeline.isEmpty)
          const Text(
            "No timeline events have been recorded yet.",
            style: TextStyle(color: Colors.white54),
          )
        else
          // Lặp qua danh sách timeline và gọi hàm router
          ...scanState.timeline
              .map((item) => _buildTimelineItem(item))
              .toList(),
      ],
    );
  }

  // === HÀM MỚI: Router để chọn card 🔵 hay 🟠 ===
  Widget _buildTimelineItem(TimelineItem item) {
    // Nếu là ProcessEventItem -> Vẽ card cam 🟠
    if (item is ProcessEventItem) {
      return _buildProcessItemCard(item.processStep);
    }
    // Nếu là HistoryEventItem -> Vẽ card xanh 🔵
    if (item is HistoryEventItem) {
      return _buildHistoryItemCard(item.historyEvent);
    }
    // Mặc định
    return const SizedBox.shrink();
  }

  // === ⛔️ HÀM NÀY ĐÃ ĐƯỢC THAY THẾ ⛔️ ===
  Widget _buildProcessItemCard(ProcessStep p) {
    // 1. Lấy icon tương ứng
    final icon = _getIconForProcess(p.processType);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      // Giảm padding ngang một chút để có chỗ cho icon
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.5),
          width: 1.5,
        ), // <-- Viền cam
      ),
      // 2. Sử dụng Row để chứa Icon và nội dung
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Căn icon và chữ lên trên
        children: [
          // 3. Thêm Icon vào
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 2.0),
            child: Icon(icon, color: Colors.orangeAccent, size: 28),
          ),
          // 4. Bọc Column cũ bằng Expanded để nó lấp đầy phần còn lại
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.processName, // Tên quy trình
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent, // <-- Màu cam
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                _historyDetailRow(
                  'Type',
                  _processTypes[p.processType],
                ), // Lấy tên từ list
                _historyDetailRow('Organization', p.organizationName),
                if (p.description.isNotEmpty) // Chỉ hiển thị nếu có
                  _historyDetailRow('Description', p.description),
                _historyDetailRow(
                  'Time',
                  DateTime.fromMillisecondsSinceEpoch(
                    p.date.toInt() * 1000,
                  ).toLocal().toString().split('.')[0],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === ⛔️ HÀM NÀY ĐÃ ĐƯỢC THAY THẾ ⛔️ ===
  Widget _buildHistoryItemCard(ProductHistory h) {
    final bool isCreateEvent = h.type == HistoryType.create;
    // 1. Lấy icon tương ứng
    final icon = _getIconForHistory(h.type);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      // Giảm padding ngang
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(0.5),
          width: 1.5,
        ), // <-- Viền xanh
      ),
      // 2. Sử dụng Row
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3. Thêm Icon
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 2.0),
            child: Icon(icon, color: Colors.greenAccent, size: 28),
          ),
          // 4. Bọc Column cũ bằng Expanded
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.note, // "Product Created" hoặc "Transferred"
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent, // <-- Màu xanh
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                // Chỉ hiển thị 'From' nếu không phải sự kiện Create
                if (!isCreateEvent)
                  _historyDetailRow('From', h.from, isAddress: true),
                _historyDetailRow('To', h.to, isAddress: true),
                _historyDetailRow('Time', h.dateTime.toString().split('.')[0]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (Các hàm build UI còn lại giữ nguyên)

  Widget _buildScannerSection(ScanBloc scanBloc) {
    // (Giữ nguyên)
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
              // 💡 SỬA LỖI: Trỏ onDetect đến hàm mới
              onDetect: _onBarcodeDetected,
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
    // (Giữ nguyên)
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
                  setState(() {
                    _lastScannedCode = batchId;
                    _isCameraRunning = false; // 💡 Dừng camera
                  });
                  _controller.stop();
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
                setState(() {
                  _lastScannedCode = batchId;
                  _isCameraRunning = false; // 💡 Dừng camera
                });
                _controller.stop();
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
    // (Giữ nguyên)
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
        // Cập nhật onRefresh để tải lại cả timeline nếu cần
        onRefresh: () async {
          bloc.add(BarcodeScannedEvent(scanState.product.batchId));
          // Nếu đang ở state chi tiết (đã tải timeline), cũng refresh luôn timeline
          if (scanState is ProductDetailsLoadedState) {
            bloc.add(FetchProductHistoryEvent(scanState.product.batchId));
          }
        },
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
    // (Giữ nguyên)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  // === HÀM ĐƯỢC VIẾT LẠI: Gom nhóm thông tin ===
  Widget _buildProductHeader(BuildContext context, Product product) {
    // (Giữ nguyên)
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
          _buildInfoGroup("Tracking Information", [
            _infoRow('Batch ID', product.batchId, isAddress: true),
            _infoRow('Status', product.status),
            _infoRow('Current Owner', product.currentOwner, isAddress: true),
            _infoRow('Organization', product.organizationName),
          ]),
          _buildInfoGroup("Product Details", [
            _infoRow('Seed Variety', product.seedVariety),
            _infoRow('Origin', product.origin),
            _infoRow(
              'Date Created',
              DateTime.fromMillisecondsSinceEpoch(
                product.date.toInt() * 1000,
              ).toLocal().toString().split(' ')[0],
            ),
          ]),
        ],
      ),
    );
  }

  // === HÀM NÀY GIỮ NGUYÊN (dùng cho _buildInfoGroup) ===
  Widget _infoRow(String title, String value, {bool isAddress = false}) {
    // (Giữ nguyên)
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

  // === THAY ĐỔI: Thêm `isAddress` cho `_historyDetailRow` ===
  Widget _historyDetailRow(
    String title,
    String value, {
    bool isAddress = false,
  }) {
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
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: isAddress
                  ? "monospace"
                  : null, // Thêm font monospace cho địa chỉ
            ),
          ),
        ),
      ],
    );
  }
}
