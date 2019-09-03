class Visma::CustomerOrder < Visma::Base
  self.table_name += 'CustomerOrder'
  self.primary_key = 'OrderNo'

  include Visma::Timestamp
  include Visma::ChangeBy

  belongs_to :customer, foreign_key: :CustomerNo
  belongs_to :chain, foreign_key: :ChainNo, primary_key: :CustomerNo, 'class_name: Visma::Customer'

  belongs_to :employee, foreign_key: :EmployeeNo
  belongs_to :our_reference,
             foreign_key: :OurRef,
             primary_key: :Name,
             class_name: 'Visma::Employee'

  has_many :customer_order_lines, foreign_key: :OrderNo
  alias order_lines customer_order_lines

  enum OrderStatus: { system_invoiced: 1030, user_invoiced: 1000, nullified: -1, for_picking: 1015 }
end
