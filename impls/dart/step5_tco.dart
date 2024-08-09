import 'dart:io';

import 'core.dart';
import 'env.dart';
import 'printer.dart' as printer;
import 'reader.dart' as reader;
import 'types.dart';

final Env replEnv = new Env();

void setupEnv() {
  ns.forEach((sym, fun) => replEnv.set(sym, fun));

  rep('(def! not (fn* (a) (if a false true)))');
}

MalType READ(String x) => reader.read_str(x);

MalType EVAL(MalType ast, Env env) {
  while (true) {

  var dbgeval = env.get("DEBUG-EVAL");
  if (dbgeval != null && !(dbgeval is MalNil)
      && !(dbgeval is MalBool && dbgeval.value == false)) {
      stdout.writeln("EVAL: ${printer.pr_str(ast)}");
  }

  if (ast is MalSymbol) {
    var result = env.get(ast.value);
    if (result == null) {
      throw new NotFoundException(ast.value);
    }
    return result;
  } else if (ast is MalList) {
    // Exit this switch.
  } else if (ast is MalVector) {
    return new MalVector(ast.elements.map((x) => EVAL(x, env)).toList());
  } else if (ast is MalHashMap) {
    var newMap = new Map<MalType, MalType>.from(ast.value);
    for (var key in newMap.keys) {
      newMap[key] = EVAL(newMap[key], env);
    }
    return new MalHashMap(newMap);
  } else {
    return ast;
  }
      // ast is a list. todo: indent left.
      if ((ast as MalList).elements.isEmpty) {
        return ast;
      } else {
        var list = ast as MalList;
        if (list.elements.first is MalSymbol) {
          var symbol = list.elements.first as MalSymbol;
          var args = list.elements.sublist(1);
          if (symbol.value == "def!") {
            MalSymbol key = args.first;
            MalType value = EVAL(args[1], env);
            env.set(key.value, value);
            return value;
          } else if (symbol.value == "let*") {
            // TODO(het): If elements.length is not even, give helpful error
            Iterable<List<MalType>> pairs(List<MalType> elements) sync* {
              for (var i = 0; i < elements.length; i += 2) {
                yield [elements[i], elements[i + 1]];
              }
            }

            var newEnv = new Env(env);
            MalIterable bindings = args.first;
            for (var pair in pairs(bindings.elements)) {
              MalSymbol key = pair[0];
              MalType value = EVAL(pair[1], newEnv);
              newEnv.set(key.value, value);
            }
            ast = args[1];
            env = newEnv;
            continue;
          } else if (symbol.value == "do") {
            for (var elt in args.sublist(0, args.length - 1)) {
              EVAL(elt, env);
            }
            ast = args.last;
            continue;
          } else if (symbol.value == "if") {
            var condition = EVAL(args[0], env);
            if (condition is MalNil ||
                condition is MalBool && condition.value == false) {
              // False side of branch
              if (args.length < 3) {
                return new MalNil();
              }
              ast = args[2];
              continue;
            } else {
              // True side of branch
              ast = args[1];
              continue;
            }
          } else if (symbol.value == "fn*") {
            var params = (args[0] as MalIterable)
                .elements
                .map((e) => e as MalSymbol)
                .toList();
            return new MalClosure(
                params,
                args[1],
                env,
                (List<MalType> funcArgs) =>
                    EVAL(args[1], new Env(env, params, funcArgs)));
          }
        }
        var f = EVAL(list.elements.first, env);
        var args = list.elements.sublist(1).map((x) => EVAL(x, env)).toList();
        if (f is MalBuiltin) {
          return f.call(args);
        } else if (f is MalClosure) {
          ast = f.ast;
          env = new Env(f.env, f.params, args);
          continue;
        } else {
          throw 'bad!';
        }
      }
  }
}

String PRINT(MalType x) => printer.pr_str(x);

String rep(String x) {
  return PRINT(EVAL(READ(x), replEnv));
}

const prompt = 'user> ';
main() {
  setupEnv();
  while (true) {
    stdout.write(prompt);
    var input = stdin.readLineSync();
    if (input == null) return;
    var output;
    try {
      output = rep(input);
    } on reader.ParseException catch (e) {
      stdout.writeln("Error: '${e.message}'");
      continue;
    } on NotFoundException catch (e) {
      stdout.writeln("Error: '${e.value}' not found");
      continue;
    } on MalException catch (e) {
      stdout.writeln("Error: ${printer.pr_str(e.value)}");
      continue;
    } on reader.NoInputException {
      continue;
    }
    stdout.writeln(output);
  }
}
