class SeriesHasManifestation < ActiveRecord::Base
  belongs_to :series_statement
  belongs_to :manifestation

  validates_associated :series_statement, :manifestation
  validates_presence_of :series_statement_id, :manifestation_id
  validates_uniqueness_of :manifestation_id, :scope => :series_statement_id
  validate :set_series_statement, :set_manifestation

  acts_as_list :scope => :series_statement_id

  after_create :reindex
  after_destroy :reindex

  def self.per_page
    10
  end

  def reindex
    series_statement.try(:index)
    manifestation.try(:index)
  end

  def set_series_statement
    if series_statement_id
      series_statement = SeriesStatement.find(:first, :conditions => ["id=?", self.series_statement_id])
      if series_statement
        self.series_statement = series_statement 
      else
        errors.add(:series_statement_id, I18n.t('activerecord.errors.messages.invalid'))
        return false
      end
    end
  end

  def set_manifestation
    if manifestation_id
      manifestation = Manifestation.find(:first, :conditions => ["id=?", self.manifestation_id])
      if manifestation
        self.manifestation = manifestation
      else
        errors.add(:manifestation_id, I18n.t('activerecord.errors.messages.invalid'))
        return false
      end
    end
  end
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

