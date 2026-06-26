# frozen_string_literal: true

require "rouge"

module Rouge
  module Lexers
    class SSDP < RegexLexer
      title "SSDP"
      desc "SSDP dump parser output"
      tag "ssdp"
      aliases "ssdp-output", "dumpdiff"

      FIELDS = %w[
        RAW INT_LE INT_BE NOT_LE NOT_BE BIN BIN_NOT NOT_RAW
      ].freeze

      # Token per data-file index: data01 → go (cyan), data02 → gd (magenta), 0 → ne (default)
      DATA_TOKENS = [
        Name::Exception,  # 0 - no data context
        Generic::Output,  # 1 - data01
        Generic::Deleted, # 2 - data02
      ].freeze

      option :fields, "comma-separated fields to color, e.g. RAW,INT_LE,NOT_RAW"

      def initialize(*)
        super
        requested = list_option(:fields) { FIELDS }
        @fields = requested.map(&:upcase) & FIELDS
        @data_idx = 0
      end

      def lex(code, *args, &b)
        @data_idx = 0
        if code.start_with?("#!fields=")
          directive, rest = code.split("\n", 2)
          @fields = directive[9..].split(",").map(&:strip).map(&:upcase) & FIELDS
          code = rest.to_s
        end
        super(code, *args, &b)
      end

      state :root do
        rule %r/^>\s+ssdp\b.*$/, Generic::Prompt
        rule %r/^Inputs:|^Diff blocks:|^File:|^Size:|^Range:/, Generic::Heading
        rule %r/^MIFARE:.*$/, Generic::Subheading

        rule %r/^\[BLOCK\].*$/, Generic::Strong
        rule %r/\[BLOCK\]/, Generic::Strong
        rule %r/^\s+\[MIFARE VALUE\].*$/, Generic::Inserted
        rule %r/^\s+\[units=\d+\]/, Generic::Subheading

        rule %r/^\s+!?\+\d+/, Name::Label
        rule %r/\[[[:xdigit:]]{2}(?:\s+[[:xdigit:]]{2})*\]/ do |m|
          tok = @data_idx > 0 ? (DATA_TOKENS[@data_idx] || Generic::Error) : Generic::Error
          token tok, m[0]
        end
        rule %r/\S*[~\/.]\S*/, Text

        rule %r/\b(data(\d*)):([ \t]*)([~\/]\S+)?/ do |m|
          @data_idx = m[2].empty? ? 0 : m[2].to_i
          tok = DATA_TOKENS[@data_idx] || DATA_TOKENS[0]
          token Name::Variable, "#{m[1]}:"
          token Text::Whitespace, m[3] unless m[3].to_s.empty?
          token tok, m[4] unless m[4].to_s.empty?
        end

        rule %r/\b(RAW|INT_LE|INT_BE|NOT_LE|NOT_BE|BIN|BIN_NOT|NOT_RAW)(=)(\s*)([^|\n]*[^\s|\n])?/ do |m|
          if @fields.include?(m[1])
            tok = DATA_TOKENS[@data_idx] || DATA_TOKENS[0]
            token tok, m[1]
            token tok, m[2]
            token Text::Whitespace, m[3] unless m[3].empty?
            token tok, m[4] unless m[4].to_s.empty?
          else
            token Text, m[0]
          end
        end

        rule %r/\b0x[0-9A-Fa-f]+\b/, Num::Hex
        rule %r/\b[0-9A-Fa-f]{2}(?: [0-9A-Fa-f]{2})+\b/, Num::Hex
        rule %r/\b(?:ID|S|B)=\d+\b/, Name::Attribute

        rule %r/\s+/, Text::Whitespace
        rule %r/./, Text
      end
    end

  end
end
