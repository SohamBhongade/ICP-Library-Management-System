// =========================================================
// Project: ICP Library Management System
// Developer: Soham Bhongade
// Copyright © 2026 | All Rights Reserved
// =========================================================




import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:icp_library/services/student_import_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'pdf_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'excel_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const ICPLibraryApp());
}

class ICPLibraryApp extends StatelessWidget {
  const ICPLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICP Library Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      // CHANGE THIS LINE:
      home: const SplashScreen(),
    );
  }
}
// --- DATABASE HELPER ---

// --- LIBRARY HOME SCREEN ---
class LibraryHomeScreen extends StatefulWidget {
  final GlobalKey<_LibraryHomeScreenState> gridKey;
  const LibraryHomeScreen({super.key, required this.gridKey});
  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  @override
  void initState() {
    super.initState();
    refreshData();
  }

  List<Map<String, dynamic>> _allBooks = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  bool _isLoading = false;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();
  final List<String> _columnKeys = [
    'date',
    'acc_no',
    'author',
    'title',
    'publisher',
    'year',
    'pages',
    'cost',
    'isbn',
    'call_no',
    'bill_info',
    'source',
    'remarks',
  ];

  Future<void> refreshData() async {
    setState(() => _isLoading = true);
    try {
      // This calls the function we just added!
      final data = await DatabaseHelper.instance.getBooks();
      setState(() {
        _allBooks = data;
        _filteredBooks = data;
      });
    } catch (e) {
      debugPrint("Error loading books: $e");
    } finally {
      // This stops the spinner even if there is an error
      setState(() => _isLoading = false);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("⚠️ Danger: Wipe All Data?"),
          content: const Text(
            "This will permanently delete ALL books, students, and issue records. This action cannot be undone!",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await DatabaseHelper.instance.clearAllData();
                Navigator.pop(context);
                refreshData(); // Refresh the UI so it shows empty
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Database cleared successfully"),
                  ),
                );
              },
              child: const Text(
                "YES, DELETE EVERYTHING",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- NEW: GENERATE PROFESSIONAL QR LABELS ---
  Future<void> _generateQRBatch() async {
    final pdf = pw.Document();

    // Create label grid logic
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.GridView(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            children: _filteredBooks.map((book) {
              return pw.Container(
                margin: const pw.EdgeInsets.all(4),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      "Imperial College of Pharmacy",
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Divider(thickness: 0.5),
                    pw.SizedBox(height: 2),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: (book['acc_no'] ?? 'N/A').toString(),
                      width: 50,
                      height: 50,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "ACC: ${(book['acc_no'] ?? '')}",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                    pw.Text(
                      "Title: ${(book['title'] ?? '').toString().toUpperCase()}",
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                    pw.Text(
                      "Author: ${(book['author'] ?? '')}",
                      maxLines: 1,
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'ICP_Library_Labels',
    );
  }

  void _showBulkQRDialog() {
    final TextEditingController startCtrl = TextEditingController();
    final TextEditingController endCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Generate Professional Labels"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select a range of Accession Numbers (Numeric only)"),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    decoration: const InputDecoration(
                      labelText: "From (e.g. 1)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("to"),
                ),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    decoration: const InputDecoration(
                      labelText: "To (e.g. 50)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "OR",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                PdfService.generateProfessionalLabels(_filteredBooks);
              },
              icon: const Icon(Icons.select_all),
              label: const Text("Print All Current Results"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              int? start = int.tryParse(startCtrl.text);
              int? end = int.tryParse(endCtrl.text);

              if (start != null && end != null) {
                // Filter logic: Extract numbers from ACC_NO (e.g., "ICP 0001" -> 1)
                final rangeList = _allBooks.where((book) {
                  String accStr = (book['acc_no'] ?? "").toString();
                  // Extract just digits
                  String digits = accStr.replaceAll(RegExp(r'[^0-9]'), '');
                  int? accNum = int.tryParse(digits);
                  return accNum != null && accNum >= start && accNum <= end;
                }).toList();

                if (rangeList.isNotEmpty) {
                  Navigator.pop(ctx);
                  PdfService.generateProfessionalLabels(rangeList);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("No books found in that range!"),
                    ),
                  );
                }
              }
            },
            child: const Text("Generate Range"),
          ),
        ],
      ),
    );
  }

  void _showPdfExportDialog() {
    List<String> selectedColumns = List.from(_columnKeys);
    bool includeSummary = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Export PDF - Select Columns"),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text(
                      "INCLUDE SUMMARY",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    subtitle: const Text("Total Books & Cost"),
                    value: includeSummary,
                    onChanged: (v) => setDialogState(() => includeSummary = v!),
                  ),
                  const Divider(),
                  ..._columnKeys.map(
                    (k) => CheckboxListTile(
                      title: Text(k.toUpperCase()),
                      value: selectedColumns.contains(k),
                      onChanged: (v) {
                        setDialogState(() {
                          v!
                              ? selectedColumns.add(k)
                              : selectedColumns.remove(k);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _generatePdf(selectedColumns, includeSummary);
              },
              child: const Text("Generate PDF"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(List<String> columns, bool showSummary) async {
    try {
      final pdf = pw.Document();
      double totalCostValue = 0;
      if (showSummary) {
        for (var book in _filteredBooks) {
          String costRaw = (book['cost'] ?? '0').toString();
          String cleanNum = costRaw.replaceAll(RegExp(r'[^0-9.]'), '');
          totalCostValue += double.tryParse(cleanNum) ?? 0;
        }
      }

      String clean(dynamic input) {
        if (input == null ||
            input.toString().toLowerCase() == 'null' ||
            input.toString().isEmpty) {
          return '';
        }
        return input.toString().replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(35),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "Imperial College of Pharmacy",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "LIBRARY ACCESSION REGISTER",
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Divider(thickness: 1),
                    ],
                  ),
                ),
              ),
              if (showSummary) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Text(
                        "Total Books: ${_filteredBooks.length}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        "Total Value: ${totalCostValue.toStringAsFixed(2)}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),
              ],
              ..._filteredBooks.map((book) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "ACC NO: ${clean(book['acc_no'])}",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            "DATE: ${clean(book['date'])}",
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.Text(
                        "TITLE: ${clean(book['title'])}",
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "AUTHOR: ${clean(book['author'])}",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        columns
                            .where(
                              (k) => ![
                                'acc_no',
                                'title',
                                'author',
                                'date',
                              ].contains(k),
                            )
                            .map((k) => "${k.toUpperCase()}: ${clean(book[k])}")
                            .join("  |  "),
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Library_Report',
      );
    } catch (e) {
      debugPrint("PDF ERROR: $e");
    }
  }

  void _showEditDialog(Map<String, dynamic> book) {
    Map<String, dynamic> updatedData = Map.from(book);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Book: ${book['acc_no']}"),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: _columnKeys
                  .map(
                    (k) => TextFormField(
                      initialValue: (book[k] ?? '').toString(),
                      decoration: InputDecoration(
                        labelText: k.toUpperCase(),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => updatedData[k] = v,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.updateBook(book['id'], updatedData);
              Navigator.pop(ctx);
              refreshData();
            },
            child: const Text("Update Changes"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: Text("Are you sure you want to delete '${book['title']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DatabaseHelper.instance.deleteBook(book['id']);
              Navigator.pop(ctx);
              refreshData();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showQRCode(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Book QR: ${book['acc_no']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: (book['acc_no'] ?? 'N/A').toString(),
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Title: ${book['title']}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text("Scan this to identify the book."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showNewIssueDialog() async {
    // 1. Setup Databases
    final bookDb = await DatabaseHelper.instance.database;
    final studentDb = await DatabaseHelper.instance.database;

    // 2. Load the data
    List<Map<String, dynamic>> allStudents = await studentDb.query('students');

    // --- VARIABLES (Defined at the top of the function) ---
    Map<String, dynamic>? foundBook;
    Map<String, dynamic>? selectedStudent;
    List<Map<String, dynamic>> suggestedStudents = [];
    int days = 7; // <--- DEFAULT VALUE IS SET HERE

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Create New Issue Record"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- STEP 1: BOOK SEARCH ---
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Step 1: Scan Barcode or Enter Accession No",
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (val) async {
                      final results = await bookDb.query(
                        'books',
                        where: 'acc_no = ?',
                        whereArgs: [val.trim()],
                      );
                      setDialogState(
                        () => foundBook = results.isNotEmpty
                            ? results.first
                            : null,
                      );
                    },
                  ),

                  if (foundBook != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "✅ ACC NO: ${foundBook!['acc_no']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text("Title: ${foundBook!['title']}"),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // --- STEP 2: STUDENT SEARCH (FIXED SEARCH LOGIC) ---
                  if (selectedStudent == null) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Step 2: Type Student Name or Enrollment ID",
                        prefixIcon: Icon(Icons.person_search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v.length < 2) {
                            suggestedStudents = [];
                          } else {
                            final query = v.toLowerCase();
                            // SEARCH BOTH NAME AND ENROLLMENT ID
                            suggestedStudents = allStudents
                                .where((s) {
                                  final name = s['name']
                                      .toString()
                                      .toLowerCase();
                                  final enroll = s['enrollment']
                                      .toString()
                                      .toLowerCase();
                                  return name.contains(query) ||
                                      enroll.contains(query);
                                })
                                .take(5)
                                .toList();
                          }
                        });
                      },
                    ),
                    if (suggestedStudents.isNotEmpty)
                      Card(
                        elevation: 4,
                        child: Column(
                          children: suggestedStudents
                              .map(
                                (s) => ListTile(
                                  title: Text(s['name']),
                                  subtitle: Text("ID: ${s['enrollment']}"),
                                  onTap: () => setDialogState(() {
                                    selectedStudent = s;
                                    suggestedStudents = [];
                                  }),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ] else ...[
                    // STUDENT CONFIRMATION CARD
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        border: Border.all(color: Colors.indigo),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.indigo),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedStudent!['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text("ID: ${selectedStudent!['enrollment']}"),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setDialogState(() => selectedStudent = null),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // --- STEP 3: BORROW TIME (1 TO 7 DAYS ONLY) ---
                  // Step 3: Duration logic
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Borrow For:"),
                      DropdownButton<int>(
                        value: days,
                        // This limits the selection to exactly 1 through 7
                        items: [1, 2, 3, 4, 5, 6, 7]
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text("$d ${d == 1 ? 'Day' : 'Days'}"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => days = v!),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Due Date: ${DateTime.now().add(Duration(days: days)).toString().split(' ')[0]}",
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: (foundBook == null || selectedStudent == null)
                  ? null
                  : () async {
                      final now = DateTime.now();
                      await bookDb.insert('issues', {
                        'book_id': foundBook!['id'],
                        'book_title': foundBook!['title'],
                        'acc_no':
                            foundBook!['acc_no'], // Saves it silently in the background
                        'student_name': selectedStudent!['name'],
                        'issue_date': now.toIso8601String(),
                        'due_date': now
                            .add(Duration(days: days))
                            .toIso8601String(),
                        'status': 'ISSUED',
                      });
                      Navigator.pop(ctx);
                      refreshData(); // Correct for the Home Screen // Refresh the main list
                    },
              child: const Text("Confirm & Issue"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result != null) {
      setState(() => _isLoading = true);
      var excel = ex.Excel.decodeBytes(
        File(result.files.single.path!).readAsBytesSync(),
      );
      final db = await DatabaseHelper.instance.database;
      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows.skip(5)) {
          if (row.length < 2 || row[1] == null) continue;
          String val(int i) => (i >= row.length || row[i] == null)
              ? ''
              : row[i]!.value.toString();
          await db.insert('books', {
            'date': val(0),
            'acc_no': val(1),
            'isbn': val(2),
            'call_no': val(3),
            'author': val(4),
            'title': val(5),
            'publisher': val(6),
            'year': val(7),
            'pages': val(8),
            'cost': val(9),
            'bill_info': val(10),
            'source': val(11),
            'remarks': val(12),
          });
        }
      }
      refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1A237E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text(
                "ICP Library Management System",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text(
                  "CLEAR ALL DATA",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              TextButton.icon(
                onPressed: _showBulkQRDialog,
                icon: const Icon(Icons.grid_view, color: Colors.white),
                label: const Text(
                  "QR Labels",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _showPdfExportDialog,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text(
                  "Generate PDF",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file), // Added missing icon
                label: const Text("Import Excel"),
                onPressed: () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['xlsx'],
                      );

                  if (result != null) {
                    String filePath = result.files.single.path!;
                    await DatabaseHelper.instance.saveExcelPath(filePath);

                    setState(() => _isLoading = true);

                    // 1. RUN THE IMPORT
                    await ExcelService().importExcel(filePath);

                    // 2. THIS IS THE KEY: Reload the table from the database
                    await refreshData();
                    setState(() => _isLoading = false);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Excel Linked and Imported!"),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () async {
                  print("Refresh clicked!");
                  String? path = await DatabaseHelper.instance.getExcelPath();

                  if (path != null) {
                    setState(() => _isLoading = true);
                    await ExcelService().importExcel(path);
                    await refreshData();
                    setState(() => _isLoading = false);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Sync complete: Data updated from Excel!",
                        ),
                      ),
                    );
                  } else {
                    // 3. If no path is saved, tell them to import manually once
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Please import the Excel file once to link it.",
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: "Search Title/Acc No...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(
              () => _filteredBooks = _allBooks
                  .where(
                    (b) =>
                        (b['title'] ?? '').toString().toLowerCase().contains(
                          v.toLowerCase(),
                        ) ||
                        (b['acc_no'] ?? '').toString().toLowerCase().contains(
                          v.toLowerCase(),
                        ),
                  )
                  .toList(),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Scrollbar(
                  controller: _hScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: Scrollbar(
                      controller: _vScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _vScroll,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFF263238),
                          ),
                          headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          columns: [
                            const DataColumn(label: Text("ACTIONS")),
                            ..._columnKeys.map(
                              (k) => DataColumn(label: Text(k.toUpperCase())),
                            ),
                          ],
                          rows: _filteredBooks
                              .map(
                                (b) => DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: "View QR Code",
                                            icon: const Icon(
                                              Icons.qr_code,
                                              color: Colors.purple,
                                              size: 20,
                                            ),
                                            onPressed: () => _showQRCode(b),
                                          ),
                                          // REPLACED: Issue Book Icon removed from here.
                                          IconButton(
                                            tooltip: "Edit Entry",
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                              size: 20,
                                            ),
                                            onPressed: () => _showEditDialog(b),
                                          ),
                                          IconButton(
                                            tooltip: "Delete Entry",
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () => _confirmDelete(b),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ..._columnKeys.map((k) {
                                      String value = (b[k] ?? '-').toString();

                                      // Clean DATE format
                                      if (k == 'date' && value.contains('T')) {
                                        value = value.split('T')[0];
                                      }

                                      return DataCell(Text(value));
                                    }),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// --- STUDENT RECORDS ---
// --- STUDENT RECORDS ---
class StudentRecordsScreen extends StatefulWidget {
  const StudentRecordsScreen({super.key});

  @override
  State<StudentRecordsScreen> createState() => _StudentRecordsScreenState();
}

class _StudentRecordsScreenState extends State<StudentRecordsScreen> {
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents(); // This is the correct name for the student screen
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    final data = await db.query('students');
    setState(() {
      _allStudents = data;
      _filteredStudents = data;
      _isLoading = false;
    });
  }
  // ... keep the rest of your _filterStudents and build methods here ...

  void _filterStudents(String query) {
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final mob = (s['mobile'] ?? '').toString().toLowerCase();
        final code = (s['enrollment'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase()) ||
            mob.contains(query.toLowerCase()) ||
            code.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Records"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () async {
              await StudentImportService.deleteAllStudents();
              _loadStudents();
            },
          ),
          TextButton.icon(
            onPressed: () async {
              await StudentImportService.importStudentCsv(context);
              _loadStudents();
            },
            icon: const Icon(Icons.file_upload),
            label: const Text("Import Students"),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterStudents,
              decoration: InputDecoration(
                hintText: "Search by Name, Mobile...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                ? const Center(child: Text("No students found."))
                : ListView.builder(
                    itemCount: _filteredStudents.length,
                    itemBuilder: (c, i) => Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Text(
                            (_filteredStudents[i]['name'] ?? 'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          _filteredStudents[i]['name'] ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Mob: ${_filteredStudents[i]['mobile'] ?? 'N/A'} | Class: ${_filteredStudents[i]['student_class'] ?? 'N/A'}",
                        ),
                        trailing: Text(
                          _filteredStudents[i]['enrollment'] ?? '-',
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// --- NAVIGATION ---
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});
  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _idx = 0;
  final GlobalKey<_LibraryHomeScreenState> _libKey =
      GlobalKey<_LibraryHomeScreenState>();

  void _showAddDialog() {
    final List<String> keys = [
      'date',
      'acc_no',
      'author',
      'title',
      'publisher',
      'year',
      'pages',
      'cost',
      'isbn',
      'call_no',
      'bill_info',
      'source',
      'remarks',
    ];
    Map<String, String> data = {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Book Entry"),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: keys
                  .map(
                    (k) => TextField(
                      decoration: InputDecoration(
                        labelText: k.toUpperCase(),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => data[k] = v,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.insertBook(data);
              Navigator.pop(ctx);
              _libKey.currentState?.refreshData();
            },
            child: const Text("Save Book"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _idx == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text("Add Individual Book"),
              backgroundColor: Colors.amber,
            )
          : null,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF1A237E),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedIconTheme: const IconThemeData(color: Colors.amber),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.library_books),
                label: Text("Books"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text("Students"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_turned_in),
                label: Text("Issuing"),
              ), // <--- ADD THIS
            ],
            selectedIndex: _idx,
            onDestinationSelected: (i) => setState(() => _idx = i),
          ),
          Expanded(
            child: _idx == 0
                ? LibraryHomeScreen(gridKey: _libKey)
                : _idx == 1
                ? const StudentRecordsScreen()
                : const IssuingWatchlistScreen(), // We will create this in Step 3
          ),
        ],
      ),
    );
  }
}

//-------Update the Issuing Section----------
class IssuingWatchlistScreen extends StatefulWidget {
  const IssuingWatchlistScreen({super.key});
  @override
  State<IssuingWatchlistScreen> createState() => _IssuingWatchlistScreenState();
}

class _IssuingWatchlistScreenState extends State<IssuingWatchlistScreen> {
  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _issueRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  List<Map<String, dynamic>> _allBooks = []; // <--- ADD THIS LINE
  bool _isLoading = true;
  double finePerDay = 1.0;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // --- HELPER METHOD FOR SUMMARY BOXES IN PDF ---
  pw.Widget _buildPdfSummaryColumn(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Load all books (for the Total Books stat)
      final books = await db.query('books');

      // 2. Load issues with Student Enrollment data (JOIN query)
      final List<Map<String, dynamic>> issueData = await db.rawQuery('''
      SELECT issues.*, students.enrollment 
      FROM issues 
      LEFT JOIN students ON issues.student_name = students.name
      ORDER BY issues.issue_date DESC
    ''');

      if (mounted) {
        setState(() {
          _allBooks = books; // Used for stats
          _allRecords = issueData; // Master list
          _issueRecords = issueData; // Display list
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading issues: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculations
    int totalBooksCount = _allBooks.length;
    int issuedCount = _allRecords.where((r) => r['status'] == 'ISSUED').length;
    int availableCount = totalBooksCount - issuedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Issuing Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            tooltip: "Clear All Issues",
            onPressed: () => _confirmDeleteAllIssues(),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_turned_in),
            tooltip: "Export University Audit Log",
            onPressed: () => _generateUniversityReport(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showFineSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewIssueDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add New Issue"),
        backgroundColor: Colors.amber,
      ),
      body: Column(
        children: [
          // --- ADDED: THE STATS CARD ---
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  "Total Books",
                  totalBooksCount.toString(),
                  Colors.blue,
                ),
                _buildStatColumn(
                  "Issued",
                  issuedCount.toString(),
                  Colors.orange,
                ),
                _buildStatColumn(
                  "Available",
                  availableCount.toString(),
                  Colors.green,
                ),
              ],
            ),
          ),

          // --- THE REST OF YOUR ORIGINAL CODE (Wrapped in Expanded) ---
          Expanded(
            child: _isLoading
                ? _buildCoolLoading()
                : _issueRecords.isEmpty
                ? const Center(child: Text("No active issues found."))
                : ListView.builder(
                    itemCount: _issueRecords.length,
                    itemBuilder: (context, index) {
                      final rec = _issueRecords[index];
                      final bool isReturned = rec['status'] == 'RETURNED';

                      DateTime dueDate = DateTime.parse(rec['due_date']);
                      DateTime todayDate = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      );
                      DateTime dueOnlyDate = DateTime(
                        dueDate.year,
                        dueDate.month,
                        dueDate.day,
                      );

                      int daysDifference = dueOnlyDate
                          .difference(todayDate)
                          .inDays;
                      bool isOverdue = daysDifference < 0;

                      return Card(
                        color: isReturned
                            ? Colors.grey.shade100
                            : (isOverdue ? Colors.red.shade50 : Colors.white),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isOverdue ? Colors.red : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: isReturned,
                            onChanged: isReturned
                                ? null
                                : (v) => _showReturnConfirmation(rec),
                          ),
                          title: Text(
                            "${rec['book_title']} (Acc: ${rec['acc_no'] ?? 'N/A'})",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isReturned
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Student: ${rec['student_name']}"),
                              if (isOverdue && !isReturned)
                                Text(
                                  "🚨 OVERDUE BY ${daysDifference.abs()} DAYS (Fine: ₹${(daysDifference.abs() * finePerDay).toStringAsFixed(0)})",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else if (!isReturned)
                                Text(
                                  "⏳ $daysDifference Days Remaining (Due: ${rec['due_date'].split('T')[0]})",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                const Text(
                                  "✅ Returned Successfully",
                                  style: TextStyle(color: Colors.blue),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _returnBook(int issueId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. UPDATE STATUS ONLY (Removed return_date because the column doesn't exist)
      await db.update(
        'issues',
        {
          'status': 'RETURNED',
          // Note: If you want to track the actual return date,
          // you must first add a 'return_date' column to your table in database_helper.dart
        },
        where: 'id = ?',
        whereArgs: [issueId],
      );

      // 2. FIND THE BOOK TO MAKE IT AVAILABLE AGAIN
      final List<Map<String, dynamic>> issueData = await db.query(
        'issues',
        where: 'id = ?',
        whereArgs: [issueId],
      );

      if (issueData.isNotEmpty) {
        final String? accNo = issueData.first['acc_no'];
        if (accNo != null) {
          await db.update(
            'books',
            {'status': 'Available'},
            where: 'acc_no = ?',
            whereArgs: [accNo],
          );
        }
      }

      // 3. REFRESH THE UI
      await _loadRecords();
    } catch (e) {
      debugPrint("Return Error: $e");
    }
  }

  void _showReturnConfirmation(Map<String, dynamic> rec) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Return"),
        content: Text(
          "Has ${rec['student_name']} returned '${rec['book_title']}'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No, Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              // Added 'async'
              await _returnBook(rec['id']); // Added 'await'
              if (mounted)
                Navigator.pop(ctx); // Close prompt AFTER update is done
            },
            child: const Text(
              "Yes, Returned",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showFineSettings() {
    final TextEditingController fineCtrl = TextEditingController(
      text: finePerDay.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Fine Settings"),
        content: TextField(
          controller: fineCtrl,
          decoration: const InputDecoration(labelText: "Fine per late day (₹)"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(
                () => finePerDay = double.tryParse(fineCtrl.text) ?? 1.0,
              );
              Navigator.pop(ctx);
            },
            child: const Text("Save Rate"),
          ),
        ],
      ),
    );
  }

  double calculateFine(String dueDateString) {
    try {
      // Convert the saved string back into a Date
      DateTime dueDate = DateTime.parse(dueDateString);
      DateTime today = DateTime.now();

      // If today is past the due date
      if (today.isAfter(dueDate)) {
        // Calculate the difference in days
        int lateDays = today.difference(dueDate).inDays;

        // Return late days * rate (Example: ₹5 per day)
        // If lateDays is 0 (less than 24hrs late), we return 0
        return lateDays > 0 ? lateDays * 5.0 : 0.0;
      }
    } catch (e) {
      return 0.0;
    }
    return 0.0;
  }

  void _showNewIssueDialog() async {
    final bookDb = await DatabaseHelper.instance.database;
    Map<String, dynamic>? foundBook;
    Map<String, dynamic>? selectedStudent;
    String selectedStudentName = ""; // We store the name here
    int days = 7;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Issue New Book"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. BOOK SEARCH (BY ACCESSION NUMBER)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "1. Scan/Type Accession No",
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (val) async {
                      final results = await bookDb.query(
                        'books',
                        where: 'acc_no = ?',
                        whereArgs: [val.trim()],
                      );
                      setDialogState(
                        () => foundBook = results.isNotEmpty
                            ? results.first
                            : null,
                      );
                    },
                  ),

                  if (foundBook != null)
                    Card(
                      color: Colors.blue.shade50,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        leading: const Icon(Icons.book, color: Colors.blue),
                        title: Text(foundBook!['title']),
                        subtitle: Text("Acc No: ${foundBook!['acc_no']}"),
                      ),
                    ),

                  const SizedBox(height: 15),

                  // 2. STUDENT SEARCH (THE AUTOCOMPLETE SEARCH BAR)
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text == '')
                        return const Iterable<String>.empty();

                      final db = await DatabaseHelper.instance.database;
                      final List<Map<String, dynamic>> maps = await db.query(
                        'students',
                        where: 'name LIKE ? OR enrollment LIKE ?',
                        whereArgs: [
                          '%${textEditingValue.text}%',
                          '%${textEditingValue.text}%',
                        ],
                        limit: 5,
                      );
                      return maps.map(
                        (json) => "${json['name']} (${json['enrollment']})",
                      );
                    },
                    onSelected: (String selection) async {
                      // <--- Added async here
                      final db = await DatabaseHelper.instance.database;

                      // 1. Get the name from the selection string
                      String nameOnly = selection.split(' (')[0];

                      // 2. Fetch the full student map from the database
                      final results = await db.query(
                        'students',
                        where: 'name = ?',
                        whereArgs: [nameOnly],
                      );

                      // 3. Update the variable that the "Confirm" button is watching
                      if (results.isNotEmpty) {
                        setDialogState(() {
                          selectedStudent =
                              results.first; // This enables the button!
                        });
                      }
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: "2. Search Student Name or ID",
                              prefixIcon: Icon(Icons.person_search),
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                  ),

                  const SizedBox(height: 15),

                  // 3. DAYS SELECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Borrow Period:"),
                      DropdownButton<int>(
                        value: days,
                        items: [1, 3, 5, 7, 14]
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text("$d Days"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => days = v!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              // The button stays disabled until BOTH a book and a student are selected
              onPressed: (foundBook == null || selectedStudent == null)
                  ? null
                  : () async {
                      try {
                        final now = DateTime.now();
                        final bookDb = await DatabaseHelper.instance.database;

                        await bookDb.insert('issues', {
                          'book_id': foundBook!['id'],
                          'book_title': foundBook!['title'],
                          'acc_no': foundBook!['acc_no'],
                          'student_name':
                              selectedStudent!['name'], // Get name from Map
                          'issue_date': now.toIso8601String(),
                          'due_date': now
                              .add(Duration(days: days))
                              .toIso8601String(),
                          'status': 'ISSUED',
                        });

                        Navigator.pop(ctx); // Close Dialog
                        _loadRecords(); // REFRESH DATA IMMEDIATELY

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Book Issued Successfully!"),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("❌ Error: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: const Text("Confirm Issue"),
            ),
          ],
        ),
      ),
    );
  }

  // --- UNIVERSITY AUDIT REPORT GENERATOR ---
  // --- UPDATED REPORT GENERATOR ---
  Future<void> _generateUniversityReport() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // 1. CALCULATE TOTALS
    int totalBooksCount = _allBooks.length;
    int issuedCount = _allRecords.where((r) => r['status'] == 'ISSUED').length;
    int availableCount = totalBooksCount - issuedCount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat.a4.landscape, // Landscape for the audit log table
        margin: const pw.EdgeInsets.all(32), // Standard margins
        build: (pw.Context context) {
          return [
            // --- HEADER (ORIGINAL LAYOUT) ---
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Imperial College of Pharmacy Library - ISSUE AUDIT LOG",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text("Academic Year: 2024-2025"),
                  pw.Text(
                    "Report Generated: ${now.day}/${now.month}/${now.year}",
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // --- ADDED: THE 3 SUMMARY BOXES (MATCHES IMAGE 1 LAYOUT) ---
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(
                vertical: 12,
              ), // Give it space
              padding: const pw.EdgeInsets.all(12), // Inner padding
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400), // Grey border
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(8),
                ), // Rounded corners
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceAround, // Space boxes evenly
                children: [
                  _buildPdfSummaryColumn("Total Books", "$totalBooksCount"),
                  _buildPdfSummaryColumn("Issued", "$issuedCount"),
                  _buildPdfSummaryColumn("Available", "$availableCount"),
                ],
              ),
            ),
            pw.SizedBox(height: 10), // Space before table
            // --- THE AUDIT LOG TABLE (ORIGINAL LAYOUT) ---
            pw.TableHelper.fromTextArray(
              // Note: TableHelper is often more stable for text arrays
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: [
                'Student Name\n(Enrollment)',
                'Book Title\n(Acc No)',
                'Issue Date',
                'Allowed\nDays',
                'Return Date',
                'Days Kept',
                'Fine Paid',
                'Status',
              ],
              data: _allRecords.map<List<dynamic>>((rec) {
                return [
                  "${rec['student_name']}\n(${rec['enrollment'] ?? 'N/A'})",
                  "${rec['book_title']}\n(${rec['acc_no']})",
                  rec['issue_date'].toString().split('T')[0],
                  "${DateTime.parse(rec['due_date'].toString()).difference(DateTime.parse(rec['issue_date'].toString())).inDays}",
                  rec['due_date'].toString().split('T')[0],
                  "0",
                  "0",
                  rec['status'].toString(),
                ];
              }).toList(),
            ),

            // --- FOOTER (ORIGINAL LAYOUT) ---
            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 20),
              trailing: pw.Text(
                "Librarian Signature: ____________________",
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ];
        },
      ),
    );

    // Layout the PDF
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'ICP_Library_Audit_Report_${now.millisecondsSinceEpoch}',
    );
  }

  Widget _buildCoolLoading() {
    return Center(
      child: Shimmer.fromColors(
        baseColor: Colors.amber.withOpacity(0.3),
        highlightColor: Colors.amber.withOpacity(0.1),
        child: const Text(
          "LOADING DATA...",
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Put this at the very bottom of main.dart
  Future<List<Map<String, dynamic>>> fetchRecordsInBackground(
    dynamic dbPath,
  ) async {
    // We have to re-open the connection in the background worker
    final db = await openDatabase(dbPath);
    return await db.rawQuery('''
    SELECT issues.*, students.enrollment 
    FROM issues 
    LEFT JOIN students ON issues.student_name = students.name
    ORDER BY issues.issue_date DESC
  ''');
  }

  void _confirmDeleteAllIssues() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Test Data?"),
        content: const Text(
          "This will delete ALL issue records and mark all books as Available. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DatabaseHelper.instance.deleteAllIssues();
              Navigator.pop(ctx);
              _loadRecords(); // Refresh the screen to show an empty list
            },
            child: const Text(
              "DELETE EVERYTHING",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

// MAKE SURE THIS IS AT THE BOTTOM OF THE FILE, OUTSIDE ALL OTHER CLASSES
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment
                  .center, // Fixed: Changed from MainValue to MainAxisAlignment
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 180,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.school, size: 100, color: Colors.indigo),
                ),
                const SizedBox(height: 30),
                const Text(
                  "IMPERIAL COLLEGE OF PHARMACY",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Library Management System",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: Text(
              "Designed and Made by: Soham Bhongade",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
