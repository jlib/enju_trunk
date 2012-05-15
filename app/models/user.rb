class User < ActiveRecord::Base
  self.extend UsersHelper
  # Include default devise modules. Others available are:
  # :token_authenticatable, :lockable and :timeoutable
  devise :database_authenticatable, #:registerable, :confirmable,
         :recoverable, :rememberable, :trackable, #:validatable,
         :lockable, :lock_strategy => :none, :unlock_strategy => :none

  # Setup accessible (or protected) attributes for your model
  #attr_accessible :email, :email_confirmation, :password, :password_confirmation, :username, :current_password, :user_number, :remember_me
  attr_accessible :email, :email_confirmation, :password, :password_confirmation, :username, :current_password, :user_number, :remember_me, :auto_generated_password, :expired_at, :locked, :unable, :user_group_id, :library_id, :locale, :role_id, :keyword_list
  cattr_accessor :current_user
  attr_accessor :new_user_number

  scope :administrators, where('roles.name = ?', 'Administrator').includes(:role)
  scope :librarians, where('roles.name = ? OR roles.name = ?', 'Administrator', 'Librarian').includes(:role)
  scope :suspended, where('locked_at IS NOT NULL')
  scope :adults, joins(:patron).where(["patrons.date_of_birth <= ?", Date.today.years_ago(18).change(:month => 4, :day => 1)])
  scope :students, joins(:patron).where(["patrons.date_of_birth < ? AND patrons.date_of_birth >= ?", Date.today.years_ago(15).change(:month => 4, :day => 1), Date.today.years_ago(18).change(:month => 4, :day => 1)])
  scope :juniors, joins(:patron).where(["patrons.date_of_birth < ? AND patrons.date_of_birth >= ?", Date.today.years_ago(12).change(:month => 4, :day => 1), Date.today.years_ago(15).change(:month => 4, :day => 1)])
  scope :elementaries, joins(:patron).where(["patrons.date_of_birth < ? AND patrons.date_of_birth >= ?", Date.today.years_ago(6).change(:month => 4, :day => 1), Date.today.years_ago(12).change(:month => 4, :day => 1)])
  scope :children, joins(:patron).where(["patrons.date_of_birth >= ?", Date.today.years_ago(6).change(:month => 4, :day => 1)])
  scope :provisional, where(:user_number => nil)
  scope :corporate, joins(:patron => :patron_type).where(["patron_types.name = ? ", "CorporateBody"])
  has_one :patron
  has_many :checkouts
  has_many :import_requests
  has_many :sent_messages, :foreign_key => 'sender_id', :class_name => 'Message'
  has_many :received_messages, :foreign_key => 'receiver_id', :class_name => 'Message'
  #has_many :user_has_shelves
  #has_many :shelves, :through => :user_has_shelves
  has_many :picture_files, :as => :picture_attachable, :dependent => :destroy
  has_many :import_requests
  has_one :user_has_role
  has_one :role, :through => :user_has_role
  has_many :bookmarks, :dependent => :destroy
  has_many :reserves, :dependent => :destroy
  has_many :reserved_manifestations, :through => :reserves, :source => :manifestation
  has_many :questions
  has_many :answers
  has_many :search_histories, :dependent => :destroy
  has_many :baskets, :dependent => :destroy
  has_many :purchase_requests
  has_many :order_lists
  has_many :subscriptions
  has_many :checkout_stat_has_users
  has_many :user_checkout_stats, :through => :checkout_stat_has_users
  has_many :reserve_stat_has_users
  has_many :user_reserve_stats, :through => :reserve_stat_has_users
  belongs_to :library, :validate => true
  belongs_to :user_group
  belongs_to :required_role, :class_name => 'Role', :foreign_key => 'required_role_id' #, :validate => true
  has_one :patron_import_result
  has_one :family, :through => :family_user
  has_one :family_user
  has_many :barcode_lists, :foreign_key => 'created_by'

  validates :username, :presence => true, :uniqueness => true
  validates_uniqueness_of :email, :scope => authentication_keys[1..-1], :case_sensitive => false, :allow_blank => true
  validates :email, :format => {:with => /\A([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})\z/i}, :allow_blank => true
  validates_date :expired_at, :allow_blank => true

  with_options :if => :password_required? do |v|
    v.validates_presence_of     :password
    v.validates_confirmation_of :password
    v.validates_length_of       :password, :within => 6..20, :allow_blank => true
  end

