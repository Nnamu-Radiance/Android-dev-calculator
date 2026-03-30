import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';

// Small helper extension used in XML parsing
extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

// ============================================================================
// TYPE ALIASES & FUNCTION SIGNATURES
// ============================================================================

typedef GradeCalculator = String Function(double marks);
typedef GPACalculator = double Function(double marks);
typedef StudentPredicate = bool Function(GradeEntry student);
typedef StudentTransformer<T> = T Function(GradeEntry student);

// ============================================================================
// GRADE ENTRY MODEL
// ============================================================================

class GradeEntry {
  final String name;
  final double marks;
  late final String grade;
  late final double gpa;

  GradeEntry({
    required this.name,
    required this.marks,
    required GradeCalculator gradeFunc,
    required GPACalculator gpaFunc,
  }) {
    grade = gradeFunc(marks);
    gpa = gpaFunc(marks);
  }

  @override
  String toString() => '$name: $marks → $grade (GPA: $gpa)';
}

// ============================================================================
// GRADING SYSTEM (Higher-Order Functions)
// ============================================================================

class GradingSystem {
  static const Map<String, double> gradeScale = {
    'A': 80.0,
    'B+': 70.0,
    'B': 60.0,
    'C+': 55.0,
    'C': 50.0,
    'D+': 45.0,
    'D': 40.0,
    'F': 0.0,
  };

  static const Map<String, double> gradeToGPA = {
    'A': 4.0,
    'B+': 3.5,
    'B': 3.0,
    'C+': 2.5,
    'C': 2.0,
    'D+': 1.5,
    'D': 1.0,
    'F': 0.0,
  };

  static GradeCalculator createGradeCalculator({
    Map<String, double>? customScale,
  }) {
    final scale = customScale ?? gradeScale;
    return (double marks) {
      for (final entry in scale.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) {
        if (marks >= entry.value) return entry.key;
      }
      return 'F';
    };
  }

  static GPACalculator createGPACalculator({
    Map<String, double>? customGPAMap,
  }) {
    final gpaMap = customGPAMap ?? gradeToGPA;
    final gradeCalc = createGradeCalculator();
    return (double marks) {
      final grade = gradeCalc(marks);
      return gpaMap[grade] ?? 0.0;
    };
  }
}

// ============================================================================
// DATA TRANSFORMATION (Functional Programming)
// ============================================================================

class DataTransformer {
  static List<GradeEntry> filterStudents(
      List<GradeEntry> students,
      StudentPredicate predicate,
      ) {
    return students.where((student) => predicate(student)).toList();
  }

  static List<T> mapStudents<T>(
      List<GradeEntry> students,
      StudentTransformer<T> transformer,
      ) {
    return students.map((student) => transformer(student)).toList();
  }

  static T reduceStudents<T>(
      List<GradeEntry> students,
      T initialValue,
      T Function(T accumulator, GradeEntry student) reducer,
      ) {
    return students.fold<T>(initialValue, reducer);
  }

  static double calculateAverageMark(List<GradeEntry> students) {
    if (students.isEmpty) return 0.0;
    final totalMarks = reduceStudents<double>(
      students,
      0.0,
          (sum, student) => sum + student.marks,
    );
    return totalMarks / students.length;
  }

  static double calculateAverageGPA(List<GradeEntry> students) {
    if (students.isEmpty) return 0.0;
    final totalGPA = students.fold<double>(
      0.0,
          (sum, student) => sum + student.gpa,
    );
    return totalGPA / students.length;
  }

  static Map<String, int> getGradeDistribution(List<GradeEntry> students) {
    return students.fold<Map<String, int>>(
      {},
          (distribution, student) {
        distribution[student.grade] = (distribution[student.grade] ?? 0) + 1;
        return distribution;
      },
    );
  }

  static List<GradeEntry> getTopStudents(List<GradeEntry> students, int n) {
    final list = students.toList();
    list.sort((a, b) => b.marks.compareTo(a.marks));
    if (n <= 0) return [];
    return list.take(n).toList();
  }
}

// ============================================================================
// EXCEL I/O
// ============================================================================

