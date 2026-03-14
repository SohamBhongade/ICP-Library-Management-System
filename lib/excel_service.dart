import 'dart:io';
import 'package:excel/excel.dart';
import 'package:sqflite/sqflite.dart'; // <--- THIS FIXES THE UNDEFINED NAME ERROR
import 'database_helper.dart';

class ExcelService {
  Future<void> importExcel(String filePath) async {
    var bytes = File(filePath).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    final db = await DatabaseHelper.instance.database;

    for (var table in excel.tables.keys) {
      // Skip 6 rows because your file has 6 header rows
      var rows = excel.tables[table]!.rows.skip(6);

      for (var row in rows) {
        // According to your file:
        // Index 0: Date, Index 1: Accession No, Index 4: Author, Index 5: Title
        if (row.length < 2 || row[1] == null || row[1]!.value == null) continue;

        String accNo = row[1]!.value.toString();

        Map<String, dynamic> bookData = {
          'acc_no': accNo,
          'date': row[0]?.value?.toString() ?? '',
          'author': row[4]?.value?.toString() ?? '',
          'title': row[5]?.value?.toString() ?? '',
          'publisher': row[6]?.value?.toString() ?? '',
          'year': row[7]?.value?.toString() ?? '',
          'pages': row[8]?.value?.toString() ?? '',
          'cost': row[9]?.value?.toString() ?? '',
          'bill_info': row[10]?.value?.toString() ?? '',
          'isbn': row[2]?.value?.toString() ?? '', // Column C
          'call_no': row[3]?.value?.toString() ?? '', // Column D
          'source': row[11]?.value?.toString() ?? '',
          'remarks': row[12]?.value?.toString() ?? '',
          'status': 'Available',
        };

        // Use ConflictAlgorithm.replace to update existing books on Refresh
        await db.insert(
          'books',
          bookData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }
}
