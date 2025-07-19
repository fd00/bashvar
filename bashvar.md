# Coding Agent Implementation Spec: `bashvar` Gem

## 1. Project Overview

`bashvar` is a small Ruby library that parses the output produced by running the following Bash snippet:

```bash
compgen -v | while read -r var; do declare -p "$var" 2>/dev/null; done
```

The library exposes a single public entrypoint class ` with a **class method **`. The `input` argument is a `String` containing one or more lines of `declare -p` output. The method returns a **Ruby **``**) → Ruby object (scalar **``**, **``**)** depending on the Bash variable attributes present in the `declare` flags.

Goal: Provide a robust, dependency‑free way to marshal Bash variables into Ruby data structures.

---

## 2. Supported Bash Declarations → Ruby Types

| Bash Flags                                          | Example `declare -p` line             | Ruby Value Type                        | Notes                                                                                      |
| --------------------------------------------------- | ------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------ |
| `--` (none), `-x`, `-r`, combos w/out `a`, `A`, `i` | `declare -- HOME="/home/u"`           | `String`                               | Attribute flags ignored for value type. Export/readonly not preserved.                     |
| `-i`                                                | `declare -i COUNT="42"`               | `Integer` (if parseable) else `String` | Numeric conversion best‑effort via `Integer()`; fallback to raw decoded string.            |
| `-a`                                                | `declare -a LIST='([0]="a" [1]="b")'` | `Array<String>`                        | Indices respected; assigning to `result[index] = value` (Ruby auto-expands & fills `nil`). |
| `-A`                                                | `declare -A MAP='([k]="v" [x]="y")'`  | `Hash<String,String>`                  | Keys preserved as strings exactly as given inside brackets.                                |

### Escapes / Special Characters

Double‑quoted values emitted by `declare -p` may contain backslash escapes (e.g., `\n`, `\t`, `\"`, `\\`). These must be decoded to their actual characters in the returned Ruby value. See §5.

### Multi‑line Logical Values

`declare -p` emits each variable on **one physical output line**; however, the value *content* may include embedded newlines represented as escape sequences. After decoding, returned Ruby strings may contain actual "\n" line breaks.

---

## 3. Non‑Goals / Out‑of‑Scope (Initial Version)

- Do **not** preserve attribute metadata (export, readonly, nameref, etc.). Only value typing.
- Do **not** attempt to resolve `nameref` (`-n`) targets.
- Do **not** evaluate arithmetic expressions beyond what Bash already evaluated in the `declare -p` output. (E.g., if user ran `declare -i X=1+2`, `declare -p` will show resolved value; parse that.)
- Do **not** parse function definitions (input stream should be only `declare -p` lines; see §10 defensive parsing).

---

## 4. Public API

```ruby
class BashVar
  # Parse a string of one-or-more Bash `declare -p` lines into a Ruby Hash.
  #
  # @param input [String] Multi-line string containing the raw output of
  #   `compgen -v | while read -r var; do declare -p "$var"; done`.
  # @return [Hash{String => (String, Integer, Array, Hash)}]
  #   Variable name mapped to decoded Ruby value.
  #
  # Type mapping rules:
  #   -a  -> Array
  #   -A  -> Hash
  #   -i  -> Integer (fallback String)
  #   else -> String
  #
  def self.parse(input)
    ...
  end
end
```

### Error Handling

- Method **must never raise** on malformed lines; skip unparseable entries.
- Recoverable parse anomalies (e.g., unknown escape `\\z`) → leave literal `z` w/o backslash.
- Return empty `{}` if `input.nil?` or blank.

---

## 5. Escape Decoding Rules

Implement a helper that converts Bash `declare -p` backslash escapes within **double‑quoted** (`"..."`) and **ANSI-C quoted** (`$'...'`) strings into real characters.

Decode these sequences:

| Escape | Char            |
| ------ | --------------- |
| `\\n`   | newline ("\n")  |
| `\\r`   | carriage return |
| `\\t`   | tab             |
| `\\v`   | vertical tab    |
| `\\f`   | form feed       |
| `\\b`   | backspace       |
| `\\a`   | bell            |
| `\\\\`   | backslash       |
| `\\"`   | double quote    |

Fallback: `\\X` → `X` (drop backslash) for any other single char `X`.

**ANSI-C Quoted** strings (`$'...'`) are decoded using the rules above.

**Single‑quoted** strings are taken verbatim (contents between quotes, no escape decoding except strip outer quotes).

**Unquoted** values: return literal raw string (after strip); no unescaping.

---

## 6. Parsing Array / Assoc Array Bodies

`declare -p` for arrays uses a Bash-ish repr inside single quotes:

```bash
declare -a LIST='([0]="foo" [1]="bar" [5]="baz")'
# body: ([0]="foo" [1]="bar" [5]="baz")

declare -A MAP='([key1]="val1" [key two]="val 2")'
```

### Steps

