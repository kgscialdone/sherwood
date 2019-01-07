require "spec"
require "../src/sherwood.cr"
include Sherwood

macro opcode(name, expected, *bytes, &block)
  describe {{name}} do
    it "" do
      bytes = {{bytes}}
      bytes = if bytes.is_a?(Tuple(Array(Byte))); bytes.first.map(&.to_u8) else bytes.to_a.map(&.to_u8) end
      result = Sherwood.runBytecode(bytes.to_a.map(&.to_u8))
      result.should eq({{expected}})
      {{block && block.body}}
    end
  end
end

macro withStdin(str, &block)
  Sherwood.stdin = IO::Memory.new({{str}})
  {{block.body}}
  Sherwood.stdin.close
  Sherwood.stdin = STDIN
end

macro withStdout(&block)
  Sherwood.stdout = IO::Memory.new()
  {{block.body}}
  Sherwood.stdout.close
  Sherwood.stdout = STDOUT
end

Spec.override_default_formatter(SherwoodFormatter.new)
class SherwoodFormatter < Spec::Formatter
  @indent = 0

  def pop; @indent -= 1 end
  def push(context)
    {% unless flag?(:stack) %}
      if @indent > 0; @io.print "  "*@indent + context.description + " : "
      else            @io.puts  "  "*@indent + context.description + " : " end
    {% else %}
      @io.puts "  "*@indent + context.description
    {% end %}

    @io.flush
    @indent += 1
  end

  def report(result)
    {% unless flag?(:stack) %} @io.puts Spec.color(result.kind.to_s.capitalize, result.kind)
    {% else %}                 @io.puts "    " + Spec.color(result.kind.to_s.capitalize, result.kind).to_s 
    {% end %}
  end

  def print_results(elapsed_time, aborted)
    Spec::RootContext.print_results(elapsed_time, aborted)
  end
end
