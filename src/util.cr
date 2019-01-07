alias Byte = UInt8

class Array
  def bitwiseConcat(size = 8); self.reduce {|a,b| (a<<size)+b} end
end

struct Float32
  def self.fromBytes(bytes : Array(Byte))
    b1, b2, b3, b4 = bytes
    tuple = {b4,b3,b2,b1}
    (pointerof(tuple).as(Float32*)).value
  end
end

struct Float64
  def self.fromBytes(bytes : Array(Byte))
    b1, b2, b3, b4, b5, b6, b7, b8 = bytes
    tuple = {b8,b7,b6,b5,b4,b3,b2,b1}
    (pointerof(tuple).as(Float64*)).value
  end
end