1. Strip leading/trailing quotes around the full raw_value.
2. Confirm it starts with `(` and ends with `)`; empty `()` → return `[]` or `{}`.
3. Tokenize repeated pattern: `[KEY]=VALUE`
   - `KEY` = any run of characters up to closing `]` (do *not* unescape inside KEY; pass literally, then strip surrounding quotes if any were inserted—in practice, `declare -p` prints keys w/o quoting unless whitespace, but handle `'...'` & `"..."`).
   - `VALUE` = one shell word: either double‑quoted, single‑quoted, or bare.
4. For `-a` (indexed array): interpret `KEY.to_i` as index. Assign: `ary[index] = decoded_value`. This will auto‑fill `nil` gaps if indices skip.
5. For `-A` (assoc): use decoded KEY string as-is: `h[key] = decoded_value`.

### Tokenization Regex Suggestion

A tolerant scan is sufficient:

```ruby
pairs = body.scan(/\[([^\]]*)\]=((?:\"(?:\\.|[^\"])*\")|(?:'(?:\\.|[^'])*')|[^\s)]+)/)
```

- Captures KEY in group 1.
- Captures VALUE in group 2 (quoted or bare token).
- Stops at whitespace or `)` boundary.

After capture, feed VALUE through same scalar parser used for top-level scalars.

---

## 7. Integer Parsing (`-i`)

- After scalar decode, attempt `Integer(value, 10)`.
- If conversion fails (raises `ArgumentError`), return decoded string unchanged.
- Accept leading `+`/`-`; whitespace trimmed.

---

## 8. Robustness Requirements

- Ignore leading/trailing whitespace around lines.
- Support combined flags (e.g., `-xi`, `-irx`, etc.) — detect presence via `flags.include?("i")` etc.
- Lines missing `name=` pattern → skip.
- Lines beginning `declare -f` or `declare -F` (functions) → skip.
- Unknown flags → ignore.

---

## 9. Performance Expectations

- Input size typically small (<5k vars) but parser should be linear in number of lines.
- Avoid heavy backtracking regex; prefer single pass per line.
- No external gem dependencies.

---

## 10. Line Grammar to Match

Target lines generally resemble:

```
declare -xr PATH="/usr/bin"
declare -- HOME="/home/u"
declare -i COUNT="42"
declare -a LIST='([0]="foo" [1]="bar")'
declare -A MAP='([k]="v" [z]="w")'
```

Use this top-level regex skeleton (safe match):

```ruby
/^declare\s+(-[A-Za-z]+)?\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$/
```

Group 1 = flags (optional)
Group 2 = var name
Group 3 = raw value (rest of line)

> Do not assume there's exactly one space between tokens; use `\s+`.

---

## 11. Implementation Sketch

```ruby
class BashVar
  class << self
    def parse(input)
      return {} if input.nil? || input.strip.empty?

      vars = {}
      input.each_line do |line|
        line = line.strip
        next unless line.start_with?("declare")
        m = line.match(/^declare\s+(-[A-Za-z]+)?\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$/)
        next unless m

        flags = m[1] || ""
        name  = m[2]
        raw   = m[3]

        # skip functions explicitly
        next if flags.include?("f") && !flags.match?(/-[^A-Za-z]*[ai]/) # crude but protects `declare -f`

        value = case
                when flags.include?("a") || flags.include?("A")
                  parse_array_like(raw, assoc: flags.include?("A"))
                when flags.include?("i")
                  parse_integer(raw)
                else
                  parse_scalar(raw)
                end

        vars[name] = value
      end
      vars
    end

    private

    def parse_scalar(raw)
      raw = raw.strip
      if raw.start_with?("$'"') && raw.end_with?("'"')
        # ANSI-C Quoting
        decode_dquoted(raw[2..-2])
      elsif raw.start_with?('"') && raw.end_with?('"')
        # Double-quoted
        decode_dquoted(raw[1..-2])
      elsif raw.start_with?("'"') && raw.end_with?("'"')
        # Single-quoted
        raw[1..-2]
      else
        # Unquoted
        raw
      end
    end

    def parse_integer(raw)
      v = parse_scalar(raw)
      begin
        Integer(v, 10)
      rescue ArgumentError, TypeError
        v
      end
    end

    def parse_array_like(raw, assoc: false)
      s = raw.strip
      # expect quoted wrapper; tolerate missing quotes
      if (s.start_with?("'"') && s.end_with?("'"')) || (s.start_with?('"') && s.end_with?('"'))
        s = s[1..-2]
      end
      s = s.strip
      return(assoc ? {} : []) unless s.start_with?("(") && s.end_with?(" )") || s.end_with?(")")

      # trim parens
      s = s[1..-2].strip

      result = assoc ? {} : []

      # scan pairs
      s.scan(/\[([^\]]*)\]=((?:\"(?:\\.|[^\"])*\")|(?:'(?:\\.|[^'])*')|[^\s)]+)/) do |k, v|
        key_str = parse_scalar(k.strip.gsub(/^\"|\"$/, '').gsub(/^'|'$/, '')) # keys seldom quoted; defensive
        val_str = parse_scalar(v)
        if assoc
          result[key_str] = val_str
        else
          idx = key_str.to_i
          result[idx] = val_str
        end
      end
      result
    end

    ESCAPE_MAP = {
      'n' => "\n", 'r' => "\r", 't' => "\t", 'v' => "\v", 'f' => "\f", 'b' => "\b", 'a' => "\a", '\\' => "\\", '"' => '"'
    }.freeze

    def decode_dquoted(str)
      str.gsub(/\\(.)/) { ESCAPE_MAP[$1] || $1 }
    end
  end
end
```

