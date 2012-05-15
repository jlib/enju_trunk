class ResourceImportResultsController < InheritedResources::Base
  respond_to :html, :json, :csv
  before_filter :access_denied, :except => [:index, :show]
  load_and_authorize_resource
  has_scope :file_id

  def index
    @resource_import_file = ResourceImportFile.where(:id => params[:resource_import_file_id]).first
    if @resource_import_file
      if params[:display_result] && params[:display_result] == "has_msg"
        @resource_import_results = @resource_import_file.resource_import_results.where("error_msg is not null")
      else
        @resource_import_results = @resource_import_file.resource_import_results 
      end
    end
    @results_num = @resource_import_results.length
    @resource_import_results = @resource_import_results.page(params[:page]) unless params[:format] == 'tsv'

    if params[:format] == 'tsv'
      respond_to do |format|
        format.tsv { send_data ResourceImportResult.get_resource_import_results_tsv(@resource_import_results), :filename => configatron.resource_import_results_print_tsv.filename }
      end
    end
  end
end
