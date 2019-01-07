class Array
  def bitwiseConcat(size = 8); self.reduce {|a,b| (a<<size)+b} end
end
