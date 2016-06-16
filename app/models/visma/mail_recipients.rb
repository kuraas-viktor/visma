class Visma::MailRecipients < ActiveRecord::Base
  establish_connection(:visma)
  self.table_name = VISMA_CONFIG["table_name_prefix"]
  self.table_name += "MailRecipients"
  self.primary_key = "Id"
  belongs_to :mail_archive, foreign_key: "MailArchiveId"
  include Visma::Timestamp
  include Visma::ChangeBy
  include Visma::CreatedScopes
end
