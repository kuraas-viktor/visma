class Visma::Customer < ActiveRecord::Base
  establish_connection(:visma)
  self.table_name = VISMA_CONFIG["table_name_prefix"]
  self.table_name += "Customer"
  self.primary_key = "CustomerNo"

  include Visma::Timestamp
  include Visma::ChangeBy
  enum :InActiveYesNo => [ :active, :inactive ]

  has_many :customer_order, foreign_key: :CustomerNo
  alias :orders :customer_order
  has_many :customer_order_copy, foreign_key: :CustomerNo
  alias :processed_orders :customer_order_copy

  has_many :transactions, foreign_key: :CustomerNo, class_name: Visma::GLAccountTransaction
  has_many :edi_transactions, foreign_key: "PartyID", class_name: Visma::EDITransaction

  has_one :primary_delivery_address, foreign_key: :DeliveryAddressNo, primary_key: :DeliveryAddressNo, class_name: Visma::CustomerDeliveryAddresses
  accepts_nested_attributes_for :primary_delivery_address
  has_many :delivery_addresses, foreign_key: :CustomerNo, class_name: Visma::CustomerDeliveryAddresses

  has_one :primary_invoice_address, foreign_key: :InvoiceAdressNo, primary_key: :InvoiceAdressNo, class_name: Visma::CustomerInvoiceAdresses
  accepts_nested_attributes_for :primary_invoice_address
  has_many :invoice_addresses, foreign_key: :InvoiceAdressCustomerNo, class_name: Visma::CustomerInvoiceAdresses

  has_one :invoice_contact, foreign_key: :ContactNo, primary_key: :ContactNoInvoice, class_name: Visma::Contact

  belongs_to :chain, foreign_key: :ChainNo, primary_key: :CustomerNo, class_name: Visma::Customer
  has_many :chain_members, foreign_key: :ChainNo, primary_key: :CustomerNo, class_name: Visma::Customer

  # Price list, discount group and such
  belongs_to :price_list, foreign_key: "PriceListNo"
  belongs_to :discount_group_customer, foreign_key: "DiscountGrpCustNo"
  alias :discount_group :discount_group_customer
  has_many :discount_agreement_customer, foreign_key: "CustomerNo"
  alias :discount_agreements :discount_agreement_customer

  # TODO: figure out campaigns in Visma Global, this is wrong
  #has_many :campaign_price_list, foreign_key: "CustomerNo"
#  has_many :chain_campaign_price_list, foreign_key: "ChainNo", class_name: Visma::CampaignPriceList

  has_one :customer_sum, foreign_key: "CustomerNo"

  # Isonor - Isomat custom table relationships
  has_many :z_usr_ruter_pr_kunde, foreign_key: "ZUsrCustomerNo"
  has_many :z_usr_ruter, through: :z_usr_ruter_pr_kunde

  # EDI, Form and Print profiles
  belongs_to :form_profile_customer, foreign_key: :FormProfileCustNo
  belongs_to :print_profile, foreign_key: :PrintProfileNo
  belongs_to :customer_edi_profile, foreign_key: :EdiProfileNo
  belongs_to :customer_profile, foreign_key: :CustomerProfileNo

  # Return the correct price for a given article
  def prices_for(artno)
    all_prices_for(artno).
       sort_by {|p| p.price }.
       inject({}) {|h,p| h[p.to_s] = p; h }
  end

  # Find all available prices for a given article number at a given date
  def all_prices_for(artno, at_date=Date.today)
    [ Visma::Article.find(artno) ] +
    discounts_for(artno, at_date)
  end

  # Return the correct price
  def price_for(artno, at=nil)
    if at.nil?
      prices_for(artno.to_i).values.first.price
    else
      discounts_for(artno, at).sort_by {|p| p.price }.first.price rescue nil
    end
  end

  # Return the correct price, explained
  def explained_price_for(artno)
    prices_for(artno.to_i).collect {|reason, source| [reason, source.price] }.first
  end

  # Find all discount agreements for given article number at a given date
  # TODO there is more discount agreements available through campaign_price_list
  # - @ringe: I have no data to work with to see how it works
  def discounts_for(artno, at_date=Date.today)
    Rails.cache.fetch ["discounts_for", cache_key, artno, at_date] do
      discount_sources = ["CustomerNo"]
      discount_sources << "PriceListNo" unless self.PriceListNo.to_i == 0
      discount_sources << "DiscountGrpCustNo" unless self.DiscountGrpCustNo.to_i == 0

      discount_ids = discount_sources.map {|ds| self.send(ds)}

      discounts = Visma::DiscountAgreementCustomer.
        includes(:customer, :discount_group_customer, :article).
        where("#{discount_sources.join(" = ? OR ")} = ?", *discount_ids).
        at(at_date, artno)

      if self.ChainNo == 0 or self.ChainNo == self.CustomerNo or chain.nil? 
        discounts
      else
        (discounts + chain.discounts_for(artno, at_date)).uniq
      end
    end
  end

  # Return the discount factor for the price
  def discount_factor(artno)
    src1,src2 = explained_price_for(artno).first.split(":")
    return 0 if src1 == "article"

    src = src2.nil? ? self.send(src1) : self.send(src1).send(src2)
    src.price_for(artno).discount_factor
  end

  # The current invoice address.
  # Based on wether the Chain or the Customer is getting the bill
  def current_invoice_address
    return invoice_address if chain.blank?
    return chain.invoice_address if self.TypeOfChain == 1
    return invoice_address
  end

  def address
    [self.Address1, self.Address2, "#{self.PostCode} #{self.PostOffice}"].join(", ")
  end

  def active_list
    where ["LastUpdate > ?", Date.new(Time.now.year - 1)]
  end

  def cleanphone(c)
    number,cell = c.Telephone.split("/")
    c.Telephone = phoneme(number)
    cphn = phoneme(cell) rescue nil
    if c.ZUsrMobilNr.blank?
      c.ZUsrMobilNr = cphn
    else
      c.Password = cphn
    end

    return c
  end

  # Clean up phone number string
  def phoneme(number)
    number.gsub(/-+|\s+/,"").gsub(/(\d{2,2})(\d{2,2})(\d{2,2})(\d{2,2})/, "\\1 \\2 \\3 \\4")
  end

  # When was the last invoice sent?
  def last_invoiced
    processed_orders.last.try(:Created)
  end

  # Exclude some info from json output.
  def to_json(options={})
    options[:except] ||= [:UtilityBits]
    super(options)
  end

  class << self
    # Find ICA stores by postcode
    def ica(postcode)
      where(PostCode: postcode.to_s).where("Name like '%rimi%' or Name like '%matkrok%' or Name like '%ica%'").all
    end

    def all_with_discount_agreements
      find(Visma::DiscountAgreementCustomer.uniq_ids(:CustomerNo))
    end

    # Exclude some info from json output.
    def to_json(options={})
      options[:except] ||= [:UtilityBits]
      super(options)
    end
  end
end
