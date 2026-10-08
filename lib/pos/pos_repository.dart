import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

int _readInt(dynamic value, {int fallback = 0}) =>
    (value as num?)?.toInt() ?? fallback;

String _readString(dynamic value, {String fallback = ''}) =>
    value is String ? value : fallback;

bool _readBool(dynamic value, {bool fallback = false}) =>
    value is bool ? value : fallback;

DateTime? _readTimestamp(dynamic value) => (value as Timestamp?)?.toDate();

class PosProfile {
  const PosProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.address = '',
    this.favorites = const [],
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String address;
  final List<String> favorites;

  bool get isAdmin => role == 'admin';

  factory PosProfile.fromDocument(
    String uid,
    Map<String, dynamic> data,
    String? authEmail,
  ) {
    return PosProfile(
      uid: uid,
      name: _readString(data['name']),
      email: _readString(data['email'], fallback: authEmail ?? ''),
      role: _readString(data['role'], fallback: 'user'),
      phone: _readString(data['phone']),
      address: _readString(data['address']),
      favorites: [
        for (final id in (data['favorites'] as List<dynamic>? ?? const []))
          if (id is String) id,
      ],
    );
  }
}

class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.price,
    required this.stock,
    required this.active,
    required this.soldCount,
    required this.createdAt,
    this.imageUrl = '',
    this.originalPrice = 0,
    this.discountPercent = 0,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final int price;
  final int stock;
  final bool active;
  final int soldCount;
  final DateTime? createdAt;
  final String imageUrl;
  final int originalPrice;
  final int discountPercent;

  bool get onSale => discountPercent > 0 && originalPrice > price;
  int get regularPrice => onSale ? originalPrice : price;

  factory PosProduct.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return PosProduct(
      id: document.id,
      name: _readString(data['name']),
      sku: _readString(data['sku']),
      category: _readString(data['category'], fallback: 'その他'),
      price: _readInt(data['price']),
      stock: _readInt(data['stock']),
      active: _readBool(data['active']),
      soldCount: _readInt(data['soldCount']),
      createdAt: _readTimestamp(data['createdAt']),
      imageUrl: _readString(data['imageUrl']),
      originalPrice: _readInt(data['originalPrice']),
      discountPercent: _readInt(data['discountPercent']),
    );
  }
}

int applyDiscount(int regularPrice, int percent) => percent <= 0
    ? regularPrice
    : (regularPrice * (100 - percent) / 100).round();

class PosProductComment {
  const PosProductComment({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String authorName;
  final String text;
  final DateTime? createdAt;

  factory PosProductComment.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return PosProductComment(
      id: document.id,
      uid: _readString(data['uid']),
      authorName: _readString(data['authorName']),
      text: _readString(data['text']),
      createdAt: _readTimestamp(data['createdAt']),
    );
  }
}

class PosOrder {
  const PosOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.total,
    required this.paymentMethod,
    required this.items,
    required this.createdAt,
    required this.status,
    required this.cancelledAt,
    required this.cancelledBy,
    required this.cancelledByName,
    required this.salesCounted,
    this.paymentSettled = true,
  });

  final String id;
  final String userId;
  final String userName;
  final int total;
  final String paymentMethod;
  final List<Map<String, dynamic>> items;
  final DateTime? createdAt;
  final String status;
  final DateTime? cancelledAt;
  final String cancelledBy;
  final String cancelledByName;
  final bool salesCounted;
  final bool paymentSettled;

  factory PosOrder.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    return PosOrder(
      id: document.id,
      userId: _readString(data['userId']),
      userName: _readString(data['userName']),
      total: _readInt(data['total']),
      paymentMethod: _readString(data['paymentMethod']),
      items: rawItems.whereType<Map<String, dynamic>>().toList(),
      createdAt: _readTimestamp(data['createdAt']),
      status: _readString(data['status'], fallback: 'completed'),
      cancelledAt: _readTimestamp(data['cancelledAt']),
      cancelledBy: _readString(data['cancelledBy']),
      cancelledByName: _readString(data['cancelledByName']),
      salesCounted: _readBool(data['salesCounted']),
      paymentSettled: _readBool(data['paymentSettled'], fallback: true),
    );
  }
}

/// Handles all Firebase access for authentication, products, orders, and user profiles.
class PosRepository {
  PosRepository(this.auth, this.firestore);

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  Stream<User?> authChanges() => auth.authStateChanges();

