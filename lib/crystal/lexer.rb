require 'strscan'

module Crystal
  class Lexer < StringScanner
    def initialize(str)
      super
      @token = Token.new
      @line_number = 1
      @column_number = 1
    end

    def next_token
      @token.value = nil
      @token.line_number = @line_number
      @token.column_number = @column_number

      if eos?
        @token.type = :EOF
      elsif scan /\n/
        @token.type = :NEWLINE
        @line_number += 1
        @column_number = 1
      elsif scan /[^\S\n]+/
        @token.type = :SPACE
      elsif scan /;+/
        @token.type = :";"
      elsif match = scan(/(\+|-)?\d+\.\d+/)
        @token.type = :FLOAT
        @token.value = match
      elsif match = scan(/(\+|-)?\d+/)
        if scan(/L/)
          @token.type = :LONG
          @token.value = match
        else
          @token.type = :INT
          @token.value = match
        end
      elsif match = scan(/'\\n'/)
        @token.type = :CHAR
        @token.value = ?\n.ord
      elsif match = scan(/'\\t'/)
        @token.type = :CHAR
        @token.value = ?\t.ord
      elsif match = scan(/'\\0'/)
        @token.type = :CHAR
        @token.value = ?\0.ord
      elsif match = scan(/'.'/)
        @token.type = :CHAR
        @token.value = match[1 .. -2].ord
      elsif match = scan(/"[^\\#\n]*?"/)
        @token.type = :STRING
        @token.value = match[1 .. -2]
      elsif match = scan(/"/)
        @token.type = :STRING_START
      elsif match = scan(/:[a-zA-Z_][a-zA-Z_0-9]*/)
        @token.type = :SYMBOL
        @token.value = match[1 .. -1]
      elsif match = scan(/\%w\(/)
        @token.type = :STRING_ARRAY_START
      elsif match = scan(%r(!=|!|==|=|<<=|<<|<=|<|>>=|>>|>=|>|\+@|\+=|\+|-@|-=|-|\*=|\*\*=|\*\*|\*|/=|%=|&=|\|=|\^=|/|\(|\)|,|\.\.\.|\.\.|\.|&&|&|\|\||\||\{|\}|\?|::|:|%|\^|~@|~|\[\]\=|\[\]|\[|\]))
        @token.type = match.to_sym
      elsif match = scan(/(def|do|elsif|else|end|if|true|false|class|module|include|while|nil|yield|return|unless|next|break|begin|lib|fun|type|struct)((\?|!)|\b)/)
        @token.type = :IDENT
        @token.value = match.end_with?('?') || match.end_with?('!') ? match : match.to_sym
      elsif match = scan(/[A-Z][a-zA-Z_0-9]*/)
        @token.type = :CONST
        @token.value = match
      elsif match = scan(/[a-zA-Z_][a-zA-Z_0-9]*(\?|!)?/)
        @token.type = :IDENT
        @token.value = match
      elsif match = scan(/@[a-zA-Z_][a-zA-Z_0-9]*/)
        @token.type = :INSTANCE_VAR
        @token.value = match
      elsif scan /#/
        if scan /.*\n/
          @token.type = :NEWLINE
          @line_number += 1
          @column_number = 1
        else
          scan /.*/
          @token.type = :EOF
        end
      else
        raise "unknown token: #{rest}"
      end

      @token
    end

    def next_string_token
      @token.value = nil
      @token.line_number = @line_number
      @token.column_number = @column_number

      if eos?
        @token.type = :EOF
      elsif scan(/"/)
        @token.type = :STRING_END
      elsif scan(/\n/)
        @line_number += 1
        @column_number = 1
        @token.value = "\n"
      elsif scan(/\\n/)
        @token.type = :STRING
        @token.value = "\n"
      elsif scan(/\\"/)
        @token.type = :STRING
        @token.value = '"'
      elsif scan(/\\t/)
        @token.type = :STRING
        @token.value = "\t"
      elsif scan(/\\/)
        @token.type = :STRING
        @token.value = "\\"
      elsif scan(/\#{/)
        @token.type = :INTERPOLATION_START
      elsif scan(/\#/)
        @token.type = :STRING
        @token.value = '#'
      elsif match = scan(/[^"\\\#\n]+/)
        @token.type = :STRING
        @token.value = match
      end

      @token
    end

    def next_string_array_token
      @token.value = nil
      @token.line_number = @line_number
      @token.column_number = @column_number

      if eos?
        @token.type = :EOF
      else
        while true
          if match = scan(/\n/)
            @line_number += 1
            @column_number = 1
          elsif scan /[^\S\n]+/
            next
          elsif match = scan(/\)/)
            @token.type = :STRING_ARRAY_END
            break
          else match = scan(/[^\s\)]+/)
            @token.type = :STRING
            @token.value = match
            break
          end
        end
      end

      @token
    end

    def scan(regex)
      if (match = super)
        @column_number += match.length
      end
      match
    end

    def next_token_skip_space
      next_token
      skip_space
    end

    def next_token_skip_space_or_newline
      next_token
      skip_space_or_newline
    end

    def next_token_skip_statement_end
      next_token
      skip_statement_end
    end

    def skip_space
      next_token_if :SPACE
    end

    def skip_space_or_newline
      next_token_if :SPACE, :NEWLINE
    end

    def skip_statement_end
      next_token_if :SPACE, :NEWLINE, :";"
    end

    def next_token_if(*types)
      next_token while types.include? @token.type
    end

    def raise(message)
      Kernel::raise Crystal::SyntaxException.new(message, @line_number, @token.column_number)
    end
  end
end
