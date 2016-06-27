class Visma::DebLTransaction < ActiveRecord::Base
  establish_connection(:visma)
  self.table_name = VISMA_CONFIG["table_name_prefix"]
  self.table_name += "DebLTransaction"
  self.primary_key = "UniqueNo"
  belongs_to :batch, foreign_key: :BatchNo, class_name: Visma::BatchInformationCopy
end
