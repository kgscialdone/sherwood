require "spec"
require "../src/sherwood.cr"
include Sherwood::Types

macro opcode(name, expected, *bytes, stdin = "", stdout = "", &block)
  describe {{name}} do
    it "" do
      withIO(IO::Memory.new(), IO::Memory.new({{stdin}})) {|stdout, stdin|
        result = Sherwood.new(stdin, stdout).runBytecode({{bytes}}.to_a.flatten.map(&.to_u8))
        result.stack.should eq({{expected}})
        stdout.rewind.to_s.should eq({{stdout}})
        {{block && block.body}}
      }
    end
  end
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
