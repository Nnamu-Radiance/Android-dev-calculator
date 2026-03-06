# Dart Grade Calculator - Architecture & Design Document

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Higher-Order Functions Explained](#higher-order-functions-explained)
3. [Functional Programming Patterns](#functional-programming-patterns)
4. [Design Decisions](#design-decisions)
5. [Data Flow](#data-flow)

---

## Architecture Overview

### Layered Architecture Pattern

```
┌─────────────────────────────────────────────┐
│         UI LAYER (UIDisplay)                │ ← Theme-based console UI
├─────────────────────────────────────────────┤
│      BUSINESS LOGIC LAYER                   │ ← Core grading & stats
│  ┌─────────────────────────────────────┐    │
│  │ - GradingSystem                     │    │
│  │ - DataTransformer                   │    │
│  │ - ThemeManager                      │    │
│  └─────────────────────────────────────┘    │
├─────────────────────────────────────────────┤
│      DATA LAYER (ExcelIO)                   │ ← File I/O
├─────────────────────────────────────────────┤
│      MODEL LAYER (GradeEntry)               │ ← Data structures
└─────────────────────────────────────────────┘
```

### Why Layered Architecture?

✅ **Separation of Concerns**: Each layer has one responsibility
✅ **Testability**: Easy to unit test each layer independently
✅ **Maintainability**: Changes to one layer don't affect others
✅ **Reusability**: Logic can be reused across different UIs
✅ **Scalability**: Easy to swap implementations (e.g., web UI instead of console)

---

## Higher-Order Functions Explained

### What is a Higher-Order Function?

A **higher-order function** is a function that:
1. **Accepts another function as a parameter**, OR
2. **Returns a function as a result**

This enables **functional programming** - composing small, reusable functions.

### Functions Used in This Project

#### 1. **GradingSystem.createGradeCalculator()**
```dart
static GradeCalculator createGradeCalculator({
  Map<String, double>? customScale,
}) {
  final scale = customScale ?? gradeScale;
  
  // Lambda: (marks) => grade
  return (double marks) {
    for (final entry in scale.entries...) {
      if (marks >= entry.value) return entry.key;
    }
    return 'F';
  };
}
```

**What it does:**
- Takes optional custom grading scale
- **Returns** a function `(marks) → grade`
- The returned function is used throughout the app

**Why it's useful:**
- Easy to create multiple graders with different scales
- Example: 
  ```dart
  final standardGrader = GradingSystem.createGradeCalculator();
  final strictGrader = GradingSystem.createGradeCalculator(
    customScale: {'A': 95, 'B+': 85, ...}
  );
  ```

---

#### 2. **DataTransformer.filterStudents()**
```dart
static List<GradeEntry> filterStudents(
  List<GradeEntry> students,
  StudentPredicate predicate,  // A function!
) {
  return students.where((student) => predicate(student)).toList();
}
```

**What it does:**
- Takes a **predicate function** (condition)
- Returns only students that match the condition

**Usage examples:**
```dart
// Get all A students
final topGraders = DataTransformer.filterStudents(
  entries,
  (student) => student.grade == 'A',
);

// Get students with passing marks (50+)
final passingStudents = DataTransformer.filterStudents(
  entries,
  (student) => student.marks >= 50,
);

// Get high performers (GPA 3.5+)
final highPerformers = DataTransformer.filterStudents(
  entries,
  (student) => student.gpa >= 3.5,
);
```

**Why it's useful:**
- Single function handles all filtering logic
- No need to write loops: `filterStudents()` does it
- Easy to combine conditions with lambdas

---

#### 3. **DataTransformer.mapStudents<T>()**
```dart
static List<T> mapStudents<T>(
  List<GradeEntry> students,
  StudentTransformer<T> transformer,  // A function!
) {
  return students.map((student) => transformer(student)).toList();
}
```

**What it does:**
- Takes a **transformer function** that converts students to something else
- Returns list of transformed values

**Usage examples:**
```dart
// Extract just names
final names = DataTransformer.mapStudents(
  entries,
  (student) => student.name,
);
// Result: ['Alice', 'Bob', 'Charlie']

// Extract just marks
final marks = DataTransformer.mapStudents(
  entries,
  (student) => student.marks,
);
// Result: [85.0, 92.0, 78.0]

// Create formatted strings
final formatted = DataTransformer.mapStudents(
  entries,
  (student) => '${student.name}: ${student.grade}',
);
// Result: ['Alice: A', 'Bob: A', 'Charlie: B']
```

**Why it's useful:**
- Transform data without loops
- Generic type `<T>` means it works for ANY type
- Used in `_createStringsXml()` to build Excel output

---

#### 4. **DataTransformer.reduceStudents<T>()**
```dart
static T reduceStudents<T>(
  List<GradeEntry> students,
  T initialValue,
  T Function(T accumulator, GradeEntry student) reducer,
) {
  return students.fold<T>(initialValue, reducer);
}
```

**What it does:**
- Takes a **reducer function** that combines all students into one value
- Accumulates result starting from `initialValue`

**Usage examples:**
```dart
// Calculate total marks
final totalMarks = DataTransformer.reduceStudents<double>(
  entries,
  0.0,  // Start with 0
  (sum, student) => sum + student.marks,  // Add each student's marks
);

// Calculate average
final average = totalMarks / entries.length;

// Count students by grade (fold into Map)
final distribution = entries.fold<Map<String, int>>(
  {},
  (map, student) {
    map[student.grade] = (map[student.grade] ?? 0) + 1;
    return map;
  },
);
// Result: {'A': 5, 'B+': 3, 'B': 7, ...}
```

**Why it's useful:**
- Single line to combine multiple values
- Used for statistics, aggregation, reporting
- Functional alternative to loops and accumulators

---

#### 5. **ExcelIO.readFromExcel() - Custom Validator**
```dart
static List<GradeEntry> readFromExcel(
  String filePath, {
  required GradeCalculator gradeFunc,
  required GPACalculator gpaFunc,
  bool Function(String name, double marks)? validator,  // Higher-order!
}) {
  // ... inside loop:
  final isValid = validator?.call(nameValue, marks) ?? (marks >= 0 && marks <= 100);
}
```

**What it does:**
- Accepts optional **validation function**
- Allows custom validation logic without changing the reader

**Usage:**
```dart
// Default validation (0-100)
final entries = ExcelIO.readFromExcel(inputFile, ...);

// Custom validation (reject extremely low marks)
final entries = ExcelIO.readFromExcel(
  inputFile,
  gradeFunc: gradeCalc,
  gpaFunc: gpaCalc,
  validator: (name, marks) => marks >= 10,  // Minimum 10 marks
);

// Complex validation
validator: (name, marks) {
  // Reject if mark too low OR name is empty
  return marks >= 20 && name.isNotEmpty && name.length < 100;
}
```

**Why it's useful:**
- Flexible validation without hardcoding
- Same reader for different use cases
- Easy to test different validation rules

---

## Functional Programming Patterns

### Pattern 1: Function Composition

```dart
// Instead of:
var filtered = entries.where((e) => e.gpa >= 3.5).toList();
var names = filtered.map((e) => e.name).toList();

// Use:
var topNames = DataTransformer.mapStudents(
  DataTransformer.filterStudents(entries, (s) => s.gpa >= 3.5),
  (s) => s.name,
);
```

### Pattern 2: Reduce/Fold for Aggregation

```dart
// Instead of:
double sum = 0;
for (var student in entries) {
  sum += student.marks;
}
double average = sum / entries.length;

// Use:
double average = DataTransformer.calculateAverageMark(entries);
// Which internally uses:
final totalMarks = entries.fold(0.0, (sum, s) => sum + s.marks);
```

### Pattern 3: Lambda Expressions

```dart
// Short, inline functions for simple operations
entries.where((student) => student.grade == 'A');
entries.map((student) => student.name);
entries.fold(0, (sum, student) => sum + 1);
```

### Pattern 4: Type Aliases for Clarity

```dart
typedef GradeCalculator = String Function(double marks);
typedef StudentPredicate = bool Function(GradeEntry student);
typedef StudentTransformer<T> = T Function(GradeEntry student);
```

Benefits:
- Self-documenting code
- Easy to understand function signatures
- Refactoring is safer

---

## Design Decisions

### 1. Why Separate GradeEntry Creation from Calculation?

**Old approach (hardcoded):**
```dart
class GradeEntry {
  void _calculateGrade() {
    if (marks >= 80) grade = 'A';
    else if (marks >= 70) grade = 'B+';
    // ... hardcoded logic
  }
}
```

**Problem:** Grading logic is locked inside the class. Hard to:
- Change grades at runtime
- Test with different scales
- Reuse logic elsewhere

**New approach (injected functions):**
```dart
class GradeEntry {
  GradeEntry({
    required GradeCalculator gradeFunc,  // Accept function
    required GPACalculator gpaFunc,
  }) {
    grade = gradeFunc(marks);  // Use injected function
    gpa = gpaFunc(marks);
  }
}
```

**Benefits:**
✅ Grading logic is now **testable independently**
✅ Easy to use different grading scales
✅ Logic is **separate from data** (separation of concerns)

---

### 2. Why Higher-Order Functions Over Utilities?

**Bad pattern (utility methods duplicated):**
```dart
List<GradeEntry> getTopGraders(List<GradeEntry> entries) {
  return entries.where((e) => e.grade == 'A').toList();
}

List<GradeEntry> getPassingStudents(List<GradeEntry> entries) {
  return entries.where((e) => e.marks >= 50).toList();
}

List<GradeEntry> getHighPerformers(List<GradeEntry> entries) {
  return entries.where((e) => e.gpa >= 3.5).toList();
}
// Lots of repetition!
```

**Good pattern (single reusable function):**
```dart
static List<GradeEntry> filterStudents(
  List<GradeEntry> students,
  StudentPredicate predicate,  // Pass logic as parameter
) {
  return students.where((student) => predicate(student)).toList();
}

// Reuse for any condition:
filterStudents(entries, (e) => e.grade == 'A');
filterStudents(entries, (e) => e.marks >= 50);
filterStudents(entries, (e) => e.gpa >= 3.5);
```

**Benefits:**
✅ **DRY (Don't Repeat Yourself)** - one function, infinite use cases
✅ Easier to maintain
✅ Reduces code duplication

---

### 3. Why Theme Manager is Singleton?

```dart
class ThemeManager {
  static ThemeData _currentTheme = BurgundyTheme();  // Static = singleton
  static ThemeData get currentTheme => _currentTheme;
  static void setTheme(ThemeData theme) { _currentTheme = theme; }
}
```

**Benefits:**
✅ Single source of truth for theme across app
✅ No need to pass theme as parameter everywhere
✅ Easy to switch themes globally

**Usage:**
```dart
ThemeManager.setTheme(BlackTheme());  // All UI updates automatically
```

---

### 4. Why Layered Architecture Over Monolithic?

| Aspect | Monolithic | Layered |
|--------|-----------|---------|
| **Testing** | Hard - must test everything together | Easy - test each layer separately |
| **Changes** | Risky - affects entire system | Safe - change one layer only |
| **Reuse** | Difficult | Easy - layers are independent |
| **Future Web UI** | Requires rewrite | Just swap UI layer |
| **Performance** | Slightly faster (no indirection) | Slightly slower (function calls) |

**Decision:** Choose **Layered** because maintainability > speed (for this project)

---

## Data Flow

### Reading & Processing

```
Excel File
    ↓
ExcelIO.readFromExcel()
    ↓ (with gradeFunc, gpaFunc, validator)
    ↓
For each row:
  ├─ Extract name & marks
  ├─ Validate (using injected validator)
  ├─ Create GradeEntry (injecting grade/GPA functions)
  └─ Add to list
    ↓
List<GradeEntry>
    ↓
DataTransformer methods:
  ├─ filterStudents() → filtered list
  ├─ mapStudents() → transformed list
  ├─ reduceStudents() → aggregate value
  ├─ calculateAverageMark() → double
  ├─ getTopStudents() → top N
  └─ getGradeDistribution() → Map<String, int>
    ↓
UIDisplay methods:
  ├─ displayResults() → formatted console output
  ├─ displayStatistics() → summary stats
  └─ displayTopStudents() → top performers
    ↓
ExcelIO.writeToExcel() → output Excel file
```

---

## Summary: Why This Architecture?

| Aspect | Why |
|--------|-----|
| **Higher-Order Functions** | Reusable, testable, flexible logic |
| **Functional Programming** | Cleaner code, no side effects, easier to reason about |
| **Type Aliases** | Self-documenting, safer refactoring |
| **Layered Architecture** | Separation of concerns, testable, maintainable |
| **Theme Abstraction** | Easy to add new themes, switch at runtime |
| **Dependency Injection** | Grading logic is not hardcoded, testable |

---

## Extension Points

### Adding a New Grading Scale
```dart
final customGrader = GradingSystem.createGradeCalculator(
  customScale: {
    'A': 95,
    'B': 80,
    'C': 70,
    'F': 0,
  }
);
```

### Adding a New Theme
```dart
class CustomTheme implements ThemeData {
  @override
  String get name => 'Custom';
  // ... implement colors
}

ThemeManager.setTheme(CustomTheme());
```

### Adding New Statistics
```dart
static double getPassRate(List<GradeEntry> students) {
  final passingCount = filterStudents(
    students,
    (s) => s.marks >= 50,
  ).length;
  return (passingCount / students.length) * 100;
}
```

---

## Conclusion

This architecture balances:
- **Flexibility** via higher-order functions
- **Clarity** via layered separation
- **Reusability** via functional patterns
- **Maintainability** via dependency injection and abstraction