> **NOTE:** The above is a sketch; the Coding Agent should refine regex boundaries, whitespace tolerance, and key quoting logic. Add unit tests first (TDD recommended).

---

## 12. Test Matrix (RSpec Suggested)

Create `spec/bashvar_spec.rb` with the scenarios below. Use `RSpec.describe BashVar do ... end`.

### 12.1 Basic Scalar

Input:

```
declare -- NAME="hello"
```

Expect: `{"NAME"=>"hello"}`

### 12.2 Integer OK

```
declare -i COUNT="42"
```

Expect: `{"COUNT"=>42}`

### 12.3 Integer Fallback (non-numeric)

```
declare -i FAILSAFE="notnum"
```

Expect: `{"FAILSAFE"=>"notnum"}`

### 12.4 Indexed Array Sequential

```
declare -a LIST='([0]="a" [1]="b")'
```

Expect: `{"LIST"=>["a","b"]}`

### 12.5 Indexed Array Sparse

```
declare -a SPARSE='([2]="x" [5]="y")'
```

Expect: `{"SPARSE"=>[nil,nil,"x",nil,nil,"y"]}`

### 12.6 Assoc Array

```
declare -A MAP='([k]="v" [x]="y")'
```

Expect: `{"MAP"=>{"k"=>"v","x"=>"y"}}`

### 12.7 Escapes & Newlines

```
declare -- MULTI="line1\nline2\tindent\"quote\""
```

Expect value with actual newline and tab, and embedded quotes.

### 12.8 Mixed Input Multi-line

Combine all above in one input string; ensure parser accumulates all.

### 12.9 Ignore Functions

Ensure lines like `declare -f myfunc` are skipped.

### 12.10 Ignore Garbage

Random lines that don’t match grammar are ignored; parser should not raise.

### 12.11 ANSI-C Quoted String

Input:
```
declare -- ANSI_C_STRING=$'line1\nline2\tindent'
```

Expect: `{"ANSI_C_STRING" => "line1\nline2\tindent"}`

---

## 13. Gem Packaging Requirements

### 13.1 `bashvar.gemspec`

Include:

- name: `bashvar`
- summary: "Parse Bash declare -p output into Ruby data structures"
- description: longer text
- authors placeholder
- email placeholder
- version from `lib/bashvar/version.rb`
- required_ruby_version ">= 2.6"
- license: MIT
- files via `git ls-files -z` or `Dir.glob`.

### 13.2 `lib/bashvar/version.rb`

```ruby
class BashVar
  VERSION = "0.1.0"
end
```

### 13.3 `lib/bashvar.rb`

(Full class implementation from §11.)

---

## 14. Namespacing Guidance

To align gem name (`bashvar`) with Ruby constant style:

- Top-level module & Public class: `BashVar` (entrypoint requested by user).
- Users can:
  ```ruby
  require 'bashvar'
  BashVar.parse(str)
  ```

---

## 15. README.md Template (generate)

Should include:

- What problem it solves
- Install steps (`gem install bashvar` / Gemfile)
- Minimal usage example
- Bash snippet to produce input
- Supported types table
- Limitations / roadmap

---

## 16. Rake Tasks

Provide default Rakefile that loads Bundler::GemTasks so `rake build`, `rake install`, `rake release` work.

---

## 17. Lint & Style

- Use frozen string literal magic comment.
- RuboCop optional (do not enforce unless configured).
- 100 char line length soft.

---

## 18. Deliverables Checklist for Coding Agent

-

---

## 19. Example End-to-End Usage Snippet (README excerpt)

```bash
# capture bash vars into a file
echo "$(compgen -v | while read -r v; do declare -p "$v" 2>/dev/null; done)" > /tmp/bash_vars.txt
```

```ruby
require "bashvar"
input = File.read("/tmp/bash_vars.txt")
vars  = BashVar.parse(input)
puts vars["HOME"]
puts vars["PATH"]
pp vars["LIST"] if vars.key?("LIST")
```

---

### Final Notes to Coding Agent

- Please implement with **unit tests first** where practical.
- Parser should favor **forgiving** behavior: skip or fallback, never crash.
- Keep runtime deps zero.
- Provide internal docstrings / YARD tags.

> When done, ensure `bundle exec rspec` passes and `gem build` succeeds without warnings.

---

End of spec.
