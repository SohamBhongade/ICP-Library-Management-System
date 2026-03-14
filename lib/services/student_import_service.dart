import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../database_helper.dart'; // Connects to your main unified database

class StudentImportService {
  // We use the main DatabaseHelper to ensure students aren't lost in a separate file
  static Future<void> importStudentCsv(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final lines = const LineSplitter().convert(utf8.decode(bytes));

      final db = await DatabaseHelper.instance.database;
      int importedCount = 0;
      int skippedCount = 0;

      await db.transaction((txn) async {
        for (var line in lines) {
          final values = line.split(',');
          // If the line is empty or too short, skip it
          if (values.length < 3) continue;

          // COLUMN MAPPING:
          // values[0] = Name
          // values[1] = Email (We skip this)
          // values[2] = Enrollment ID (The 'Student Code')
          // values[3] = Mobile

          String name = values[0].trim();
          String enrollment = values[2].trim(); // Changed from [1] to [2]
          String mobile = values.length > 3
              ? values[3].trim()
              : ""; // Changed from [2] to [3]
          String className = values.length > 4 ? values[4].trim() : "";

          if (name.isNotEmpty && name.toLowerCase() != "student name") {
            final existing = await txn.query(
              'students',
              where: 'enrollment = ?',
              whereArgs: [enrollment],
            );

            if (existing.isEmpty) {
              await txn.insert('students', {
                'name': name,
                'enrollment': enrollment,
                'mobile': mobile,
                'student_class': className,
              });
              importedCount++;
            } else {
              skippedCount++;
            }
          }
        }
      });

      // --- YOUR ORIGINAL SNACKBAR CODE ---
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Imported: $importedCount | Skipped Duplicates: $skippedCount",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Import Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> deleteAllStudents() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('students');
  }
}
