import 'package:reflectable/reflectable.dart';

class Reflector extends Reflectable {
  const Reflector()
      : super(newInstanceCapability, invokingCapability, metadataCapability,
            reflectedTypeCapability, declarationsCapability, typeCapability, typeRelationsCapability);
}

const reflector = Reflector();
