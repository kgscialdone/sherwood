module Sherwood
  VERSION = "0.1.0"

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
  #   0x07 str  (len:u32)+len
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
  # SECTION: IO Operations
  #   Basic IO interactions.
  # = opcd name (params) ==============================================================================================================
  #   0x30 getc ()      -- Gets a char from stdin and pushes it as a u32.
  #   0x31 getl ()      -- Gets a line from stdin and pushes it as a str (excluding trailing \r?\n).
  #   0x32 putc (c:int) -- Prints an int from the stack as a character. Errors if c < 0 or c > u32.
  #   0x33 puts (s:str) -- Prints a string from the stack.
  #
  # SECTION: Variable Operations
  #   Opcodes for interactng with variable storage.
  # = opcd name (params) ==============================================================================================================
  #   0x40 vget (name:str)  -- Pushes the value at the given variable name to the stack.
  #   0x41 vput (value:any) -- Stores the value on top of the stack as a variable.
  #   0x42 vdel (name:str)  -- Deletes the value at the given variable name.
  #   TODO: Scoping ops
  #
  # TODO: Arithmetic Operations
  # TODO: Control Flow
  # TODO: Type Queries

  alias Any = Nil | Num | Bool | String | Array(Any)
  alias Num = Byte | Int32 | Int64 | UInt32 | UInt64
  alias Byte = UInt8

  def self.runBytecode(prog : IO)
    return self.runBytecode(bs.each_byte.to_a) end
  def self.runBytecode(*prog : Byte)
    return self.runBytecode(bs) end
  def self.runBytecode(prog : Array(Byte))
    insp  = 0
    stack = [] of Any
    vars  = {} of UInt64 => Any

    while curbyte = prog[insp]?
      case curbyte

      # SECTION: Literals
      when 0x00 then stack.push(nil)
      when 0x01 then stack.push(prog[insp+1])
      when 0x02 then stack.push(prog[insp+1] > 0)
      when 0x03 then stack.push(prog[insp+1..insp+4].map(&.to_i32).reduce {|a,b| (a<<8)+b})
      when 0x04 then stack.push(prog[insp+1..insp+8].map(&.to_i64).reduce {|a,b| (a<<8)+b})
      when 0x05 then stack.push(prog[insp+1..insp+4].map(&.to_u32).reduce {|a,b| (a<<8)+b})
      when 0x06 then stack.push(prog[insp+1..insp+8].map(&.to_u64).reduce {|a,b| (a<<8)+b})
      when 0x07 then stack.push(prog[insp+5...insp+5+(prog[insp+1..insp+4].sum)].map(&.chr).sum(""))

      # SECTION: Constructors
      when 0x10 then stack.push(Array(Any).new(popType(Num, stack)) { stack.pop })

      # SECTION: Stack Operations
      when 0x20 then stack.pop()
      when 0x21 then stack.push(stack.last)
      when 0x22 then stack.push(stack.pop(), stack.pop())

      # SECTION: IO Operations
      when 0x30 then stack.push(STDIN.raw &.read_char.try(&.ord))
      when 0x31 then stack.push(STDIN.read_line)
      when 0x32 then print popType(Num, stack).chr
      when 0x33 then print popType(String, stack)

      # TODO: Variable Operations
      # TODO: Arithmetic Operations
      # TODO: Control Flow
      # TODO: Type Queries
      end

      puts "0x#{curbyte.to_s(16).rjust(2,'0')} #{stack}"
      insp += getCurInstWidth(insp, prog)
    end

    return stack
  end
  
  private def self.getCurInstWidth(insp : Int, prog : Array(Byte))
    return 1 + case prog[insp]
    when 0x01 then 1
    when 0x02 then 1
    when 0x03 then 4
    when 0x04 then 8
    when 0x05 then 4
    when 0x06 then 8
    when 0x07 then 4+prog[insp+1..insp+4].sum
    else 0
    end
  end

  private macro popType(typ, stack)
    (v = {{stack}}.pop).as?({{typ}}) || 
      raise "Type error: Expected #{{{typ}}}, got #{typeof(v)}"
  end
  
  # SECTION: Tests
  # TODO: Move to proper spec definition

  private def self.test(desc : String, expected : Array(Any), *bc : Byte) 
    test(desc, expected, bc.to_a) end
  private def self.test(desc : String, expected : Array(Any), bc : Array(Byte))
    result = runBytecode(bc)
    raise "  Test failed: #{desc}\n  Resulting stack: #{result}\n  Expected stack: #{expected}" unless result == expected
    puts  "  Test succeeded: #{desc}"
  end

  def self.runTests
    puts "SECTION: Literals"
    test "0x00 null", [nil],                    0x00
    test "0x01 byte", [0_u8],                   0x01, 0x00
    test "0x02 bool", [false],                  0x02, 0x00
    test "0x03 i32",  [0x0f0f0f0f_i32],         0x03, 0x0f, 0x0f, 0x0f, 0x0f
    test "0x04 i64",  [0x0f0f0f0f0f0f0f0f_i64], 0x04, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f
    test "0x05 u32",  [0x0f0f0f0f_u32],         0x05, 0x0f, 0x0f, 0x0f, 0x0f
    test "0x06 u64",  [0x0f0f0f0f0f0f0f0f_u64], 0x06, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f
    test "0x07 str",  ["Hello, world!"],        [0x07, 0x00, 0x00, 0x00, 13].map(&.to_u8) + "Hello, world!".bytes
    puts

    puts "SECTION: Constructors"
    test "0x10 list", [[true, false]], 0x02, 0, 0x02, 1, 0x01, 2, 0x10
    puts

    puts "SECTION: Stack Operations"
    test "0x20 drop", [] of Any,     0x00, 0x20
    test "0x21 dupe", [nil, nil],    0x00, 0x21
    test "0x22 swap", [true, false], 0x02, 0, 0x02, 1, 0x22
    puts

    puts "SECTION: IO Operations"
    puts "(Please input: 'a')"
    test "0x30 getc", ['a'.ord], 0x30
    puts "(Please input: 'abc<ENTER>')"
    test "0x31 getl", ["abc"],   0x31
    test "0x32 putc", [] of Any, 0x01, 97, 0x32
    test "0x33 putl", [] of Any, [0x07, 0x00, 0x00, 0x00, 14].map(&.to_u8) + "Hello, world!\n".bytes + [0x33_u8]
    puts

    # TODO: Variable Operations
    # TODO: Arithmetic Operations
    # TODO: Control Flow
    # TODO: Type Queries
  end
end

# Sherwood.runBytecode File.open(ARGV[0])
Sherwood.runTests