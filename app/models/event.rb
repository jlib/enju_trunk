# -*- encoding: utf-8 -*-
class Event < ActiveRecord::Base
  scope :closing_days, :include => :event_category, :conditions => ['event_categories.id = 2 OR event_categories.checkin_ng = ?', true]
  scope :on, lambda {|datetime| where('start_at >= ? AND start_at < ?', datetime.beginning_of_day, datetime.tomorrow.beginning_of_day + 1)}
  scope :past, lambda {|datetime| where('end_at <= ?', Time.zone.parse(datetime).beginning_of_day)}
  scope :upcoming, lambda {|datetime| where('start_at >= ?', Time.zone.parse(datetime).beginning_of_day)}
  scope :at, lambda {|library| where(:library_id => library.id)}

  belongs_to :event_category, :validate => true
  belongs_to :library, :validate => true
  has_many :attachment_files, :as => :attachable
  has_many :picture_files, :as => :picture_attachable
  has_many :participates, :dependent => :destroy
  has_many :patrons, :through => :participates
  has_one :event_import_result

  has_event_calendar

  searchable do
    text :name, :note
    integer :library_id
    time :created_at
    time :updated_at
    time :start_at
    time :end_at
  end

  validates_presence_of :name, :library, :event_category
  validates_associated :library, :event_category
  validate :check_date
  before_validation :set_date
  before_validation :set_display_name, :on => :create

  def self.per_page
    10
  end

  def set_date
    if self.start_at.blank?
      self.start_at = Time.zone.today.beginning_of_day
    end
    if self.end_at.blank?
      self.end_at = Time.zone.today.end_of_day
    end

    set_all_day
  end

  def set_all_day
    if self.all_day
      self.start_at = self.start_at.beginning_of_day
      self.end_at = self.end_at.end_of_day
    end
  end

  def check_date
    if self.start_at and self.end_at
      if self.start_at >= self.end_at
        errors.add(:start_at)
        errors.add(:end_at)
      end
    end
  end

  def set_display_name
    self.display_name = self.name if self.display_name.blank?
  end

  def self.get_event_list_tsv(events)
    data = String.new
    data << "\xEF\xBB\xBF".force_encoding("UTF-8") + "\n"
    columns = [
      [:library, 'activerecord.models.library'],
      [:event, 'activerecord.attributes.event.name'],
      [:note, 'activerecord.attributes.event.note'],
      [:start_at, 'activerecord.attributes.event.start_at'],
      [:end_at, 'activerecord.attributes.event.end_at'],
    ]

    # title column
    row = columns.map {|column| I18n.t(column[1])}
    data << '"'+row.join("\"\t\"")+"\"\n"

    events.each do |event|
      row = []
      columns.each do |column|
        case column[0]
        when :library
          row << event.library.display_name.gsub(/"/, '""')
        when :event
          row << event.display_name.localize.gsub(/"/, '""')
        when :note
          row << event.note.to_s.gsub(/"/, '""')
        when :start_at
          row << event.start_at.to_s.gsub(/"/, '""')
        when :end_at
          row << event.end_at.to_s.gsub(/"/, '""')
        end
      end
      data << '"'+row.join("\"\t\"")+"\"\n"
    end
    return data
  end
end

# == Schema Information
#
# Table name: events
#
#  id                :integer         not null, primary key
#  library_id        :integer         default(1), not null
#  event_category_id :integer         default(1), not null
#  name              :string(255)
#  note              :text
#  start_at          :datetime
#  end_at            :datetime
#  all_day           :boolean         default(FALSE), not null
#  deleted_at        :datetime
#  created_at        :datetime
#  updated_at        :datetime
#  display_name      :text
#

