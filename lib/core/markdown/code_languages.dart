import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

/// The grammars the app highlights with, shared by the read-only markdown code
/// block and the editable code editor.
///
/// Highlighting the whole of `all.dart` would pull 197 grammars into the
/// bundle. These are the languages course content and the question bank
/// realistically use; anything else renders unhighlighted, which is what the
/// web's Prism does for an unknown tag too.
///
/// Kept in one place because two copies would drift: a language added for the
/// solve editor but missing from the markdown block would highlight a coding
/// question's statement differently from the answer written below it.
final Map<String, Mode> codeLanguages = {
  'bash': langBash,
  'sh': langBash,
  'shell': langBash,
  'zsh': langBash,
  'c': langC,
  'cpp': langCpp,
  'c++': langCpp,
  'cs': langCsharp,
  'csharp': langCsharp,
  'css': langCss,
  'dart': langDart,
  'go': langGo,
  'html': langXml,
  'java': langJava,
  'javascript': langJavascript,
  'js': langJavascript,
  'node': langJavascript,
  'json': langJson,
  'kotlin': langKotlin,
  'kt': langKotlin,
  'markdown': langMarkdown,
  'md': langMarkdown,
  'php': langPhp,
  'py': langPython,
  'python': langPython,
  'python3': langPython,
  'rb': langRuby,
  'ruby': langRuby,
  'rs': langRust,
  'rust': langRust,
  'sql': langSql,
  'swift': langSwift,
  'ts': langTypescript,
  'typescript': langTypescript,
  'xml': langXml,
  'yaml': langYaml,
  'yml': langYaml,
};

/// One shared engine — registering the grammars per widget would re-compile
/// every mode on each build.
final Highlight codeHighlight = () {
  final engine = Highlight();
  engine.registerLanguages(codeLanguages);
  return engine;
}();

/// Whether [language] has a grammar registered, matched case-insensitively.
bool hasHighlighting(String? language) =>
    codeLanguages.containsKey((language ?? '').toLowerCase());
