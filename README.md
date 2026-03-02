Dart Grade Calculator
Overview
A Dart console application that reads student names and marks (0-100) from an Excel file, calculates their corresponding grades (A-F) and GPA (4.0-0.0) based on a predefined grading scale, and exports the results to a new Excel file. The app displays all results in a formatted console table and provides comprehensive error handling for invalid data.

Features
Excel Input: Reads student data from Excel files (.xlsx format)
Grade Calculation: Automatically calculates letter grades and GPA values
Excel Output: Exports results to a new Excel file with formatted columns
Console Display: Shows all results in a nicely formatted table before exporting
Error Handling: Validates marks and provides warnings for invalid data
Flexible Arguments: Specify custom input and output file paths via command line
Grading Scale
Grade	GPA	Marks Range
A	4.0	80-100
B+	3.5	70-79
B	3.0	60-69
C+	2.5	55-59
C	2.0	50-54
D+	1.5	45-49
D	1.0	40-44
F	0.0	0-39
Requirements
Dart SDK (>=2.19.0)
Dependencies: archive, xml, args
Installation
Navigate to the project directory
Run dart pub get to install dependencies
Usage
dart calculator.dart <input_file.xlsx> [output_file.xlsx]

dart calculator.dart <input_file.xlsx> [output_file.xlsx]
Examples

# Basic usage
dart calculator.dart students.xlsx results.xlsx

# Using default output filename (grade_results.xlsx)
dart calculator.dart students.xlsx

# Display help
dart calculator.dart

# Basic usagedart calculator.dart students.xlsx results.xlsx# Using default output filename (grade_results.xlsx)dart calculator.dart students.xlsx# Display helpdart calculator.dart
Input File Format
Your input Excel file should have:

Column A: Student Names
Column B: Marks (0-100)
Example:

Student Name	Marks
John Smith	85
Jane Doe	92
Bob Johnson	78
Output File Format
The generated results file will contain:

Column A: Student Name
Column B: Marks (original score)
Column C: Grade (letter grade)
Column D: GPA (grade point average)
Project Structure
calculator.dart: Main application with grade calculation logic
pubspec.yaml: Project configuration and dependencies
Classes
GradeEntry
Represents a student with their name, marks, calculated grade, and GPA.

GradeCalculator
Handles Excel file operations (reading/writing) and grade calculations.

Error Handling
Validates that marks are between 0 and 100
Skips invalid entries with warning messages
Provides clear error messages for missing files or corrupt Excel data
Handles parsing errors gracefully
Notes
The application supports inline string values in Excel cells
Large Excel files (100+ students) are processed efficiently
Console output is formatted for easy readability
Marks outside the 0-100 range are automatically skipped with a warning
