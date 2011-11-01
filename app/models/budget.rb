class Budget < ActiveRecord::Base
  validates_presence_of :library_id, :term_id
  has_one :library, :dependent => :destroy
  has_one :term, :dependent => :destroy
  validates_numericality_of :amount

  def library
    Library.find(self.library_id) 
  end
  
  def term
    Term.find(self.term_id)
  end
end

