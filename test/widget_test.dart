import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newflutterapp/pos/pos_app.dart';
import 'package:newflutterapp/pos/pos_repository.dart';

void main() {
  group('Japanese POS app', () {
    test('formats JPY with grouping separators', () {
      expect(formatYen(0), '¥0');
      expect(formatYen(1200), '¥1,200');
      expect(formatYen(-987654), '-¥987,654');
    });

    testWidgets('shows login and can switch to account registration', (
      tester,
    ) async {
      await tester.pumpWidget(
        PosApp(auth: MockFirebaseAuth(), firestore: FakeFirebaseFirestore()),
      );
      await tester.pumpAndSettle();

      expect(find.text('MORIにログイン'), findsOneWidget);
      expect(find.text('メールアドレス'), findsOneWidget);
      expect(find.text('ログイン'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-selector')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('language-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to MORI'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);

      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Create a MORI account'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-selector')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('language-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日本語').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('MORIアカウントを作成'), findsOneWidget);
      expect(find.text('名前'), findsOneWidget);
      expect(find.text('アカウントを作成'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-selector')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('language-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('မြန်မာ').last);
      await tester.pumpAndSettle();

      expect(find.text('MORI အကောင့် ဖန်တီးရန်'), findsOneWidget);
      expect(find.text('အီးမေးလ်လိပ်စာ'), findsOneWidget);
      expect(find.text('အကောင့်ဖန်တီးရန်'), findsOneWidget);
    });

    testWidgets('guest can browse and add to cart before signing in to order', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('products').doc('tea').set({
        'name': '緑茶',
        'sku': 'TEA-1',
        'category': '飲料',
        'price': 150,
        'stock': 4,
        'active': true,
      });
      await firestore.collection('products').doc('hidden').set({
        'name': '非公開商品',
        'sku': 'HIDDEN-1',
        'category': 'その他',
        'price': 999,
        'stock': 1,
        'active': false,
      });

      await tester.pumpWidget(
        PosApp(auth: MockFirebaseAuth(), firestore: firestore),
      );
      await tester.pumpAndSettle();

      expect(find.text('MORIにログイン'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('browse-as-guest')));
      await tester.pumpAndSettle();
      expect(find.text('商品を見る'), findsOneWidget);
      expect(find.text('緑茶'), findsWidgets);
      expect(find.text('非公開商品'), findsNothing);

      await tester.tap(find.text('緑茶'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add-product-detail-to-cart')),
      );
      await tester.pumpAndSettle();
      expect(find.text('カート 1点'), findsOneWidget);
      expect(find.text('MORIにログイン'), findsNothing);

      await tester.tap(find.text('会計へ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('注文を確定する'));
      await tester.pumpAndSettle();
      expect(find.text('注文にはアカウントが必要です'), findsOneWidget);
      expect(find.text('メールアドレス'), findsOneWidget);
      expect((await firestore.collection('orders').get()).docs, isEmpty);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('1点'), findsOneWidget);
      expect(find.text('緑茶'), findsWidgets);
      expect((await firestore.collection('orders').get()).docs, isEmpty);
    });

    testWidgets(
      'guest sees best sellers and recent products with shared comments',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('products').doc('top').set({
          'name': 'Top product',
          'sku': 'TOP-1',
          'category': '飲料',
          'price': 300,
          'stock': 8,
          'active': true,
          'soldCount': 12,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 8)),
        });
        await firestore.collection('products').doc('next').set({
          'name': 'Next product',
          'sku': 'NEXT-1',
          'category': '飲料',
          'price': 200,
          'stock': 8,
          'active': true,
          'soldCount': 4,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
        });
        await firestore
            .collection('products')
            .doc('top')
            .collection('comments')
            .doc('shared')
            .set({
              'uid': 'reviewer',
              'authorName': 'Guest reviewer',
              'text': 'Fresh and delicious',
              'createdAt': Timestamp.fromDate(DateTime(2026, 10, 8)),
            });

        await tester.pumpWidget(
          PosApp(auth: MockFirebaseAuth(), firestore: firestore),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('browse-as-guest')));
        await tester.pumpAndSettle();

        expect(find.text('ベストセラー商品'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Top product').first).dx,
          lessThan(tester.getTopLeft(find.text('Next product').first).dx),
        );
        await tester.drag(
          find.byKey(const ValueKey('storefront-product-list')),
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
        expect(find.text('新着商品'), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('storefront-product-list')),
          const Offset(0, 1500),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Top product');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-product-top')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('product-comment-input')),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Guest reviewer'), findsOneWidget);
        expect(find.text('Fresh and delicious'), findsOneWidget);
        expect(find.text('ログインしてコメント'), findsOneWidget);
      },
    );

    testWidgets('signed-in user can post a shared product comment', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('reviewer-1').set({
        'uid': 'reviewer-1',
        'name': 'Reviewer',
        'email': 'reviewer@example.com',
        'role': 'user',
      });
      await firestore.collection('products').doc('coffee').set({
        'name': 'コーヒー',
        'sku': 'COFFEE-1',
        'category': '飲料',
        'price': 300,
        'stock': 5,
        'active': true,
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'reviewer-1',
              email: 'reviewer@example.com',
            ),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-product-coffee')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('product-comment-input')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(
        find.byKey(const ValueKey('product-comment-input')),
        '  Smooth and rich  ',
      );
      await tester.tap(find.byKey(const ValueKey('submit-product-comment')));
      await tester.pumpAndSettle();

      final comments = await firestore
          .collection('products')
          .doc('coffee')
          .collection('comments')
          .get();
      expect(comments.docs, hasLength(1));
      expect(comments.docs.single.data()['uid'], 'reviewer-1');
      expect(comments.docs.single.data()['text'], 'Smooth and rich');
      expect(comments.docs.single.data()['authorName'], 'reviewer');
      expect(find.text('Smooth and rich'), findsOneWidget);
    });

    test(
      'checkout updates popularity count with the purchased quantity',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = PosRepository(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'buyer', email: 'buyer@example.com'),
          ),
          firestore,
        );
        await firestore.collection('products').doc('tea').set({
          'name': 'Tea',
          'sku': 'TEA-1',
          'category': '飲料',
          'price': 150,
          'stock': 5,
          'active': true,
        });

        await repository.checkout(
          profile: const PosProfile(
            uid: 'buyer',
            name: 'Buyer',
            email: 'buyer@example.com',
            role: 'user',
          ),
          products: const [
            PosProduct(
              id: 'tea',
              name: 'Tea',
              sku: 'TEA-1',
              category: '飲料',
              price: 150,
              stock: 5,
              active: true,
              soldCount: 0,
              createdAt: null,
            ),
          ],
          quantities: {'tea': 2},
          paymentMethod: '現金',
        );

        final savedProduct = await firestore
            .collection('products')
            .doc('tea')
            .get();
        expect(savedProduct.data()?['stock'], 3);
        expect(savedProduct.data()?['soldCount'], 2);
        final savedOrder = (await firestore.collection('orders').get())
            .docs
            .single
            .data();
        expect(savedOrder['status'], 'pending');
        expect(savedOrder['paymentSettled'], isTrue);
        expect(savedOrder['settlementUpdatedBy'], 'buyer');
      },
    );

    test(
      'admin acceptance and shipment enforce the order progression',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('orders').doc('lifecycle').set({
          'status': 'pending',
          'userId': 'buyer',
        });
        final repository = PosRepository(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin', email: 'admin@example.com'),
          ),
          firestore,
        );
        const admin = PosProfile(
          uid: 'admin',
          name: 'Admin',
          email: 'admin@example.com',
          role: 'admin',
        );

        await repository.updateOrderStatus(
          orderId: 'lifecycle',
          status: 'preparing',
          profile: admin,
        );
        final accepted =
            (await firestore.collection('orders').doc('lifecycle').get())
                .data()!;
        expect(accepted['status'], 'preparing');
        expect(accepted['acceptedBy'], 'admin');

        await repository.updateOrderStatus(
          orderId: 'lifecycle',
          status: 'shipped',
          profile: admin,
        );
        final shipped =
            (await firestore.collection('orders').doc('lifecycle').get())
                .data()!;
        expect(shipped['status'], 'shipped');
        expect(shipped['shippedBy'], 'admin');

        const customer = PosProfile(
          uid: 'buyer',
          name: 'Buyer',
          email: 'buyer@example.com',
          role: 'user',
        );
        await expectLater(
          repository.cancelOrder(
            order: const PosOrder(
              id: 'lifecycle',
              userId: 'buyer',
              userName: 'Buyer',
              total: 0,
              paymentMethod: '現金',
              items: [],
              createdAt: null,
              status: 'shipped',
              cancelledAt: null,
              cancelledBy: '',
              cancelledByName: '',
              salesCounted: false,
            ),
            profile: customer,
          ),
          throwsStateError,
        );
        await expectLater(
          repository.rejectOrder(orderId: 'lifecycle', profile: admin),
          throwsStateError,
        );
      },
    );

    test(
      'admin rejection restores inventory and removes rejected sales',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('products').doc('tea').set({
          'stock': 3,
          'soldCount': 2,
        });
        await firestore.collection('orders').doc('rejected-order').set({
          'status': 'pending',
          'salesCounted': true,
          'productIds': ['tea'],
          'quantities': {'tea': 2},
        });
        final repository = PosRepository(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin', email: 'admin@example.com'),
          ),
          firestore,
        );
        const admin = PosProfile(
          uid: 'admin',
          name: 'Admin',
          email: 'admin@example.com',
          role: 'admin',
        );

        await repository.rejectOrder(orderId: 'rejected-order', profile: admin);

        final rejected =
            (await firestore.collection('orders').doc('rejected-order').get())
                .data()!;
        final product =
            (await firestore.collection('products').doc('tea').get()).data()!;
        expect(rejected['status'], 'rejected');
        expect(rejected['rejectedBy'], 'admin');
        expect(product['stock'], 5);
        expect(product['soldCount'], 0);

        await expectLater(
          repository.rejectOrder(orderId: 'rejected-order', profile: admin),
          throwsStateError,
        );
      },
    );

    test(
      'admin backfill includes completed history once and ignores cancellations',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('products').doc('tea').set({
          'name': 'Tea',
          'sku': 'TEA-1',
          'category': '飲料',
          'price': 150,
          'stock': 5,
          'active': true,
          'soldCount': 1,
        });
        await firestore.collection('products').doc('coffee').set({
          'name': 'Coffee',
          'sku': 'COFFEE-1',
          'category': '飲料',
          'price': 300,
          'stock': 5,
          'active': true,
        });
        await firestore.collection('orders').doc('old-sale').set({
          'status': 'pending',
          'salesCounted': false,
        });
        await firestore.collection('orders').doc('canceled-sale').set({
          'status': 'cancelled',
          'salesCounted': false,
        });
        final repository = PosRepository(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin', email: 'admin@example.com'),
          ),
          firestore,
        );
        const admin = PosProfile(
          uid: 'admin',
          name: 'Admin',
          email: 'admin@example.com',
          role: 'admin',
        );
        const completedOrder = PosOrder(
          id: 'old-sale',
          userId: 'staff',
          userName: 'Staff',
          total: 600,
          paymentMethod: '現金',
          items: [
            {'productId': 'tea', 'quantity': 2},
            {'productId': 'coffee', 'quantity': 2},
          ],
          createdAt: null,
          status: 'completed',
          cancelledAt: null,
          cancelledBy: '',
          cancelledByName: '',
          salesCounted: false,
        );
        const canceledOrder = PosOrder(
          id: 'canceled-sale',
          userId: 'staff',
          userName: 'Staff',
          total: 300,
          paymentMethod: '現金',
          items: [
            {'productId': 'tea', 'quantity': 2},
          ],
          createdAt: null,
          status: 'cancelled',
          cancelledAt: null,
          cancelledBy: '',
          cancelledByName: '',
          salesCounted: false,
        );
        const products = [
          PosProduct(
            id: 'tea',
            name: 'Tea',
            sku: 'TEA-1',
            category: '飲料',
            price: 150,
            stock: 5,
            active: true,
            soldCount: 1,
            createdAt: null,
          ),
          PosProduct(
            id: 'coffee',
            name: 'Coffee',
            sku: 'COFFEE-1',
            category: '飲料',
            price: 300,
            stock: 5,
            active: true,
            soldCount: 0,
            createdAt: null,
          ),
        ];

        await repository.rebuildProductSalesCounts(
          profile: admin,
          orders: const [completedOrder, canceledOrder],
          products: products,
        );
        await repository.rebuildProductSalesCounts(
          profile: admin,
          orders: const [completedOrder, canceledOrder],
          products: products,
        );

        expect(
          (await firestore.collection('products').doc('tea').get())
              .data()?['soldCount'],
          2,
        );
        expect(
          (await firestore.collection('products').doc('coffee').get())
              .data()?['soldCount'],
          2,
        );
        expect(
          (await firestore.collection('orders').doc('old-sale').get())
              .data()?['salesCounted'],
          isTrue,
        );
        expect(
          (await firestore.collection('orders').doc('canceled-sale').get())
              .data()?['salesCounted'],
          isFalse,
        );
      },
    );

    testWidgets('routes an authenticated customer to the shopping app', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('staff-1').set({
        'uid': 'staff-1',
        'name': 'スタッフ',
        'email': 'staff@example.com',
        'role': 'user',
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'staff-1', email: 'staff@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('商品を見る'), findsWidgets);
      expect(find.text('注文履歴'), findsOneWidget);
      expect(find.text('マイページ'), findsOneWidget);
      expect(find.text('MORI  /  DAILY MARKET'), findsOneWidget);
      expect(find.text('商品を読み込み中...'), findsNothing);

      await tester.tap(find.text('マイページ').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-selector')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('language-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(find.text('App settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-selector')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('language-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('မြန်မာ').last);
      await tester.pumpAndSettle();

      expect(find.text('အက်ပ်ဆက်တင်များ'), findsOneWidget);
      expect(find.text('ဘာသာစကား'), findsOneWidget);
      expect(find.text('မြန်မာ'), findsWidgets);
    });

    testWidgets('customer can favorite a product and save contact details', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('fav-1').set({
        'uid': 'fav-1',
        'name': 'Fan',
        'email': 'fan@example.com',
        'role': 'user',
      });
      await firestore.collection('products').doc('tea').set({
        'name': 'お茶',
        'sku': 'T1',
        'category': '飲料',
        'price': 100,
        'stock': 5,
        'active': true,
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'fav-1', email: 'fan@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('favorite-tea')));
      await tester.pumpAndSettle();
      expect(
        (await firestore.collection('users').doc('fav-1').get())
            .data()?['favorites'],
        ['tea'],
      );

      await tester.tap(find.byKey(const ValueKey('filter-favorites')));
      await tester.pumpAndSettle();
      expect(find.text('お茶'), findsOneWidget);

      await tester.tap(find.text('マイページ').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit-contact')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('edit-contact')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('contact-address')),
        '東京都1-2-3',
      );
      await tester.enterText(
        find.byKey(const ValueKey('contact-phone')),
        '090-0000-0000',
      );
      await tester.tap(find.byKey(const ValueKey('contact-save')));
      await tester.pumpAndSettle();

      final data = (await firestore.collection('users').doc('fav-1').get())
          .data();
      expect(data?['address'], '東京都1-2-3');
      expect(data?['phone'], '090-0000-0000');
      expect(find.text('東京都1-2-3'), findsOneWidget);
    });

    testWidgets('customer profile shows stats, renames and lists favorites', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('prof-1').set({
        'uid': 'prof-1',
        'name': 'Hana',
        'email': 'hana@example.com',
        'role': 'user',
        'favorites': ['tea'],
      });
      await firestore.collection('products').doc('tea').set({
        'name': 'お茶',
        'sku': 'T1',
        'category': '飲料',
        'price': 100,
        'stock': 5,
        'active': true,
      });
      await firestore.collection('orders').doc('profile-order-1').set({
        'userId': 'prof-1',
        'userName': 'Hana',
        'items': [],
        'productIds': [],
        'quantities': {},
        'prices': {},
        'total': 12000,
        'paymentMethod': '現金',
        'status': 'completed',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'prof-1', email: 'hana@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('マイページ').last);
      await tester.pumpAndSettle();

      expect(find.text('シルバー会員'), findsOneWidget);
      expect(find.text('累計購入額'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('edit-profile-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-name-field')),
        'Hanako',
      );
      await tester.tap(find.byKey(const ValueKey('profile-name-save')));
      await tester.pumpAndSettle();
      expect(
        (await firestore.collection('users').doc('prof-1').get())
            .data()?['name'],
        'Hanako',
      );

      await tester.tap(find.byKey(const ValueKey('open-favorites')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('favorite-tea')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('unfavorite-tea')));
      await tester.pumpAndSettle();
      expect(find.text('お気に入りはまだありません'), findsOneWidget);
    });

    testWidgets('admin can promote a customer from the customers page', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-1').set({
        'uid': 'admin-1',
        'name': 'Boss',
        'email': 'boss@example.com',
        'role': 'admin',
      });
      await firestore.collection('users').doc('cust-1').set({
        'uid': 'cust-1',
        'name': 'Customer',
        'email': 'c@example.com',
        'role': 'user',
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-1', email: 'boss@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('設定').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('open-customers')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('open-customers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-role-cust-1')));
      await tester.pumpAndSettle();
      expect(
        (await firestore.collection('users').doc('cust-1').get())
            .data()?['role'],
        'admin',
      );
    });

    test('reorder places a new order and CSV escapes values', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('products').doc('tea').set({
        'name': 'お茶',
        'sku': 'T1',
        'category': '飲料',
        'price': 100,
        'stock': 5,
        'active': true,
      });
      final repository = PosRepository(MockFirebaseAuth(), firestore);
      const profile = PosProfile(
        uid: 'u1',
        name: 'A,B',
        email: 'a@example.com',
        role: 'user',
      );
      const old = PosOrder(
        id: 'old',
        userId: 'u1',
        userName: 'A,B',
        total: 200,
        paymentMethod: '現金',
        items: [
          {'productId': 'tea', 'name': 'お茶', 'quantity': 2},
        ],
        createdAt: null,
        status: 'completed',
        cancelledAt: null,
        cancelledBy: '',
        cancelledByName: '',
        salesCounted: true,
      );
      final id = await repository.reorder(
        profile: profile,
        order: old,
        paymentMethod: '現金',
      );
      final order = await firestore.collection('orders').doc(id).get();
      expect(order.data()?['total'], 200);
      expect(
        (await firestore.collection('products').doc('tea').get())
            .data()?['stock'],
        3,
      );
      expect(repository.salesCsv([old]), contains('"A,B"'));
    });

    testWidgets('uses desktop navigation at wide web sizes', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('staff-desktop').set({
        'uid': 'staff-desktop',
        'name': 'Staff',
        'email': 'staff@example.com',
        'role': 'user',
      });
      await firestore.collection('products').doc('desktop-product').set({
        'name': 'Desktop product',
        'sku': 'DESKTOP-1',
        'category': '飲料',
        'price': 250,
        'stock': 6,
        'active': true,
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'staff-desktop',
              email: 'staff@example.com',
            ),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final productCard = tester.getSize(
        find.byKey(const ValueKey('open-product-desktop-product')),
      );
      expect(productCard.width, lessThanOrEqualTo(320));
      expect(productCard.height, 226);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('admin is notified of new user orders and can view them', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-orders').set({
        'uid': 'admin-orders',
        'name': 'Admin',
        'email': 'admin@example.com',
        'role': 'admin',
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-orders', email: 'admin@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('新しい注文'), findsNothing);
      await firestore.collection('orders').doc('new-order').set({
        'userId': 'customer-1',
        'userName': 'New customer',
        'items': [
          {
            'productId': 'tea',
            'name': 'Green tea',
            'sku': 'TEA-1',
            'quantity': 2,
            'unitPrice': 150,
            'subtotal': 300,
          },
        ],
        'productIds': ['tea'],
        'quantities': {'tea': 2},
        'prices': {'tea': 150},
        'total': 300,
        'paymentMethod': '現金',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('新しい注文'), findsOneWidget);
      expect(find.textContaining('New customer'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-order-notifications')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('注文を見る'));
      await tester.pumpAndSettle();
      expect(find.text('売上一覧'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('order-card-new-order')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('order-card-new-order')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-order-notifications')),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    });

    testWidgets('admin can accept a new order from the popup dialog', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-pop').set({
        'uid': 'admin-pop',
        'name': 'Admin',
        'email': 'admin@example.com',
        'role': 'admin',
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-pop', email: 'admin@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await firestore.collection('orders').doc('pop-order').set({
        'userId': 'customer-1',
        'userName': 'Pop customer',
        'items': [
          {
            'productId': 'tea',
            'name': 'Green tea',
            'sku': 'TEA-1',
            'quantity': 2,
            'unitPrice': 150,
            'subtotal': 300,
          },
        ],
        'productIds': ['tea'],
        'quantities': {'tea': 2},
        'prices': {'tea': 150},
        'total': 300,
        'paymentMethod': '現金',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('new-order-dialog')), findsOneWidget);
      expect(find.textContaining('Green tea'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('alert-accept-order')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('new-order-dialog')), findsNothing);
      final doc = await firestore.collection('orders').doc('pop-order').get();
      expect(doc.data()?['status'], 'preparing');
    });

    testWidgets('customer sees a dialog when the admin accepts the order', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('cust-dlg').set({
        'uid': 'cust-dlg',
        'name': 'Customer',
        'email': 'c@example.com',
        'role': 'user',
      });
      await firestore.collection('orders').doc('order-dialog-1').set({
        'userId': 'cust-dlg',
        'userName': 'Customer',
        'items': [],
        'productIds': [],
        'quantities': {},
        'prices': {},
        'total': 500,
        'paymentMethod': '現金',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'cust-dlg', email: 'c@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-status-dialog')), findsNothing);

      await firestore.collection('orders').doc('order-dialog-1').update({
        'status': 'shipped',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('order-status-dialog')), findsOneWidget);
      expect(find.text('発送済み'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('status-view-orders')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-status-dialog')), findsNothing);
    });

    testWidgets('cart with many items scrolls and keeps checkout visible', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('many-cart').set({
        'uid': 'many-cart',
        'name': 'User',
        'email': 'many@example.com',
        'role': 'user',
      });
      for (var i = 0; i < 25; i++) {
        await firestore.collection('products').doc('p$i').set({
          'name': 'Item$i',
          'sku': 'S$i',
          'category': '食品',
          'price': 100,
          'stock': 5,
          'active': true,
        });
      }
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'many-cart', email: 'many@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 25; i++) {
        final add = find.byKey(ValueKey('quick-add-p$i')).first;
        await tester.ensureVisible(add);
        await tester.pump();
        await tester.tap(add);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('会計へ'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('注文を確定する'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('注文を確定する'), findsOneWidget);
    });

    testWidgets('cart items can be decreased and removed before checkout', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('staff-cart').set({
        'uid': 'staff-cart',
        'name': 'スタッフ',
        'email': 'cart@example.com',
        'role': 'user',
      });
      await firestore.collection('products').doc('tea').set({
        'name': 'お茶',
        'sku': 'TEA-1',
        'category': '飲料',
        'price': 150,
        'stock': 5,
        'active': true,
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'staff-cart', email: 'cart@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('お茶'));
      await tester.pumpAndSettle();
      expect(find.text('商品詳細'), findsOneWidget);
      expect(find.text('カート 0点'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('add-product-detail-to-cart')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('お茶'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('add-product-detail-to-cart')),
      );
      await tester.pumpAndSettle();
      expect(find.text('カート 2点'), findsOneWidget);
      await tester.tap(find.text('会計へ'));
      await tester.pumpAndSettle();

      expect(find.text('2点'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('decrease-cart-tea')));
      await tester.pumpAndSettle();
      expect(find.text('1点'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('remove-cart-tea')));
      await tester.pumpAndSettle();
      expect(find.text('カートに商品がありません。'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '注文を確定する'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('cashier can open a product detail and add it to cart', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('staff-product').set({
        'uid': 'staff-product',
        'name': 'スタッフ',
        'email': 'product@example.com',
        'role': 'user',
      });
      await firestore.collection('products').doc('tea').set({
        'name': '緑茶',
        'sku': 'TEA-1',
        'category': '飲料',
        'price': 150,
        'stock': 7,
        'active': true,
      });

      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'staff-product',
              email: 'product@example.com',
            ),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('カート 0点'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-product-tea')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('increase-detail-quantity')),
      );
      expect(find.text('商品詳細'), findsOneWidget);
      expect(find.text('緑茶'), findsOneWidget);
      expect(find.text('商品コード'), findsOneWidget);
      expect(find.text('TEA-1'), findsOneWidget);
      expect(find.text('カテゴリー'), findsOneWidget);
      expect(find.text('在庫数'), findsOneWidget);
      expect(find.text('7点'), findsOneWidget);
      expect(find.text('カートに追加可能な在庫: 7点'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-product-detail-to-cart')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('increase-detail-quantity')));
      await tester.tap(find.byKey(const ValueKey('increase-detail-quantity')));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('小計: ¥450'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('add-product-detail-to-cart')),
      );
      await tester.pumpAndSettle();
      expect(find.text('カート 3点'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-product-tea')));
      await tester.pumpAndSettle();
      expect(find.text('カートに追加可能な在庫: 4点'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('increase-detail-quantity')));
      await tester.tap(find.byKey(const ValueKey('increase-detail-quantity')));
      await tester.tap(find.byKey(const ValueKey('increase-detail-quantity')));
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('increase-detail-quantity')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('add-product-detail-to-cart')),
      );
      await tester.pumpAndSettle();
      expect(find.text('カート 7点'), findsOneWidget);
    });

    testWidgets('admin can open product details and edit from there', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-product').set({
        'uid': 'admin-product',
        'name': '管理者',
        'email': 'admin-product@example.com',
        'role': 'admin',
      });
      await firestore.collection('products').doc('coffee').set({
        'name': 'コーヒー',
        'sku': 'COFFEE-1',
        'category': '飲料',
        'price': 300,
        'stock': 12,
        'active': true,
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'admin-product',
              email: 'admin-product@example.com',
            ),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('商品').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('コーヒー'));
      await tester.pumpAndSettle();

      expect(find.text('商品詳細'), findsOneWidget);
      expect(find.text('COFFEE-1'), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-product-detail')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('edit-product-detail')));
      await tester.pumpAndSettle();
      expect(find.text('商品を編集'), findsOneWidget);
      expect(find.text('商品名'), findsOneWidget);
    });

    testWidgets('order history opens a detailed receipt page', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('staff-order').set({
        'uid': 'staff-order',
        'name': 'スタッフ',
        'email': 'order@example.com',
        'role': 'user',
      });
      await firestore.collection('orders').doc('receipt-123456').set({
        'userId': 'staff-order',
        'userName': 'スタッフ',
        'items': [
          {
            'productId': 'tea',
            'name': '緑茶',
            'sku': 'TEA-1',
            'quantity': 2,
            'unitPrice': 150,
            'subtotal': 300,
          },
        ],
        'total': 300,
        'paymentMethod': '現金',
        'status': 'completed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5, 14, 30)),
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'staff-order', email: 'order@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('注文履歴').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('order-card-receipt-123456')));
      await tester.pumpAndSettle();

      expect(find.text('注文詳細'), findsOneWidget);
      expect(find.text('注文番号'), findsOneWidget);
      expect(find.text('receipt-123456'), findsOneWidget);
      expect(find.text('支払い方法'), findsOneWidget);
      expect(find.text('精算状態'), findsOneWidget);
      expect(find.text('精算済み'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('toggle-order-settlement')),
        findsNothing,
      );
      expect(find.text('緑茶'), findsOneWidget);
      expect(find.textContaining('数量: 2 × ¥150'), findsOneWidget);
      expect(find.text('¥300'), findsWidgets);
    });

    testWidgets('admin sales list summarizes, filters, and searches orders', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-sales').set({
        'uid': 'admin-sales',
        'name': 'Sales admin',
        'email': 'sales@example.com',
        'role': 'admin',
      });
      Future<void> addOrder({
        required String id,
        required String customer,
        required String product,
        required int quantity,
        required int total,
        required String status,
        bool paymentSettled = true,
      }) async {
        await firestore.collection('orders').doc(id).set({
          'userId': customer.toLowerCase().replaceAll(' ', '-'),
          'userName': customer,
          'items': [
            {
              'productId': product.toLowerCase().replaceAll(' ', '-'),
              'name': product,
              'sku': 'SKU-$id',
              'quantity': quantity,
              'unitPrice': total ~/ quantity,
              'subtotal': total,
            },
          ],
          'total': total,
          'paymentMethod': '現金',
          'status': status,
          'paymentSettled': paymentSettled,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 6, 10)),
        });
      }

      await addOrder(
        id: 'settled-sale',
        customer: 'Alice',
        product: 'Green tea',
        quantity: 2,
        total: 200,
        status: 'completed',
      );
      await addOrder(
        id: 'unsettled-sale',
        customer: 'Bob',
        product: 'Coffee',
        quantity: 1,
        total: 300,
        status: 'completed',
        paymentSettled: false,
      );
      await addOrder(
        id: 'canceled-sale',
        customer: 'Carol',
        product: 'Cake',
        quantity: 4,
        total: 800,
        status: 'cancelled',
      );

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-sales', email: 'sales@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('売上').last);
      await tester.pumpAndSettle();

      expect(find.text('売上概要'), findsOneWidget);
      expect(find.text('受注済み注文'), findsOneWidget);
      expect(find.text('2件'), findsOneWidget);
      expect(find.text('総売上'), findsOneWidget);
      expect(find.text('¥500'), findsOneWidget);
      expect(find.text('販売点数'), findsOneWidget);
      expect(find.text('3点'), findsOneWidget);
      expect(find.text('未精算の注文 (1件)'), findsOneWidget);
      expect(find.text('¥300'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '未精算'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '未精算'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('order-card-unsettled-sale')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('order-card-settled-sale')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('order-card-canceled-sale')),
        findsNothing,
      );

      await tester.dragUntilVisible(
        find.widgetWithText(ChoiceChip, 'すべて'),
        find.byKey(const ValueKey('sales-order-filters')),
        const Offset(300, 0),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'すべて'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('sales-order-search')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sales-order-search')),
        'Alice',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('order-card-settled-sale')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('order-card-unsettled-sale')),
        findsNothing,
      );
    });

    testWidgets('admin can settle and unsettle a completed order', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-settlement').set({
        'uid': 'admin-settlement',
        'name': 'Admin',
        'email': 'admin@example.com',
        'role': 'admin',
      });
      await firestore.collection('products').doc('tea').set({
        'name': 'Green tea',
        'sku': 'TEA-1',
        'category': '飲料',
        'price': 150,
        'stock': 3,
        'active': true,
        'soldCount': 2,
      });
      await firestore.collection('orders').doc('settle-order').set({
        'userId': 'customer-1',
        'userName': 'Customer',
        'items': [
          {
            'productId': 'tea',
            'name': 'Green tea',
            'sku': 'TEA-1',
            'quantity': 2,
            'unitPrice': 150,
            'subtotal': 300,
          },
        ],
        'productIds': ['tea'],
        'quantities': {'tea': 2},
        'prices': {'tea': 150},
        'total': 300,
        'paymentMethod': '現金',
        'status': 'completed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 6, 10)),
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'admin-settlement',
              email: 'admin@example.com',
            ),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin-order-notifications')),
        findsOneWidget,
      );
      await tester.tap(find.text('売上').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('order-card-settle-order')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('order-card-settle-order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('order-card-settle-order')));
      await tester.pumpAndSettle();
      expect(find.text('精算済み'), findsOneWidget);
      expect(find.text('注文状態'), findsOneWidget);
      expect(find.text('完了'), findsOneWidget);
      expect(find.text('担当スタッフ'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('toggle-order-settlement')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('toggle-order-settlement')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-order-settlement')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-order-settlement')));
      await tester.pumpAndSettle();
      var savedOrder = await firestore
          .collection('orders')
          .doc('settle-order')
          .get();
      expect(savedOrder.data()?['paymentSettled'], isFalse);
      expect(savedOrder.data()?['settlementUpdatedBy'], 'admin-settlement');
      expect(find.text('未精算'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('toggle-order-settlement')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-order-settlement')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-order-settlement')));
      await tester.pumpAndSettle();
      savedOrder = await firestore
          .collection('orders')
          .doc('settle-order')
          .get();
      expect(savedOrder.data()?['paymentSettled'], isTrue);
      expect(find.text('精算済み'), findsOneWidget);

      final savedProduct = await firestore
          .collection('products')
          .doc('tea')
          .get();
      expect(savedProduct.data()?['stock'], 3);
      expect(savedProduct.data()?['soldCount'], 2);
    });

    testWidgets(
      'customer can cancel a pending order which disappears from history',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('users').doc('staff-cancel').set({
          'uid': 'staff-cancel',
          'name': '担当スタッフ',
          'email': 'cancel@example.com',
          'role': 'user',
        });
        await firestore.collection('products').doc('tea').set({
          'name': '緑茶',
          'sku': 'TEA-1',
          'category': '飲料',
          'price': 150,
          'stock': 3,
          'active': true,
          'soldCount': 2,
        });
        await firestore.collection('orders').doc('cancel-me').set({
          'userId': 'staff-cancel',
          'userName': '担当スタッフ',
          'items': [
            {
              'productId': 'tea',
              'name': '緑茶',
              'sku': 'TEA-1',
              'quantity': 2,
              'unitPrice': 150,
              'subtotal': 300,
            },
          ],
          'productIds': ['tea'],
          'quantities': {'tea': 2},
          'prices': {'tea': 150},
          'total': 300,
          'paymentMethod': '現金',
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5, 14, 30)),
          'salesCounted': true,
        });

        await tester.pumpWidget(
          PosApp(
            auth: MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(
                uid: 'staff-cancel',
                email: 'cancel@example.com',
              ),
            ),
            firestore: firestore,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('注文履歴').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('order-card-cancel-me')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('cancel-order')),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(const ValueKey('cancel-order')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('confirm-cancel-order')));
        await tester.pumpAndSettle();

        final savedOrder = await firestore
            .collection('orders')
            .doc('cancel-me')
            .get();
        final savedProduct = await firestore
            .collection('products')
            .doc('tea')
            .get();
        expect(savedOrder.data()?['status'], 'cancelled');
        expect(savedOrder.data()?['cancelledBy'], 'staff-cancel');
        expect(savedProduct.data()?['stock'], 5);
        expect(savedProduct.data()?['soldCount'], 0);
        expect(
          find.byKey(const ValueKey('order-card-cancel-me')),
          findsNothing,
        );
        expect(find.text('注文履歴はありません'), findsOneWidget);

        final auditRepository = PosRepository(
          MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'audit-admin', email: 'admin@example.com'),
          ),
          firestore,
        );
        final adminOrders = await auditRepository
            .orders(
              profile: const PosProfile(
                uid: 'audit-admin',
                name: 'Admin',
                email: 'admin@example.com',
                role: 'admin',
              ),
            )
            .first;
        final customerOrders = await auditRepository
            .orders(
              profile: const PosProfile(
                uid: 'staff-cancel',
                name: 'Customer',
                email: 'cancel@example.com',
                role: 'user',
              ),
            )
            .first;
        expect(adminOrders.map((order) => order.id), contains('cancel-me'));
        expect(
          customerOrders.map((order) => order.id),
          isNot(contains('cancel-me')),
        );
      },
    );

    testWidgets('admin product editor keeps barcode entry without image UI', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-1').set({
        'uid': 'admin-1',
        'name': '管理者',
        'email': 'admin@example.com',
        'role': 'admin',
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-1', email: 'admin@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MORI  /  ADMIN DESK'), findsOneWidget);
      await tester.tap(find.text('商品').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('商品を追加'));
      await tester.pumpAndSettle();

      expect(find.text('画像を選択'), findsNothing);
      expect(find.text('カメラで撮影'), findsNothing);
      expect(find.text('商品名'), findsOneWidget);
      expect(find.text('SKU / 商品コード'), findsOneWidget);
      expect(find.byTooltip('バーコードをスキャン'), findsOneWidget);
    });

    testWidgets('admin products can be filtered, bulk stopped and duplicated', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-9').set({
        'uid': 'admin-9',
        'name': '管理者',
        'email': 'a9@example.com',
        'role': 'admin',
      });
      for (final e in {'p1': ('Apple', 2), 'p2': ('Banana', 50)}.entries) {
        await firestore.collection('products').doc(e.key).set({
          'name': e.value.$1,
          'sku': e.key,
          'category': '食品',
          'price': 100,
          'stock': e.value.$2,
          'active': true,
          'soldCount': 0,
          'imageUrl': '',
          'createdAt': Timestamp.now(),
        });
      }
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-9', email: 'a9@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('商品').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('admin-filter-low')));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('admin-filter-all')));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Apple'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-deactivate')));
      await tester.pumpAndSettle();
      expect(
        (await firestore.collection('products').doc('p1').get())['active'],
        false,
      );

      await tester.ensureVisible(find.byKey(const ValueKey('product-menu-p2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('product-menu-p2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('複製'));
      await tester.pumpAndSettle();
      final all = await firestore.collection('products').get();
      expect(all.docs.length, 3);
    });

    testWidgets('admin can add a new category from the product editor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-c').set({
        'uid': 'admin-c',
        'name': '管理者',
        'email': 'c@example.com',
        'role': 'admin',
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-c', email: 'c@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('商品').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('商品を追加'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Cake');
      await tester.enterText(fields.at(1), 'CAKE-1');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('＋ 新しいカテゴリー').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new-category-field')),
        'お菓子',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '税込価格（円）'),
        '300',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '在庫数'), '5');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final docs = (await firestore.collection('products').get()).docs;
      expect(docs.single['category'], 'お菓子');
      expect(find.text('お菓子'), findsWidgets);
    });

    testWidgets('admin discounts all products and customers see sale items', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-d').set({
        'uid': 'admin-d',
        'name': '管理者',
        'email': 'd@example.com',
        'role': 'admin',
      });
      await firestore.collection('products').doc('tea').set({
        'name': 'お茶',
        'sku': 'TEA-1',
        'category': '飲料',
        'price': 200,
        'stock': 9,
        'active': true,
      });
      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-d', email: 'd@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('商品').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-select-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-discount')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('discount-percent-field')),
        '25',
      );
      await tester.tap(find.byKey(const ValueKey('discount-apply')));
      await tester.pumpAndSettle();
      final doc = await firestore.collection('products').doc('tea').get();
      expect(doc['price'], 150);
      expect(doc['originalPrice'], 200);
      expect(doc['discountPercent'], 25);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        PosApp(auth: MockFirebaseAuth(signedIn: false), firestore: firestore),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('アカウントなしで商品を見る'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sale-section')), findsOneWidget);
      expect(find.byKey(const ValueKey('sale-badge-tea')), findsWidgets);
    });

    testWidgets('admin dashboard shows sales, best sellers, and stock alerts', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('admin-2').set({
        'uid': 'admin-2',
        'name': '管理者',
        'email': 'admin2@example.com',
        'role': 'admin',
      });
      await firestore.collection('products').doc('coffee').set({
        'name': 'コーヒー',
        'sku': 'COFFEE-1',
        'category': '飲料',
        'price': 300,
        'stock': 2,
        'active': true,
        'soldCount': 5,
      });
      await firestore.collection('products').doc('tea').set({
        'name': '緑茶',
        'sku': 'TEA-1',
        'category': '飲料',
        'price': 150,
        'stock': 4,
        'active': true,
        'soldCount': 2,
      });
      await firestore.collection('orders').doc('order-1').set({
        'userId': 'admin-2',
        'userName': '管理者',
        'items': [
          {
            'productId': 'coffee',
            'name': 'コーヒー',
            'sku': 'COFFEE-1',
            'quantity': 2,
            'unitPrice': 300,
            'subtotal': 600,
          },
        ],
        'total': 600,
        'paymentMethod': '現金',
        'status': 'completed',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      await tester.pumpWidget(
        PosApp(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'admin-2', email: 'admin2@example.com'),
          ),
          firestore: firestore,
        ),
      );
      await tester.pumpAndSettle();

      final dashboardList = find.byType(ListView).first;
      Future<void> scrollDashboard() async {
        await tester.drag(dashboardList, const Offset(0, -250));
        await tester.pumpAndSettle();
      }

      await scrollDashboard();
      expect(find.text('今月の売上'), findsOneWidget);
      expect(find.text('平均客単価'), findsOneWidget);
      await scrollDashboard();
      expect(find.text('過去7日間の売上'), findsOneWidget);
      await scrollDashboard();
      expect(find.text('本日の支払い内訳'), findsOneWidget);
      await scrollDashboard();
      expect(find.text('最も販売された商品'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('most-sold-product-coffee')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('most-sold-product-tea')))
              .dy,
        ),
      );
      expect(find.text('5点'), findsOneWidget);
      expect(find.text('2点'), findsOneWidget);
      await scrollDashboard();
      expect(find.text('在庫アラート'), findsOneWidget);
      await scrollDashboard();
      expect(find.text('コーヒー'), findsWidgets);
      expect(find.text('在庫 2点'), findsOneWidget);
      expect(find.text('¥600'), findsWidgets);
      await scrollDashboard();
      await tester.tap(
        find.byKey(const ValueKey('rebuild-best-seller-counts')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ベストセラーを再集計'), findsNWidgets(2));
      expect(
        find.text('過去の完了済み注文から販売数を再集計します。処理中は会計と注文キャンセルを停止してください。'),
        findsOneWidget,
      );
      await tester.tap(find.text('キャンセル').last);
      await tester.pumpAndSettle();
    });
  });
}
