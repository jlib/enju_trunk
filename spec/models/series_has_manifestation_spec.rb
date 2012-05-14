require 'spec_helper'

describe SeriesHasManifestation do
=begin
  TODO:
  it "should reindex" do
    series_has_manifestation = Factory.create(:series_has_manifestation)
    series_has_manifestation.reindex.should be_true
  end
=end
end
# == Schema Information
#
# Table name: series_has_manifestations
#
#  id                  :integer         not null, primary key
#  series_statement_id :integer
#  manifestation_id    :integer
#  position            :integer
#  created_at          :datetime
#  updated_at          :datetime
#