#  validates_presence_of :email, :email_confirmation, :on => :create #, :if => proc{|user| !user.operator.try(:has_role?, 'Librarian')}
  validates_associated :patron, :user_group, :library
  validates_presence_of :user_group, :library, :locale #, :user_number
  validates :user_number, :uniqueness => true, :format => {:with => /\A[0-9A-Za-z_]+\Z/}, :allow_blank => true
  validates_confirmation_of :email #, :on => :create, :if => proc{|user| !user.operator.try(:has_role?, 'Librarian')}
  before_validation :set_role_and_patron, :on => :create
  before_validation :set_lock_information
  before_destroy :check_item_before_destroy, :check_role_before_destroy
  before_save :check_expiration
  before_create :set_expired_at
  after_destroy :remove_from_index
  after_create :set_confirmation
  after_save :index_patron
  after_destroy :index_patron

  extend FriendlyId
  friendly_id :username
  #acts_as_tagger
  has_paper_trail
  normalize_attributes :username, :user_number #, :email

  searchable do
    text :username, :email, :note, :user_number
    text :telephone_number_1_1 do
      patron.telephone_number_1.gsub("-", "") if patron && patron.telephone_number_1
    end
    text :telephone_number_1_2 do
      patron.telephone_number_1 if patron && patron.telephone_number_1
    end
    text :extelephone_number_1_1 do
      patron.extelephone_number_1.gsub("-", "") if patron && patron.extelephone_number_1
    end
    text :extelephone_number_1_2_ do
      patron.extelephone_number_1 if patron && patron.extelephone_number_1
    end
    text :fax_number_1_1 do
      patron.fax_number_1.gsub("-", "") if patron && patron.fax_number_1
    end
    text :fax_number_1_2 do
      patron.fax_number_1 if patron && patron.fax_number_1
    end
    text :telephone_number_2_1 do
      patron.telephone_number_2.gsub("-", "") if patron && patron.telephone_number_2
    end
    text :telephone_number_2_2 do
      patron.telephone_number_2 if patron && patron.telephone_number_2
    end
    text :extelephone_number_2_1 do
      patron.extelephone_number_2.gsub("-", "") if patron && patron.extelephone_number_2
    end
    text :extelephone_number_2_2 do
      patron.extelephone_number_2 if patron && patron.extelephone_number_2
    end
    text :fax_number_2_1 do
      patron.fax_number_2.gsub("-", "") if patron && patron.fax_number_2
    end
    text :fax_number_2_2 do
      patron.fax_number_2 if patron && patron.fax_number_2
    end
    text :address do
      addresses = []
      addresses << patron.address_1 if patron
      addresses << patron.address_2 if patron
    end
    text :address_1 do
      patron.address_1 if patron
    end
    text :name do
      patron.name if patron
    end
    string :username
    string :email
    string :user_number
    string :telephone_number do
      patron.telephone_number_1.gsub("-", "") if patron && patron.telephone_number_1
    end
    string :full_name do
      patron.full_name_transcription if patron
    end
    string :telephone_number do
      patron.telephone_number_1 if patron && patron.telephone_number_1
    end
    integer :required_role_id
    integer :id
    time :created_at
    time :updated_at
    time :date_of_birth do
      patron.date_of_birth if patron
    end
    boolean :active do
      active_for_authentication?
    end
    time :confirmed_at
    string :library do
      library.name
    end
    string :role do
      role.display_name
    end
    string :patron_type do
      patron.patron_type.name if patron
    end
  end

  attr_accessor :first_name, :middle_name, :last_name, :full_name,
    :first_name_transcription, :middle_name_transcription,
    :last_name_transcription, :full_name_transcription,
    :zip_code, :address, :address_1, :telephone_number, :fax_number, :address_note,
    :role_id, :patron_id, :operator, :password_not_verified,
    :update_own_account, :auto_generated_password,
    :locked, :current_password, :birth_date, :death_date #, :email

  def self.per_page
    10
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def has_role?(role_in_question)
    return false unless role
    return true if role.name == role_in_question
    case role.name
    when 'Administrator'
      return true
    when 'Librarian'
      return true if role_in_question == 'User'
    else
      false
    end
  end

  def set_role_and_patron
    #self.required_role = Role.find_by_name('Librarian')