  Stream<DocumentSnapshot<Map<String, dynamic>>> profileChanges(String uid) {
    return firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
    await firestore.collection('users').doc(credential.user!.uid).set({
      'uid': credential.user!.uid,
      'name': name.trim(),
      'email': email.trim(),
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureProfile({required User user, required String name}) async {
    final profile = firestore.collection('users').doc(user.uid);
    final snapshot = await profile.get();
    if (snapshot.exists) return;
    await profile.set({
      'uid': user.uid,
      'name': name.trim().isEmpty ? (user.displayName ?? '') : name.trim(),
      'email': user.email ?? '',
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() => auth.signOut();

  Future<void> setFavorite(String uid, String productId, bool favorite) {
    return firestore.collection('users').doc(uid).update({
      'favorites': favorite
          ? FieldValue.arrayUnion([productId])
          : FieldValue.arrayRemove([productId]),
    });
  }

  Future<void> updateName(String uid, String name) async {
    final trimmed = name.trim();
    await firestore.collection('users').doc(uid).update({'name': trimmed});
    await auth.currentUser?.updateDisplayName(trimmed);
  }

  Future<void> sendPasswordReset(String email) {
    return auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateContact(String uid, String phone, String address) {
    return firestore.collection('users').doc(uid).update({
      'phone': phone.trim(),
      'address': address.trim(),
    });
  }

  Map<String, int> extractQuantityMap(Map<dynamic, dynamic> source) {
    final quantities = <String, int>{};
    for (final entry in source.entries) {
      final productId = entry.key;
      final quantity = _readInt(entry.value);
      if (productId is String && productId.isNotEmpty && quantity > 0) {
        quantities[productId] = quantity;
      }
    }
    return quantities;
  }

  Stream<List<PosProduct>> products({
    required bool includeInactive,
    bool publicOnly = false,
  }) {
    Query<Map<String, dynamic>> query = firestore.collection('products');
    if (publicOnly) query = query.where('active', isEqualTo: true);
    return query.snapshots().map((snapshot) {
      final products = snapshot.docs
          .map(PosProduct.fromDocument)
          .where((product) => includeInactive || product.active)
          .toList();
      products.sort((left, right) => left.name.compareTo(right.name));
      return products;
    });
  }

  Future<void> saveProduct({
    String? id,
    required String name,
    required String sku,
    required String category,
    required int price,
    required int stock,
    required bool active,
    String imageUrl = '',
    int discountPercent = 0,
  }) async {
    final percent = discountPercent.clamp(0, 90);
    final collection = firestore.collection('products');
    final reference = id == null ? collection.doc() : collection.doc(id);
    final trimmedImageUrl = imageUrl.trim();
    final data = <String, dynamic>{
      'name': name.trim(),
      'sku': sku.trim(),
      'category': category,
      'price': applyDiscount(price, percent),
      'originalPrice': percent > 0 ? price : 0,
      'discountPercent': percent,
      'stock': stock,
      'active': active,
      'imageUrl': trimmedImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) data['createdAt'] = FieldValue.serverTimestamp();
    await reference.set(data, SetOptions(merge: true));
  }

  Stream<List<PosProductComment>> productComments(String productId) {
    return firestore
        .collection('products')
        .doc(productId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map(PosProductComment.fromDocument)
              .toList();
          return comments;
        });
  }

  Future<void> addProductComment({
    required String productId,
    required String text,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('コメントを投稿するにはログインしてください。');
    final comment = text.trim();
    if (comment.isEmpty || comment.length > 500) {
      throw StateError('コメントは1〜500文字で入力してください。');
    }
    await firestore
        .collection('products')
        .doc(productId)
        .collection('comments')
        .add({
          'uid': user.uid,
          'authorName': user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'User'),
          'text': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<List<PosOrder>> orders({required PosProfile profile}) {
    Query<Map<String, dynamic>> query = firestore.collection('orders');
    if (!profile.isAdmin) {
      query = query.where('userId', isEqualTo: profile.uid);
    }
    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map(PosOrder.fromDocument)
          .where((order) => profile.isAdmin || order.status != 'cancelled')
          .toList();
      orders.sort(
        (left, right) => (right.createdAt ?? DateTime(1970)).compareTo(
          left.createdAt ?? DateTime(1970),
        ),
      );
      return orders;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> orderChanges(String orderId) {
    return firestore.collection('orders').doc(orderId).snapshots();
  }

  Future<int> rebuildProductSalesCounts({
    required PosProfile profile,
    required List<PosOrder> orders,
    required List<PosProduct> products,
  }) async {
    if (!profile.isAdmin) {
      throw StateError('ベストセラーを再集計する権限がありません。');
    }

    final soldCounts = <String, int>{};
    for (final order in orders.where(
      (order) =>
          order.status == 'pending' ||
          order.status == 'preparing' ||
          order.status == 'shipped' ||
          order.status == 'completed',
    )) {
      for (final item in order.items) {
        final productId = item['productId'];
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId is String && productId.isNotEmpty && quantity > 0) {
          soldCounts.update(
            productId,
            (current) => current + quantity,
            ifAbsent: () => quantity,
          );
        }
      }
    }

    final legacyOrders = orders
        .where(
          (order) =>
              (order.status == 'pending' ||
                  order.status == 'preparing' ||
                  order.status == 'shipped' ||
                  order.status == 'completed') &&
              !order.salesCounted,
        )
        .toList();
    for (var start = 0; start < legacyOrders.length; start += 400) {
      final batch = firestore.batch();
      final end = (start + 400).clamp(0, legacyOrders.length);
      for (final order in legacyOrders.sublist(start, end)) {
        batch.update(firestore.collection('orders').doc(order.id), {
          'salesCounted': true,
        });
      }
      await batch.commit();
    }

    for (var start = 0; start < products.length; start += 400) {
      final batch = firestore.batch();
      final end = (start + 400).clamp(0, products.length);
      for (final product in products.sublist(start, end)) {
        batch.update(firestore.collection('products').doc(product.id), {
          'soldCount': soldCounts[product.id] ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    return products.length;
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    required PosProfile profile,
  }) async {
    if (!profile.isAdmin) {
      throw StateError('注文状態を変更する権限がありません。');
    }
    if (status != 'preparing' && status != 'shipped') {
      throw StateError('指定された注文状態は変更できません。');
    }

    final orderReference = firestore.collection('orders').doc(orderId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderReference);
      final data = snapshot.data();
      if (data == null) throw StateError('注文が見つかりません。');
      final currentStatus = data['status'];
      final validTransition =
          (currentStatus == 'pending' && status == 'preparing') ||
          (currentStatus == 'preparing' && status == 'shipped');
      if (!validTransition) {
        throw StateError('この注文状態からは変更できません。');
      }

      final update = <String, Object>{
        'status': status,
        if (status == 'preparing') ...{
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedBy': profile.uid,
          'acceptedByName': profile.name,
        },
        if (status == 'shipped') ...{
          'shippedAt': FieldValue.serverTimestamp(),
          'shippedBy': profile.uid,
          'shippedByName': profile.name,
        },
      };
      transaction.update(orderReference, update);
    });
  }

  Future<void> rejectOrder({
    required String orderId,
    required PosProfile profile,
  }) async {
    if (!profile.isAdmin) {
      throw StateError('注文を拒否する権限がありません。');
    }

    final orderReference = firestore.collection('orders').doc(orderId);
    await firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderReference);
      final orderData = orderSnapshot.data();
      if (orderData == null) throw StateError('注文が見つかりません。');
      if (orderData['status'] != 'pending') {
        throw StateError('受付待ちの注文のみ拒否できます。');
      }

      final rawQuantities = orderData['quantities'];
      if (rawQuantities is! Map) {
        throw StateError('注文の在庫情報を読み込めません。');
      }
      final quantities = extractQuantityMap(rawQuantities);
      if (quantities.isEmpty) {
        throw StateError('注文の在庫情報を読み込めません。');
      }

      final productReferences = {
        for (final productId in quantities.keys)
          productId: firestore.collection('products').doc(productId),
      };
      final productSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in productReferences.entries) {
        productSnapshots[entry.key] = await transaction.get(entry.value);
      }

      for (final entry in productReferences.entries) {
        final data = productSnapshots[entry.key]!.data();
        if (data == null) {
          throw StateError('拒否する商品の在庫データが見つかりません。');
        }
        final currentStock = (data['stock'] as num?)?.toInt() ?? 0;
        final productUpdate = <String, Object>{
          'stock': currentStock + quantities[entry.key]!,
          'lastRejectionOrderId': orderId,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (orderData['salesCounted'] == true) {
          final currentSoldCount = (data['soldCount'] as num?)?.toInt() ?? 0;
          final returnedSoldCount = currentSoldCount < quantities[entry.key]!
              ? currentSoldCount
              : quantities[entry.key]!;
          productUpdate['soldCount'] = currentSoldCount - returnedSoldCount;
        }
        transaction.update(entry.value, productUpdate);
      }

      transaction.update(orderReference, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': profile.uid,
        'rejectedByName': profile.name,
      });
    });
  }

  Future<void> cancelOrder({
    required PosOrder order,
    required PosProfile profile,
  }) async {
    if (!profile.isAdmin && order.userId != profile.uid) {
      throw StateError('この注文をキャンセルする権限がありません。');
    }

    final orderReference = firestore.collection('orders').doc(order.id);
    await firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderReference);
      final orderData = orderSnapshot.data();
      if (orderData == null) {
        throw StateError('注文が見つかりません。');
      }
      if (!profile.isAdmin && orderData['userId'] != profile.uid) {
        throw StateError('この注文をキャンセルする権限がありません。');
      }
      final status = orderData['status'];
      final canCancel =
          status == 'pending' || (profile.isAdmin && status == 'completed');
      if (!canCancel) {
        throw StateError('注文は管理者の確認前にのみキャンセルできます。');
      }

      final rawQuantities = orderData['quantities'];
      if (rawQuantities is! Map) {
        throw StateError('注文の在庫情報を読み込めません。');
      }
      final quantities = extractQuantityMap(rawQuantities);
      if (quantities.isEmpty) {
        throw StateError('注文の在庫情報を読み込めません。');
      }

      final productReferences = {
        for (final productId in quantities.keys)
          productId: firestore.collection('products').doc(productId),
      };
      final productSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in productReferences.entries) {
        productSnapshots[entry.key] = await transaction.get(entry.value);
      }

      for (final entry in productReferences.entries) {
        final data = productSnapshots[entry.key]!.data();
        if (data == null) {
          throw StateError('キャンセルする商品の在庫データが見つかりません。');
        }
        final currentStock = (data['stock'] as num?)?.toInt() ?? 0;
        final currentSoldCount = (data['soldCount'] as num?)?.toInt() ?? 0;
        final productUpdate = <String, Object>{
          'stock': currentStock + quantities[entry.key]!,
          'lastCancellationOrderId': order.id,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (orderData['salesCounted'] == true) {
          final returnedSoldCount = currentSoldCount < quantities[entry.key]!
              ? currentSoldCount
              : quantities[entry.key]!;
          productUpdate['soldCount'] = currentSoldCount - returnedSoldCount;
        }
        transaction.update(entry.value, productUpdate);
      }

      transaction.update(orderReference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': profile.uid,
        'cancelledByName': profile.name,
      });
    });
  }

  Future<void> updateOrderSettlement({
    required String orderId,
    required bool settled,
    required PosProfile profile,
  }) async {
    if (!profile.isAdmin) {
      throw StateError('支払い状態を変更する権限がありません。');
    }

    final orderReference = firestore.collection('orders').doc(orderId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderReference);
      final data = snapshot.data();
      if (data == null) throw StateError('注文が見つかりません。');
      if (data['status'] != 'completed') {
        throw StateError('キャンセル済みの注文は精算状態を変更できません。');
      }
      if ((data['paymentSettled'] as bool? ?? true) == settled) return;

      transaction.update(orderReference, {
        'paymentSettled': settled,
        'settlementUpdatedAt': FieldValue.serverTimestamp(),
        'settlementUpdatedBy': profile.uid,
      });
    });
  }

