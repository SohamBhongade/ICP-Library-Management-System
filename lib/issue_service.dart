import 'database_helper.dart'; // Add this import at the top

class IssueService {
  static Future<void> saveIssueRecord({
    required int bookId,
    required String bookTitle,
    required String studentName,
    required int daysToBorrow,
  }) async {
    // Talk to the SAME database as everyone else
    final db = await DatabaseHelper.instance.database;

    final now = DateTime.now();
    final dueDate = now.add(Duration(days: daysToBorrow));

    await db.insert('issues', {
      'book_id': bookId,
      'book_title': bookTitle,
      'student_name': studentName,
      'issue_date': now.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': 'ISSUED',
    });
  }
}
