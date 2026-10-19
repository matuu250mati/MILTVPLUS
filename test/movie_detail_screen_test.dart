import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miltv_plus/features/catalog/movie_detail_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildScreen({
    String? synopsis,
    String? posterUrl,
    int? year,
  }) {
    return MaterialApp(
      home: MovieDetailScreen(
        contentKey: 'movie-qa-1',
        title: 'Película de prueba QA',
        category: 'Cine',
        genres: const ['Drama'],
        posterUrl: posterUrl,
        year: year,
        synopsis: synopsis,
      ),
    );
  }

  testWidgets('movie details show metadata and a fallback for missing synopsis',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Película de prueba QA'), findsOneWidget);
    expect(find.text('Cine'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(
      find.textContaining('La descripción de este título todavía no fue agregada'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('favorite and like reactions persist locally', (tester) async {
    await tester.pumpWidget(buildScreen(synopsis: 'Sinopsis de prueba'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Agregar a favoritos'));
    await tester.tap(find.text('Agregar a favoritos'));
    await tester.pumpAndSettle();

    var preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('miltvplus.favorite.movie.movie-qa-1'), isTrue);

    await tester.ensureVisible(find.text('Me gusta'));
    await tester.tap(find.text('Me gusta'));
    await tester.pumpAndSettle();

    preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('miltvplus.like.movie.movie-qa-1'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(buildScreen(synopsis: 'Sinopsis de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('En favoritos'), findsOneWidget);
    expect(find.text('Te gusta'), findsOneWidget);
  });

  testWidgets('playback remains unavailable and explains why', (tester) async {
    await tester.pumpWidget(buildScreen(synopsis: 'Sinopsis de prueba'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reproducción próximamente').last);
    await tester.tap(find.text('Reproducción próximamente').last);
    await tester.pumpAndSettle();

    expect(find.text('Estamos preparando este título'), findsOneWidget);
    expect(
      find.textContaining('una fuente autorizada'),
      findsOneWidget,
    );
    expect(find.text('Entendido'), findsOneWidget);
  });
}
