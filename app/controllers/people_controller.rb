class PeopleController < ApplicationController
  before_action :data_check, :build_request, except: :postcode_lookup

  ROUTE_MAP = {
    show:              proc { |params| ParliamentHelper.parliament_request.people(params[:person_id]) },
    lookup:            proc { |params| ParliamentHelper.parliament_request.people.lookup(params[:source], params[:id]) }
  }.freeze

  def show
    @postcode = flash[:postcode]

    @person, @seat_incumbencies, @house_incumbencies = RequestHelper.filter_response_data(
      @request,
      'http://id.ukpds.org/schema/Person',
      'http://id.ukpds.org/schema/SeatIncumbency',
      'http://id.ukpds.org/schema/HouseIncumbency'
    )

    @person = @person.first

    @current_party_membership = @person.party_memberships.select(&:current?).first

    sorted_incumbencies = Parliament::NTriple::Utils.sort_by({
      list:             @person.incumbencies,
      parameters:       [:end_date],
      prepend_rejected: false
    })

    @most_recent_incumbency = sorted_incumbencies.last
    @current_incumbency = @most_recent_incumbency && @most_recent_incumbency.current? ? @most_recent_incumbency : nil

    return unless @postcode && @current_incumbency

    begin
      response = PostcodeHelper.lookup(@postcode)
      @postcode_constituency = response.filter('http://id.ukpds.org/schema/ConstituencyGroup').first
      postcode_correct = @postcode_constituency.graph_id == @current_incumbency.constituency.graph_id
      @postcode_constituency.correct = postcode_correct
    rescue PostcodeHelper::PostcodeError => error
      flash[:error] = error.message
      @postcode = nil
    end
  end

  def lookup
    @person = @request.get.first

    redirect_to person_path(@person.graph_id)
  end

  def postcode_lookup
    flash[:postcode] = params[:postcode]

    redirect_to person_path(params[:person_id])
  end
end
