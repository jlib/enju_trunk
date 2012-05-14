class BudgetType < ActiveRecord::Base
  has_many :budgets
end
# == Schema Information
#
# Table name: budget_types
#
#  id         :integer         not null, primary key
#  name       :string(255)
#  created_at :datetime
#  updated_at :datetime
#

