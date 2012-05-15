# -*- encoding: utf-8 -*-
class Message < ActiveRecord::Base
  scope :unread, where(:state => 'unread')
  belongs_to :message_request
  belongs_to :sender, :class_name => 'User'
  belongs_to :receiver, :class_name => 'User'
  validates_presence_of :recipient, :on => :create
  validate :exist_user, :on => :create
  validates_presence_of :subject, :body #, :sender
  validates_presence_of :receiver, :on => :update
  before_validation :set_receiver
  after_save :index
  after_destroy :remove_from_index
  after_create :send_notification

  acts_as_tree
  attr_accessor :recipient

  state_machine :initial => :unread do
    before_transition any => :read, :do => :read
    before_transition :read => :unread, :do => :unread

    event :sm_read do
      transition any => :read
    end

    event :sm_unread do
      transition :read => :unread
    end
  end

  searchable do
    text :body, :subject
    string :subject
    integer :receiver_id
    integer :sender_id
    time :created_at
    boolean :is_read do
      self.read?
    end
  end

  def self.per_page
    10
  end

  def set_receiver
    if self.recipient
      user = User.find(:first, :conditions => ["username=?", self.recipient])
#      self.receiver = User.find(self.recipient)
      self.receiver = user unless user.nil?
    end
  end

  def send_notification
    Notifier.message_notification(self).deliver if receiver.try(:email).present?
  end

  def read
    self.read_at = Time.zone.now unless self.read_at
    self.save(:validate => false)
  end

  def read?
    return true if state == 'read'
    false
  end

  def exist_user
    unless self.recipient.blank?
      errors.add(:receiver, I18n.t('activerecord.errors.messages.non_exist_user')) if self.receiver.nil?
    end
  end
 
end
# == Schema Information
#
# Table name: messages
#
#  id                 :integer         not null, primary key
#  read_at            :datetime
#  receiver_id        :integer
#  sender_id          :integer
#  subject            :string(255)     not null
#  body               :text
#  created_at         :datetime
#  updated_at         :datetime
#  message_request_id :integer
#  state              :string(255)
#  parent_id          :integer
#  lft                :integer
#  rgt                :integer
#

