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

struct Int
  abstract def bytesize : Int
  def self.fromBytes(bytes : Array(Byte)) : self; bytes.bitwiseConcat end
  
  def bytes : Array(Byte)
    arr = [] of UInt8
    str = to_s(16).rjust(bytesize*2, '0')
    str.chars.each_slice(2) do |a| arr << a.join.to_u8(16) end
    return arr
  end
end

struct Int8;    def bytesize; 1  end end
struct Int16;   def bytesize; 2  end end
struct Int32;   def bytesize; 4  end end
struct Int64;   def bytesize; 8  end end
struct Int128;  def bytesize; 16 end end
struct UInt8;   def bytesize; 1  end end
struct UInt16;  def bytesize; 2  end end
struct UInt32;  def bytesize; 4  end end
struct UInt64;  def bytesize; 8  end end
struct UInt128; def bytesize; 16 end end

def withIO(*ios : IO, &block)
  ret = yield *ios
  ios.map &.close
  return ret
end
