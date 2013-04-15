require_dependency "v1/application_controller"

#TODO: eliminate new duplication between resources here and break this into ItemsController and CollectionsController (to invert the current topology)
#TODO: Consider handling all our own exception classes in a: rescue_from SearchError

module V1
  class SearchController < ApplicationController
    before_filter :authenticate!, :except => [:repo_status]  #, :links  #links is just here for testing auth
    rescue_from Errno::ECONNREFUSED, :with => :connection_refused
    rescue_from Exception, :with => :generic_exception_handler

    def authenticate!
      if !authenticate_api_key(params['api_key'])
        logger.info "UnauthorizedSearchError for api_key: #{ params['api_key'] || '(none)' }"
        render_error(UnauthorizedSearchError.new, params)
      end
      # Delete this key now that we're done with it
      params.delete 'api_key'
    end

    def cache_key(params)
      # cache without api_key, callback, _, controller, action params keys
      excluded = %w( api_key callback _ controller action )
      key_hash = params.dup
      key_hash.delete_if {|k| excluded.include? k }
      key_hash
    end

    def items
      begin
        Rails.logger.debug "CK!: #{ cache_key(params) }"

        results = nil
#        Rails.cache.fetch(cache_key(params), :raw => true) do
#          Rails.logger.debug "CACHE M!SS...."
          results = Item.search(params).to_json
#        end
        render :json => render_as_json(results, params)
      rescue SearchError => e
        render_error(e, params)
      end
    end

    def fetch
      begin
        results = nil
        results = Item.fetch(params[:ids].split(/,\s*/)).to_json
        render :json => render_as_json(results, params)
      rescue NotFoundSearchError => e
        render_error(e, params)
      end
    end

    def collections
      
      begin
        results = nil
        results = Collection.search(params).to_json
        render :json => render_as_json(results, params)
      rescue SearchError => e
        render_error(e, params)
      end
    end

    def fetch_collections
      begin
        results = nil
        results = Collection.fetch(params[:ids].split(/,\s*/)).to_json
        render :json => render_as_json(results, params)
      rescue NotFoundSearchError => e
        render_error(e, params)
      end

    end

    def render_as_json(results, params)
      # Handles optional JSONP callback param
      if params['callback'].present?
        params['callback'] + '(' + results.to_s + ')'
      else
        results
      end
    end

    def render_json(results, params)
      # Handles optional JSONP callback param
      if params['callback'].present?
        params['callback'] + '(' + results.to_s + ')'
      else
        results
      end
    end

    def repo_status
      status = :ok
      message = nil

      begin
        response = JSON.parse(Repository.service_status(true))
        
        if response['doc_count'].to_s == ''
          status = :error
          message = response.to_s
        end
      rescue Errno::ECONNREFUSED => e
        status = :service_unavailable
        message = e.to_s
      rescue => e
        status = :error
        message = e.to_s
      end

      logger.warn "REPO_STATUS Check: #{message}" if message
      head status
    end
    
    def connection_refused(exception)
      logger.warn "search_controller#connection_refused handler firing"
      render_error(ServiceUnavailableSearchError.new, params)
    end
    
    def authenticate_api_key(key_id)
      logger.debug "API_AUTH: authenticate_key firing for key: '#{key_id}'"
      
      if Config.skip_key_auth_completely?
        logger.warn "API_AUTH: skip_key_auth_completely? is true"
        return true
      end

      if Config.accept_any_api_key? && key_id.to_s != ''
        logger.warn "API_AUTH: accept_any_api_key? is true and an API key is present"
        return true
      end

      #TODO: Rails.cache this
      begin
        return Repository.authenticate_api_key(key_id)
      rescue Errno::ECONNREFUSED
        # Avoid refusing api auth if we could not connect to the api auth server
        logger.warn "API_AUTH: Connection Refused trying to auth api key '#{key_id}'"
        return true
      end
    end    

    def generic_exception_handler(exception)
      logger.warn "#{self.class}.generic_exception_handler firing for: #{exception.class}: #{exception}"
      render_error(InternalServerSearchError.new, params)
    end

    def render_error(e, params)
      render :json => render_json({:message => e.message}, params), :status => e.http_status
    end

    def links; end

  end
end
