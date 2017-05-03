module Visma
  # Set SeqNo
  module SequenceNumber
    def siblings
      raise NotImplementedError
    end

    # Set the sequence number to the next in range
    def set_sequence
      seq = sequence.last + 1
      self.SeqNo = format('%08d', seq.to_s.reverse.to_i).reverse
    end

    # Define the sequence numbering for all siblings
    def sequence
      siblings.pluck(:SeqNo).collect { |n| n.to_s.sub(/0+$/, '').to_i }.sort
    rescue NoMethodError
      [1000]
    end
  end
end
