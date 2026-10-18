class Customer {
  final String id;
  final String name;
  final String? phone;
  final double balance;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
  });

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        balance: double.parse(m['balance'].toString()),
      );
}