class ExcelIO {
  // For web compatibility - accepts bytes directly
  static List<GradeEntry> readFromExcelBytes(
      Uint8List bytes, {
        required GradeCalculator gradeFunc,
        required GPACalculator gpaFunc,
        bool Function(String name, double marks)? validator,
      }) {
    try {
      print('File size: ${bytes.length} bytes');

      final archive = ZipDecoder().decodeBytes(bytes);
      print('Archive files: ${archive.length}');

      ArchiveFile? worksheetFile;
      for (var f in archive) {
        if (f.name.contains('sheet') && f.name.endsWith('.xml')) {
          worksheetFile = f;
          break;
        }
      }

      if (worksheetFile == null) {
        print('No worksheet found');
        return [];
      }

      print('Found worksheet: ${worksheetFile.name}');

      final sharedStrings = _extractSharedStrings(archive);
      print('Shared strings: ${sharedStrings.length}');

      final xmlString = String.fromCharCodes(worksheetFile.content as List<int>);
      final cleanXml = xmlString.replaceAll(RegExp(r' xmlns="[^"]*"'), '');
      final document = XmlDocument.parse(cleanXml);

      final entries = <GradeEntry>[];
      int rowIndex = 0;
      int successCount = 0;
      int skipCount = 0;

      for (var row in document.findAllElements('row')) {
        rowIndex++;
        if (rowIndex == 1) {
          print('Skipping header row');
          continue;
        }

        final cells = row.findAllElements('c').toList();
        if (cells.length < 2) {
          skipCount++;
          continue;
        }

        try {
          String? nameValue;

          var isElem = cells[0].findElements('is').firstOrNull;
          if (isElem != null) {
            var tElem = isElem.findElements('t').firstOrNull;
            nameValue = tElem?.innerText;
          }

          if (nameValue == null) {
            var vElem = cells[0].findElements('v').firstOrNull;
            if (vElem != null) {
              final cellType = cells[0].getAttribute('t');
              if (cellType == 's') {
                try {
                  final idx = int.parse(vElem.innerText);
                  nameValue = sharedStrings[idx];
                } catch (e) {
                  nameValue = vElem.innerText;
                }
              } else {
                nameValue = vElem.innerText;
              }
            }
          }

          if (nameValue == null || nameValue.isEmpty) {
            skipCount++;
            continue;
          }

          String? marksValue;

          isElem = cells[1].findElements('is').firstOrNull;
          if (isElem != null) {
            var tElem = isElem.findElements('t').firstOrNull;
            marksValue = tElem?.innerText;
          }

          if (marksValue == null) {
            var vElem = cells[1].findElements('v').firstOrNull;
            if (vElem != null) {
              marksValue = vElem.innerText;
            }
          }

          if (marksValue == null || marksValue.isEmpty) {
            skipCount++;
            continue;
          }

          double marks;
          try {
            marks = double.parse(marksValue);
          } catch (e) {
            print('Failed to parse marks "$marksValue" for $nameValue: $e');
            skipCount++;
            continue;
          }

          final isValid = validator?.call(nameValue, marks) ?? (marks >= 0 && marks <= 100);
          if (!isValid) {
            print('Validation failed: $nameValue = $marks');
            skipCount++;
            continue;
          }

          entries.add(
            GradeEntry(
              name: nameValue,
              marks: marks,
              gradeFunc: gradeFunc,
              gpaFunc: gpaFunc,
            ),
          );
          successCount++;
        } catch (e) {
          print('Error processing row $rowIndex: $e');
          skipCount++;
          continue;
        }
      }

      print('===== EXCEL PARSING RESULT =====');
      print('Total rows processed: $rowIndex');
      print('Successfully parsed: $successCount');
      print('Skipped: $skipCount');
      print('Final entries: ${entries.length}');
      print('================================');

      return entries;
    } catch (e) {
      print('Excel read error: $e');
      return [];
    }
  }

