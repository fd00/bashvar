# bashvar

`bashvar` is a small Ruby library that parses the output produced by running the following Bash snippet:

```bash
compgen -v | while read -r var; do declare -p "$var" 2>/dev/null; done
```

It provides a robust, dependency-free way to marshal Bash variables into Ruby data structures.

## Project Origin

This library was initially scaffolded with assistance from Google Gemini CLI. All code has been reviewed and modified by human contributors. See LICENSE (MIT) for terms.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bashvar'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install bashvar
```

## Usage

First, capture your Bash variables into a file (e.g., `/tmp/bash_vars.txt`):

```bash
echo "$(compgen -v | while read -r v; do declare -p "$v" 2>/dev/null; done)" > /tmp/bash_vars.txt
```

Then, parse them in Ruby:

```ruby
require "bashvar"

input = File.read("/tmp/bash_vars.txt")
vars  = BashVar.parse(input)

puts vars["HOME"]
puts vars["PATH"]

# Example for array/hash variables
require 'pp' # For pretty printing
pp vars["LIST"] if vars.key?("LIST")
pp vars["MAP"] if vars.key?("MAP")
```

## Supported Bash Declarations → Ruby Types

| Bash Flags                                          | Example `declare -p` line             | Ruby Value Type                        | Notes                                                                                      |
| --------------------------------------------------- | ------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------ |
| `--` (none), `-x`, `-r`, combos w/out `a`, `A`, `i` | `declare -- HOME="/home/u"`           | `String`                               | Attribute flags ignored for value type. Export/readonly not preserved.                     |
| `-i`                                                | `declare -i COUNT="42"`               | `Integer` (if parseable) else `String` | Numeric conversion best‑effort via `Integer()`; fallback to raw decoded string.            |
| `-a`                                                | `declare -a LIST='([0]="a" [1]="b")'` | `Array<String>`                        | Indices respected; assigning to `result[index] = value` (Ruby auto-expands & fills `nil`). |
| `-A`                                                | `declare -A MAP='([k]="v" [x]="y")'`  | `Hash<String,String>`                  | Keys preserved as strings exactly as given inside brackets.                                |

### Escapes / Special Characters

Double‑quoted values and ANSI-C quoted (`$'...'`) values emitted by `declare -p` may contain backslash escapes (e.g., `\n`, `\t`, `\"`, `\\`). These are decoded to their actual characters in the returned Ruby value.

## Limitations

- Does not preserve attribute metadata (export, readonly, nameref, etc.). Only value typing.
- Does not attempt to resolve `nameref` (`-n`) targets.
- Does not evaluate arithmetic expressions beyond what Bash already evaluated in the `declare -p` output.
- Does not parse function definitions.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/fd00/bashvar](https://github.com/fd00/bashvar).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

```
