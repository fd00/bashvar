# frozen_string_literal: true

require_relative 'bashvar/version'

class BashVar
  class << self
    def parse(input)
      return {} if input.nil? || input.strip.empty?

      vars = {}
      input.each_line do |line|
        line = line.strip

        # Main regex for parsing declare lines
        m = line.match(/^declare\s+(-[A-Za-z\-]+)?\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$/)
        next unless m

        flags = m[1] || ''
        name  = m[2]
        raw   = m[3]

        # skip functions explicitly
        next if flags.include?('f') && !flags.match?(/-[^A-Za-z]*[ai]/) # crude but protects `declare -f`

        value = if flags.include?('a') || flags.include?('A')
                  parse_array_like(raw, assoc: flags.include?('A'))
                elsif flags.include?('i')
                  parse_integer(raw)
                else
                  parse_scalar(raw)
                end

        vars[name] = value
      end
      vars
    end

    ESCAPE_MAP = {
      'n' => "\n", 'r' => "\r", 't' => "\t", 'v' => "\v", 'f' => "\f", 'b' => "\b", 'a' => "\a", '\\' => '\\', '"' => '"'
    }.freeze

    private_constant :ESCAPE_MAP

    private

    def parse_scalar(raw)
      raw = raw.strip
      if raw.start_with?("$'") && raw.end_with?("'") # ANSI-C Quoting
        decode_bash_escapes(raw[2..-2])
      elsif raw.start_with?('"') && raw.end_with?('"') # Double-quoted
        decode_bash_escapes(raw[1..-2])
      elsif raw.start_with?("'") && raw.end_with?("'") # Single-quoted
        raw[1..-2]
      else # Unquoted
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
      # Corrected string comparisons for quotes
      s = s[1..-2] if (s.start_with?("'") && s.end_with?("'")) || (s.start_with?('"') && s.end_with?('"'))
      s = s.strip
      # Corrected: Removed parentheses around return value, and fixed the logical grouping
      return assoc ? {} : [] unless s.start_with?('(') && s.end_with?(' )', ')')

      # trim parens
      s = s[1..-2].strip

      result = assoc ? {} : []

      # scan pairs
      # Corrected regex: proper escaping for quotes and backslashes
      s.scan(/\[([^\]]*)\]=("(?:\\.|[^"])*"|'(?:\\.|[^'])*'|[^\s)]+)/) do |k, v|
        # Corrected gsub for keys: use correct Ruby string literal syntax
        key_str = parse_scalar(k.strip.gsub(/^"|"$/, '').gsub(/^'|'$/, '')) # keys seldom quoted; defensive
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

    def decode_bash_escapes(str)
      str.gsub(/\\(.)/) { ESCAPE_MAP[::Regexp.last_match(1)] || ::Regexp.last_match(1) }
    end
  end
end
