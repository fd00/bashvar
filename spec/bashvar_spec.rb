# frozen_string_literal: true

require 'bashvar'

RSpec.describe BashVar do
  describe '.parse' do
    # 12.1 Basic Scalar
    it 'parses a basic scalar variable' do
      input = 'declare -- NAME="hello"'
      expect(BashVar.parse(input)).to eq({ 'NAME' => 'hello' })
    end

    # 12.2 Integer OK
    it 'parses an integer variable' do
      input = 'declare -i COUNT="42"'
      expect(BashVar.parse(input)).to eq({ 'COUNT' => 42 })
    end

    # 12.3 Integer Fallback (non-numeric)
    it 'falls back to string for non-numeric integer variables' do
      input = 'declare -i FAILSAFE="notnum"'
      expect(BashVar.parse(input)).to eq({ 'FAILSAFE' => 'notnum' })
    end

    # 12.4 Indexed Array Sequential
    it 'parses a sequential indexed array' do
      input = "declare -a LIST='([0]=\"a\" [1]=\"b\")'"
      expect(BashVar.parse(input)).to eq({ 'LIST' => %w[a b] })
    end

    # 12.5 Indexed Array Sparse
    it 'parses a sparse indexed array' do
      input = "declare -a SPARSE='([2]=\"x\" [5]=\"y\")'"
      expect(BashVar.parse(input)).to eq({ 'SPARSE' => [nil, nil, 'x', nil, nil, 'y'] })
    end

    # 12.6 Assoc Array
    it 'parses an associative array' do
      input = "declare -A MAP='([k]=\"v\" [x]=\"y\")'"
      expect(BashVar.parse(input)).to eq({ 'MAP' => { 'k' => 'v', 'x' => 'y' } })
    end

    # 12.7 Escapes & Newlines
    it 'decodes escaped characters and newlines' do
      input = 'declare -- MULTI="line1\\nline2\\tindent\"quote\""'
      expect(BashVar.parse(input)).to eq({ 'MULTI' => "line1\nline2\tindent\"quote\"" })
    end

    # 12.8 Mixed Input Multi-line
    it 'parses mixed input with multiple lines' do
      input = <<~BASH
        declare -- NAME="hello"
        declare -i COUNT="42"
        declare -a LIST='([0]="a" [1]="b")'
      BASH
      expected = {
        'NAME' => 'hello',
        'COUNT' => 42,
        'LIST' => %w[a b]
      }
      expect(BashVar.parse(input)).to eq(expected)
    end

    # 12.9 Ignore Functions
    it 'ignores function declarations' do
      input = 'declare -f myfunc'
      expect(BashVar.parse(input)).to eq({})
    end

    # 12.10 Ignore Garbage
    it 'ignores garbage lines' do
      input = 'this is not a declare line'
      expect(BashVar.parse(input)).to eq({})
    end

    # 12.11 ANSI-C Quoted String
    it 'parses ANSI-C quoted strings' do
      input = "declare -- ANSI_C_STRING=$'line1\\nline2\\tindent'"
      expect(BashVar.parse(input)).to eq({ 'ANSI_C_STRING' => "line1\nline2\tindent" })
    end

    # Error Handling: Return empty hash for nil or blank input
    it 'returns an empty hash for nil input' do
      expect(BashVar.parse(nil)).to eq({})
    end

    it 'returns an empty hash for blank input' do
      expect(BashVar.parse("\n\t ")).to eq({})
    end
  end
end
