import 'package:dart_graphql/src/builder/generator.dart';
import 'package:dart_graphql/src/decorators/arg.dart';
import 'package:dart_graphql/src/decorators/query.dart';
import 'package:dart_graphql/src/decorators/reflector.dart';
import 'package:dart_graphql/src/decorators/resolver.dart';

import 'package:graphql_schema/graphql_schema.dart';
import 'package:reflectable/mirrors.dart';

GraphQLSchema buildSchema(List<Type> resolvers) {
  var baseQuery = objectType('Query');
  var gen = Generator();

  for (var resolver in resolvers) {
    if (!reflector.canReflectType(resolver)) {
      reflector.reflectType(resolver);
      //TODO : better errors
    }

    ClassMirror clazz = reflector.reflectType(resolver);
    if (!clazz.metadata.any((decorator) => decorator is Resolver)) {
      throw "Resolver not in decorator";
      //TODO : better errors
    }
    var resolverInstance = clazz.newInstance("", []);
    var resolverInstanceMirror = reflector.reflect(resolverInstance);

    List<DeclarationMirror> queriesFunctions = clazz.declarations.values
        .where(
          (method) =>
              (method is MethodMirror) &&
              (method.metadata.any((decorator) => decorator is Query)),
        )
        .toList();

    baseQuery.fields.addAll(
      queriesFunctions.map(
        (func) => _buildQueryField(func, clazz, gen, resolverInstanceMirror),
      ),
    );
  }
  return GraphQLSchema(queryType: baseQuery);
}

GraphQLObjectField _buildQueryField(MethodMirror queryMethod,
    ClassMirror resolver, Generator gen, InstanceMirror instanceMirror) {
  Query q = queryMethod.metadata.firstWhere((dec) => dec is Query);

  var parameters = queryMethod.parameters
      .where((param) => param.metadata.any((dec) => dec is Arg));
  var inputs = parameters.map((param) {
    Arg arg = param.metadata.firstWhere((dec) => dec is Arg);
    return GraphQLFieldInput(param.simpleName,
        gen.resolveType(param.reflectedType ?? param.dynamicReflectedType),
        description: arg.desciption);
  });

  return field(
      queryMethod.simpleName,
      gen.resolveType(queryMethod.reflectedReturnType ??
          queryMethod.dynamicReflectedReturnType),
      description: q.description,
      resolve: (_, args) => instanceMirror.invoke(
          queryMethod.simpleName, [...inputs.map((inp) => args[inp.name])]),
      inputs: [...inputs]);
}
