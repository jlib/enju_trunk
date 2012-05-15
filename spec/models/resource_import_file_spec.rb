# -*- encoding: utf-8 -*-
require 'spec_helper'

describe ResourceImportFile do
  fixtures :all
  use_vcr_cassette "enju_ndl/ndl_search", :record => :new_episodes

  describe "when its mode is 'create'" do
    describe "when it is written in utf-8" do
      before(:each) do
        @file = ResourceImportFile.create :resource_import => File.new("#{Rails.root.to_s}/examples/resource_import_file_sample1.tsv")
      end

      it "should be imported" do
        old_manifestations_count = Manifestation.count
        old_items_count = Item.count
        old_patrons_count = Patron.count
        old_import_results_count = ResourceImportResult.count
        @file.import_start.should eq({:manifestation_imported => 7, :item_imported => 6, :manifestation_found => 4, :item_found => 3, :failed => 5})
        manifestation = Item.where(:item_identifier => '11111').first.manifestation
        manifestation.publishers.first.full_name.should eq 'test4'
        manifestation.publishers.first.full_name_transcription.should eq 'てすと4'
        manifestation.publishers.second.full_name_transcription.should eq 'てすと5'
        Manifestation.count.should eq old_manifestations_count + 7
        Item.count.should eq old_items_count + 6
        Patron.count.should eq old_patrons_count + 5
        ResourceImportResult.count.should eq old_import_results_count + 16
        Item.find_by_item_identifier('10101').manifestation.creators.size.should eq 2
        # 以下2行に関しては、timestampで比較すると通らないため文字型変換してから比較をしている。
        Item.find_by_item_identifier('10101').manifestation.date_of_publication.to_s.should eq Time.zone.parse('2001-12-31').end_of_month.to_s
        Item.find_by_item_identifier('10102').manifestation.date_of_publication.to_s.should eq Time.zone.parse('2001-01-31').end_of_month.to_s
        Item.find_by_item_identifier('10104').manifestation.date_of_publication.should eq Time.zone.parse('2001-01-01')
        Manifestation.find_by_identifier('103').original_title.should eq 'ダブル"クォート"を含む資料'
        item = Item.find_by_item_identifier('11111')
        Shelf.find_by_name('first_shelf').should eq item.shelf
        item.manifestation.price.should eq 1000
        item.price.should eq 0
        item.manifestation.publishers.size.should eq 2
        @file.file_hash.should be_true
      end
    end

    describe "when it is written in shift_jis" do
      before(:each) do
        @file = ResourceImportFile.create :resource_import => File.new("#{Rails.root.to_s}/examples/resource_import_file_sample2.tsv")
      end

      it "should be imported" do
        old_manifestations_count = Manifestation.count
        old_items_count = Item.count
        old_patrons_count = Patron.count
        old_import_results_count = ResourceImportResult.count
        @file.import_start.should eq({:manifestation_imported => 7, :item_imported => 6, :manifestation_found => 4, :item_found => 3, :failed => 5})
        manifestation = Item.where(:item_identifier => '11111').first.manifestation
        manifestation.publishers.first.full_name.should eq 'test4'
        manifestation.publishers.first.full_name_transcription.should eq 'てすと4'
        manifestation.publishers.second.full_name_transcription.should eq 'てすと5'
        Manifestation.count.should eq old_manifestations_count + 7
        Item.count.should eq old_items_count + 6
        Patron.count.should eq old_patrons_count + 5
        ResourceImportResult.count.should eq old_import_results_count + 16
        Item.find_by_item_identifier('10101').manifestation.creators.size.should eq 2
        # 以下2行に関しては、timestampで比較すると通らないため文字型変換してから比較をしている。
        Item.find_by_item_identifier('10101').manifestation.date_of_publication.to_s.should eq Time.zone.parse('2001-12-31').end_of_month.to_s
        Item.find_by_item_identifier('10102').manifestation.date_of_publication.to_s.should eq Time.zone.parse('2001-01-31').end_of_month.to_s
        Item.find_by_item_identifier('10104').manifestation.date_of_publication.should eq Time.zone.parse('2001-01-01')
        Manifestation.find_by_identifier('103').original_title.should eq 'ダブル"クォート"を含む資料'
        item = Item.find_by_item_identifier('11111')
        Shelf.find_by_name('first_shelf').should eq item.shelf
        item.manifestation.price.should eq 1000
        item.price.should eq 0
        item.manifestation.publishers.size.should eq 2
        @file.file_hash.should be_true
      end
    end

    describe "when it has only isbn" do
      before(:each) do
        @file = ResourceImportFile.create :resource_import => File.new("#{Rails.root.to_s}/examples/isbn_sample.txt")
      end

      it "should be imported" do
        old_manifestations_count = Manifestation.count
        old_patrons_count = Patron.count
        @file.import_start
        Manifestation.count.should eq old_manifestations_count + 1
        Patron.count.should eq old_patrons_count + 4
      end
    end
  end

  describe "when its mode is 'update'" do
    it "should update items" do
      @file = ResourceImportFile.create :resource_import => File.new("#{Rails.root.to_s}/examples/item_update_file.tsv")
      @file.modify
      Item.where(:item_identifier => '00001').first.manifestation.creators.collect(&:full_name).should eq ['たなべ', 'こうすけ']
      Item.where(:item_identifier => '00001').first.manifestation.contributors.collect(&:full_name).should eq ['test1']
      Item.where(:item_identifier => '00002').first.manifestation.contributors.collect(&:full_name).should eq ['test2']
      Item.where(:item_identifier => '00003').first.manifestation.original_title.should eq 'テスト3'
    end
  end

  describe "when its mode is 'destroy'" do
    it "should remove items" do
      old_count = Item.count
      @file = ResourceImportFile.create :resource_import => File.new("#{Rails.root.to_s}/examples/item_delete_file.tsv")
      @file.remove
      Item.count.should eq old_count - 2
    end
  end
end

# == Schema Information
#
# Table name: resource_import_files
#
#  id                           :integer         not null, primary key
#  parent_id                    :integer
#  content_type                 :string(255)
#  size                         :integer
#  file_hash                    :string(255)
#  user_id                      :integer
#  note                         :text
#  executed_at                  :datetime
#  state                        :string(255)
#  resource_import_file_name    :string(255)
#  resource_import_content_type :string(255)
#  resource_import_file_size    :integer
#  resource_import_updated_at   :datetime
#  created_at                   :datetime        not null
#  updated_at                   :datetime        not null
#  edit_mode                    :string(255)
#  resource_import_fingerprint  :string(255)
#

