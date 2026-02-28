class Order {
  final String id;
  final String title;
  final double price;
  final String status;

  Order({required this.id, required this.title, required this.price, required this.status});

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      title: map['title'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
    );
  }
}