require "./util"

struct Opcode
  getter opcd, data
  def initialize(@opcd : Byte, @data = [] of Byte); end
end

class Bytecode < Array(Opcode)
  getter raw
  getter labels = {} of String => Int32

  def initialize(@raw : Array(Byte))
    super()
    insp = 0

    while curbyte = @raw[insp]?
      op = (size = getCurInstWidth(insp, @raw)) > 0 ? 
        Opcode.new(curbyte, @raw[insp+1...insp+size]) :
        Opcode.new(curbyte)
      case curbyte
        when 0x70 then self.labels[op.data.bitwiseString] = self.size
        else self << op
      end
      insp += size
    end
  end

  private def getCurInstWidth(insp : Int, prog : Array(Byte))
    return 1 + case prog[insp]
    when 0x01, 0x02 then 1
    when 0x03, 0x05, 0x07 then 4
    when 0x04, 0x06, 0x08 then 8
    when 0x09, 0x70, 0x71, 0x72 then 4+prog[insp+1..insp+4].bitwiseConcat
    when 0x0a then 4
    else 0
    end
  end
end
