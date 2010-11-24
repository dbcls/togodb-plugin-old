class Togodb::Column < ActiveRecord::Base
  set_table_name "togodb_columns"

  include Migratable
  include ActsAsBits

  column :name,             :string
  column :type,             :string
  column :label,            :string
  column :enabled,          :boolean, :default=>true
  column :actions,          :string
  column :roles,            :string
  column :position,         :integer
  column :html_link_prefix, :string
  column :html_link_suffix, :string
  column :list_disp_order,  :integer
  column :show_disp_order,  :integer
  column :dl_column_order,  :integer
  column :other_type,       :string
  column :web_services,     :string

  acts_as_bits :actions, %w( list show search luxury ), :prefix=>true
  acts_as_bits :roles,   %w( primary_key record_name sanitize sorting indexing )
  acts_as_bits :web_services, %w(genbank_entry_text genbank_entry_xml genbank_seq_fasta pubmed_abstract
                                  embl_entry_text embl_entry_xml embl_seq_fasta
                                  ddbj_entry_text ddbj_entry_xml ddbj_seq_fasta)

  belongs_to :table, :class_name=>"Togodb::Table", :foreign_key=>"table_id"

  class << self
    def inheritance_column
      "disable_sti"
    end
  end

  def text?
    %w( string text ).include?(self[:type].to_s)
  end

  def number?
    %w( float integer decimal).include?(self[:type].to_s)
  end

  def web_service_list
    return [] unless web_service?

    ws_list = []
    ws = %w(genbank_entry_text genbank_entry_xml genbank_seq_fasta pubmed_abstract
            embl_entry_text embl_entry_xml embl_seq_fasta
            ddbj_entry_text ddbj_entry_xml ddbj_seq_fasta)
    ws.each_with_index {|ws_name, pos|
      ws_list << ws_name if self.send("#{ws_name}?")
    }
    ws_list
  end
  
  def web_service?
    !self[:web_services].blank? && !self[:web_services].index("1").nil?
  end

  def aws_type
    ActionWebService::SignatureTypes.canonical_type_name(self[:type])
  end

  def searchable_authorized?
    if new_record?
      # new_record means whether we can see the schema or not in action.
      true
    else
      # otherwise, whether this record is editable or not.
      # here, we want to edit only text fields in place editor.
#      text?
      # for luxury search
      true
    end
  end
end
