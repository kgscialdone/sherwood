alias Byte = UInt8

struct Opcode
  getter opcd, data
  def initialize(@opcd : Byte, @data = [] of Byte); end
end

class Bytecode < Array(Opcode)
  getter raw
  def initialize(@raw : Array(Byte))
    super()
    insp = 0

    while curbyte = @raw[insp]?
      (size = getCurInstWidth(insp, @raw)) > 0 && 
        self << Opcode.new(curbyte, @raw[insp+1...insp+size]) || 
        self << Opcode.new(curbyte)
      insp += size
    end
  end

  private def getCurInstWidth(insp : Int, prog : Array(Byte))
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
end
