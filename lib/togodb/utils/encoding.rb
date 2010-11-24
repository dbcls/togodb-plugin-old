require 'nkf'
require 'kconv'

module Togodb::Utils::Encoding
  UNKNOWN = 0
  ASCII   = 1
  JIS     = 2
  EUC     = 3
  SJIS    = 4
  UTF8    = 5
  UTF16   = 6
  BINARY  = 7
  AUTO    = 8
  NOCONV  = 9

  NUM_ENCODINGS = 10

  NKF_CODES = {
    Togodb::Utils::Encoding::JIS     => NKF::JIS,
    Togodb::Utils::Encoding::EUC     => NKF::EUC,
    Togodb::Utils::Encoding::SJIS    => NKF::SJIS,
    Togodb::Utils::Encoding::BINARY  => NKF::BINARY,
    Togodb::Utils::Encoding::UNKNOWN => NKF::UNKNOWN,
    Togodb::Utils::Encoding::ASCII   => NKF::ASCII,
    Togodb::Utils::Encoding::UTF8    => NKF::UTF8,
    Togodb::Utils::Encoding::UTF16   => NKF::UTF16
  }

  KCONV_CODES = {
    Togodb::Utils::Encoding::AUTO    => Kconv::AUTO,
    Togodb::Utils::Encoding::JIS     => Kconv::JIS,
    Togodb::Utils::Encoding::EUC     => Kconv::EUC,
    Togodb::Utils::Encoding::SJIS    => Kconv::SJIS,
    Togodb::Utils::Encoding::BINARY  => Kconv::BINARY,
    Togodb::Utils::Encoding::UNKNOWN => Kconv::UNKNOWN,
    Togodb::Utils::Encoding::NOCONV  => Kconv::NOCONV,
    Togodb::Utils::Encoding::ASCII   => Kconv::ASCII,
    Togodb::Utils::Encoding::UTF8    => Kconv::UTF8,
    Togodb::Utils::Encoding::UTF16   => Kconv::UTF16
  }

  def guess_encoding(file, max_lines = nil)
    num_encodings = Hash.new
    num_lines = 0
    File.open(file, 'r') {|f|
      while line = f.gets
        nkfcode = NKF.guess(line)

        mycode = nkfcode2mycode(nkfcode)
        next unless is_japanese(mycode)

        if num_encodings.key?(mycode)
          num_encodings[mycode] += 1
        else
          num_encodings[mycode] = 1
        end

        num_lines += 1

        if !max_lines.nil? && num_lines == max_lines
          break
        end
      end
    }

    if num_encodings.empty?
      Togodb::Utils::Encoding::NOCONV
    else
      num_encodings.keys.sort {|a, b| num_encodings[b] <=> num_encodings[a]}.fetch(0)
    end
  end

  def tosjis(str, incode = nil)
    convert_encoding(str, Togodb::Utils::Encoding::SJIS, incode)
  end

  def toutf8(str, incode = nil)
    convert_encoding(str, Togodb::Utils::Encoding::UTF8, incode)
  end

  def utf8tosjis(str)
    if str.respond_to?(:kconv)
      str.kconv(Kconv::SJIS, Kconv::UTF8)
    else
      str
    end
  end
  
  private

  def convert_encoding(data, outcode, incode = nil)
    unless data.respond_to?(:kconv)
      return data
    end

    if incode.nil?
      incode = nkfcode2mycode(NKF.guess(data))
    end

    if is_japanese(incode) && outcode != incode
      data.kconv(mycode2kconvcode(outcode), mycode2kconvcode(incode))
    else
      data
    end
  end
  
  def nkfcode2mycode(nkfcode)
    Togodb::Utils::Encoding::NKF_CODES.index(nkfcode)
  end

  def mycode2kconvcode(mycode)
    Togodb::Utils::Encoding::KCONV_CODES[mycode]
  end
  
  def is_japanese(code)
    (code == Togodb::Utils::Encoding::JIS) || (code == Togodb::Utils::Encoding::SJIS) || (code == Togodb::Utils::Encoding::UTF8) || (code == Togodb::Utils::Encoding::UTF16)
  end
  
end
