module Visma
  # Common methods for Visma models
  class Base < ActiveRecord::Base
    establish_connection :visma
    self.table_name_prefix = VISMA_CONFIG['table_name_prefix']
  end
end
