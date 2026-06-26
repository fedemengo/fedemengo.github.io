# frozen_string_literal: true

require "rouge"

module Rouge
  module Lexers
    class Proxmark3 < RegexLexer
      title "Proxmark3"
      desc "Proxmark3 client sessions"
      tag "pm3"
      aliases "proxmark3", "proxmark"

      state :root do
        rule %r/(\[)([^\]\s]+)(\]\s+pm3\s+--\>)/ do
          groups Generic::Prompt, Generic::Inserted, Generic::Prompt
          push :command
        end
        rule %r/^\[\+\]/, Generic::Inserted
        rule %r/^\[-\]/, Generic::Deleted
        rule %r/^\[!\]/, Generic::Error
        rule %r/^\[\?\]/, Generic::Heading
        rule %r/^\[=\]/, Generic::Subheading
        rule %r/`[^`]+`/, Str
        rule %r/\S*[~\/.]\S*/, Text
        rule %r/\b[0-9A-Fa-f]{13,}\b/, Text
        rule %r/\b[0-9A-Fa-f]{12}\b/, Num::Hex
        rule %r/\b[0-9A-Fa-f]{2}(?: [0-9A-Fa-f]{2})+\b/, Num::Hex
        rule %r/\s+/, Text::Whitespace
        rule %r/./, Text
      end

      state :command do
        rule %r/\r?\n/, Text::Whitespace, :pop!
        rule %r/\S*[~\/.]\S*/, Text
        rule %r/--[a-zA-Z0-9][\w-]*/, Name::Attribute
        rule %r/(\s+)(-[A-Za-z]\b)/ do
          groups Text::Whitespace, Name::Attribute
        end
        rule %r/(\s+)(hf|mf|rdbl|wrbl|dump|info|search|autopwn)(?=\s|$)/ do
          groups Text::Whitespace, Keyword
        end
        rule %r/\b[0-9A-Fa-f]{13,}\b/, Text
        rule %r/\b[0-9A-Fa-f]{12}\b/, Num::Hex
        rule %r/\b[0-9A-Fa-f]{2}(?: [0-9A-Fa-f]{2})+\b/, Num::Hex
        rule %r/\s+/, Text::Whitespace
        rule %r/./, Text
      end
    end
  end
end
