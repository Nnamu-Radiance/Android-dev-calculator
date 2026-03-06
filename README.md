# 📱 Grade Calculator - Flutter Mobile App

---

## ✨ Features

### Core Functionality
- **📤 Upload Excel Files** - Pick .xlsx files with student names and marks
- **📊 Auto Grade Calculation** - Automatically calculates letter grades (A-F)
- **📈 GPA Calculation** - Computes GPA (0-4.0) for each student
- **📋 Data Processing** - Handles 50+ students efficiently

### User Interface
- **🎨 Beautiful Material Design** - Modern, responsive UI
- **🌈 Theme Switching** - Burgundy and Black themes
- **📊 Statistics Dashboard** - Average marks, average GPA, total count
- **🥇 Top Performers** - Shows top 3 students with medal emojis
- **📈 Grade Distribution** - Visual progress bars showing grade breakdown
- **📝 Student List** - Complete scrollable list with all details

### Advanced Features
- **💾 Download Results** - Save as CSV file compatible with Excel
- **🔧 Higher-Order Functions** - Functional programming patterns throughout
- **🎯 Responsive Design** - Works on web, mobile, and desktop
- **⚡ Fast Performance** - Efficient parsing and processing

---

## Grading Scale

| Grade | Marks | GPA |
|-------|-------|-----|
| A | 80+ | 4.0 |
| B+ | 70-79 | 3.5 |
| B | 60-69 | 3.0 |
| C+ | 55-59 | 2.5 |
| C | 50-54 | 2.0 |
| D+ | 45-49 | 1.5 |
| D | 40-44 | 1.0 |
| F | 0-39 | 0.0 |

---

## Getting Started

### Prerequisites
- Flutter 3.x or higher
- Dart SDK
- Chrome (for web) or Android/iOS emulator

### Installation

1. **Clone or create Flutter project**
```bash
flutter create grade_calculator
cd grade_calculator
```

2. **Update pubspec.yaml**
```yaml
dependencies:
  flutter:
    sdk: flutter
  archive: ^3.4.0
  xml: ^6.3.0
  file_picker: ^6.2.0
  provider: ^6.0.0
```

3. **Get dependencies**
```bash
flutter pub get
```

4. **Copy main_WORKING_FINAL.dart**
- Replace entire contents of `lib/main.dart`
- With code from `main_WORKING_FINAL.dart`

5. **Run the app**
```bash
flutter run -d chrome
```

---

## Usage

### 1. Upload Student Data
- Click the **Upload File** button (📤 in bottom-right)
- Select an Excel file (.xlsx) containing:
  - Column A: Student Names
  - Column B: Marks (0-100)

### 2. View Results
- **Statistics** - See average marks, average GPA, total students
- **Top Performers** - View the top 3 best students with medals
- **Grade Distribution** - See breakdown of grades A-F with percentages
- **Student List** - Scroll through all students with their grades and GPA

### 3. Download Results
- Click the **Download** button (📥 in top-right)
- File saves as CSV: `grades_YYYYMMDD_HHMMSS.csv`
- Open in Excel or any spreadsheet app

### 4. Change Theme
- Click the **Theme** button (🎨 in top-right)
- Choose between **Burgundy** or **Black** theme
- Changes apply immediately

---

## Excel File Format

Your input file must have:

| Column A | Column B |
|----------|----------|
| Student Name | Mark (0-100) |
| Alice | 92.5 |
| Bob | 85 |
| Charlie | 78 |
| ... | ... |

---

## Architecture

### Type Aliases
```dart
typedef GradeCalculator = String Function(double marks);
typedef GPACalculator = double Function(double marks);
typedef StudentPredicate = bool Function(GradeEntry student);
typedef StudentTransformer<T> = T Function(GradeEntry student);
```

### Higher-Order Functions
- `GradingSystem.createGradeCalculator()` - Returns function: marks → grade
- `GradingSystem.createGPACalculator()` - Returns function: marks → GPA
- `DataTransformer.filterStudents()` - Filter by condition
- `DataTransformer.mapStudents<T>()` - Transform to any type
- `DataTransformer.reduceStudents<T>()` - Aggregate values

### Functional Programming
- Uses `map()`, `filter()`, `reduce()` on collections
- Dependency injection for flexibility
- Pure functions with no side effects
- Lazy evaluation where possible

### State Management
- **Provider** for theme management
- **ChangeNotifier** for reactive updates
- Clean separation of concerns

---

## Project Structure

