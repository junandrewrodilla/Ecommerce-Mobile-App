// security.dart
bool canLogin() {
  // Define the cutoff date as December 10, 2024
  final cutoffDate = DateTime(2024, 12, 10);
  final currentDate = DateTime.now();

  // Check if current date is before the cutoff date
  return currentDate.isBefore(cutoffDate);
}
