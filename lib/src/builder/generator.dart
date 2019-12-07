import 'package:dart_graphql/src/decorators/arg.dart';
import 'package:dart_graphql/src/decorators/field.dart';
import 'package:dart_graphql/src/decorators/objectType.dart';
import 'package:dart_graphql/src/decorators/reflector.dart';

import 'package:graphql_schema/graphql_schema.dart';
import 'package:reflectable/reflectable.dart';

class Generator {
  Generator();

  Map<Type, GraphQLObjectType> generatedTypes = Map();

  GraphQLObjectType _generateObjectType(Type type) {
    if (generatedTypes[type] != null) {
      return generatedTypes[type];
    }

    ClassMirror clazz = reflector.reflectType(type);
    ObjectType objectTypeM =
        clazz.metadata.firstWhere((x) => x is ObjectType, orElse: () => null);
    if (objectTypeM == null) {
      throw "${clazz.simpleName} Not ObjectType";
    }

    var obj = GraphQLObjectType(clazz.simpleName, objectTypeM.description);
    generatedTypes[type] = obj;

    try{
      var superCl = _generateObjectType(clazz.superclass.reflectedType);
      obj.fields.addAll(superCl.fields);
    }catch(e){
      
    }

    List<DeclarationMirror> fieldMembers = [];
    for (var member in clazz.declarations.values) {
      if (member.metadata.any((x) => x is Field)) {
        fieldMembers.add(member);
      }
    }

    var fields = fieldMembers.map(
      (member) {
        var inputs = Iterable<GraphQLFieldInput>.empty();
        if (member is MethodMirror) {
          var parameters = member.parameters
              .where((param) => param.metadata.any((dec) => dec is Arg));
          inputs = parameters.map((param) {
            Arg arg = param.metadata.firstWhere((dec) => dec is Arg);
            return GraphQLFieldInput(param.simpleName,
                resolveType(param.reflectedType ?? param.dynamicReflectedType),
                description: arg.desciption);
          });
        }

        return field(member.simpleName, resolveMember(member),
            description:
                (member.metadata.firstWhere((t) => t is Field) as Field)
                    .description, resolve: (instance, args) {
          var instancemirror = reflector.reflect(instance);

          var value;
          if (member is VariableMirror) {
            value = instancemirror.invokeGetter(member.simpleName);
          } else if (member is MethodMirror && member.isGetter) {
            value = instancemirror.invokeGetter(member.simpleName);
          } else {
            value = instancemirror.invoke(
                member.simpleName, [...inputs.map((f) => args[f.name])]);
          }

          return value;
        }, inputs: inputs);
      },
    );

    obj.fields.addAll(fields);
    // print(obj);
    return obj;
  }

  Type getTypeOfMember(DeclarationMirror member) {
    Type t;
    if (member is VariableMirror) {
      t = member.reflectedType ?? member.dynamicReflectedType;
    } else if (member is MethodMirror) {
      t = member.reflectedReturnType ?? member.dynamicReflectedReturnType;
    }
    return t;
  }

  GraphQLType resolveMember(DeclarationMirror member) {
    Type t = getTypeOfMember(member);
    return resolveType(t);
  }

  GraphQLType resolveType(Type type) {
    // print("Resolve Type $type");

    var gt = resolvePrimitiveType(type) ??
        resolveObjectType(type) ??
        resolveFutureList(type.toString(), ObjectType);
    if (gt != null) {
      return gt;
    }

    throw "Could not resolve type";
  }

  GraphQLType resolvePrimitiveType(Type t) {
    switch (t) {
      case String:
        return graphQLString;
      case int:
        return graphQLInt;
      case double:
        return graphQLFloat;
      case bool:
        return graphQLBoolean;
      case DateTime:
        return graphQLDate;
    }
    return null;
  }

  GraphQLType resolveObjectType(Type t) {
    ClassMirror clazz;
    try {
      clazz = reflector.reflectType(t);
    } catch (e) {
      return null;
    }

    if (clazz.metadata.any((t) => t is ObjectType)) {
      if (generatedTypes.containsKey(t)) {
        return generatedTypes[t];
      } else {
        return generatedTypes[t] = _generateObjectType(t);
      }
    }
    return null;
  }

  Type typeFromClassName(String className, Type typeCheck) {
    if (className == (String).toString()) {
      return String;
    } else if (className == (int).toString()) {
      return int;
    } else if (className == (double).toString()) {
      return double;
    } else if (className == (bool).toString()) {
      return bool;
    } else if (className == (DateTime).toString()) {
      return DateTime;
    } else if (reflector.annotatedClasses
        .any((c) => c.simpleName == className)) {
      var c = reflector.annotatedClasses
          .firstWhere((c) => c.simpleName == className);
      if (c.metadata.any((c) => c.runtimeType == typeCheck)) {
        return c.reflectedType;
      }
    } else {
      return null;
    }
  }

  GraphQLType resolveFutureList(String typeStr, Type typeCheck) {
    if (typeFromClassName(typeStr, typeCheck) != null) {
      return resolveType(typeFromClassName(typeStr, typeCheck));
    }

    var regex = RegExp(r"(\w*)<(.*)>");
    var matches = regex.firstMatch(typeStr);
    if (matches == null) {
      return null;
    }
    var typeMain = matches.group(1);
    var args = matches.group(2);

    if (typeMain == "Future") {
      return resolveFutureList(args, typeCheck);
    } else if (typeMain == "List") {
      return listOf(resolveFutureList(args, typeCheck));
    }
  }
}
