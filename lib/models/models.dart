class Account {
  int? id; String name; double balance;
  Account({this.id, required this.name, required this.balance});
}
class Category {
  int? id; String name;
  Category({this.id, required this.name});
}
class TransactionModel {
  int? id, accountId, categoryId;
  String type, description, date;
  double amount; double? balanceAfter;
  String? accountName, categoryName;
  TransactionModel({this.id, this.accountId, this.categoryId, required this.type, required this.amount, required this.description, required this.date, this.balanceAfter, this.accountName, this.categoryName});
}
class Recurring {
  int? id; String name, frequency, nextDate; double amount;
  Recurring({this.id, required this.name, required this.amount, required this.frequency, required this.nextDate});
}