  Future<String> checkout({
    required PosProfile profile,
    required List<PosProduct> products,
    required Map<String, int> quantities,
    required String paymentMethod,
  }) async {
    if (quantities.isEmpty) {
      throw StateError('カートに商品がありません。');
    }
    final orderReference = firestore.collection('orders').doc();
    final productReferences = {
      for (final product in products)
        if (quantities.containsKey(product.id))
          product.id: firestore.collection('products').doc(product.id),
    };
    final total = products.fold<int>(
      0,
      (amount, product) =>
          amount + product.price * (quantities[product.id] ?? 0),
    );

    await firestore.runTransaction((transaction) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in productReferences.entries) {
        snapshots[entry.key] = await transaction.get(entry.value);
      }
      final lineItems = <Map<String, dynamic>>[];
      final productIds = <String>[];
      final quantityMap = <String, int>{};
      final priceMap = <String, int>{};

      for (final product in products.where(
        (product) => quantities.containsKey(product.id),
      )) {
        final snapshot = snapshots[product.id]!;
        final data = snapshot.data();
        final quantity = quantities[product.id]!;
        if (data == null || data['active'] != true) {
          throw StateError('${product.name}は現在販売できません。');
        }
        final currentPrice = (data['price'] as num?)?.toInt() ?? -1;
        final currentStock = (data['stock'] as num?)?.toInt() ?? 0;
        if (currentPrice != product.price) {
          throw StateError('${product.name}の価格が更新されました。カートを確認してください。');
        }
        if (currentStock < quantity) {
          throw StateError('${product.name}の在庫が不足しています。');
        }
        lineItems.add({
          'productId': product.id,
          'name': product.name,
          'sku': product.sku,
          'quantity': quantity,
          'unitPrice': product.price,
          'subtotal': product.price * quantity,
        });
        productIds.add(product.id);
        quantityMap[product.id] = quantity;
        priceMap[product.id] = product.price;
      }

      transaction.set(orderReference, {
        'userId': profile.uid,
        'userName': profile.name,
        'items': lineItems,
        'productIds': productIds,
        'quantities': quantityMap,
        'prices': priceMap,
        'total': total,
        'paymentMethod': paymentMethod,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'salesCounted': true,
        'paymentSettled': true,
        'settlementUpdatedAt': FieldValue.serverTimestamp(),
        'settlementUpdatedBy': profile.uid,
      });

      for (final product in products.where(
        (product) => quantities.containsKey(product.id),
      )) {
        final data = snapshots[product.id]!.data()!;
        final currentStock = (data['stock'] as num).toInt();
        transaction.update(productReferences[product.id]!, {
          'stock': currentStock - quantities[product.id]!,
          'soldCount': FieldValue.increment(quantities[product.id]!),
          'lastSaleOrderId': orderReference.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return orderReference.id;
  }

  Future<String> reorder({
    required PosProfile profile,
    required PosOrder order,
    required String paymentMethod,
  }) async {
    final snapshot = await firestore
        .collection('products')
        .where('active', isEqualTo: true)
        .get();
    final products = snapshot.docs.map(PosProduct.fromDocument).toList();
    final quantities = <String, int>{};
    for (final item in order.items) {
      final productId = item['productId'];
      final quantity = _readInt(item['quantity']);
      if (productId is! String || quantity <= 0) continue;
      final product = products.where((p) => p.id == productId).firstOrNull;
      if (product == null) {
        throw StateError('${_readString(item['name'])}は現在販売できません。');
      }
      quantities[productId] = quantity;
    }
    return checkout(
      profile: profile,
      products: products,
      quantities: quantities,
      paymentMethod: paymentMethod,
    );
  }

  Stream<List<PosProfile>> customers() {
    return firestore.collection('users').snapshots().map((snapshot) {
      final profiles = snapshot.docs
          .map((doc) => PosProfile.fromDocument(doc.id, doc.data(), null))
          .toList();
      profiles.sort((a, b) => a.name.compareTo(b.name));
      return profiles;
    });
  }

  Future<void> setUserRole(String uid, String role) {
    if (role != 'admin' && role != 'user') {
      throw ArgumentError('Invalid role');
    }
    return firestore.collection('users').doc(uid).update({'role': role});
  }

  String salesCsv(List<PosOrder> orders) {
    String cell(Object? value) {
      final text = '$value';
      return text.contains(RegExp(r'[",\n]'))
          ? '"${text.replaceAll('"', '""')}"'
          : text;
    }

    final rows = <String>['orderId,date,customer,status,payment,settled,total'];
    for (final order in orders) {
      rows.add(
        [
          order.id,
          order.createdAt?.toIso8601String() ?? '',
          order.userName,
          order.status,
          order.paymentMethod,
          order.paymentSettled,
          order.total,
        ].map(cell).join(','),
      );
    }
    return rows.join('\n');
  }
}
