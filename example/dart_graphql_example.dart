import 'dart:io';

import 'package:angel_framework/angel_framework.dart' as angel;
import 'package:angel_framework/http.dart';
import 'package:angel_graphql/angel_graphql.dart';
import 'package:dart_graphql/dart_graphql.dart';
import 'package:dart_graphql/src/decorators/arg.dart';
import 'package:dart_graphql/src/decorators/field.dart';
import 'package:dart_graphql/src/decorators/objectType.dart';
import 'package:dart_graphql/src/decorators/query.dart';
import 'package:dart_graphql/src/decorators/reflector.dart';
import 'package:dart_graphql/src/decorators/resolver.dart';
import 'package:graphql_server/graphql_server.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'dart_graphql_example.reflectable.dart';

main() async {
  initializeReflectable();

  var logger = Logger('angel_graphql');
  var portStr = Platform.environment['PORT'] ?? '8080';
  var host = Platform.environment["hostname"] ?? 'localhost';
  var port = int.tryParse(portStr);

  var app = angel.Angel(
      logger: logger
        ..onRecord.listen((rec) {
          print(rec);
          if (rec.error != null) print(rec.error);
          if (rec.stackTrace != null) print(rec.stackTrace);
        }));
  var http = AngelHttp(app);

  app.all('/graphql', graphQLHttp(GraphQL(buildSchema([R1]))));
  app.get('/graphiql', graphiQL());

  var server = await http.startServer(host, port);
  var uri =
      Uri(scheme: 'http', host: server.address.address, port: server.port);
  var graphiqlUri = uri.replace(path: 'graphiql');
  print('Listening at $uri');
  print('Access graphiql at $graphiqlUri');
}

@reflector
@Resolver()
class R1 {
  @Query(description: "generate Test Page")
  Page testPage() => Page();

  @Query(description: "generate Multiple Pages")
  List<Page> multiplePages() {
    return [Page()..title = "Page   1", Page()..title = "Page   2"];
  }

  @Query(description: "Page with input title")
  Page pageInputTitle(@Arg(desciption: "title of page") String title) {
    return Page(title);
  }

  @Query(description: "ExtraPage")
  ExPage exPage(){
    return ExPage();
  }

}

@reflector
@ObjectType(description: "Page with title")
class Page {
  Page([this.title = "defaultPage"]);

  @Field(description: "Title of Page")
  String title;

  @Field()
  Future<String> get fStr async => await "ABC";

  @Field()
  List<List<int>> rArray = [
    [1, 2, 3],
    [4, 5, 6]
  ];

  @Field()
  Future<List<List<String>>> futureArray = Future.value([
    ["1", "2", "3"],
    ["a", "b", "c"]
  ]);

  @Field(description: "Count")
  int getCount(@Arg() int count) {
    return count;
  }

}

@reflector
@ObjectType()
class ExPage extends Page{

  @Field()
  String extra="extra";

}