# module MemberStructs
# member :fieldname :type
# 
# memberで外に見せたいfieldを定義する(もし全フィード見せてOKならこの定義は不要でARオブジェクトをそのままAPIの返り値にできる.
# :int
# :string
# :base64 binary用(Soap Protocolが対応してたら)
# :bool
# :float
# :time   RubyのTime型
# :datetime   RubyのDateTime型
# :date   RubyのDate型

#module #{class_name}Structs

module MemberStructs
  class Member < ActionWebService::Struct
    member :id,     :int
    member :name,   :string
    member :age,    :int
  end
end

# ここで外部公開するAPIを定義する
class MemberApi < ActionWebService::API::Base
  inflect_names false
  api_method :getNumOfSearchResult,
  :expects => [{:query => :string}],
  :returns => [:int]

  api_method :getSearchResults,
  :expects => [{:query => :string}, {:limit => :int}, {:offset => :int}],
  :returns => [[MemberStructs::Member]]
end


class MemberService < ActionWebService::Base
  web_service_api MemberApi

  def getNumOfSearchResult(query)
    return Member.count
  end

  # MemberStructs::Memberのインスタンスにフィールドをセットしてその配列を返す
  # MemberStructs::Member.each_pairでキーが手に入るので,実際のARオブジェクトからデータをコピーして返す
  def getSearchResults(query, limit, offset)
    return Member.find(:all).map do |mem|
      memberObj = MemberStructs::Member.new
      memberObj.each_pair do |member_name, value|
       memberObj.send("#{member_name.to_s}=", mem.send(member_name.to_s))
      end
      memberObj
    end
  end
end
