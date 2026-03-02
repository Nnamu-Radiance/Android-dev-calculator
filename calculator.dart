// ignore_for_file: sdk_version_since

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

class GradeEntry {
  final String name;
  final double marks;
  late final String grade;
  late final double gpa;

  GradeEntry({required this.name, required this.marks}) {
    _calculateGrade();
  }

  void _calculateGrade() {
    if (marks >= 80) {
      grade = 'A';
      gpa = 4.0;
    } else if (marks >= 70) {
      grade = 'B+';
      gpa = 3.5;
    } else if (marks >= 60) {
      grade = 'B';
      gpa = 3.0;
    } else if (marks >= 55) {
      grade = 'C+';
      gpa = 2.5;
    } else if (marks >= 50) {
      grade = 'C';
      gpa = 2.0;
    } else if (marks >= 45) {
      grade = 'D+';
      gpa = 1.5;
    } else if (marks >= 40) {
      grade = 'D';
      gpa = 1.0;
    } else {
      grade = 'F';
      gpa = 0.0;
    }
  }
}

class GradeCalculator {
  /// Read student data from Excel file
  List<GradeEntry> readFromExcel(String filePath) {
    try {
      var file = File(filePath);
      if (!file.existsSync()) {
        print('Error: File not found at $filePath');
        return [];
      }

      var bytes = file.readAsBytesSync();
      var archive = ZipDecoder().decodeBytes(bytes);

      // Find and read the worksheet XML
      ArchiveFile? worksheetFile;
      for (var file in archive) {
        if (file.name.contains('sheet') && file.name.endsWith('.xml')) {
          worksheetFile = file;
          break;
        }
      }

      if (worksheetFile == null) {
        print('Error: Could not find worksheet in Excel file');
        return [];
      }

      // Parse the XML
      var xmlString = String.fromCharCodes(worksheetFile.content as List<int>);
      var document = XmlDocument.parse(xmlString);

      // Extract shared strings if available
      Map<int, String> sharedStrings = {};
      ArchiveFile? stringsFile;
      for (var file in archive) {
        if (file.name.contains('sharedStrings.xml')) {
          stringsFile = file;
          break;
        }
      }

      if (stringsFile != null) {
        var stringsXml = String.fromCharCodes(stringsFile.content as List<int>);
        var stringsDoc = XmlDocument.parse(stringsXml);
        int index = 0;
        for (var si in stringsDoc.findAllElements('si')) {
          var t = si.findElements('t').first;
          sharedStrings[index] = t.innerText;
          index++;
        }
      }

      List<GradeEntry> entries = [];
      int rowIndex = 0;

      // Parse rows
      for (var row in document.findAllElements('row')) {
        rowIndex++;
        if (rowIndex == 1) continue; // Skip header

        var cells = row.findAllElements('c').toList();

        if (cells.length < 2) continue;

        try {
          // Get name from first cell
          var nameCell = cells[0];
          var nameValue = _getCellValue(nameCell, sharedStrings);

          if (nameValue == null || nameValue.isEmpty) continue;

          // Get marks from second cell
          var marksCell = cells[1];
          var marksValue = _getCellValue(marksCell, sharedStrings);

          if (marksValue == null) continue;

          double marks = double.parse(marksValue);

          if (marks < 0 || marks > 100) {
            print(
                'Warning: Invalid marks ($marks) for $nameValue, skipping...');
            continue;
          }

          entries.add(GradeEntry(name: nameValue, marks: marks));
        } catch (e) {
          print('Error parsing row $rowIndex: $e');
          continue;
        }
      }

      return entries;
    } catch (e) {
      print('Error reading Excel file: $e');
      return [];
    }
  }

  String? _getCellValue(XmlElement cell, Map<int, String> sharedStrings) {
    var cellType = cell.getAttribute('t');

    // Handle inline strings: <c t="inlineStr"><is><t>value</t></is></c>
    if (cellType == 'inlineStr') {
      var isElement = cell.findElements('is').firstOrNull;
      if (isElement != null) {
        var tElement = isElement.findElements('t').firstOrNull;
        if (tElement != null) {
          return tElement.innerText;
        }
      }
      return null;
    }

    // Handle regular values: <c><v>value</v></c>
    var value = cell.findElements('v').firstOrNull;
    if (value == null) return null;

    var innerText = value.innerText;

    // If it's a shared string reference, look it up
    if (cellType == 's') {
      int stringIndex = int.parse(innerText);
      return sharedStrings[stringIndex];
    }

    return innerText;
  }