#    self.locale = I18n.default_locale.to_s
    unless self.patron
#      self.patron = Patron.create(:full_name => self.username) if self.username
    end
  end

  def set_lock_information
    if self.locked == '1' and self.active_for_authentication?
      lock_access!
    elsif self.locked == '0' and !self.active_for_authentication?
      unlock_access!
    end
  end

  def set_confirmation
    if operator and respond_to?(:confirm!)
      reload
      confirm!
    end
  end

  def index_patron
    if self.patron
      self.patron.index
    end
  end

  def check_expiration
    return if self.has_role?('Administrator')
    if expired_at
      if expired_at.beginning_of_day < Time.zone.now.beginning_of_day
        lock_access! if self.active_for_authentication?
      end
    end
  end

  def check_item_before_destroy
    # TODO: 貸出記録を残す場合
    if checkouts.size > 0
      raise 'This user has items still checked out.'
    end
  end

  def check_role_before_destroy
    if self.has_role?('Administrator')
      raise 'This is the last administrator in this system.' if Role.find_by_name('Administrator').users.size == 1
    end
  end

  def set_auto_generated_password
    password = Devise.friendly_token[0..7]
    self.reset_password!(password, password)
  end

  def reset_checkout_icalendar_token
    self.checkout_icalendar_token = Devise.friendly_token
  end

  def delete_checkout_icalendar_token
    self.checkout_icalendar_token = nil
  end

  def reset_answer_feed_token
    self.answer_feed_token = Devise.friendly_token
  end

  def delete_answer_feed_token
    self.answer_feed_token = nil
  end

  def self.lock_expired_users
    User.find_each do |user|
      user.lock_access! if user.expired? and user.active_for_authentication?
    end
  end

  def expired?
    if expired_at
      true if expired_at.beginning_of_day < Time.zone.now.beginning_of_day
    end
  end

  def checked_item_count
    checkout_count = {}
    CheckoutType.all.each do |checkout_type|
      # 資料種別ごとの貸出中の冊数を計算
      checkout_count[:"#{checkout_type.name}"] = self.checkouts.count_by_sql(["
        SELECT count(item_id) FROM checkouts
          WHERE item_id IN (
            SELECT id FROM items
              WHERE checkout_type_id = ?
          )
          AND user_id = ? AND checkin_id IS NULL", checkout_type.id, self.id]
      )
    end
    return checkout_count
  end

  def reached_reservation_limit?(manifestation)
    return true if self.user_group.user_group_has_checkout_types.available_for_carrier_type(manifestation.carrier_type).where(:user_group_id => self.user_group.id).collect(&:reservation_limit).max.to_i <= self.reserves.waiting.size
    false
  end

  def is_admin?
    true if self.has_role?('Administrator')
  end

  def last_librarian?
    if self.has_role?('Librarian')
      role = Role.where(:name => 'Librarian').first
      true if role.users.size == 1
    end
  end

  def send_message(status, options = {})
    MessageRequest.transaction do
      request = MessageRequest.new
      request.sender = User.find(1)
      request.receiver = self
      request.message_template = MessageTemplate.localized_template(status, self.locale)
      request.save_message_body(options)
      request.sm_send_message!
    end
  end

  def owned_tags_by_solr
    bookmark_ids = bookmarks.collect(&:id)
    if bookmark_ids.empty?
      []
    else
      Tag.bookmarked(bookmark_ids)
    end
  end

  def check_update_own_account(user)
    if user == self
      self.update_own_account = true
      return true
    end
    false
  end

  def send_confirmation_instructions
    unless self.operator
      Devise::Mailer.delay.confirmation_instructions(self) if self.email.present?
    end
  end

  def set_expired_at
    if self.user_group.valid_period_for_new_user > 0
      self.expired_at = self.user_group.valid_period_for_new_user.days.from_now.end_of_day
    end
  end

  def deletable_by(current_user)
    # 未返却の資料のあるユーザを削除しようとした
    if self.checkouts.count > 0
      errors[:base] << I18n.t('user.this_user_has_checked_out_item')
    end

    if self.has_role?('Librarian')
      # 管理者以外のユーザが図書館員を削除しようとした。図書館員の削除は管理者しかできない
      unless current_user.has_role?('Administrator')
        errors[:base] << I18n.t('user.only_administrator_can_destroy')
      end
      # 最後の図書館員を削除しようとした
      if self.last_librarian?
        errors[:base] << I18n.t('user.last_librarian')
      end
    end

    # 最後の管理者を削除しようとした
    if self.has_role?('Administrator')
      if Role.where(:name => 'Administrator').first.users.size == 1
        errors[:base] << I18n.t('user.last_administrator')
      end
    end

    if errors[:base] == []
      true
    else
      false
    end
  end

  def self.create_with_params(params, has_role_id)
    logger.debug "create_with_params start."
    user = User.new(params)
    user_group = UserGroup.find(params[:user_group_id])
    user.user_group = user_group if user_group
    user.locale = params[:locale]
    library = Library.find(params[:library_id])
    user.library = library if library
    user.operator = current_user

    logger.debug "create_with_params create-1"

    if params
      #self.username = params[:user][:login]
      user.note = params[:note]
      user.user_group_id = params[:user_group_id] ||= 1
      user.library_id = params[:library_id] ||= 1
      # user.role_id = params[:role_id] ||= 1
      
      if !params[:role_id].blank? and has_role_id.blank?
        user.role_id = params[:role_id] ||= 1
        user.role = Role.find(user.role_id)
      elsif !has_role_id.blank?
        user.role_id = has_role_id ||= 1
        user.role = Role.find(has_role_id)
      else
        user.role_id = Role.where(:name => 'User').first.id ||= 1
        user.role = Role.where(:name => 'User').first
      end

      user.required_role_id = params[:required_role_id] ||= 1
      user.required_role = Role.find(user.required_role_id)
      user.keyword_list = params[:keyword_list]
      user.user_number = params[:user_number]
      user.locale = params[:locale]
    end

    logger.debug "create_with_params create-10"

    if user.patron_id
      user.patron = Patron.find(user.patron_id) rescue nil
    end
    logger.debug "create_with_params end."
    user
  end

  def update_with_params(params)
    self.operator = current_user
    self.openid_identifier = params[:openid_identifier]
    self.keyword_list = params[:keyword_list]
    self.checkout_icalendar_token = params[:checkout_icalendar_token]
    self.email = params[:email]
    #self.note = params[:note]
    #self.username = params[:login]

    if current_user.has_role?('Librarian')
      self.email = params[:email]
      self.expired_at = params[:expired_at]
      self.note = params[:note]
      self.user_group_id = params[:user_group_id] || 1
      self.library_id = params[:library_id] || 1
      self.role_id = params[:role_id]
      self.required_role_id = params[:required_role_id] || 1
      self.locale = params[:locale]
      self.user_number = params[:user_number]
      self.locked = params[:locked]
      self.expired_at = params[:expired_at]
      self.unable = params[:unable]
    end
    self
  end

  def deletable?
    true if checkouts.not_returned.empty? and id != 1
  end

  def set_family(user_id)
    family = User.find(user_id).family rescue nil    
    if family
      family.users << self
    else
        family = Family.create() 
        user = User.find(user_id)
        family.users << self         
        family.users << user
    end
  end
  
  def out_of_family
    begin
      family_user = FamilyUser.find(:first, :conditions => ['user_id=?', self.id])
      family_id = family_user.family_id
      family_user.destroy
      all_users = FamilyUser.find(:all, :conditions => ['family_id=?', family_id])
      if all_users && all_users.length == 1
        all_users.each do |user| 
          user.destroy 
        end
      end
    rescue Exception => e
      logger.error e
    end
  end
  
  def family
    FamilyUser.find(:first, :conditions => ['user_id=?', id]).family
  end
 
  def user_notice
    @messages = []
    @messages << I18n.t('user.not_connect', :user => self.username) if self.unable
    overdues = self.checkouts.overdue(Time.zone.now) rescue nil
    @messages << I18n.t('user.overdue_item', :user => self.username, :count => overdues.length) unless overdues.empty?
    reserves = self.reserves.hold rescue nil
    @messages << I18n.t('user.retained_reserve', :user => self.username, :count => reserves.length) unless reserves.empty?
    return @messages
  end

  def age
    Date.today.year - patron.date_of_birth.year
  end

  def set_color
    @color = nil
    @color = SystemConfiguration.get("user.unable.background") if self.unable == true
    @color = SystemConfiguration.get("user.locked.background") unless self.locked_at.blank?
    return @color
  end

  def available_for_reservation?
    return false if self.user_number.blank? or self.locked_at or (self.expired_at and self.expired_at < Time.zone.today.beginning_of_day)
    true
  end

  def delete_reserves
    items = []
    if self.reserves.not_waiting
      self.reserves.not_waiting.each do |reserve| 
        if reserve.item
          items << reserve.item
          Reserve.delete(reserve)
        end
      end
    end

    items.each do |item|
      item.cancel_retain!
      item.set_next_reservation if item.manifestation.next_reservation
    end
  end

  def self.output_userlist_pdf(users)
    report = ThinReports::Report.new :layout => File.join(Rails.root, 'report', 'userlist.tlf')

    # set page_num
    report.events.on :page_create do |e|
      e.page.item(:page).value(e.page.no)
    end
    report.events.on :generate do |e|
      e.pages.each do |page|
        page.item(:total).value(e.report.page_count)
      end
    end

    report.start_new_page do |page|
      page.item(:date).value(Time.now)
      users.each do |user|
        page.list(:list).add_row do |row|
          row.item(:full_name).value(user.patron.full_name)
          row.item(:username).value(user.username)
          row.item(:user_number).value(user.user_number)
          row.item(:tel1).value(user.patron.telephone_number_1) if user.patron.telephone_number_1
          row.item(:tel2).value(user.patron.telephone_number_2) if user.patron.telephone_number_2
          row.item(:created_at).value(user.created_at)
          row.item(:locked).value(I18n.t('activerecord.attributes.user.locked_yes')) if user.active_for_authentication?
          row.item(:locked).value(I18n.t('activerecord.attributes.user.locked_no')) unless user.active_for_authentication?
          row.item(:unable).value(I18n.t('activerecord.attributes.user.unable_yes')) unless user.unable
          row.item(:unable).value(I18n.t('activerecord.attributes.user.unable_no')) if user.unable
        end
      end
    end
    return report
  end

  def self.output_userlist_tsv(users)
    columns = [
      [:full_name, 'activerecord.attributes.patron.full_name'],
      [:full_name_transcription, 'activerecord.attributes.patron.full_name_transcription'],
      [:full_name_alternative, 'activerecord.attributes.patron.full_name_alternative'],
      ['username', 'activerecord.attributes.user.username'],
      ['user_number', 'activerecord.attributes.user.user_number'],
      [:library, 'activerecord.attributes.user.library'],
      [:expired_at, 'activerecord.attributes.user.expired_at'],
      [:locked, 'activerecord.attributes.user.locked'],
      [:unable, 'activerecord.attributes.user.unable'],
      [:patron_type, 'activerecord.models.patron_type'],
      [:email, 'activerecord.attributes.patron.email'],
      [:url, 'activerecord.attributes.patron.url'],
      [:other_designation, 'activerecord.attributes.patron.other_designation'],
      [:place, 'activerecord.attributes.patron.place'],
      [:language, 'activerecord.models.language'],
      [:zip_code_1, 'activerecord.attributes.patron.zip_code_1'],
      [:address_1, 'activerecord.attributes.patron.address_1'],
      [:telephone_number_1, 'activerecord.attributes.patron.telephone_number_1'],
      [:extelephone_number_1, 'activerecord.attributes.patron.extelephone_number_1'],
      [:fax_number_1, 'activerecord.attributes.patron.fax_number_1'],
      [:address_1_note, 'activerecord.attributes.patron.address_1_note'],
      [:zip_code_2, 'activerecord.attributes.patron.zip_code_2'],
      [:address_2, 'activerecord.attributes.patron.address_2'],
      [:telephone_number_2, 'activerecord.attributes.patron.telephone_number_2'],
      [:extelephone_number_2, 'activerecord.attributes.patron.extelephone_number_2'],
      [:fax_number_2, 'activerecord.attributes.patron.fax_number_2'],
      [:address_2_note, 'activerecord.attributes.patron.address_2_note'],
      [:date_of_birth, 'activerecord.attributes.patron.date_of_birth'],
      [:date_of_death, 'activerecord.attributes.patron.date_of_death'],
      [:note, 'activerecord.attributes.patron.note'],
      [:note_update_at, 'activerecord.attributes.patron.note_update_at'],
      [:patron_identifier, 'patron.patron_identifier'],
      [:created_at, 'page.created_at'],
      [:updated_at, 'page.updated_at'],
    ]

    data = String.new

    data << "\xEF\xBB\xBF".force_encoding("UTF-8") + "\n"
    # title column
    row = []
    columns.each do |column|
      row << I18n.t(column[1])
    end
    data << '"'+row.join("\"\t\"")+"\"\n"

    users.each do |user|
      row = []
      columns.each do |column|
        case column[0]
        when :full_name
          row << user.patron.full_name
        when :full_name_transcription
          row << user.patron.full_name_transcription
        when :full_name_alternative
          row << user.patron.full_name_alternative
        when :library
          row << user.library.display_name
        when :expired_at
          expired_at = ""
          if user.expired_at
            year = user.expired_at.strftime("%Y")
            month = user.expired_at.strftime("%m")
            date = user.expired_at.strftime("%d")
            expired_at = I18n.t('expense.date_format', :year => year, :month => month, :date => date) 
          end
          row << expired_at
        when :locked
          row << I18n.t('activerecord.attributes.user.locked_yes') if user.active_for_authentication?
          row << I18n.t('activerecord.attributes.user.locked_no') unless user.active_for_authentication?
        when :unable
          row << I18n.t('activerecord.attributes.user.unable_yes') unless user.unable
          row << I18n.t('activerecord.attributes.user.unable_no') if user.unable
        when :patron_type
          row << user.patron.patron_type.display_name.localize
        when :email
          row << user.patron.email
        when :url
          row << user.patron.url
        when :other_designation
          row << user.patron.other_designation
        when :place
          row << user.patron.place
        when :language
          row << user.patron.language.display_name.localize
        when :zip_code_1
          row << user.patron.zip_code_1
        when :address_1
          row << user.patron.address_1
        when :telephone_number_1
          telephone_number_1 = user.patron.telephone_number_1
          telephone_number_1 += ' (' + I18n.t(i18n_telephone_type(user.patron.telephone_number_1_type_id).strip_tags) +')' unless user.patron.telephone_number_1.blank?
          row << telephone_number_1 
        when :extelephone_number_1
          extelephone_number_1 = user.patron.extelephone_number_1
          extelephone_number_1 += ' (' + I18n.t(i18n_telephone_type(user.patron.extelephone_number_1_type_id).strip_tags) +')' unless user.patron.extelephone_number_1.blank?
          row << extelephone_number_1 
        when :fax_number_1
          fax_number_1 = user.patron.fax_number_1
          fax_number_1 += ' (' + I18n.t(i18n_telephone_type(user.patron.fax_number_1_type_id).strip_tags) +')' unless user.patron.fax_number_1.blank?
          row << fax_number_1 
        when :address_1_note
          row << user.patron.address_1_note 
        when :zip_code_2
          row << user.patron.zip_code_2
        when :address_2
          row << user.patron.address_2
        when :telephone_number_2
          telephone_number_2 = user.patron.telephone_number_2
          telephone_number_2 += ' (' + I18n.t(i18n_telephone_type(user.patron.telephone_number_2_type_id).strip_tags) +')' unless user.patron.telephone_number_2.blank?
          row << telephone_number_2
        when :extelephone_number_2
          extelephone_number_2 = user.patron.extelephone_number_2
          extelephone_number_2 += ' (' + I18n.t(i18n_telephone_type(user.patron.extelephone_number_2_type_id).strip_tags) +')' unless user.patron.extelephone_number_2.blank?
          row << extelephone_number_2
        when :fax_number_2
          fax_number_2 = user.patron.fax_number_2
          fax_number_2 += ' (' + I18n.t(i18n_telephone_type(user.patron.fax_number_2_type_id).strip_tags) +')' unless user.patron.fax_number_2.blank?
          row << fax_number_2 
        when :address_2_note
          row << user.patron.address_2_note
        when :date_of_birth
          date_of_birth = ""
          if user.patron.date_of_birth
            year = user.patron.date_of_birth.strftime("%Y")
            month = user.patron.date_of_birth.strftime("%m")
            date = user.patron.date_of_birth.strftime("%d")
            date_of_birth = I18n.t('expense.date_format', :year => year, :month => month, :date => date)
          end
          row << date_of_birth
        when :date_of_death
          date_of_death = ""
          if user.patron.date_of_death
            year = user.patron.date_of_death.strftime("%Y")
            month = user.patron.date_of_death.strftime("%m")
            date = user.patron.date_of_death.strftime("%d")
            date_of_death = I18n.t('expense.date_format', :year => year, :month => month, :date => date)
          end
          row << date_of_death
        when :note
          row << user.patron.note
        when :note_update_at
          note_update = user.patron.note_update_at.strftime("%Y/%m/%d %H:%M:%S") if user.patron.note_update_at
          note_update += ' ' + I18n.t('patron.last_update_by') + ':' + user.patron.note_update_by if user.patron.note_update_by
          note_update += '(' + user.patron.note_update_library + ')' if user.patron.note_update_library
          row << note_update
        when :patron_identifier
          row << user.patron.patron_identifier
        when :created_at
          row << user.created_at.strftime("%Y/%m/%d %H:%M:%S")
        when :updated_at
          row << user.updated_at.strftime("%Y/%m/%d %H:%M:%S")
        else
          row << get_object_method(user, column[0].split('.')).to_s.gsub(/\r\n|\r|\n/," ").gsub(/\"/,"\"\"")
        end
      end  
      data << '"'+row.join("\"\t\"")+"\"\n"
    end
    return data
  end

  private
  def self.get_object_method(obj,array)
    _obj = obj.send(array.shift)
    return get_object_method(_obj, array) if array.present?
    return _obj
  end
end

# == Schema Information
#
# Table name: users
#
#  id                       :integer         not null, primary key
#  email                    :string(255)     default("")
#  encrypted_password       :string(255)
#  confirmation_token       :string(255)
#  confirmed_at             :datetime
#  confirmation_sent_at     :datetime
#  reset_password_token     :string(255)
#  reset_password_sent_at   :datetime
#  remember_token           :string(255)
#  remember_created_at      :datetime
#  sign_in_count            :integer         default(0)
#  current_sign_in_at       :datetime
#  last_sign_in_at          :datetime
#  current_sign_in_ip       :string(255)
#  last_sign_in_ip          :string(255)
#  failed_attempts          :integer         default(0)
#  unlock_token             :string(255)
#  locked_at                :datetime
#  authentication_token     :string(255)
#  password_salt            :string(255)
#  created_at               :datetime
#  updated_at               :datetime
#  deleted_at               :datetime
#  username                 :string(255)
#  library_id               :integer         default(1), not null
#  user_group_id            :integer         default(1), not null
#  reserves_count           :integer         default(0), not null
#  expired_at               :datetime
#  libraries_count          :integer         default(0), not null
#  bookmarks_count          :integer         default(0), not null
#  checkouts_count          :integer         default(0), not null
#  checkout_icalendar_token :string(255)
#  questions_count          :integer         default(0), not null
#  answers_count            :integer         default(0), not null
#  answer_feed_token        :string(255)
#  due_date_reminder_days   :integer         default(1), not null
#  note                     :text
#  share_bookmarks          :boolean         default(FALSE), not null
#  save_search_history      :boolean         default(FALSE), not null
#  save_checkout_history    :boolean         default(FALSE), not null
#  required_role_id         :integer         default(1), not null
#  keyword_list             :text
#  user_number              :string(255)
#  state                    :string(255)
#  required_score           :integer         default(0), not null
#  locale                   :string(255)
#  openid_identifier        :string(255)
#  oauth_token              :string(255)
#  oauth_secret             :string(255)
#  enju_access_key          :string(255)
#  unable                   :boolean
#

