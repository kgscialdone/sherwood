require "./bytecode"
require "./util"

module Sherwood
  VERSION = "0.1.0"

  # Standard IO ports, abstracted out for ease of testing
  @@stdin  : IO = STDIN
  @@stdout : IO = STDOUT
  @@stderr : IO = STDERR
  def self.stdin= (@@stdin  : IO); end
  def self.stdout=(@@stdout : IO); end
  def self.stderr=(@@stderr : IO); end
  def self.stdin ; @@stdin  end
  def self.stdout; @@stdout end
  def self.stderr; @@stderr end

  # -- Bytecode instruction layout --
  #
  # SECTION: Literals
  #   Literals should be followed by n bytes of data to push as the given type.
  #   When encountered, the resulting value will be pushed to the stack.
  # = opcd name n =====================================================================================================================
  #   0x00 null 0
  #   0x01 byte 1
  #   0x02 bool 1
  #   0x03 i32  4
  #   0x04 i64  8
  #   0x05 u32  4
  #   0x06 u64  8
  #   0x07 f32  4
  #   0x08 f64  8
  #   0x09 str  (len:u32)+len
  # 
  # SECTION: Constructors
  #   In contrast to literals, constructors pop their initialization data from the stack like normal opcodes.
  #   When encountered, the resulting value will be pushed to the stack.
  # = opcd name (params) ==============================================================================================================
  #   0x10 list (len:int, members:any*len) -- Highest member on stack will be first in list. Errors if len < 0 or len > u32.
  #
  # SECTION: Stack Operations
  #   Base operations on the data stack itself.
  # = opcd name (params) ==============================================================================================================
  #   0x20 drop (v:any)        -- Removes the top of the stack.
  #   0x21 dupe (v:any)        -- Duplicates the top of the stack.
  #   0x22 swap (a:any, b:any) -- Swaps the top of the stack with the next value down.
  #
  # SECTION: Arithmetic Operations
  #   Basic and bitwise arithmetic operations.
  # = opcd name (params) ==============================================================================================================
  #   0x30 add  (a:int, b:int) -- Adds the two numbers on the top of the stack.
  #   0x31 sub  (a:int, b:int) -- Subtracts the number on the top of the stack from the number below it.
  #   0x32 mul  (a:int, b:int) -- Multiplies the two numbers on the top of the stack.
  #   0x33 div  (a:int, b:int) -- Divides the number on the top of the stack from the number below it.
  #   0x34 mod  (a:int, b:int) -- Gets the remainder of dividing the two numbers on the top of the stack.
  #   0x35 shl  (d:int, n:int) -- Shifts n left by d bits.
  #   0x36 shr  (d:int, n:int) -- Shifts n right by d bits.
  #   0x37 not  (a:int)        -- Bitwise NOT of a.
  #   0x38 and  (a:int, b:int) -- Bitwise AND of a and b.
  #   0x39 or   (a:int, b:int) -- Bitwise OR of a and b.
  #   0x3a xor  (a:int, b:int) -- Bitwise XOR of a and b.
  #
  # SECTION: IO Operations
  #   Basic IO interactions.
  # = opcd name (params) ==============================================================================================================
  #   0x40 getc ()      -- Gets a char from stdin and pushes it as a u32.
  #   0x41 getl ()      -- Gets a line from stdin and pushes it as a str (excluding trailing \r?\n).
  #   0x42 putc (c:int) -- Prints a number from the stack as a character. Errors if c < 0 or c > u32.
  #   0x43 puts (s:str) -- Prints a string from the stack.
  #
  # TODO: Variable Operations
  # TODO: Control Flow
  # TODO: Type Queries

  alias SWAny = Nil | SWNum | Bool | String | Array(SWAny)
  alias SWNum = SWInt | SWFlt
  alias SWInt = Byte | Int32 | Int64 | UInt32 | UInt64
  alias SWFlt = Float32 | Float64

  def self.runBytecode(prog : IO)
    return self.runBytecode(prog.each_byte.to_a) end
  def self.runBytecode(*prog : Byte)
    return self.runBytecode(prog) end
  def self.runBytecode(prog : Array(Byte))
    return self.runBytecode(Bytecode.new(prog)) end
  def self.runBytecode(prog : Bytecode)
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

      # SECTION: Constructors
      when 0x10 then stack.push(Array(SWAny).new(popType(SWInt, stack)) { stack.pop })

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
      when 0x37 then stack.push(~popType(SWInt, stack))
      when 0x38 then stack.push(popType(SWInt, stack) & popType(SWInt, stack))
      when 0x39 then stack.push(popType(SWInt, stack) | popType(SWInt, stack))
      when 0x3a then stack.push(popType(SWInt, stack) ^ popType(SWInt, stack))

      # SECTION: IO Operations
      when 0x40 then
        if (csi = @@stdin).is_a?(IO::FileDescriptor) && csi.tty?
          stack.push(csi.raw &.read_char.try(&.ord))
        else
          stack.push(csi.read_char.try(&.ord))
        end
      when 0x41 then stack.push(@@stdin.gets)
      when 0x42 then @@stdout.print popType(SWInt, stack).chr
      when 0x43 then @@stdout.print popType(String, stack)

      # TODO: Variable Operations
      # TODO: Control Flow
      # TODO: Type Queries
      end

      {% if flag?(:stack) %} puts "    0x#{op.opcd.to_s(16).rjust(2,'0')} #{stack}" {% end %}
      insp += 1
    end

    return stack
  end

  private macro popType(typ, stack)
    (v = {{stack}}.pop).as?({{typ}}) || 
      raise "Type error: Expected #{{{typ}}}, got #{v.class}"
  end
end

# Sherwood.runBytecode File.open(ARGV[0])