  /// Write grade results to Excel file
  void writeToExcel(List<GradeEntry> entries, String outputPath) {
    try {
      // Create XLSX structure manually
      var archive = Archive();

      // Create the workbook
      var workbookXml = _createWorkbookXml();
      archive.addFile(
          ArchiveFile('xl/workbook.xml', workbookXml.length, workbookXml));

      // Create the worksheet with data
      var worksheetXml = _createWorksheetXml(entries);
      archive.addFile(ArchiveFile(
          'xl/worksheets/sheet1.xml', worksheetXml.length, worksheetXml));

      // Create shared strings
      var stringsXml = _createStringsXml(entries);
      archive.addFile(
          ArchiveFile('xl/sharedStrings.xml', stringsXml.length, stringsXml));

      // Create relationships
      var workbookRelsXml = _createWorkbookRels();
      archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels',
          workbookRelsXml.length, workbookRelsXml));

      var documentRelsXml = _createDocumentRels();
      archive.addFile(
          ArchiveFile('_rels/.rels', documentRelsXml.length, documentRelsXml));

      // Create content types
      var contentTypesXml = _createContentTypes();
      archive.addFile(ArchiveFile(
          '[Content_Types].xml', contentTypesXml.length, contentTypesXml));

      // Encode to bytes and write
      var encoder = ZipEncoder();
      var encodedBytes = encoder.encode(archive);
      File(outputPath).writeAsBytesSync(encodedBytes!);

      print('✓ Results saved to $outputPath');
    } catch (e) {
      print('Error writing Excel file: $e');
    }
  }

  String _createWorkbookXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Grades" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
  }

  String _createWorkbookRels() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>''';
  }

  String _createDocumentRels() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
  }

  String _createContentTypes() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>''';
  }

  String _createStringsXml(List<GradeEntry> entries) {
    var strings = ['Name', 'Marks', 'Grade', 'GPA'];

    for (var entry in entries) {
      strings.add(entry.name);
      strings.add(entry.grade);
    }

    var si = strings.map((s) => '<si><t>$s</t></si>').join('');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${strings.length}" uniqueCount="${strings.length}">
$si
</sst>''';
  }

  String _createWorksheetXml(List<GradeEntry> entries) {
    var rows =
        '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c></row>';

    int rowNum = 2;
    int stringIndex = 4;

    for (var entry in entries) {
      var nameIndex = stringIndex++;
      var gradeIndex = stringIndex++;
      // ignore: unused_local_variable
      var colStr = _numberToColumn(rowNum);

      rows += '<row r="$rowNum">'
          '<c r="A$rowNum" t="s"><v>$nameIndex</v></c>'
          '<c r="B$rowNum"><v>${entry.marks}</v></c>'
          '<c r="C$rowNum" t="s"><v>$gradeIndex</v></c>'
          '<c r="D$rowNum"><v>${entry.gpa}</v></c>'
          '</row>';

      rowNum++;
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    $rows
  </sheetData>
</worksheet>''';
  }

  String _numberToColumn(int num) {
    return String.fromCharCode(64 + num);
  }

  /// Display results in console
  void displayResults(List<GradeEntry> entries) {
    if (entries.isEmpty) {
      print('No data to display.');
      return;
    }

    print('\n' + '=' * 60);
    print('  GRADE CALCULATION RESULTS');
    print('=' * 60);
    print(
      '${_padRight('Name', 20)} ${_padRight('Marks', 10)} ${_padRight('Grade', 8)} ${_padRight('GPA', 8)}',
    );
    print('-' * 60);

    for (var entry in entries) {
      print(
        '${_padRight(entry.name, 20)} ${_padRight(entry.marks.toString(), 10)} ${_padRight(entry.grade, 8)} ${entry.gpa}',
      );
    }

    print('=' * 60 + '\n');
  }

  String _padRight(String text, int width) {
    if (text.length >= width) return text;
    return text + ' ' * (width - text.length);
  }
}

void main(List<String> args) {
  print('╔════════════════════════════════════╗');
  print('║  Dart Grade Calculator Application  ║');
  print('╚════════════════════════════════════╝\n');

  if (args.isEmpty) {
    print('Usage: dart calculator.dart <input_file.xlsx> [output_file.xlsx]');
    print('Example: dart calculator.dart students.xlsx results.xlsx\n');
    print('Expected input format:');
    print('  Column A: Student Name');
    print('  Column B: Marks (0-100)\n');
    print('Grading Scale:');
    print('  A  (4.0): 80-100');
    print('  B+ (3.5): 70-79');
    print('  B  (3.0): 60-69');
    print('  C+ (2.5): 55-59');
    print('  C  (2.0): 50-54');
    print('  D+ (1.5): 45-49');
    print('  D  (1.0): 40-44');
    print('  F  (0.0): 0-39\n');
    return;
  }

  String inputFile = args[0];
  String outputFile = args.length > 1 ? args[1] : 'grade_results.xlsx';

  var calculator = GradeCalculator();

  print('Processing: $inputFile\n');
  var entries = calculator.readFromExcel(inputFile);

  if (entries.isEmpty) {
    print('No valid entries found in the Excel file.');
    return;
  }

  calculator.displayResults(entries);
  calculator.writeToExcel(entries, outputFile);
}