  static List<GradeEntry> readFromExcel(
      String filePath, {
        required GradeCalculator gradeFunc,
        required GPACalculator gpaFunc,
        bool Function(String name, double marks)? validator,
      }) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('File does not exist: $filePath');
        return [];
      }

      final bytes = file.readAsBytesSync();
      return readFromExcelBytes(
        bytes,
        gradeFunc: gradeFunc,
        gpaFunc: gpaFunc,
        validator: validator,
      );
    } catch (e) {
      print('Excel read error: $e');
      return [];
    }
  }

  static Map<int, String> _extractSharedStrings(Archive archive) {
    final sharedStrings = <int, String>{};
    ArchiveFile? stringsFile;

    for (var f in archive) {
      if (f.name.contains('sharedStrings.xml')) {
        stringsFile = f;
        break;
      }
    }

    if (stringsFile != null) {
      try {
        final stringsXml = String.fromCharCodes(stringsFile.content as List<int>);
        final cleanXml = stringsXml.replaceAll(RegExp(r' xmlns="[^"]*"'), '');
        final stringsDoc = XmlDocument.parse(cleanXml);
        int index = 0;

        for (var si in stringsDoc.findAllElements('si')) {
          final t = si.findElements('t').firstOrNull;
          if (t != null) {
            sharedStrings[index] = t.innerText;
          } else {
            sharedStrings[index] = '';
          }
          index++;
        }
      } catch (e) {
        print('Shared strings error: $e');
      }
    }

    return sharedStrings;
  }
}

// ============================================================================
// THEME SYSTEM
// ============================================================================

abstract class AppThemeData {
  String get name;
  Color get primaryColor;
  Color get accentColor;
  Color get backgroundColor;
  Color get surfaceColor;
  Color get textColor;
  Color get secondaryTextColor;
  ThemeData get themeData;
}

class BurgundyTheme implements AppThemeData {
  @override
  String get name => 'Burgundy';

  @override
  Color get primaryColor => const Color(0xFF800020);

  @override
  Color get accentColor => const Color(0xFFA01848);

  @override
  Color get backgroundColor => const Color(0xFF1A1A1A);

  @override
  Color get surfaceColor => const Color(0xFF2D2D2D);

  @override
  Color get textColor => Colors.white;

  @override
  Color get secondaryTextColor => Colors.white70;

  @override
  ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      background: backgroundColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 4,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: Colors.white),
      labelMedium: TextStyle(color: Colors.white),
    ),
  );
}

class BlackTheme implements AppThemeData {
  @override
  String get name => 'Black';

  @override
  Color get primaryColor => Colors.white;

  @override
  Color get accentColor => const Color(0xFF808080);

  @override
  Color get backgroundColor => const Color(0xFF0A0A0A);

  @override
  Color get surfaceColor => const Color(0xFF1A1A1A);

  @override
  Color get textColor => Colors.white;

  @override
  Color get secondaryTextColor => Colors.white54;

  @override
  ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      background: backgroundColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: primaryColor,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 2,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: Colors.white),
      labelMedium: TextStyle(color: Colors.white),
    ),
  );
}

// ============================================================================
// THEME MANAGER (Singleton)
// ============================================================================

class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();

  late AppThemeData _currentTheme;

  factory ThemeManager() {
    return _instance;
  }

  ThemeManager._internal() {
    _currentTheme = BurgundyTheme();
  }

  AppThemeData get currentTheme => _currentTheme;

  void setTheme(AppThemeData theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  AppThemeData getThemeByName(String name) {
    return name.toLowerCase() == 'black' ? BlackTheme() : BurgundyTheme();
  }

  List<AppThemeData> get availableThemes => [BurgundyTheme(), BlackTheme()];
}

// ============================================================================
// MAIN APP
// ============================================================================

void main() {
  runApp(const GradeCalculatorApp());
}

