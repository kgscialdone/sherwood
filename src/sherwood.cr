require "./bytecode"
require "./util"

class Sherwood
  VERSION = "0.1.0"
  module Types
    alias SWAny = Nil | SWNum | Bool | String | Array(SWAny)
    alias SWNum = SWInt | SWFlt
    alias SWInt = Byte | Int32 | Int64 | UInt32 | UInt64
    alias SWFlt = Float32 | Float64
  end

  def initialize(@stdin : IO = STDIN, @stdout : IO = STDOUT)
  end

  # Runs a set of bytecode.
  def runBytecode(prog : IO); return runBytecode(prog.each_byte.to_a) end
  def runBytecode(*prog : Byte); return runBytecode(prog) end
  def runBytecode(prog : Array(Byte)); return runBytecode(Bytecode.new(prog)) end
  def runBytecode(prog : Bytecode)
    insp  = 0
    stack = [] of SWAny

    while op = prog[insp]?; case op.opcd
      # SECTION: Literals
      when 0x00 then stack.push(nil)
      when 0x01 then stack.push(op.data[0])
      when 0x02 then stack.push(op.data[0] > 0)
      when 0x03 then stack.push(op.data.map(&.to_i32).bitwiseConcat)
      when 0x04 then stack.push(op.data.map(&.to_i64).bitwiseConcat)
      when 0x05 then stack.push(op.data.map(&.to_u32).bitwiseConcat)
      when 0x06 then stack.push(op.data.map(&.to_u64).bitwiseConcat)
      when 0x07 then stack.push(Float32.fromBytes(op.data))
      when 0x08 then stack.push(Float64.fromBytes(op.data))
      when 0x09 then stack.push(op.data.skip(4).map(&.chr).sum(""))
      when 0x0a then 
        (size = op.data.map(&.to_u32).bitwiseConcat) > 0 &&
          stack.push(Array(SWAny).new(size) { stack.pop }) ||
          stack.push([] of SWAny)
        
      # SECTION: Type Queries
      when 0x10 then stack.push(stack.last.nil?)
      when 0x11 then stack.push(stack.last.is_a?(Byte))
      when 0x12 then stack.push(stack.last.is_a?(Bool))
      when 0x13 then stack.push(stack.last.is_a?(Int32))
      when 0x14 then stack.push(stack.last.is_a?(Int64))
      when 0x15 then stack.push(stack.last.is_a?(UInt32))
      when 0x16 then stack.push(stack.last.is_a?(UInt64))
      when 0x17 then stack.push(stack.last.is_a?(Float32))
      when 0x18 then stack.push(stack.last.is_a?(Float64))
      when 0x19 then stack.push(stack.last.is_a?(String))
      when 0x1a then stack.push(stack.last.is_a?(Array))

      # SECTION: Stack Operations
      when 0x20 then stack.pop()
      when 0x21 then stack.push(stack.last)
      when 0x22 then stack.push(stack.pop(), stack.pop())
        
      # SECTION: Arithmetic Operations
      when 0x30 then stack.push(popType(SWNum, stack) + popType(SWNum, stack))
      when 0x31 then stack.push((b = popType(SWNum, stack); popType(SWNum, stack)) - b)
      when 0x32 then stack.push(popType(SWNum, stack) * popType(SWNum, stack))
      when 0x33 then stack.push((b = popType(SWNum, stack); popType(SWNum, stack)) / b)
      when 0x34 then stack.push((b = popType(SWInt, stack); popType(SWInt, stack)) % b)
      when 0x35 then stack.push((b = popType(SWInt, stack); popType(SWInt, stack)) << b)
      when 0x36 then stack.push((b = popType(SWInt, stack); popType(SWInt, stack)) >> b)
      when 0x37 then
        checkType(SWInt, stack) &&
          stack.push(~popType(SWInt, stack)) ||
          stack.push(!popType(Bool, stack))
      when 0x38 then
        checkType(SWInt, stack) &&
          stack.push(popType(SWInt, stack) & popType(SWInt, stack)) ||
          stack.push(popType(Bool, stack) && popType(Bool, stack))
      when 0x39 then
        checkType(SWInt, stack) &&
          stack.push(popType(SWInt, stack) | popType(SWInt, stack)) ||
          stack.push(popType(Bool, stack) || popType(Bool, stack))
      when 0x3a then 
        stack.push(popType(SWInt, stack) ^ popType(SWInt, stack))

      # SECTION: Comparison Operations
      when 0x40 then stack.push(stack[-1] == stack[-2])
      when 0x41 then stack.push(stack[-1] != stack[-2])
      when 0x42 then stack.push(peekType(SWNum, stack, -2) >  peekType(SWNum, stack))
      when 0x43 then stack.push(peekType(SWNum, stack, -2) >= peekType(SWNum, stack))
      when 0x44 then stack.push(peekType(SWNum, stack, -2) <  peekType(SWNum, stack))
      when 0x45 then stack.push(peekType(SWNum, stack, -2) <= peekType(SWNum, stack))

      # SECTION: IO Operations
      when 0x50 then stack.push((@stdin.as(IO::FileDescriptor).raw &.read_char rescue @stdin.read_char).try(&.ord))
      when 0x51 then stack.push(@stdin.gets)
      when 0x52 then @stdout.print popType(SWInt, stack).chr
      when 0x53 then @stdout.print popType(String, stack)

      # TODO: Variable Operations
      # TODO: Control Flow
      when 0x70 then insp -= popType(SWInt, stack)
      when 0x71 then
        if popType(Bool, stack)
          popType(SWInt, stack)
        end
        
      when 0x72 then
        insp = popType(SWInt, stack)

      else raise "Encountered undefined opcode 0x#{op.opcd.to_s(16).rjust(2,'0')}"
      end

      {% if flag?(:stack) %} puts "    0x#{op.opcd.to_s(16).rjust(2,'0')} #{stack}" {% end %}
      insp += 1
    end

    return stack
  end

  # Pops a value of the given type from the stack or throws a type error on failure.
  private macro popType(typ, stack)
    checkType({{typ}}, {{stack}}) ? stack.pop.as({{typ}})
      : raise "Type error: Expected #{{{typ}}}, got #{stack.pop.class}"
  end

  # Peeks a value of the given type from the stack or throws a type error on failure.
  private macro peekType(typ, stack, pos = -1)
    checkType({{typ}}, {{stack}}, {{pos}}) ? stack[{{pos}}].as({{typ}}) 
      : raise "Type error: Expected #{{{typ}}}, got #{stack.pop.class}"
  end

  # Checks the type of the top of the stack and returns true if it matches.
  private macro checkType(typ, stack, pos = -1)
    {{stack}}[{{pos}}].is_a?({{typ}})
  end
end

# Sherwood.new.runBytecode File.open(ARGV[0])