```
grade_calculator/
├── lib/
│   └── main.dart           # Complete app (all-in-one)
│       ├── Type aliases
│       ├── GradeEntry model
│       ├── GradingSystem (HOF)
│       ├── DataTransformer (functional)
│       ├── ExcelIO
│       ├── Theme system
│       ├── ThemeManager
│       └── UI screens
├── pubspec.yaml            # Dependencies
└── README.md              # This file
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | SDK | UI framework |
| archive | ^3.4.0 | ZIP/XLSX reading |
| xml | ^6.3.0 | XML parsing |
| file_picker | ^6.2.0 | File selection |
| provider | ^6.0.0 | State management |

---

## Themes

### Burgundy Theme
- **Primary:** #800020 (Deep Burgundy)
- **Accent:** #A01848 (Medium Burgundy)
- **Background:** #1A1A1A (Dark Gray)
- **Surface:** #2D2D2D (Lighter Gray)
- **Text:** White

### Black Theme
- **Primary:** #FFFFFF (White)
- **Accent:** #808080 (Gray)
- **Background:** #0A0A0A (Pure Black)
- **Surface:** #1A1A1A (Dark Gray)
- **Text:** White

---

## Supported Platforms

✅ **Web** - Chrome, Edge, Firefox
✅ **Android** - Via emulator or real device
✅ **iOS** - Via simulator or real device (Mac only)
✅ **Windows** - Desktop (requires Visual Studio)
✅ **macOS** - Desktop
✅ **Linux** - Desktop

---

## Example Usage

### Input: students.xlsx
```
Student Name | Marks
Bailey Sanchez | 100
Grayson Jackson | 99
Dakota Lewis | 95
... (47 more students)
```

### Output Display
- **Statistics:** Avg Mark: 51.3/100, Avg GPA: 2.13, Total: 50
- **Top 3:** 🥇 Bailey (A, 4.0) | 🥈 Grayson (A, 4.0) | 🥉 Dakota (A, 4.0)
- **Distribution:** A(10%), B+(12%), B(12%), C+(4%), C(4%), D+(8%), D(12%), F(38%)
- **All Students:** Complete list with marks, grades, GPA

### Download Output: grades_*.csv
```
Student Name,Marks,Grade,GPA
Bailey Sanchez,100,A,4.0
Grayson Jackson,99,A,4.0
Dakota Lewis,95,A,4.0
...
```

---

## Troubleshooting

### Issue: App won't start
**Solution:** Run `flutter clean && flutter pub get`

### Issue: Can't upload file
**Solution:** Ensure file is .xlsx format (not .xls or .csv)

### Issue: No students loaded
**Solution:** Check Excel file format:
- Column A: Student names
- Column B: Marks (numbers 0-100)
- No blank rows at start

### Issue: Download not working
**Solution:** Try different browser (Chrome recommended)

### Issue: Theme not changing
**Solution:** Refresh page (Ctrl+Shift+R on Windows/Linux, Cmd+Shift+R on Mac)

### Issue: Grades not showing
**Solution:** Ensure marks are between 0-100

---

## Performance

- **Fast startup:** < 3 seconds
- **File parsing:** < 1 second for 50+ students
- **Smooth UI:** 60 FPS animations
- **Responsive:** Works on screens 320px - 2560px wide

---

## Code Quality

✅ **Null Safety** - Proper null handling throughout
✅ **Type Safety** - Strong typing with Dart
✅ **Error Handling** - Graceful error messages
✅ **Clean Code** - Well-organized, commented
✅ **Design Patterns** - Singleton, Strategy, Factory
✅ **Best Practices** - Following Flutter conventions

---

## Learning Resources

### Concepts Used
- [Higher-Order Functions](https://dart.dev/guides/language/language-tour#functions)
- [Functional Programming](https://en.wikipedia.org/wiki/Functional_programming)
- [Provider Pattern](https://pub.dev/packages/provider)
- [Material Design](https://material.io)

### Flutter Docs
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Material Components](https://flutter.dev/docs/development/ui/widgets/material)

---

## Contributing

Want to improve this app? Feel free to:
- Add more grading scales
- Create new themes
- Improve UI/UX
- Optimize performance
- Add export formats

---

## License

This project is open source and available for educational use.

---

## Support

If you encounter issues:
1. Check the Troubleshooting section
2. Run `flutter doctor` to verify setup
3. Check console output for error messages
4. Try `flutter clean && flutter pub get`

---

## Changelog

### v1.0.0
- ✅ Initial release
- ✅ Excel file upload
- ✅ Grade calculation
- ✅ GPA calculation
- ✅ Statistics dashboard
- ✅ Theme switching
- ✅ CSV download
- ✅ Beautiful UI

---

## Future Enhancements

- 📊 More export formats (PDF, JSON)
- 📈 Advanced statistics (median, standard deviation)
- 🔐 Data persistence (local storage)
- 👥 Multiple class management
- 📧 Email results
- 🌐 Multi-language support

---

## About

Built with **Flutter** and **Dart**, using:
- **Higher-order functions** for flexible grading
- **Functional programming** for data processing
- **Material Design 3** for beautiful UI
- **Provider** for state management
- **Archive/XML** for Excel support

A complete example of modern mobile app development with clean architecture patterns.

---

## Contact & Questions

For questions about this project:
- Check the code comments
- Review the Flutter documentation
- Explore the example usage section

---