class GradeCalculatorApp extends StatelessWidget {
  const GradeCalculatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeManager>(
      create: (_) => ThemeManager(),
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, _) {
          return MaterialApp(
            title: 'Grade Calculator',
            theme: themeManager.currentTheme.themeData,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<GradeEntry> entries = [];
  bool isLoading = false;
  late AnimationController _animationController;

  late GradeCalculator gradeCalc;
  late GPACalculator gpaCalc;

  @override
  void initState() {
    super.initState();
    gradeCalc = GradingSystem.createGradeCalculator();
    gpaCalc = GradingSystem.createGPACalculator();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() => isLoading = true);

      await Future.delayed(const Duration(milliseconds: 500));

      final file = result.files.single;
      List<GradeEntry> excelEntries = [];

      if (file.bytes != null) {
        // Web or if bytes were loaded
        excelEntries = ExcelIO.readFromExcelBytes(
          file.bytes!,
          gradeFunc: gradeCalc,
          gpaFunc: gpaCalc,
          validator: (name, marks) => marks >= 0 && marks <= 100,
        );
      } else if (file.path != null) {
        // Mobile / Desktop
        excelEntries = ExcelIO.readFromExcel(
          file.path!,
          gradeFunc: gradeCalc,
          gpaFunc: gpaCalc,
          validator: (name, marks) => marks >= 0 && marks <= 100,
        );
      } else {
        setState(() => isLoading = false);
        _showSnackBar('Could not read file data', isError: true);
        return;
      }

      setState(() {
        entries = excelEntries;
        isLoading = false;
      });

      _animationController.forward();

      if (excelEntries.isEmpty) {
        _showSnackBar('No valid entries found in Excel file', isError: true);
      } else {
        _showSnackBar('Loaded ${excelEntries.length} students successfully!');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Calculator'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _showThemeSelector,
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : entries.isEmpty
          ? _buildEmptyState()
          : _buildResultsState(),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        tooltip: 'Load Excel File',
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Processing students...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'No students loaded',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the upload button to load an Excel file',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatisticsSection(),
        const SizedBox(height: 24),
        if (entries.isNotEmpty) _buildTopPerformersSection(),
        const SizedBox(height: 32),
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PreviewScreen(entries: entries),
                ),
              );
            },
            icon: const Icon(Icons.remove_red_eye),
            label: const Text('Preview & Download Results'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    final avgMark = DataTransformer.calculateAverageMark(entries);
    final avgGPA = DataTransformer.calculateAverageGPA(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Avg Mark', '${avgMark.toStringAsFixed(1)}/100'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard('Avg GPA', avgGPA.toStringAsFixed(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard('Total', entries.length.toString()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformersSection() {
    final topStudents = DataTransformer.getTopStudents(entries, 3);
    const medals = ['🥇', '🥈', '🥉'];

    if (topStudents.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performers',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 12),
        ...List.generate(topStudents.length, (index) {
          final student = topStudents[index];
          final medal = index < medals.length ? medals[index] : '⭐';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: Text(
                  medal,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(student.name),
                subtitle: Text('${student.marks}/100 • ${student.grade}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    student.gpa.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showThemeSelector() {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Theme',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            ...themeManager.availableThemes.map((theme) {
              final isSelected = themeManager.currentTheme.name == theme.name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    themeManager.setTheme(theme);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? theme.primaryColor : Colors.grey,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          theme.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        if (isSelected) Icon(Icons.check, color: theme.primaryColor),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PREVIEW SCREEN
// ============================================================================

class PreviewScreen extends StatelessWidget {
  final List<GradeEntry> entries;

  const PreviewScreen({Key? key, required this.entries}) : super(key: key);

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _downloadExcel(BuildContext context) async {
    if (entries.isEmpty) {
      _showSnackBar(context, 'No students to download', isError: true);
      return;
    }

    try {
      final csv = StringBuffer();
      csv.write('Student Name,Marks,Grade,GPA\n');

      for (final student in entries) {
        csv.write('${student.name},${student.marks},${student.grade},${student.gpa}\n');
      }

      final fileName = 'grades_${DateTime.now().toString().replaceAll(RegExp(r'[:\s.]'), '_').substring(0, 19)}.csv';

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv.toString());

      _showSnackBar(context, 'Saved to ${file.path}');
    } catch (e) {
      _showSnackBar(context, 'Error downloading file: $e', isError: true);
    }
  }

  Future<void> _shareExcel(BuildContext context) async {
    if (entries.isEmpty) {
      _showSnackBar(context, 'No students to share', isError: true);
      return;
    }

    try {
      final csv = StringBuffer();
      csv.write('Student Name,Marks,Grade,GPA\n');

      for (final student in entries) {
        csv.write('${student.name},${student.marks},${student.grade},${student.gpa}\n');
      }

      final fileName = 'grades_${DateTime.now().toString().replaceAll(RegExp(r'[:\s.]'), '_').substring(0, 19)}.csv';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Grade Calculator Results');
    } catch (e) {
      _showSnackBar(context, 'Error sharing file: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareExcel(context),
            tooltip: 'Share Results',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadExcel(context),
            tooltip: 'Download Results as CSV',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStudentListSection(context),
        ],
      ),
    );
  }

  Widget _buildStudentListSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Students',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => Divider(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
            itemBuilder: (context, index) {
              final student = entries[index];
              return ListTile(
                title: Text(student.name),
                subtitle: Text('${student.marks.toStringAsFixed(1)}/100'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        student.grade,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GPA: ${student.gpa.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
